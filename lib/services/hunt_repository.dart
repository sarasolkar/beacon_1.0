import 'dart:typed_data';
import '../models/evidence_submission.dart';
import '../models/hunt.dart';
import '../models/hunt_room.dart';
import '../models/hunter_proximity.dart';
import '../models/participant.dart';

abstract class HuntRepository {
  Future<HuntRoom> createHuntRoom({
    required Hunt hunt,
    required String hiderId,
    required String hiderName,
    Uint8List? referenceImageBytes,
  });

  Future<HuntRoom?> getRoomByCode(String roomCode);
  Future<List<HuntRoom>> getCurrentHuntsForUser(String userId);
  Stream<HuntRoom?> streamRoom(String roomCode);
  Stream<List<HunterParticipant>> streamParticipants(String roomCode);

  Future<bool> joinRoom({
    required String roomCode,
    required HunterParticipant participant,
  });

  Future<void> startHunt(String roomCode);
  Future<void> endHunt(String roomCode);

  Future<void> updateHunterDistance({
    required String roomCode,
    required String hunterId,
    required double distanceMeters,
  });

  Future<HunterProximity> updateHunterPosition({
    required String roomCode,
    required String hunterId,
    required double latitude,
    required double longitude,
  });

  Future<List<String>> getUnlockedHints({
    required String roomCode,
    required String hunterId,
  });

  Future<bool> submitEvidence({
    required String roomCode,
    required String hunterId,
    required String hunterName,
    Uint8List? photoBytes,
    required double currentDistanceMeters,
    List<String> questions,
    List<String> answers,
  });

  Future<List<String>> getExpectedAnswers(String roomCode);

  /// The hider's reference photo for [roomCode], or null if none was saved.
  Future<Uint8List?> getReferenceImage(String roomCode);

  Stream<List<EvidenceSubmission>> streamSubmissions(String roomCode);

  Stream<EvidenceSubmission?> streamHunterSubmission(
    String roomCode,
    String hunterId,
  );

  Future<bool> approveSubmission({
    required String roomCode,
    required String submissionId,
    required String hunterId,
  });

  Future<bool> rejectSubmission({
    required String roomCode,
    required String submissionId,
    required String hunterId,
    String? reason,
  });
}