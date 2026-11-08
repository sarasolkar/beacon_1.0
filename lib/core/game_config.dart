/// Central configuration for gameplay constants.
///
/// Change values here to tune behaviour without hunting through the codebase.
class GameConfig {
  GameConfig._();

  // ── Hint timing ────────────────────────────────────────────────────────────

  /// Time between hints after the first one is unlocked in the search zone.
  static const Duration hintUnlockInterval = Duration(minutes: 1);

  // ── Search-zone detection ──────────────────────────────────────────────────

  /// Distance threshold (metres) that defines the "In search zone" ring.
  ///
  /// Hunters within this radius may submit their evidence photo.
  static const double searchZoneRadiusMeters = 30.0;

  /// Minimum GPS horizontal accuracy (metres) required before the app
  /// considers the Hunter to be *inside* the search zone.
  ///
  /// If the device reports accuracy worse than this the app shows
  /// "Getting closer" even if the raw distance is ≤ [searchZoneRadiusMeters].
  static const double searchZoneMinAccuracyMeters = 20.0;

  // ── Proximity label thresholds ─────────────────────────────────────────────

  /// Distance below which the Hunter is "Getting closer" (but not yet in zone).
  static const double gettingCloserThresholdMeters = 100.0;
}
