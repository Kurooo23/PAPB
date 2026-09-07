import 'package:flutter/material.dart';
import 'dart:math';

class AvatarHelper {
  // 25 ikon avatar bertema gaming, kompetitif, dan komunitas
  static const List<IconData> _avatarIcons = [
    Icons.sports_esports_rounded,
    Icons.videogame_asset_rounded,
    Icons.gamepad_rounded,
    Icons.smart_toy_rounded,
    Icons.psychology_rounded,

    Icons.local_fire_department_rounded,
    Icons.bolt_rounded,
    Icons.flash_on_rounded,
    Icons.auto_awesome_rounded,
    Icons.whatshot_rounded,

    Icons.emoji_events_rounded,
    Icons.military_tech_rounded,
    Icons.workspace_premium_rounded,
    Icons.shield_rounded,
    Icons.gpp_good_rounded,

    Icons.diamond_rounded,
    Icons.star_rounded,
    Icons.rocket_launch_rounded,
    Icons.sailing_rounded,
    Icons.flight_takeoff_rounded,

    Icons.pets_rounded,
    Icons.cruelty_free_rounded,
    Icons.bug_report_rounded,
    Icons.smartphone_rounded,
    Icons.memory_rounded,
  ];

  // Mendapatkan ikon berdasarkan index dari database
  static IconData getIcon(int? index) {
    if (index == null || index < 0 || index >= _avatarIcons.length) {
      return Icons.sports_esports_rounded;
    }

    return _avatarIcons[index];
  }

  // Memilih avatar secara acak saat register
  static int getRandomIndex() {
    return Random().nextInt(_avatarIcons.length);
  }
}