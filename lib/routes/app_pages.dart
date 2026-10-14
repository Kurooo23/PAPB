import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/turnamen_model.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/turnamen/buat_turnamen_screen.dart';
import '../screens/turnamen/detail_turnamen_screen.dart';
import '../screens/turnamen/edit_turnamen_screen.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final pages = <GetPage>[
    GetPage(name: AppRoutes.home, page: () => const HomeScreen()),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const RegisterScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.verifyEmail,
      page: () => _withArgs(
        (args) => VerifyEmailScreen(
          email: args['email'] as String,
          userId: args['userId'] as String?,
        ),
      ),
    ),
    GetPage(
      name: AppRoutes.buatTurnamen,
      page: () => const BuatTurnamenScreen(),
    ),
    GetPage(
      name: AppRoutes.detailTurnamen,
      page: () => _withArgs(
        (args) => DetailTurnamenScreen(
          idTurnamen: args['idTurnamen'] as String,
          isPrivate: args['isPrivate'] as bool?,
        ),
      ),
    ),
    GetPage(
      name: AppRoutes.editTurnamen,
      page: () => _withArgs(
        (args) => EditTurnamenScreen(turnamen: args['turnamen'] as TurnamenModel),
      ),
    ),
  ];

  // Baca arguments, bisa dari Navigator.pushNamed maupun Get.toNamed
  static Widget _withArgs(Widget Function(Map<String, dynamic> args) builder) {
    return Builder(
      builder: (context) {
        final args = ModalRoute.of(context)?.settings.arguments;
        return builder(args is Map<String, dynamic> ? args : const {});
      },
    );
  }
}