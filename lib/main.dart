import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:rivnet/controllers/turnamen_controller.dart';
import 'package:rivnet/screen/main/main_shell.dart';
import 'package:rivnet/themes/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(TurnamenController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Rivnet Training',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const MainShell(),
    );
  }
}
