import 'package:flutter/material.dart';

import 'package:rivnet/screen/main/home_screen.dart';
import 'package:rivnet/screen/main/riwayat_screen.dart';
import 'package:rivnet/themes/color.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _screens = const [HomeScreen(), RiwayatScreen()];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                color: AppColors.kBackground,
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
                alignment: Alignment.centerLeft,
                child: Text(
                  'RivNet',
                  style: TextStyle(
                    fontSize: size.width * 0.05,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(flex: 8, child: _screens[_index]),
            Expanded(
              flex: 1,
              child: Container(
                color: AppColors.kNavBar,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _navItem(
                        0,
                        Icons.dashboard,
                        'Daftar Turnamen',
                        size,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: _navItem(1, Icons.history, 'Riwayat', size),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label, Size size) {
    final aktif = _index == i;
    final warna = aktif ? AppColors.kTeal : Colors.white70;

    return InkWell(
      onTap: () => setState(() => _index = i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: warna, size: size.width * 0.06),
          SizedBox(height: size.height * 0.005),
          Text(
            label,
            style: TextStyle(color: warna, fontSize: size.width * 0.03),
          ),
        ],
      ),
    );
  }
}
