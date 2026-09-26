// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/theme/app_colors.dart';
import 'data/database_helper.dart';
import 'screens/home/home_screen.dart';

const _storage = FlutterSecureStorage();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final token = await _storage.read(key: 'user_token');
  final user = await DatabaseHelper.instance.getUserSession();

  final isLoggedIn =
      token != null && token.isNotEmpty && user != null;

  runApp(MyApp(initialUser: isLoggedIn ? user : null));
}

class MyApp extends StatelessWidget {
  final Map<String, dynamic>? initialUser;

  const MyApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RivNet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.bgCard,
        ),
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(user: initialUser),
    );
  }
}