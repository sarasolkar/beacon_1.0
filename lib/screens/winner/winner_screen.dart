import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_button.dart';
import '../role_selection/role_selection_screen.dart';

/// Displayed when the Hider approves the winning evidence submission.
///
/// Shows the winner's name and a simple "Back to Home" action.
/// There is no scoreboard, leaderboard, or point tally — just the winner.
class WinnerScreen extends StatelessWidget {
  final String? winnerName;
  final String huntName;
  final String? winnerRole;

  const WinnerScreen({
    super.key,
    this.winnerName,
    required this.huntName,
    this.winnerRole,
  });

  @override
  Widget build(BuildContext context) {
    final resultTitle = switch (winnerRole) {
      'hunter' => 'Hunter Wins!',
      'hider' => 'Hider Wins!',
      _ => 'Hunt Ended',
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Trophy icon
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.mintLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.mint.withValues(alpha: 0.35),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 52)),
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  resultTitle,
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  winnerName ?? 'No winner recorded',
                  style: AppTextStyles.displayMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  winnerName == null ? huntName : 'won $huntName',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                BeaconButton(
                  label: 'Back to Home',
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const RoleSelectionScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
