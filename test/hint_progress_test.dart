import 'package:flutter_test/flutter_test.dart';
import 'package:beacon/models/hint_progress.dart';

void main() {
  group('HintProgress', () {
    final start = DateTime.utc(2026, 1, 1);

    test('unlocks hints at one, two, and three minutes after hunt start', () {
      final atStart = HintProgress.calculate(
        startedAt: start,
        isWithinSearchZone: false,
        now: start,
      );
      final first = HintProgress.calculate(
        startedAt: start,
        isWithinSearchZone: false,
        now: start.add(const Duration(minutes: 1)),
      );
      final second = HintProgress.calculate(
        startedAt: start,
        isWithinSearchZone: false,
        now: start.add(const Duration(minutes: 2)),
      );
      final third = HintProgress.calculate(
        startedAt: start,
        isWithinSearchZone: false,
        now: start.add(const Duration(minutes: 3)),
      );

      expect(atStart.unlockedCount, 0);
      expect(atStart.timeUntilNextHint, const Duration(minutes: 1));
      expect(first.unlockedCount, 1);
      expect(first.timeUntilNextHint, const Duration(minutes: 1));
      expect(second.unlockedCount, 2);
      expect(second.timeUntilNextHint, const Duration(minutes: 1));
      expect(third.unlockedCount, 3);
      expect(third.timeUntilNextHint, isNull);
    });

    test('30 metres unlocks all hints and just beyond does not', () {
      expect(HintProgress.isWithinSearchZone(30), isTrue);
      expect(HintProgress.isWithinSearchZone(30.001), isFalse);
      expect(HintProgress.isWithinSearchZone(null), isFalse);

      final within = HintProgress.calculate(
        startedAt: start,
        isWithinSearchZone: HintProgress.isWithinSearchZone(30),
        now: start,
      );
      final beyond = HintProgress.calculate(
        startedAt: start,
        isWithinSearchZone: HintProgress.isWithinSearchZone(30.001),
        now: start,
      );

      expect(within.unlockedCount, 3);
      expect(within.timeUntilNextHint, isNull);
      expect(beyond.unlockedCount, 0);
    });

    test('unlocked hints remain unlocked after leaving the radius', () {
      final progress = HintProgress.calculate(
        startedAt: start,
        isWithinSearchZone: false,
        alreadyUnlocked: 3,
        now: start,
      );

      expect(progress.unlockedCount, 3);
    });

    test('missing hunt start and position do not unlock hints', () {
      final progress = HintProgress.calculate(
        startedAt: null,
        isWithinSearchZone: false,
        now: start.add(const Duration(minutes: 10)),
      );

      expect(progress.unlockedCount, 0);
      expect(progress.timeUntilNextHint, isNull);
    });
  });
}
