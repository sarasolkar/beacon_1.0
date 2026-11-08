import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class BeaconCompassWidget extends StatelessWidget {
  final double bearingDegrees; // 0 to 360
  final double distanceMeters;
  final double size;

  const BeaconCompassWidget({
    super.key,
    required this.bearingDegrees,
    required this.distanceMeters,
    this.size = 220.0,
  });

  @override
  Widget build(BuildContext context) {
    final isClose = distanceMeters <= 20.0;
    final isMedium = distanceMeters <= 100.0 && !isClose;

    final primaryAccent = isClose
        ? AppColors.mint
        : (isMedium ? AppColors.primary : AppColors.primary.withValues(alpha: 0.85));

    final bearingRadians = (bearingDegrees * math.pi) / 180.0;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow Ring
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryAccent.withValues(alpha: isClose ? 0.15 : 0.06),
              border: Border.all(
                color: primaryAccent.withValues(alpha: isClose ? 0.4 : 0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryAccent.withValues(alpha: isClose ? 0.3 : 0.08),
                  blurRadius: 24,
                  spreadRadius: isClose ? 4 : 0,
                ),
              ],
            ),
          ),

          // Inner Dial Surface
          Container(
            width: size - 36,
            height: size - 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
          ),

          // Cardinal Markings (N, E, S, W)
          SizedBox(
            width: size - 36,
            height: size - 36,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'N',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'S',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      'W',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      'E',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rotating Needle
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: bearingRadians, end: bearingRadians),
            duration: const Duration(milliseconds: 250),
            builder: (context, angle, child) {
              return Transform.rotate(
                angle: angle,
                child: SizedBox(
                  width: size - 70,
                  height: size - 70,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Target needle head pointing towards bearing
                      Positioned(
                        top: 4,
                        child: Column(
                          children: [
                            Icon(
                              Icons.navigation_rounded,
                              color: primaryAccent,
                              size: 38,
                            ),
                            Container(
                              width: 3,
                              height: 24,
                              decoration: BoxDecoration(
                                color: primaryAccent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Center Hub with Compass Icon and Degree
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: primaryAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: primaryAccent.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.explore_rounded,
                    color: primaryAccent,
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bearingDegrees.toInt()}°',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
