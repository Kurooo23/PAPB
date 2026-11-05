import 'package:flutter/material.dart';

import 'package:rivnet/controllers/turnamen_controller.dart';
import 'package:rivnet/routes/app_routes.dart';
import 'package:rivnet/widgets/turnamen_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indeksTabTerpilih = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_indeksTabTerpilih == 0 ? 'Turnamen' : 'Riwayat Turnamen'),
      ),
      body: IndexedStack(
        index: _indeksTabTerpilih,
        children: const [
          DaftarTurnamen(apakahRiwayat: false),
          DaftarTurnamen(apakahRiwayat: true),
        ],
      ),
      floatingActionButton: _indeksTabTerpilih == 0
          ? FloatingActionButton.extended(
              // Named Route
              onPressed: () =>
                  Navigator.pushNamed(context, Routes.createTurnament),
              icon: const Icon(Icons.add),
              label: const Text('Buat Turnamen'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indeksTabTerpilih,
        onDestinationSelected: (indeksBaru) =>
            setState(() => _indeksTabTerpilih = indeksBaru),
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

/// apakahRiwayat = false -> turnamen yang belum selesai
/// apakahRiwayat = true  -> turnamen yang sudah selesai
class DaftarTurnamen extends StatelessWidget {
  final bool apakahRiwayat;
  const DaftarTurnamen({super.key, required this.apakahRiwayat});

  @override
  Widget build(BuildContext context) {
    // Akses controller via singleton (bukan Get.find)
    final turnamenController = TurnamenController.instance;

    return AnimatedBuilder(
      animation: turnamenController,
      builder: (context, child) {
        final daftarTurnamen = turnamenController.turnamen
            .where(
              (turnamen) => apakahRiwayat
                  ? turnamen.status == 'Selesai'
                  : turnamen.status != 'Selesai',
            )
            .toList();

        if (daftarTurnamen.isEmpty) {
          return Center(
            child: Text(
              apakahRiwayat
                  ? 'Belum ada riwayat turnamen.'
                  : 'Belum ada turnamen.',
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: daftarTurnamen.length,
          itemBuilder: (context, indeks) =>
              TurnamenCard(turnamen: daftarTurnamen[indeks]),
        );
      },
    );
  }
}
