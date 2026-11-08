import 'package:flutter/material.dart';
import '../../core/game_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_button.dart';
import '../../core/widgets/beacon_card.dart';
import '../../models/evidence_submission.dart';
import '../../models/hunt.dart';
import '../../models/hunt_room.dart';
import '../../models/participant.dart';
import '../../services/service_locator.dart';
import '../role_selection/role_selection_screen.dart';
import '../winner/winner_screen.dart';

class HiderDashboardScreen extends StatelessWidget {
  final String roomCode;

  const HiderDashboardScreen({super.key, required this.roomCode});

  void _confirmEndHunt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('End Hunt Session?', style: AppTextStyles.titleMedium),
        content: Text(
          'Ending the hunt will close the room and return everyone to the home screen.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Keep Active', style: AppTextStyles.labelMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ServiceLocator().huntRepository.endHunt(roomCode);
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen(),
                  ),
                  (route) => false,
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not end the hunt: $error')),
                );
              }
            },
            child: Text('End Hunt', style: AppTextStyles.labelMedium),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ServiceLocator().huntRepository;

    return StreamBuilder<HuntRoom?>(
      stream: repo.streamRoom(roomCode),
      builder: (context, snapshot) {
        final room = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (room == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Dashboard')),
            body: Center(
              child: Text('Room not found', style: AppTextStyles.titleMedium),
            ),
          );
        }

        final participants = room.participants;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
            title: Column(
              children: [
                Text('Hider Dashboard', style: AppTextStyles.titleSmall),
                Text(
                  'Room: ${room.roomCode}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: room.status == RoomStatus.active
                      ? AppColors.mintLight
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: room.status == RoomStatus.active
                            ? AppColors.mint
                            : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      room.status.label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: room.status == RoomStatus.active
                            ? AppColors.mintDark
                            : AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hunt status and summary
                  BeaconCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                room.hunt.name,
                                style: AppTextStyles.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: AppColors.borderLight),
                        Text(
                          'Status: ${room.status.label}',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: room.status == RoomStatus.completed
                                ? AppColors.mintDark
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Evidence Reviews (Pending Submissions)
                  _PendingSubmissionsSection(roomCode: room.roomCode),

                  // Hunter Tracking Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hunter Live Radar',
                        style: AppTextStyles.titleMedium,
                      ),
                      Text(
                        'Auto-updating',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.mintDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (participants.isEmpty) ...[
                    const BeaconCard(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No hunters connected yet.')),
                    ),
                  ] else ...[
                    ...participants.map(
                      (hunter) => _HunterTrackingCard(hunter: hunter),
                    ),
                  ],

                  const SizedBox(height: 32),

                  if (room.status == RoomStatus.completed)
                    BeaconButton(
                      label: 'View Hunt Result',
                      variant: BeaconButtonVariant.mint,
                      icon: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WinnerScreen(
                              winnerName: room.winnerName,
                              winnerRole: room.winnerRole,
                              huntName: room.hunt.name,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    BeaconButton(
                      label: 'End Hunt Session',
                      variant: BeaconButtonVariant.secondary,
                      icon: const Icon(
                        Icons.stop_circle_outlined,
                        color: AppColors.error,
                        size: 20,
                      ),
                      onPressed: () => _confirmEndHunt(context),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HunterTrackingCard extends StatelessWidget {
  final HunterParticipant hunter;

  const _HunterTrackingCard({required this.hunter});

  @override
  Widget build(BuildContext context) {
    final isFound = hunter.status == ParticipantStatus.found;
    final isInSearchZone =
        hunter.distanceMeters <= GameConfig.searchZoneRadiusMeters && !isFound;
    final isGettingCloser =
        hunter.distanceMeters > GameConfig.searchZoneRadiusMeters &&
        hunter.distanceMeters <= GameConfig.gettingCloserThresholdMeters &&
        !isFound;

    String proximityLabel;
    Color badgeColor;
    Color badgeBg;

    if (isFound) {
      proximityLabel = 'Found 🏆';
      badgeColor = AppColors.mint;
      badgeBg = AppColors.mintLight;
    } else if (isInSearchZone) {
      proximityLabel = 'In search zone';
      badgeColor = AppColors.mint;
      badgeBg = AppColors.mintLight;
    } else if (isGettingCloser) {
      proximityLabel = 'Getting closer';
      badgeColor = AppColors.primary;
      badgeBg = AppColors.primaryLight;
    } else {
      proximityLabel = 'Far';
      badgeColor = AppColors.textSecondary;
      badgeBg = AppColors.surfaceMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFound ? AppColors.mint : AppColors.borderLight,
          width: isFound ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: badgeBg,
                radius: 20,
                child: Text(
                  hunter.name.isNotEmpty ? hunter.name[0].toUpperCase() : 'H',
                  style: AppTextStyles.titleSmall.copyWith(color: badgeColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hunter.name, style: AppTextStyles.labelMedium),
                    Text(
                      '${hunter.hintsUnlocked}/3 Hints Unlocked',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  proximityLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingSubmissionsSection extends StatelessWidget {
  final String roomCode;

  const _PendingSubmissionsSection({required this.roomCode});

  void _showRejectDialog(
    BuildContext context,
    EvidenceSubmission submission, {
    String? defaultReason,
  }) {
    final textController = TextEditingController(
      text: defaultReason ?? 'One or more location answers were incorrect.',
    );
    final reasons = [
      'One or more location answers were incorrect.',
      'Answers do not match the target location.',
      'Answers are incomplete or inaccurate.',
      'Wrong location or distance.',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Reject Submission', style: AppTextStyles.titleMedium),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Let ${submission.hunterName} know why their answers were rejected so they can resubmit:',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                ...reasons.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () {
                        setDialogState(() {
                          textController.text = r;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: textController.text == r
                              ? AppColors.primaryLight
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: textController.text == r
                                ? AppColors.primary
                                : AppColors.borderLight,
                          ),
                        ),
                        child: Text(
                          r,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: textController.text == r
                                ? AppColors.primaryDark
                                : AppColors.textPrimary,
                            fontWeight: textController.text == r
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textController,
                  maxLines: 2,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Reason for rejection',
                    labelStyle: AppTextStyles.bodySmall,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: AppTextStyles.labelMedium),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final reason = textController.text.trim();
                Navigator.of(ctx).pop();
                final success = await ServiceLocator().huntRepository
                    .rejectSubmission(
                      roomCode: roomCode,
                      submissionId: submission.id,
                      hunterId: submission.hunterId,
                      reason: reason.isNotEmpty
                          ? reason
                          : 'Submission rejected by Hider',
                    );
                if (context.mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Submission rejected. ${submission.hunterName} can resubmit.',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: Text('Reject Submission', style: AppTextStyles.labelMedium),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmApprove(BuildContext context, EvidenceSubmission submission) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Approve Find? 🏆', style: AppTextStyles.titleMedium),
        content: Text(
          'Confirm that all 3 location answers from ${submission.hunterName} are correct. Approval completes the hunt and records ${submission.hunterName} as the winner.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.labelMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mint,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ServiceLocator().huntRepository
                  .approveSubmission(
                    roomCode: roomCode,
                    submissionId: submission.id,
                    hunterId: submission.hunterId,
                  );
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '🎉 Approved! ${submission.hunterName} found the treasure!',
                    ),
                    backgroundColor: AppColors.mintDark,
                  ),
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WinnerScreen(
                      winnerName: submission.hunterName,
                      winnerRole: 'hunter',
                      huntName: 'the hunt',
                    ),
                  ),
                );
              }
            },
            child: Text('Approve Find', style: AppTextStyles.labelMedium),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EvidenceSubmission>>(
      stream: ServiceLocator().huntRepository.streamSubmissions(roomCode),
      builder: (context, snapshot) {
        final submissions = snapshot.data ?? [];
        final pending = submissions
            .where((s) => s.status == SubmissionStatus.pending)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        'Evidence Reviews',
                        style: AppTextStyles.titleMedium,
                      ),
                      if (pending.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${pending.length} Pending',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  pending.isEmpty ? 'All caught up' : 'Needs review',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: pending.isEmpty
                        ? AppColors.mintDark
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pending.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.mint,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No pending verification submissions to review.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...pending.map(
                (sub) => _PendingSubmissionCard(
                  submission: sub,
                  roomCode: roomCode,
                  onApprove: () => _confirmApprove(context, sub),
                  onReject: (defaultReason) =>
                      _showRejectDialog(context, sub, defaultReason: defaultReason),
                ),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _PendingSubmissionCard extends StatefulWidget {
  final EvidenceSubmission submission;
  final String roomCode;
  final VoidCallback onApprove;
  final void Function(String? defaultReason) onReject;

  const _PendingSubmissionCard({
    required this.submission,
    required this.roomCode,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_PendingSubmissionCard> createState() => _PendingSubmissionCardState();
}

class _PendingSubmissionCardState extends State<_PendingSubmissionCard> {
  List<String> _expectedAnswers = [];
  bool _loadingAnswers = true;
  late List<bool?> _evaluations;

  @override
  void initState() {
    super.initState();
    final count = widget.submission.questions.isNotEmpty
        ? widget.submission.questions.length
        : 3;
    _evaluations = List<bool?>.filled(count, null);
    _loadExpectedAnswers();
  }

  Future<void> _loadExpectedAnswers() async {
    try {
      final answers = await ServiceLocator().huntRepository
          .getExpectedAnswers(widget.roomCode);
      if (mounted) {
        setState(() {
          _expectedAnswers = answers.isNotEmpty
              ? answers
              : Hunt.defaultAnswers();
          _loadingAnswers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _expectedAnswers = Hunt.defaultAnswers();
          _loadingAnswers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.submission.questions.isNotEmpty
        ? widget.submission.questions
        : Hunt.defaultQuestions();
    final hunterAnswers = widget.submission.answers;

    if (_evaluations.length != questions.length) {
      _evaluations = List<bool?>.filled(questions.length, null);
    }

    final allReviewed = _evaluations.every((e) => e != null);
    final allCorrect = allReviewed && _evaluations.every((e) => e == true);
    final anyIncorrect = _evaluations.any((e) => e == false);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: allCorrect
              ? AppColors.mint
              : (anyIncorrect
                  ? AppColors.error.withValues(alpha: 0.5)
                  : AppColors.primary.withValues(alpha: 0.4)),
          width: 1.5,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                radius: 18,
                child: Text(
                  widget.submission.hunterName.isNotEmpty
                      ? widget.submission.hunterName[0].toUpperCase()
                      : 'H',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.submission.hunterName,
                      style: AppTextStyles.labelMedium,
                    ),
                    Text(
                      widget.submission.distanceMeters <=
                              GameConfig.searchZoneRadiusMeters
                          ? 'In search zone (${widget.submission.distanceMeters.toStringAsFixed(0)}m)'
                          : 'Submitted from ${widget.submission.distanceMeters.toStringAsFixed(0)}m',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Pending Review',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (widget.submission.photoBytes != null) ...[
            Text(
              'Photo from ${widget.submission.hunterName} (tap to enlarge)',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    child: Image.memory(widget.submission.photoBytes!),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  widget.submission.photoBytes!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review each answer below. Mark Correct or Incorrect.',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          ...List.generate(questions.length, (i) {
            final q = questions[i];
            final hunterAns = i < hunterAnswers.length
                ? hunterAnswers[i]
                : '(No answer provided)';
            final expectedAns = _loadingAnswers
                ? 'Loading expected answer...'
                : (i < _expectedAnswers.length
                    ? _expectedAnswers[i]
                    : Hunt.defaultAnswers()[i % Hunt.defaultAnswers().length]);
            final eval = _evaluations[i];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: eval == true
                    ? AppColors.mintLight.withValues(alpha: 0.3)
                    : (eval == false
                        ? const Color(0xFFFFEBEE).withValues(alpha: 0.5)
                        : AppColors.surfaceMuted),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: eval == true
                      ? AppColors.mint
                      : (eval == false
                          ? AppColors.error
                          : AppColors.borderLight),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Question ${i + 1}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (eval == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mintLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Correct ✅',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.mintDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else if (eval == false)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Incorrect ❌',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hunter\'s Answer:',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hunterAns,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.mintLight.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.mint.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.vpn_key_rounded,
                          size: 14,
                          color: AppColors.mintDark,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expected Answer (Hider Only):',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.mintDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                expectedAns,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text('Correct'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: eval == true
                                ? AppColors.mint
                                : AppColors.surface,
                            foregroundColor: eval == true
                                ? Colors.white
                                : AppColors.mintDark,
                            side: BorderSide(
                              color: AppColors.mint,
                              width: eval == true ? 2 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _evaluations[i] = true;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_rounded, size: 16),
                          label: const Text('Incorrect'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: eval == false
                                ? AppColors.error
                                : AppColors.surface,
                            foregroundColor: eval == false
                                ? Colors.white
                                : AppColors.error,
                            side: BorderSide(
                              color: AppColors.error,
                              width: eval == false ? 2 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _evaluations[i] = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),

          if (allCorrect) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.mintLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.mint),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.mintDark, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All 3 answers verified correct! You can now confirm and complete the hunt.',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.mintDark),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (anyIncorrect) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'One or more answers marked incorrect. Reject the verification to let the Hunter try again.',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Text(
                  'Mark each question as Correct or Incorrect to proceed.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
          ],

          Row(
            children: [
              Expanded(
                child: BeaconButton(
                  label: 'Reject ❌',
                  variant: BeaconButtonVariant.secondary,
                  onPressed: () {
                    final incorrectIndices = <int>[];
                    for (int i = 0; i < _evaluations.length; i++) {
                      if (_evaluations[i] == false) incorrectIndices.add(i + 1);
                    }
                    final defaultReason = incorrectIndices.isNotEmpty
                        ? 'Question(s) ${incorrectIndices.join(", ")} were incorrect.'
                        : 'One or more location answers were incorrect.';
                    widget.onReject(defaultReason);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BeaconButton(
                  label: 'Approve Find 🏆',
                  variant: BeaconButtonVariant.mint,
                  onPressed: allCorrect ? widget.onApprove : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}