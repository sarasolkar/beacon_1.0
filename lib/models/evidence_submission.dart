import 'dart:typed_data';

enum SubmissionStatus {
  pending('Pending Review', '⏳'),
  approved('Approved', '✅'),
  rejected('Rejected', '❌');

  final String label;
  final String icon;
  const SubmissionStatus(this.label, this.icon);
}

class EvidenceSubmission {
  final String id;
  final String roomCode;
  final String hunterId;
  final String hunterName;
  final String photoUrl;
  final Uint8List? photoBytes;
  final double distanceMeters;
  final DateTime submittedAt;
  final SubmissionStatus status;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final List<String> questions;
  final List<String> answers;

  EvidenceSubmission({
    required this.id,
    required this.roomCode,
    required this.hunterId,
    required this.hunterName,
    this.photoUrl = '',
    this.photoBytes,
    required this.distanceMeters,
    DateTime? submittedAt,
    this.status = SubmissionStatus.pending,
    this.rejectionReason,
    this.reviewedAt,
    this.questions = const [],
    this.answers = const [],
  }) : submittedAt = submittedAt ?? DateTime.now();

  bool get isPending => status == SubmissionStatus.pending;
  bool get isApproved => status == SubmissionStatus.approved;
  bool get isRejected => status == SubmissionStatus.rejected;

  EvidenceSubmission copyWith({
    String? id,
    String? roomCode,
    String? hunterId,
    String? hunterName,
    String? photoUrl,
    Uint8List? photoBytes,
    double? distanceMeters,
    DateTime? submittedAt,
    SubmissionStatus? status,
    String? rejectionReason,
    DateTime? reviewedAt,
    List<String>? questions,
    List<String>? answers,
  }) {
    return EvidenceSubmission(
      id: id ?? this.id,
      roomCode: roomCode ?? this.roomCode,
      hunterId: hunterId ?? this.hunterId,
      hunterName: hunterName ?? this.hunterName,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBytes: photoBytes ?? this.photoBytes,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomCode': roomCode,
      'hunterId': hunterId,
      'hunterName': hunterName,
      'photoUrl': photoUrl,
      'distanceMeters': distanceMeters,
      'submittedAt': submittedAt.toIso8601String(),
      'status': status.name,
      'rejectionReason': rejectionReason,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'questions': questions,
      'answers': answers,
    };
  }

  factory EvidenceSubmission.fromMap(Map<String, dynamic> map, {String? id}) {
    return EvidenceSubmission(
      id: id ?? map['id'] as String? ?? '',
      roomCode: map['roomCode'] as String? ?? '',
      hunterId: map['hunterId'] as String? ?? '',
      hunterName: map['hunterName'] as String? ?? 'Hunter',
      photoUrl: map['photoUrl'] as String? ?? '',
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      submittedAt: map['submittedAt'] != null
          ? DateTime.tryParse(map['submittedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: SubmissionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SubmissionStatus.pending,
      ),
      rejectionReason: map['rejectionReason'] as String?,
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.tryParse(map['reviewedAt'] as String)
          : null,
      questions: List<String>.from(map['questions'] ?? const []),
      answers: List<String>.from(map['answers'] ?? const []),
    );
  }
}
