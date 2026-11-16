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
  void initState() {
    super.initState();
    TurnamenController.instance.muatDariDatabase();
  }

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
        if (!turnamenController.sudahDimuat &&
            turnamenController.sedangMemuat) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!turnamenController.sudahDimuat &&
            turnamenController.errorMuat != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat database.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        turnamenController.muatDariDatabase(paksa: true),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

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
        final lebarLayar = MediaQuery.of(context).size.width;
        final duaKolom = lebarLayar > 600;
        const paddingLuar = 16.0;
        const gap = 12.0;

        if (!duaKolom) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              paddingLuar,
              16,
              paddingLuar,
              90,
            ),
            itemCount: daftarTurnamen.length,
            itemBuilder: (context, indeks) =>
                TurnamenCard(turnamen: daftarTurnamen[indeks]),
          );
        }

        // Layar lebar (> 600): Row 2 kolom rasio 1:1 berbasis MediaQuery
        final lebarKartu = (lebarLayar - paddingLuar * 2 - gap) / 2;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(paddingLuar, 16, paddingLuar, 90),
          itemCount: (daftarTurnamen.length / 2).ceil(),
          itemBuilder: (context, indeksBaris) {
            final indeksKiri = indeksBaris * 2;
            final indeksKanan = indeksKiri + 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: lebarKartu,
                  child: TurnamenCard(turnamen: daftarTurnamen[indeksKiri]),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: lebarKartu,
                  child: indeksKanan < daftarTurnamen.length
                      ? TurnamenCard(turnamen: daftarTurnamen[indeksKanan])
                      : const SizedBox.shrink(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
