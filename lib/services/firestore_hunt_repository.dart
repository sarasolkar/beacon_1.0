import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/evidence_submission.dart';
import '../models/hunt.dart';
import '../models/hunter_proximity.dart';
import '../models/hunt_room.dart';
import '../models/participant.dart';
import '../models/hint_item.dart';
import '../models/hint_progress.dart';
import 'location_service.dart';
import 'hunt_repository.dart';

/// Generates a unique 5-character alphanumeric room code.
String _generateRoomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random.secure();
  return List.generate(5, (_) => chars[rng.nextInt(chars.length)]).join();
}

class _HuntInfo {
  final DateTime? startedAt;
  final int totalHints;
  const _HuntInfo({required this.startedAt, required this.totalHints});
}

/// Firestore-only repository (no Cloud Functions, no Cloud Storage), so it
/// works on the free Spark plan.
class FirestoreHuntRepository implements HuntRepository {
  final FirebaseFirestore _firestore;

  /// Firestore documents are limited to 1 MiB, so the reference photo must be
  /// small. The picker is configured to produce roughly 100-200 KB.
  static const int _maxReferenceImageBytes = 700 * 1024;

  final Map<String, (double, double)> _targetCache = {};
  final Map<String, _HuntInfo> _huntInfoCache = {};
  final Map<String, List<String>> _hintTextCache = {};
  final Map<String, DateTime> _lastDistanceWrite = {};
  final Map<String, bool> _lastZoneState = {};
  final Map<String, int> _hintsSynced = {};

  FirestoreHuntRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Collection references ──────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _hunts =>
      _firestore.collection('hunts');

  DocumentReference<Map<String, dynamic>> _huntDoc(String roomCode) =>
      _hunts.doc(roomCode);

  CollectionReference<Map<String, dynamic>> _participants(String roomCode) =>
      _huntDoc(roomCode).collection('participants');

  // ── Create hunt room ───────────────────────────────────────────────────────

  @override
  Future<HuntRoom> createHuntRoom({
    required Hunt hunt,
    required String hiderId,
    required String hiderName,
    Uint8List? referenceImageBytes,
  }) async {
    // Generate a unique room code (retry if collision).
    String roomCode = _generateRoomCode();
    for (int attempt = 0; attempt < 5; attempt++) {
      final existing = await _huntDoc(roomCode).get();
      if (!existing.exists) break;
      roomCode = _generateRoomCode();
    }

    final now = Timestamp.now();
    final batch = _firestore.batch();
    final huntRef = _huntDoc(roomCode);

    // The photo is stored inside Firestore (small, compressed) instead of
    // Cloud Storage, which needs a paid plan.
    String? referenceImageMarker;
    if (referenceImageBytes != null &&
        referenceImageBytes.length <= _maxReferenceImageBytes) {
      batch.set(huntRef.collection('media').doc('reference_image'), {
        'bytes': Blob(referenceImageBytes),
        'contentType': 'image/jpeg',
        'createdAt': now,
      });
      referenceImageMarker = 'firestore:reference_image';
    } else if (referenceImageBytes != null) {
      debugPrint(
        'Reference image skipped: ${referenceImageBytes.length} bytes is too large.',
      );
    }

    // Main hunt document (readable by hider + participants).
    batch.set(huntRef, {
      'roomCode': roomCode,
      'hiderId': hiderId,
      'hiderName': hiderName,
      'name': hunt.name,
      'difficulty': hunt.difficulty.name,
      'reward': hunt.reward,
      'referenceImageUrl': referenceImageMarker,
      'status': RoomStatus.waiting.name,
      'createdAt': now,
      'startedAt': null,
      'completedAt': null,
      'hints': hunt.hints
          .map(
            (h) => {
              'id': h.id,
              'unlockDistanceMeters': h.unlockDistanceMeters,
              'label': h.label,
            },
          )
          .toList(),
      'locationQuestions': hunt.locationQuestions,
    });

    // Hider-only secrets (coordinates, hint texts, expected answers).
    batch.set(huntRef.collection('secret').doc('target_coordinates'), {
      'locationCoordinates': hunt.locationCoordinates,
      'hints': hunt.hints.map((hint) => hint.text).toList(),
      'locationAnswers': hunt.locationAnswers,
      'createdAt': now,
    });

    // Target location for hunters. Rules only let participants read it while
    // the hunt is active; the app computes distance and bearing from it.
    batch.set(huntRef.collection('target').doc('location'), {
      'locationCoordinates': hunt.locationCoordinates,
      'createdAt': now,
    });

    // One doc per hint so Firestore rules can release each one on schedule.
    for (var i = 0; i < hunt.hints.length; i++) {
      batch.set(huntRef.collection('hints').doc('hint_$i'), {
        'index': i,
        'text': hunt.hints[i].text,
        'unlockSeconds': HintProgress
            .unlockSchedule[min(i, HintProgress.unlockSchedule.length - 1)]
            .inSeconds,
      });
    }

    await batch.commit();

    return HuntRoom(
      roomCode: roomCode,
      hunt: hunt.copyWith(
        code: roomCode,
        referenceImageUrl: referenceImageMarker,
      ),
      hiderId: hiderId,
      hiderName: hiderName,
      status: RoomStatus.waiting,
      createdAt: now.toDate(),
    );
  }

  // ── Reference photo (stored in Firestore) ──────────────────────────────────

  @override
  Future<Uint8List?> getReferenceImage(String roomCode) async {
    try {
      final snap = await _huntDoc(
        roomCode.toUpperCase(),
      ).collection('media').doc('reference_image').get();
      final bytes = snap.data()?['bytes'];
      if (bytes is Blob) return bytes.bytes;
    } catch (error) {
      debugPrint('Could not load reference image: $error');
    }
    return null;
  }

  // ── Get room by code ───────────────────────────────────────────────────────

  @override
  Future<HuntRoom?> getRoomByCode(String roomCode) async {
    final doc = await _huntDoc(roomCode.toUpperCase()).get();
    if (!doc.exists || doc.data() == null) return null;
    return _mapDocToRoom(doc);
  }

  @override
  Future<List<HuntRoom>> getCurrentHuntsForUser(String userId) async {
    // Track unique rooms by roomCode to avoid duplicates.
    final Map<String, HuntRoom> roomsByCode = {};
    Object? firstError;

    // 1. Hunts where this user is the hider.
    try {
      final hiderQuery = await _hunts
          .where('hiderId', isEqualTo: userId)
          .get();
      for (final doc in hiderQuery.docs) {
        try {
          final room = _mapDocToRoom(doc);
          roomsByCode[room.roomCode] = room;
        } catch (e) {
          firstError ??= e; // skip one malformed doc, keep the rest
        }
      }
    } catch (e) {
      firstError ??= e;
    }

    // 2. Hunts where this user is a participant (hunter).
    //    Needs the COLLECTION_GROUP index on participants.id
    //    (firestore.indexes.json) to be DEPLOYED. If it is missing this must
    //    not hide the hunts the user created, so it is isolated here.
    try {
      final participantQuery = await _firestore
          .collectionGroup('participants')
          .where('id', isEqualTo: userId)
          .get();
      final participantRoomCodes = participantQuery.docs
          .map((doc) => doc.reference.parent.parent?.id)
          .whereType<String>()
          .toSet();

      for (final roomCode in participantRoomCodes) {
        if (roomsByCode.containsKey(roomCode)) continue;
        try {
          final doc = await _huntDoc(roomCode).get();
          if (doc.exists && doc.data() != null) {
            roomsByCode[roomCode] = _mapDocToRoom(doc);
          }
        } catch (e) {
          firstError ??= e;
        }
      }
    } catch (e) {
      firstError ??= e;
    }

    // If nothing loaded AND something failed, surface the real error so the
    // UI shows it instead of a misleading "No hunts yet".
    if (roomsByCode.isEmpty && firstError != null) {
      throw firstError;
    }

    final rooms = roomsByCode.values.toList();
    return rooms..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ── Stream single room ─────────────────────────────────────────────────────

  @override
  Stream<HuntRoom?> streamRoom(String roomCode) {
    final code = roomCode.toUpperCase();
    return Stream.multi((controller) {
      HuntRoom? currentRoom;
      List<HunterParticipant> currentParticipants = [];
      var roomLoaded = false;
      var participantsLoaded = false;

      void emitRoom() {
        if (!roomLoaded || !participantsLoaded) return;
        if (currentRoom != null) {
          currentRoom!.participants
            ..clear()
            ..addAll(currentParticipants);
        }
        controller.add(currentRoom);
      }

      final roomSubscription = _huntDoc(code).snapshots().listen((snap) {
        currentRoom = snap.exists && snap.data() != null
            ? _mapDocToRoom(snap)
            : null;
        roomLoaded = true;
        emitRoom();
      }, onError: controller.addError);
      final participantsSubscription = streamParticipants(code).listen((
        participants,
      ) {
        currentParticipants = participants;
        participantsLoaded = true;
        emitRoom();
      }, onError: controller.addError);

      controller.onCancel = () async {
        await roomSubscription.cancel();
        await participantsSubscription.cancel();
      };
    });
  }

  // ── Stream participants ────────────────────────────────────────────────────

  @override
  Stream<List<HunterParticipant>> streamParticipants(String roomCode) {
    return _participants(roomCode.toUpperCase())
        .orderBy('joinedAt')
        .snapshots()
        .map((snap) => snap.docs.map(_mapDocToParticipant).toList());
  }

  // ── Join room ──────────────────────────────────────────────────────────────

  @override
  Future<bool> joinRoom({
    required String roomCode,
    required HunterParticipant participant,
  }) async {
    final code = roomCode.toUpperCase();
    final huntDoc = await _huntDoc(code).get();
    if (!huntDoc.exists) return false;

    final data = huntDoc.data()!;
    final status = RoomStatus.values.byName(
      data['status'] as String? ?? 'waiting',
    );
    if (status == RoomStatus.completed) return false;

    final participantRef = _participants(code).doc(participant.id);
    final existingParticipant = await participantRef.get();
    if (existingParticipant.exists) {
      await participantRef.update({
        'name': participant.name,
        'avatarUrl': participant.avatarUrl,
        'lastActive': FieldValue.serverTimestamp(),
      });
      return true;
    }

    await participantRef.set({
      'id': participant.id,
      'name': participant.name,
      'avatarUrl': participant.avatarUrl,
      'distanceMeters': participant.distanceMeters,
      'status': status == RoomStatus.active
          ? ParticipantStatus.active.name
          : participant.status.name,
      'hintsUnlocked': participant.hintsUnlocked,
      'foundAt': null,
      'joinedAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    });
    return true;
  }

  // ── Hunt lifecycle ─────────────────────────────────────────────────────────

  @override
  Future<void> startHunt(String roomCode) async {
    final huntRef = _huntDoc(roomCode.toUpperCase());
    await _firestore.runTransaction((transaction) async {
      final hunt = await transaction.get(huntRef);
      if (!hunt.exists) throw StateError('Hunt room does not exist.');
      if (hunt.get('status') == RoomStatus.active.name) return;
      if (hunt.get('status') != RoomStatus.waiting.name) {
        throw StateError('A completed hunt cannot be started again.');
      }
      transaction.update(huntRef, {
        'status': RoomStatus.active.name,
        'startedAt': FieldValue.serverTimestamp(),
      });
    });

    // Mark all waiting participants as active.
    final parts = await _participants(
      roomCode.toUpperCase(),
    ).where('status', isEqualTo: ParticipantStatus.waiting.name).get();
    final batch = _firestore.batch();
    for (final doc in parts.docs) {
      batch.update(doc.reference, {'status': ParticipantStatus.active.name});
    }
    await batch.commit();
  }

  @override
  Future<void> endHunt(String roomCode) async {
    final huntRef = _huntDoc(roomCode.toUpperCase());
    await _firestore.runTransaction((transaction) async {
      final hunt = await transaction.get(huntRef);
      if (!hunt.exists || hunt.get('status') == RoomStatus.completed.name) {
        return;
      }
      transaction.update(huntRef, {
        'status': RoomStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Update hunter distance ─────────────────────────────────────────────────

  @override
  Future<void> updateHunterDistance({
    required String roomCode,
    required String hunterId,
    required double distanceMeters,
  }) async {
    final code = roomCode.toUpperCase();
    final docRef = _participants(code).doc(hunterId);

    await docRef.update({
      'distanceMeters': distanceMeters,
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  // ── Proximity & hints (computed in the app, no Cloud Functions) ────────────

  Future<_HuntInfo> _loadHuntInfo(String code) async {
    final cached = _huntInfoCache[code];
    if (cached != null && cached.startedAt != null) return cached;

    final snap = await _huntDoc(code).get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('This hunt no longer exists.');
    }
    if (data['status'] != RoomStatus.active.name) {
      throw StateError('This hunt is not active.');
    }
    final rawHints = data['hints'];
    final info = _HuntInfo(
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      totalHints: rawHints is List ? min(rawHints.length, 3) : 3,
    );
    _huntInfoCache[code] = info;
    return info;
  }

  Future<(double, double)> _loadTarget(String code) async {
    final cached = _targetCache[code];
    if (cached != null) return cached;

    final snap = await _huntDoc(
      code,
    ).collection('target').doc('location').get();
    final parsed = LocationService.parseCoordinates(
      snap.data()?['locationCoordinates'] as String?,
    );
    if (parsed == null) {
      throw StateError('The hider has not saved a valid hunt location.');
    }
    _targetCache[code] = parsed;
    return parsed;
  }

  Future<List<String>> _readUnlockedHints(
    String code,
    _HuntInfo info,
    bool withinZone,
  ) async {
    final texts = _hintTextCache.putIfAbsent(code, () => <String>[]);
    // Hints already read stay unlocked even if the hunter later leaves the zone.
    final progress = HintProgress.calculate(
      startedAt: info.startedAt,
      isWithinSearchZone: withinZone,
      totalHints: info.totalHints,
      alreadyUnlocked: texts.length,
    );
    while (texts.length < progress.unlockedCount) {
      try {
        final snap = await _huntDoc(
          code,
        ).collection('hints').doc('hint_${texts.length}').get();
        final text = snap.data()?['text'];
        if (text is! String) break;
        texts.add(text);
      } on FirebaseException catch (e) {
        // Rules release a hint only once the server clock says it is due. If
        // this device's clock is slightly ahead, try again on the next update.
        if (e.code == 'permission-denied') break;
        rethrow;
      }
    }
    return List<String>.from(texts.take(progress.unlockedCount));
  }

  /// Records how many hints this hunter has unlocked so the hider's dashboard
  /// ("x/3 Hints Unlocked") stays accurate. It only ever increases.
  Future<void> _syncHintsUnlocked(
    String code,
    String hunterId,
    int count,
  ) async {
    if (count <= (_hintsSynced[code] ?? 0)) return;
    _hintsSynced[code] = count; // set first so a failure is not retried forever
    try {
      await _participants(code).doc(hunterId).update({'hintsUnlocked': count});
    } catch (error) {
      debugPrint('Could not sync hints unlocked: $error');
    }
  }

  @override
  Future<HunterProximity> updateHunterPosition({
    required String roomCode,
    required String hunterId,
    required double latitude,
    required double longitude,
  }) async {
    final code = roomCode.toUpperCase();
    final info = await _loadHuntInfo(code);
    final target = await _loadTarget(code);

    final distance = LocationService.calculateDistanceMeters(
      startLatitude: latitude,
      startLongitude: longitude,
      endLatitude: target.$1,
      endLongitude: target.$2,
    );
    final bearing = LocationService.calculateBearingDegrees(
      startLatitude: latitude,
      startLongitude: longitude,
      endLatitude: target.$1,
      endLongitude: target.$2,
    );
    final withinZone = HintProgress.isWithinSearchZone(distance);

    // Persist the distance (the hider's dashboard and the evidence rules read
    // it), but not on every GPS tick.
    final now = DateTime.now();
    final lastWrite = _lastDistanceWrite[code];
    if (lastWrite == null ||
        _lastZoneState[code] != withinZone ||
        now.difference(lastWrite) >= const Duration(seconds: 5)) {
      await _participants(code).doc(hunterId).update({
        'distanceMeters': distance,
        'lastActive': FieldValue.serverTimestamp(),
      });
      _lastDistanceWrite[code] = now;
      _lastZoneState[code] = withinZone;
    }

    final unlocked = await _readUnlockedHints(code, info, withinZone);
    await _syncHintsUnlocked(code, hunterId, unlocked.length);
    return HunterProximity(
      distanceMeters: distance,
      bearingDegrees: bearing,
      isWithinSearchZone: withinZone,
      huntStartedAt: info.startedAt,
      unlockedHints: unlocked,
    );
  }

  @override
  Future<List<String>> getUnlockedHints({
    required String roomCode,
    required String hunterId,
  }) async {
    final code = roomCode.toUpperCase();
    final info = await _loadHuntInfo(code);
    final me = await _participants(code).doc(hunterId).get();
    if (!me.exists) throw StateError('Join this hunt before requesting hints.');
    final distance = (me.data()?['distanceMeters'] as num?)?.toDouble();
    final unlocked = await _readUnlockedHints(
      code,
      info,
      HintProgress.isWithinSearchZone(distance),
    );
    await _syncHintsUnlocked(code, hunterId, unlocked.length);
    return unlocked;
  }

  // ── Submit evidence (Phase 3: Q&A Verification) ──────────────────────────

  @override
  Future<bool> submitEvidence({
    required String roomCode,
    required String hunterId,
    required String hunterName,
    Uint8List? photoBytes,
    required double currentDistanceMeters,
    List<String> questions = const [],
    List<String> answers = const [],
  }) async {
    final code = roomCode.toUpperCase();
    final now = Timestamp.now();
    final submissionRef = _huntDoc(code).collection('evidence').doc(hunterId);

    List<String> resolvedQuestions = questions;
    if (resolvedQuestions.isEmpty) {
      final huntSnap = await _huntDoc(code).get();
      resolvedQuestions = List<String>.from(
        huntSnap.data()?['locationQuestions'] ?? Hunt.defaultQuestions(),
      );
    }

    // Save pending submission record in Firestore (zero Storage requirement!)
    await submissionRef.set({
      'id': hunterId,
      'roomCode': code,
      'hunterId': hunterId,
      'hunterName': hunterName,
      'photoUrl': '',
      // The hunter's photo is stored inside Firestore (no Cloud Storage).
      'photo': (photoBytes != null && photoBytes.length <= _maxReferenceImageBytes)
          ? Blob(photoBytes)
          : null,
      'questions': resolvedQuestions,
      'answers': answers,
      'distanceMeters': currentDistanceMeters,
      'status': SubmissionStatus.pending.name,
      'submittedAt': now,
      'rejectionReason': null,
      'reviewedAt': null,
    });

    // Update participant status to pendingApproval
    await _participants(code).doc(hunterId).update({
      'status': ParticipantStatus.pendingApproval.name,
      'lastActive': FieldValue.serverTimestamp(),
    });

    return true;
  }

  @override
  Future<List<String>> getExpectedAnswers(String roomCode) async {
    try {
      final secretSnap = await _huntDoc(roomCode.toUpperCase())
          .collection('secret')
          .doc('target_coordinates')
          .get();
      if (secretSnap.exists && secretSnap.data() != null) {
        final list = secretSnap.data()!['locationAnswers'];
        if (list is List) {
          return list.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    return Hunt.defaultAnswers();
  }

  // ── Stream submissions for Hider review ────────────────────────────────────

  @override
  Stream<List<EvidenceSubmission>> streamSubmissions(String roomCode) {
    return _huntDoc(roomCode.toUpperCase())
        .collection('evidence')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => _mapDocToSubmission(doc, roomCode))
              .toList(),
        );
  }

  @override
  Stream<EvidenceSubmission?> streamHunterSubmission(
    String roomCode,
    String hunterId,
  ) {
    return _huntDoc(roomCode.toUpperCase())
        .collection('evidence')
        .doc(hunterId)
        .snapshots()
        .map(
          (snap) => snap.exists && snap.data() != null
              ? _mapDocToSubmission(snap, roomCode)
              : null,
        );
  }

  // ── Approve submission and complete the hunt ──────────────────────────────

  @override
  Future<bool> approveSubmission({
    required String roomCode,
    required String submissionId,
    required String hunterId,
  }) async {
    final code = roomCode.toUpperCase();
    final submissionRef = _huntDoc(code).collection('evidence').doc(hunterId);
    final participantRef = _participants(code).doc(hunterId);
    final huntRef = _huntDoc(code);

    return _firestore.runTransaction((transaction) async {
      final subSnap = await transaction.get(submissionRef);
      if (!subSnap.exists) return false;

      final data = subSnap.data()!;
      if (data['status'] == SubmissionStatus.approved.name) {
        return true;
      }
      final huntSnap = await transaction.get(huntRef);
      if (!huntSnap.exists ||
          huntSnap.data()?['status'] != RoomStatus.active.name) {
        return false;
      }

      final partSnap = await transaction.get(participantRef);
      if (!partSnap.exists) return false;

      final now = FieldValue.serverTimestamp();
      transaction.update(submissionRef, {
        'status': SubmissionStatus.approved.name,
        'reviewedAt': now,
      });

      transaction.update(participantRef, {
        'status': ParticipantStatus.found.name,
        'foundAt': now,
        'lastActive': now,
      });
      transaction.update(huntRef, {
        'status': RoomStatus.completed.name,
        'completedAt': now,
        'winnerId': hunterId,
        'winnerName': data['hunterName'] as String? ?? 'Hunter',
        'winnerRole': 'hunter',
      });

      return true;
    });
  }

  // ── Reject Submission (Hider only, allows hunter to resubmit) ───────────────

  @override
  Future<bool> rejectSubmission({
    required String roomCode,
    required String submissionId,
    required String hunterId,
    String? reason,
  }) async {
    final code = roomCode.toUpperCase();
    final submissionRef = _huntDoc(code).collection('evidence').doc(hunterId);
    final participantRef = _participants(code).doc(hunterId);

    final batch = _firestore.batch();
    batch.update(submissionRef, {
      'status': SubmissionStatus.rejected.name,
      'rejectionReason': reason ?? 'Photo does not match the treasure cache.',
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    // Reset hunter back to active so they can resubmit another photo!
    batch.update(participantRef, {
      'status': ParticipantStatus.active.name,
      'lastActive': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return true;
  }

  EvidenceSubmission _mapDocToSubmission(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String roomCode,
  ) {
    final data = doc.data()!;
    return EvidenceSubmission(
      id: doc.id,
      roomCode: roomCode,
      hunterId: data['hunterId'] as String? ?? doc.id,
      hunterName: data['hunterName'] as String? ?? 'Hunter',
      photoUrl: data['photoUrl'] as String? ?? '',
      photoBytes: data['photo'] is Blob ? (data['photo'] as Blob).bytes : null,
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      status: SubmissionStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => SubmissionStatus.pending,
      ),
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rejectionReason: data['rejectionReason'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      questions: List<String>.from(data['questions'] ?? const []),
      answers: List<String>.from(data['answers'] ?? const []),
    );
  }

  // ── Mapping helpers ────────────────────────────────────────────────────────

  HuntRoom _mapDocToRoom(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    final rawHints = List<Map<String, dynamic>>.from(data['hints'] ?? []);
    final hints = rawHints
        .map(
          (h) => HintItem(
            id: h['id'] as String? ?? '',
            text: '',
            unlockDistanceMeters:
                (h['unlockDistanceMeters'] as num?)?.toDouble() ?? 100.0,
            label: h['label'] as String? ?? '',
          ),
        )
        .toList();

    final locationQuestions = List<String>.from(
      data['locationQuestions'] ?? Hunt.defaultQuestions(),
    );

    final hunt = Hunt(
      id: doc.id,
      code: doc.id,
      name: data['name'] as String? ?? '',
      locationCoordinates: '',
      difficulty: HuntDifficulty.values.byName(
        data['difficulty'] as String? ?? 'medium',
      ),
      reward: data['reward'] as String?,
      referenceImageUrl: data['referenceImageUrl'] as String?,
      hints: hints,
      locationQuestions: locationQuestions,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );

    return HuntRoom(
      roomCode: doc.id,
      hunt: hunt,
      hiderId: data['hiderId'] as String? ?? '',
      hiderName: data['hiderName'] as String? ?? '',
      status: RoomStatus.values.byName(data['status'] as String? ?? 'waiting'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      winnerId: data['winnerId'] as String?,
      winnerName: data['winnerName'] as String?,
      winnerRole: data['winnerRole'] as String?,
    );
  }

  HunterParticipant _mapDocToParticipant(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return HunterParticipant(
      id: data['id'] as String? ?? doc.id,
      name: data['name'] as String? ?? 'Unknown',
      avatarUrl: data['avatarUrl'] as String?,
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 300.0,
      status: ParticipantStatus.values.byName(
        data['status'] as String? ?? 'waiting',
      ),
      hintsUnlocked: data['hintsUnlocked'] as int? ?? 0,
      foundAt: (data['foundAt'] as Timestamp?)?.toDate(),
      lastActive:
          (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}