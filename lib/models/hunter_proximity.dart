class HunterProximity {
  final double distanceMeters;
  final double bearingDegrees;
  final bool isWithinSearchZone;
  final DateTime? huntStartedAt;
  final List<String> unlockedHints;

  const HunterProximity({
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.isWithinSearchZone,
    required this.huntStartedAt,
    required this.unlockedHints,
  });
}
