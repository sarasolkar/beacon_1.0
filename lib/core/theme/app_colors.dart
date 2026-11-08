import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette
  static const Color background = Color(0xFFFAF6F2); // Warm cream
  static const Color primary = Color(0xFFFF5A3C);    // Beacon Orange
  static const Color primaryLight = Color(0xFFFFECE8);
  static const Color primaryDark = Color(0xFFE04529);

  // Mint Highlights
  static const Color mint = Color(0xFF2EC4B6);
  static const Color mintLight = Color(0xFFE6F8F6);
  static const Color mintDark = Color(0xFF21968B);

  // Surface & Neutral Colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF4EFEA);
  static const Color border = Color(0xFFEADBCE);
  static const Color borderLight = Color(0xFFF2ECE4);

  // Text Colors
  static const Color textPrimary = Color(0xFF1E1B18);
  static const Color textSecondary = Color(0xFF7A7269);
  static const Color textMuted = Color(0xFFA59E95);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Feedback
  static const Color success = Color(0xFF2EC4B6);
  static const Color warning = Color(0xFFFFB703);
  static const Color error = Color(0xFFE63946);

  // Subtle Card Shadow
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF23180D).withValues(alpha: 0.06),
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: const Color(0xFF23180D).withValues(alpha: 0.02),
          offset: const Offset(0, 2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.28),
          offset: const Offset(0, 10),
          blurRadius: 22,
          spreadRadius: 0,
        ),
      ];
}
