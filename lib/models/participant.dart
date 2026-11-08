enum ParticipantStatus {
  waiting('Waiting in Lobby', '⏳'),
  active('Hunting', '🧭'),
  pendingApproval('Pending Review', '📸'),
  stale('Offline/Idle', '⚠️'),
  found('Treasure Found!', '🏆');

  final String label;
  final String icon;
  const ParticipantStatus(this.label, this.icon);
}

class HunterParticipant {
  final String id;
  final String name;
  final String? avatarUrl;
  double distanceMeters;
  ParticipantStatus status;
  int hintsUnlocked;
  DateTime? foundAt;
  DateTime lastActive;

  HunterParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.distanceMeters = 300.0,
    this.status = ParticipantStatus.waiting,
    this.hintsUnlocked = 0,
    this.foundAt,
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  HunterParticipant copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    double? distanceMeters,
    ParticipantStatus? status,
    int? hintsUnlocked,
    DateTime? foundAt,
    DateTime? lastActive,
  }) {
    return HunterParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      status: status ?? this.status,
      hintsUnlocked: hintsUnlocked ?? this.hintsUnlocked,
      foundAt: foundAt ?? this.foundAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
