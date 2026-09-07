import 'package:flutter/material.dart';

class AppColors {
  // Background Gradients
  static const Color bgDark = Color(0xFF0B0F19);
  static const Color bgDarkSecondary = Color(0xFF111827);
  static const Color bgCard = Color(0xFF1E293B);

  // Aurora Glow Orbs
  static const Color orbCyan = Color(0xFF06B6D4);
  static const Color orbPurple = Color(0xFF8B5CF6);
  static const Color orbPink = Color(0xFFEC4899);
  static const Color orbBlue = Color(0xFF3B82F6);

  // Accents & Brand
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color secondary = Color(0xFF06B6D4); // Cyan
  static const Color accent = Color(0xFFA855F7); // Purple

  // Glassmorphism Values
  static Color glassBg = Colors.white.withValues(alpha: 0.07);
  static Color glassBorder = Colors.white.withValues(alpha: 0.15);
  static Color glassShadow = Colors.black.withValues(alpha: 0.35);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // States
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}
