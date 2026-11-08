import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class StepItem {
  final String title;
  final IconData icon;

  const StepItem({
    required this.title,
    required this.icon,
  });
}

class BeaconStepIndicator extends StatelessWidget {
  final int currentStep;
  final List<StepItem> steps;
  final ValueChanged<int>? onStepTapped;

  const BeaconStepIndicator({
    super.key,
    required this.currentStep,
    required this.steps,
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepBefore = index ~/ 2;
            final isCompleted = stepBefore < currentStep;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.mint : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final step = steps[stepIndex];
          final isActive = stepIndex == currentStep;
          final isCompleted = stepIndex < currentStep;

          Color badgeColor;
          Color iconColor;
          Border? border;

          if (isCompleted) {
            badgeColor = AppColors.mint;
            iconColor = Colors.white;
          } else if (isActive) {
            badgeColor = AppColors.primary;
            iconColor = Colors.white;
          } else {
            badgeColor = AppColors.surfaceMuted;
            iconColor = AppColors.textMuted;
            border = Border.all(color: AppColors.border, width: 1);
          }

          return GestureDetector(
            onTap: onStepTapped != null ? () => onStepTapped!(stepIndex) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: border,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 20, color: Colors.white)
                        : Icon(step.icon, size: 18, color: iconColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.title,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isActive
                        ? AppColors.primary
                        : (isCompleted ? AppColors.mintDark : AppColors.textMuted),
                    fontWeight: isActive || isCompleted
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
