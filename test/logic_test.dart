import 'package:flutter_test/flutter_test.dart';
import 'package:beacon/core/game_config.dart';
import 'package:beacon/models/evidence_submission.dart';
import 'package:beacon/models/hint_progress.dart';
import 'package:beacon/models/hunt.dart';
import 'package:beacon/services/location_service.dart';

void main() {
  group('HintProgress', () {
    final start = DateTime(2026, 1, 1, 12);

    test('no hints unlock before the hunt starts', () {
      final progress = HintProgress.calculate(
        startedAt: null,
        isWithinSearchZone: false,
      );
      expect(progress.unlockedCount, 0);
    });

    test('hints unlock on schedule', () {
      final now = start.add(
        GameConfig.hintUnlockInterval * 2 + const Duration(seconds: 1),
      );
      final progress = HintProgress.calculate(
        startedAt: start,
        isWithinSearchZone: false,
        now: now,
      );
      expect(progress.unlockedCount, 2);
      expect(progress.timeUntilNextHint, isNotNull);
    });

    test('entering the search zone unlocks every hint', () {
      final progress = HintProgress.calculate(
        startedAt: start,
        isWithinSearchZone: true,
        now: start.add(const Duration(seconds: 5)),
      );
      expect(progress.unlockedCount, 3);
      expect(progress.timeUntilNextHint, isNull);
    });

    test('already unlocked hints are never re-locked', () {
      final progress = HintProgress.calculate(
        startedAt: start,
        isWithinSearchZone: false,
        now: start,
        alreadyUnlocked: 2,
      );
      expect(progress.unlockedCount, 2);
    });
  });

  group('LocationService', () {
    test('parses coordinates with N/S/E/W suffixes', () {
      final parsed = LocationService.parseCoordinates(
        '37.7749° N, 122.4194° W',
      );
      expect(parsed, isNotNull);
      expect(parsed!.$1, closeTo(37.7749, 1e-9));
      expect(parsed.$2, closeTo(-122.4194, 1e-9));
    });

    test('rejects invalid coordinates', () {
      expect(LocationService.parseCoordinates(''), isNull);
      expect(LocationService.parseCoordinates('hello'), isNull);
      expect(LocationService.parseCoordinates('95, 10'), isNull);
    });

    test('distance between identical points is zero', () {
      final distance = LocationService.calculateDistanceMeters(
        startLatitude: 37.7749,
        startLongitude: -122.4194,
        endLatitude: 37.7749,
        endLongitude: -122.4194,
      );
      expect(distance, closeTo(0, 0.01));
    });

    test('one degree of latitude is about 111 km', () {
      final distance = LocationService.calculateDistanceMeters(
        startLatitude: 0,
        startLongitude: 0,
        endLatitude: 1,
        endLongitude: 0,
      );
      expect(distance, closeTo(111195, 300));
    });

    test('bearing due north is 0 degrees', () {
      final bearing = LocationService.calculateBearingDegrees(
        startLatitude: 0,
        startLongitude: 0,
        endLatitude: 1,
        endLongitude: 0,
      );
      expect(bearing, closeTo(0, 0.01));
    });
  });

  group('Hunt', () {
    test('generated codes are 5 unambiguous characters', () {
      final pattern = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$');
      for (var i = 0; i < 50; i++) {
        expect(Hunt.generateCode(), matches(pattern));
      }
    });
  });

  group('EvidenceSubmission', () {
    test('survives a toMap / fromMap round trip', () {
      final original = EvidenceSubmission(
        id: 'hunter_1',
        roomCode: 'ABCDE',
        hunterId: 'hunter_1',
        hunterName: 'Sam',
        distanceMeters: 12.5,
        status: SubmissionStatus.rejected,
        rejectionReason: 'Wrong answer',
        questions: const ['Q1', 'Q2', 'Q3'],
        answers: const ['A1', 'A2', 'A3'],
      );

      final copy = EvidenceSubmission.fromMap(original.toMap());

      expect(copy.id, 'hunter_1');
      expect(copy.hunterName, 'Sam');
      expect(copy.distanceMeters, 12.5);
      expect(copy.isRejected, isTrue);
      expect(copy.rejectionReason, 'Wrong answer');
      expect(copy.questions, ['Q1', 'Q2', 'Q3']);
      expect(copy.answers, ['A1', 'A2', 'A3']);
    });
  });
}