import '../core/game_config.dart';

class HintProgress {
  final int unlockedCount;
  final Duration? timeUntilNextHint;

  const HintProgress({
    required this.unlockedCount,
    required this.timeUntilNextHint,
  });

  /// When each hint unlocks, measured from the start of the hunt.
  static const List<Duration> unlockSchedule = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  static bool isWithinSearchZone(double? distanceMeters) =>
      distanceMeters != null &&
      distanceMeters <= GameConfig.searchZoneRadiusMeters;

  factory HintProgress.calculate({
    required DateTime? startedAt,
    required bool isWithinSearchZone,
    DateTime? now,
    int totalHints = 3,
    int alreadyUnlocked = 0,
  }) {
    if (totalHints <= 0) {
      return const HintProgress(unlockedCount: 0, timeUntilNextHint: null);
    }

    final currentTime = now ?? DateTime.now();

    var scheduledUnlocks = 0;
    if (startedAt != null) {
      final elapsed = currentTime.difference(startedAt);
      for (var i = 0; i < unlockSchedule.length && i < totalHints; i++) {
        if (elapsed >= unlockSchedule[i]) scheduledUnlocks = i + 1;
      }
    }

    final zoneUnlocks = isWithinSearchZone && startedAt != null
        ? totalHints
        : 0;
    final unlocked = [
      scheduledUnlocks,
      zoneUnlocks,
      alreadyUnlocked,
    ].reduce((a, b) => a > b ? a : b).clamp(0, totalHints).toInt();

    Duration? timeUntilNext;
    if (startedAt != null &&
        unlocked < totalHints &&
        unlocked < unlockSchedule.length) {
      final remaining = startedAt
          .add(unlockSchedule[unlocked])
          .difference(currentTime);
      timeUntilNext = remaining.isNegative ? Duration.zero : remaining;
    }

    return HintProgress(
      unlockedCount: unlocked,
      timeUntilNextHint: timeUntilNext,
    );
  }
}