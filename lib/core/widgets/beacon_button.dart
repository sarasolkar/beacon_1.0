import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum BeaconButtonVariant {
  primary,
  mint,
  secondary,
  outline,
  ghost,
}

class BeaconButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final BeaconButtonVariant variant;
  final Widget? icon;
  final bool isFullWidth;
  final bool isLoading;
  final double height;
  final double borderRadius;

  const BeaconButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BeaconButtonVariant.primary,
    this.icon,
    this.isFullWidth = true,
    this.isLoading = false,
    this.height = 56.0,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;
    List<BoxShadow>? shadow;

    switch (variant) {
      case BeaconButtonVariant.primary:
        backgroundColor = AppColors.primary;
        foregroundColor = AppColors.textOnPrimary;
        shadow = AppColors.elevatedShadow;
        break;
      case BeaconButtonVariant.mint:
        backgroundColor = AppColors.mint;
        foregroundColor = Colors.white;
        shadow = [
          BoxShadow(
            color: AppColors.mint.withValues(alpha: 0.25),
            offset: const Offset(0, 8),
            blurRadius: 18,
          ),
        ];
        break;
      case BeaconButtonVariant.secondary:
        backgroundColor = AppColors.surface;
        foregroundColor = AppColors.textPrimary;
        borderSide = const BorderSide(color: AppColors.border, width: 1.2);
        shadow = AppColors.cardShadow;
        break;
      case BeaconButtonVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.primary;
        borderSide = const BorderSide(color: AppColors.primary, width: 1.5);
        break;
      case BeaconButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.textSecondary;
        break;
    }

    final buttonTextStyle = AppTextStyles.labelLarge.copyWith(
      color: foregroundColor,
      fontWeight: FontWeight.w600,
    );

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            label,
            style: buttonTextStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );

    Widget button = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: onPressed != null && !isLoading ? shadow : null,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: borderSide ?? BorderSide.none,
          ),
        ),
        child: content,
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
