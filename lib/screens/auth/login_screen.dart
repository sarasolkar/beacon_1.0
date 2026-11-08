import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/beacon_button.dart';
import '../../core/widgets/beacon_text_field.dart';
import '../role_selection/role_selection_screen.dart';
import '../../services/service_locator.dart';
import '../../services/auth_service.dart';
import '../../models/user_profile.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter an email address');
      return;
    }
    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserProfile? user;
      if (_isSignUp) {
        user = await ServiceLocator().authService
            .signUpWithEmail(
              email,
              _passwordController.text,
              _nameController.text.trim().isEmpty
                  ? email.split('@').first
                  : _nameController.text.trim(),
            )
            .timeout(const Duration(seconds: 30));
      } else {
        user = await ServiceLocator().authService
            .signInWithEmail(email, _passwordController.text)
            .timeout(const Duration(seconds: 30));
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (user != null) _navigateToHome();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e is ProfileSyncException) {
        _navigateToHome(
          notice: 'Signed in, but profile sync failed: ${e.cause}',
        );
        return;
      }
      if (e is TimeoutException) {
        if (ServiceLocator().authService.currentUser != null) {
          _navigateToHome(
            notice:
                'You are signed in, but account setup timed out while syncing your profile.',
          );
        } else {
          _showError(
            'Sign-in timed out. Check your internet connection and try again.',
          );
        }
        return;
      }
      _showError(e.toString());
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await ServiceLocator().authService
          .signInWithGoogle()
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (user != null) _navigateToHome();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e is ProfileSyncException) {
        _navigateToHome(
          notice: 'Signed in, but profile sync failed: ${e.cause}',
        );
        return;
      }
      if (e is TimeoutException) {
        if (ServiceLocator().authService.currentUser != null) {
          _navigateToHome(
            notice:
                'You are signed in, but account setup timed out while syncing your profile.',
          );
        } else {
          _showError(
            'Google sign-in timed out. Check your connection and try again.',
          );
        }
        return;
      }
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigateToHome({String? notice}) {
    if (notice != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notice),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                _isSignUp ? 'Create Account' : 'Welcome Back',
                style: AppTextStyles.displayMedium,
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                _isSignUp
                    ? 'Join a community of explorers and treasure creators.'
                    : 'Sign in to access your hunts and join quests.',
                style: AppTextStyles.bodyMedium,
              ),

              const SizedBox(height: 24),

              BeaconButton(
                label: 'Continue with Google',
                variant: BeaconButtonVariant.secondary,
                isLoading: _isLoading,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                onPressed: _isLoading ? null : _handleGoogleSignIn,
              ),

              const SizedBox(height: 16),

              // Divider with "or"
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or continue with email',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ],
              ),

              const SizedBox(height: 24),

              if (_isSignUp) ...[
                BeaconTextField(
                  label: 'Full Name',
                  hintText: 'Alex Hunter',
                  controller: _nameController,
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Email Field
              BeaconTextField(
                label: 'Email Address',
                hintText: 'alex@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(
                  Icons.mail_outline_rounded,
                  color: AppColors.textMuted,
                ),
              ),

              const SizedBox(height: 16),

              // Password Field
              BeaconTextField(
                label: 'Password',
                hintText: '••••••••',
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.textMuted,
                ),
                suffixIcon: IconButton(
                  tooltip: _isPasswordVisible
                      ? 'Hide password'
                      : 'Show password',
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Primary Action (Sign In / Create Account)
              BeaconButton(
                label: _isSignUp ? 'Create Account' : 'Sign In',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleEmailAuth,
              ),

              const SizedBox(height: 16),

              // Toggle Sign In / Sign Up
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodyMedium,
                      children: [
                        TextSpan(
                          text: _isSignUp
                              ? 'Already have an account? '
                              : "Don't have an account? ",
                        ),
                        TextSpan(
                          text: _isSignUp ? 'Sign In' : 'Create Account',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Footer Note
              Center(
                child: Text(
                  ServiceLocator().isAuthAvailable
                      ? 'Secured by Firebase Authentication'
                      : 'Firebase Authentication is unavailable',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}