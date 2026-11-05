import 'package:flutter/material.dart';

// Kalau mau ganti warna, cukup ubah di file ini saja.
class AppColors {
  AppColors._();

  // latar
  static const background = Color(0xFF0F172A);
  static const backgroundAlt = Color(0xFF182234);
  static const card = Color(0xFF1E293B);

  // warna utama
  static const primary = Color(0xFF6366F1);
  static const primaryDark = Color(0xFF4F46E5);
  static const primaryLight = Color(0xFFA5B4FC);
  static const secondary = Color(0xFF38BDF8);
  static const accent = Color(0xFF39D0B1);

  // teks
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  // status
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // medali klasemen
  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFE2E8F0);
  static const bronze = Color(0xFFF97316);
  static const bronzeDark = Color(0xFFB45309);

  // latar tipis baris juara 1-3 di klasemen
  static const podiumGold = Color(0x0DFFD700);
  static const podiumSilver = Color(0x08C0C0C0);
  static const podiumBronze = Color(0x08CD7F32);

  static const black = Color(0xff000000);

  static const primaryGradient = LinearGradient(colors: [primary, primaryDark]);
}
