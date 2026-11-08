import '../core/game_config.dart';

class HintProgress {
  final int unlockedCount;
  final Duration? timeUntilNextHint;

  const HintProgress({
    required this.unlockedCount,
    required this.timeUntilNextHint,
  });

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
    final scheduledUnlocks = startedAt == null
        ? 0
        : (currentTime.difference(startedAt).inSeconds ~/
                  GameConfig.hintUnlockInterval.inSeconds)
              .clamp(0, totalHints)
              .toInt();
    final unlocked = [
      scheduledUnlocks,
      isWithinSearchZone && startedAt != null ? totalHints : 0,
      alreadyUnlocked,
    ].reduce((a, b) => a > b ? a : b).clamp(0, totalHints).toInt();
    final remaining = startedAt
        ?.add(GameConfig.hintUnlockInterval * (scheduledUnlocks + 1))
        .difference(currentTime);

    return HintProgress(
      unlockedCount: unlocked,
      timeUntilNextHint: unlocked < totalHints && remaining != null
          ? (remaining.isNegative ? Duration.zero : remaining)
          : null,
    );
  }
}
