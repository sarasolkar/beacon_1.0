import 'hunt.dart';
import 'participant.dart';

enum RoomStatus {
  waiting('In Lobby', '⏳'),
  active('Hunt Active', '🧭'),
  completed('Hunt Ended', '🏁');

  final String label;
  final String icon;
  const RoomStatus(this.label, this.icon);
}

class HuntRoom {
  final String roomCode;
  final Hunt hunt;
  final String hiderId;
  final String hiderName;
  RoomStatus status;
  final List<HunterParticipant> participants;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;
  String? winnerId;
  String? winnerName;
  String? winnerRole;

  HuntRoom({
    required this.roomCode,
    required this.hunt,
    required this.hiderId,
    required this.hiderName,
    this.status = RoomStatus.waiting,
    List<HunterParticipant>? participants,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
    this.winnerId,
    this.winnerName,
    this.winnerRole,
  }) : participants = participants ?? [],
       createdAt = createdAt ?? DateTime.now();

  bool get isWaiting => status == RoomStatus.waiting;
  bool get isActive => status == RoomStatus.active;
  bool get isCompleted => status == RoomStatus.completed;
}
