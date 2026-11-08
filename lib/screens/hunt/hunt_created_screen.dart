import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_button.dart';
import '../../core/widgets/beacon_card.dart';
import '../../models/hunt.dart';
import '../role_selection/role_selection_screen.dart';
import '../lobby/lobby_screen.dart';

class HuntCreatedScreen extends StatelessWidget {
  final Hunt hunt;

  const HuntCreatedScreen({
    super.key,
    required this.hunt,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateToHome(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Treasure Chest Celebration Graphic
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight.withValues(alpha: 0.7),
                        ),
                      ),
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.inventory_2_rounded,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Mint star badge
                      Positioned(
                        top: 10,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 3),
                          ),
                          child: const Icon(Icons.star_rounded, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Heading
                Text(
                  'Hunt Created!',
                  style: AppTextStyles.displayLarge.copyWith(fontSize: 32),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'Your treasure is live! Share your code with fellow explorers so they can track it down.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),

                const SizedBox(height: 32),

                // Code Display Card
                BeaconCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'HUNT CODE',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hunt.code,
                              style: AppTextStyles.codeSnippet,
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                              tooltip: 'Copy Code',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: hunt.code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Hunt code "${hunt.code}" copied to clipboard!'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap copy to share code easily',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Summary Metadata Card
                BeaconCard(
                  color: AppColors.surfaceMuted,
                  hasShadow: false,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _summaryRow(Icons.title_rounded, 'Treasure Name', hunt.name),
                      const Divider(height: 20, color: AppColors.borderLight),
                      _summaryRow(
                        Icons.pin_drop_rounded,
                        'Coordinates',
                        hunt.locationCoordinates,
                      ),
                      const Divider(height: 20, color: AppColors.borderLight),
                      _summaryRow(
                        Icons.speed_rounded,
                        'Difficulty',
                        '${hunt.difficulty.label} ${hunt.difficulty.icon}',
                      ),
                      if (hunt.reward != null && hunt.reward!.isNotEmpty) ...[
                        const Divider(height: 20, color: AppColors.borderLight),
                        _summaryRow(
                          Icons.military_tech_rounded,
                          'Reward',
                          hunt.reward!,
                        ),
                      ],
                      const Divider(height: 20, color: AppColors.borderLight),
                      _summaryRow(
                        Icons.lightbulb_outline_rounded,
                        'Clues Setup',
                        '${hunt.hints.length} Distance Tiers',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Open Lobby Button
                BeaconButton(
                  label: 'Open Hunt Lobby 🚀',
                  variant: BeaconButtonVariant.primary,
                  icon: const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 20),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => LobbyScreen(roomCode: hunt.code, isHider: true),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Share Button (UI only)
                BeaconButton(
                  label: 'Share Hunt Code',
                  variant: BeaconButtonVariant.mint,
                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.mintDark,
                        content: Text(
                          'Share sheet simulated! Code: ${hunt.code} ("${hunt.name}")',
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Back to Home Button
                BeaconButton(
                  label: 'Back to Home',
                  variant: BeaconButtonVariant.secondary,
                  icon: const Icon(Icons.home_rounded, color: AppColors.textPrimary, size: 20),
                  onPressed: () => _navigateToHome(context),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  Widget _summaryRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(title, style: AppTextStyles.bodyMedium),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
