import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_button.dart';
import '../../core/widgets/beacon_card.dart';
import '../../models/hunt_room.dart';
import '../../models/participant.dart';
import '../../services/service_locator.dart';
import '../dashboard/hider_dashboard_screen.dart';
import '../hunt/hunt_mode_screen.dart';
import '../role_selection/role_selection_screen.dart';

class LobbyScreen extends StatelessWidget {
  final String roomCode;
  final bool isHider;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    this.isHider = false,
  });

  void _leaveRoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isHider ? 'Cancel Hunt?' : 'Leave Room?', style: AppTextStyles.titleMedium),
        content: Text(
          isHider
              ? 'Are you sure you want to cancel this hunt? All participating hunters will be disconnected.'
              : 'Are you sure you want to leave this room?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Stay', style: AppTextStyles.labelMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
            child: Text(isHider ? 'Cancel Hunt' : 'Leave', style: AppTextStyles.labelMedium),
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
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final room = snapshot.data;

        if (room == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Room Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text('Hunt Room "$roomCode" does not exist.', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 24),
                  BeaconButton(
                    label: 'Back to Home',
                    isFullWidth: false,
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final isStarted = room.status == RoomStatus.active;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _leaveRoom(context);
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => _leaveRoom(context),
              ),
              title: Text('Hunt Lobby', style: AppTextStyles.titleMedium),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isStarted ? AppColors.mintLight : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isStarted ? Icons.play_arrow_rounded : Icons.hourglass_top_rounded,
                        size: 14,
                        color: isStarted ? AppColors.mintDark : AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isStarted ? 'Active' : 'Waiting',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isStarted ? AppColors.mintDark : AppColors.primaryDark,
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
                    // Room Code Card
                    BeaconCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ROOM CODE',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.primary),
                                    tooltip: 'Copy Code',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: room.roomCode));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Room code "${room.roomCode}" copied!'),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share_rounded, size: 20, color: AppColors.mint),
                                    tooltip: 'Share Code',
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppColors.mintDark,
                                          content: Text('Sharing room code ${room.roomCode}...'),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                room.roomCode,
                                style: AppTextStyles.codeSnippet.copyWith(fontSize: 32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Hunt Details Summary
                    BeaconCard(
                      color: AppColors.surfaceMuted,
                      hasShadow: false,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.inventory_2_rounded, size: 20, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(room.hunt.name, style: AppTextStyles.titleMedium),
                                    Text('Created by ${room.hiderName}', style: AppTextStyles.bodySmall),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: Text(
                                  room.hunt.difficulty.label,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Verification Questions Review Card
                    if (isHider) ...[
                      BeaconCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.mintLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.quiz_rounded,
                                    size: 20,
                                    color: AppColors.mintDark,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Verification Questions (3)',
                                        style: AppTextStyles.titleSmall,
                                      ),
                                      Text(
                                        'Hunters must answer these to complete the hunt',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(
                              room.hunt.locationQuestions.length,
                              (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${i + 1}. ',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        room.hunt.locationQuestions[i],
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      BeaconCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.mintLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.quiz_rounded,
                                size: 20,
                                color: AppColors.mintDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '3 Location Questions Configured',
                                    style: AppTextStyles.titleSmall,
                                  ),
                                  Text(
                                    'You will answer these questions when you reach the target coordinates.',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Participants Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hunters in Room',
                          style: AppTextStyles.titleMedium,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.mintLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${room.participants.length} Joined',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.mintDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Participants List
                    if (room.participants.isEmpty) ...[
                      BeaconCard(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.group_outlined, size: 36, color: AppColors.textMuted),
                              const SizedBox(height: 8),
                              Text('Waiting for hunters to join...', style: AppTextStyles.bodyMedium),
                              const SizedBox(height: 4),
                              Text('Share code "${room.roomCode}" with friends', style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      ...room.participants.map((hunter) => _HunterTile(hunter: hunter)),
                    ],

                    const SizedBox(height: 36),

                    // Action Controls
                    if (isHider) ...[
                      BeaconButton(
                        label: isStarted ? 'Open Hider Dashboard' : 'Start Hunt 🚀',
                        onPressed: () async {
                          if (!isStarted) {
                            final questions = room.hunt.locationQuestions;
                            if (questions.length < 3 ||
                                questions.any((q) => q.trim().isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'All 3 verification questions must be configured before starting the hunt.',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }
                            await repo.startHunt(room.roomCode);
                          }
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => HiderDashboardScreen(roomCode: room.roomCode),
                              ),
                            );
                          }
                        },
                      ),
                    ] else ...[
                      if (isStarted) ...[
                        BeaconButton(
                          label: 'Enter Hunt Mode 🧭',
                          variant: BeaconButtonVariant.mint,
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => HuntModeScreen(roomCode: room.roomCode),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Waiting for Hider to start...',
                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 12),

                    BeaconButton(
                      label: isHider ? 'Cancel Hunt' : 'Leave Room',
                      variant: BeaconButtonVariant.ghost,
                      onPressed: () => _leaveRoom(context),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HunterTile extends StatelessWidget {
  final HunterParticipant hunter;

  const _HunterTile({required this.hunter});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            radius: 20,
            child: Text(
              hunter.name.isNotEmpty ? hunter.name[0].toUpperCase() : 'H',
              style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hunter.name, style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary)),
                Text(hunter.status.label, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.mint),
                const SizedBox(width: 4),
                Text(
                  'Ready',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.mintDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
