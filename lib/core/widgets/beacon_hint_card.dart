import 'package:flutter/material.dart';
import '../game_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../models/hint_item.dart';
import 'beacon_card.dart';

class BeaconHintCard extends StatelessWidget {
  final HintItem hint;
  final int tierNumber; // 1, 2, or 3
  final bool isUnlocked;
  final double currentDistanceMeters;
  final String? revealedText;

  const BeaconHintCard({
    super.key,
    required this.hint,
    required this.tierNumber,
    required this.isUnlocked,
    required this.currentDistanceMeters,
    this.revealedText,
  });

  @override
  Widget build(BuildContext context) {
    final isEligible =
        currentDistanceMeters <= GameConfig.searchZoneRadiusMeters;
    final isRevealed = isUnlocked;

    Color badgeColor;
    Color badgeBg;
    if (tierNumber == 1) {
      badgeColor = AppColors.mint;
      badgeBg = AppColors.mintLight;
    } else if (tierNumber == 2) {
      badgeColor = const Color(0xFFF77F00);
      badgeBg = const Color(0xFFFFF3E6);
    } else {
      badgeColor = AppColors.primary;
      badgeBg = AppColors.primaryLight;
    }

    return BeaconCard(
      padding: const EdgeInsets.all(18),
      border: isEligible && !isRevealed
          ? Border.all(color: badgeColor, width: 2)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$tierNumber',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: badgeColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(hint.title, style: AppTextStyles.titleSmall),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isRevealed ? badgeBg : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isRevealed
                        ? badgeColor.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRevealed
                          ? Icons.lock_open_rounded
                          : (isEligible
                                ? Icons.lock_clock_rounded
                                : Icons.lock_outline_rounded),
                      size: 14,
                      color: isRevealed ? badgeColor : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hint.distanceLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isRevealed ? badgeColor : AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (isRevealed) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                (revealedText ?? hint.text).isEmpty
                    ? 'No clue provided for this tier.'
                    : (revealedText ?? hint.text),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEligible
                          ? 'Locked. Wait for the next hint to unlock.'
                          : 'Locked. Get within ${GameConfig.searchZoneRadiusMeters.toInt()}m to unlock clues.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
