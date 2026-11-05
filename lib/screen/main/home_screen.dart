import 'package:flutter/material.dart';

import 'package:rivnet/controllers/turnamen_controller.dart';
import 'package:rivnet/routes/app_routes.dart';
import 'package:rivnet/widgets/turnamen_card.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Turnamen' : 'Riwayat Turnamen'),
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          DaftarTurnamen(riwayat: false),
          DaftarTurnamen(riwayat: true),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              // Named Route pakai Navigator.pushNamed (bukan Get.toNamed)
              onPressed: () =>
                  Navigator.pushNamed(context, Routes.createTurnament),
              icon: const Icon(Icons.add),
              label: const Text('Buat Turnamen'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Turnamen',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history_toggle_off),
            label: 'Riwayat',
          ),
        ],
      ),
    );
  }
}

/// riwayat = false -> turnamen yang belum selesai
/// riwayat = true  -> turnamen yang sudah selesai
class DaftarTurnamen extends StatelessWidget {
  final bool riwayat;
  const DaftarTurnamen({super.key, required this.riwayat});

  @override
  Widget build(BuildContext context) {
    // Akses controller via singleton (bukan Get.find)
    final tc = TurnamenController.instance;

    // AnimatedBuilder menggantikan Obx (bukan GetX)
    return AnimatedBuilder(
      animation: tc,
      builder: (context, _) {
        final data = tc.turnamen
            .where(
              (t) => riwayat ? t.status == 'Selesai' : t.status != 'Selesai',
            )
            .toList();

        if (data.isEmpty) {
          return Center(
            child: Text(
              riwayat ? 'Belum ada riwayat turnamen.' : 'Belum ada turnamen.',
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: data.length,
          itemBuilder: (_, i) => TurnamenCard(t: data[i]),
        );
      },
    );
  }
}
