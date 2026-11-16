import 'package:flutter/material.dart';

import 'package:rivnet/routes/app_routes.dart';
import 'package:rivnet/screen/main/home_screen.dart';
import 'package:rivnet/screen/turnamen/create_turnament.dart';
import 'package:rivnet/screen/turnamen/detail_turnament.dart';
import 'package:rivnet/themes/app_theme.dart';
import 'package:rivnet/utils/pesan.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RivnetApp());
}

class RivnetApp extends StatelessWidget {
  const RivnetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rivnet',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      initialRoute: Routes.home,
      onGenerateRoute: (settings) {
        Widget halaman;
        switch (settings.name) {
          case Routes.createTurnament:
          case Routes.editTurnament:
            // edit turnament & create turnament pakai layar yang sama
            halaman = const CreateTurnamentScreen();
            break;
          case Routes.detailTurnament:
            halaman = const DetailTurnamentScreen();
            break;
          case Routes.home:
          default:
            halaman = const HomeScreen();
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => halaman,
        );
      },
    );
  }
}
