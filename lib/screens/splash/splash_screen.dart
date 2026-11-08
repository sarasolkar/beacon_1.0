import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_button.dart';
import '../../services/service_locator.dart';
import '../auth/login_screen.dart';
import '../role_selection/role_selection_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Animated/Glow Compass Beacon Icon
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer subtle pulse ring
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                    // Middle ring
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    // Inner Beacon core
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF7E47)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 26,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.explore_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Mint satellite dot
                    Positioned(
                      top: 14,
                      right: 20,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.mint.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // App Name
              Text(
                'Beacon',
                style: AppTextStyles.displayLarge.copyWith(
                  color: AppColors.textPrimary,
                  letterSpacing: -1.0,
                  fontSize: 42,
                ),
              ),

              const SizedBox(height: 12),

              // Tagline: "Hide. Hint. Hunt."
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Hide',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _buildDot(),
                  Text(
                    'Hint',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.mint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _buildDot(),
                  Text(
                    'Hunt.',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Sub-description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'The real-world GPS treasure hunt adventure. Hide treasures, leave clues, and lead the quest.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Action Button: "Let's Go"
              BeaconButton(
                label: "Let's Go",
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () {
                  if (ServiceLocator().authService.currentUser != null) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const RoleSelectionScreen(),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildDot() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 5,
      height: 5,
      decoration: const BoxDecoration(
        color: AppColors.textMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}
