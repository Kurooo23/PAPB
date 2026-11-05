import 'package:flutter/material.dart';

import 'package:rivnet/controllers/detail_turnamen_controller.dart';
import 'package:rivnet/models/klasemen.dart';
import 'package:rivnet/models/turnamen.dart';
import 'package:rivnet/themes/color.dart';
import 'package:rivnet/widgets/logo_klub.dart';
import 'package:rivnet/widgets/turnamen_card.dart';

class DetailTurnamentScreen extends StatefulWidget {
  const DetailTurnamentScreen({super.key});

  @override
  State<DetailTurnamentScreen> createState() => _DetailTurnamentScreenState();
}

class _DetailTurnamentScreenState extends State<DetailTurnamentScreen> {
  final _controller = DetailTurnamenController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ambil argumen Named Route
    _controller.init(ModalRoute.of(context)?.settings.arguments);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final turnamen = _controller.data;

    if (turnamen == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Turnamen')),
        body: const Center(child: Text('Turnamen tidak ditemukan.')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detail Turnamen'),
          actions: [
            IconButton(
              tooltip: 'Edit turnamen',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _controller.ubahTurnamen(context),
            ),
            IconButton(
              tooltip: 'Hapus turnamen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _controller.hapusTurnamen(context),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _Header(turnamen: turnamen),
            ),
            AnimatedBuilder(
              animation: turnamen,
              builder: (context, child) => turnamen.status != 'Selesai'
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Flexible(
                            fit: FlexFit.tight,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _controller.akhiriTurnamen(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.black,
                              ),
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Akhiri turnamen & kunci skor'),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Klasemen'),
                Tab(text: 'Pertandingan'),
                Tab(text: 'Peserta'),
              ],
            ),
            Flexible(
              child: TabBarView(
                children: [
                  _KlasemenTab(klasemen: _controller.klasemenTersimpan),
                  _PertandinganTab(turnamen: turnamen, controller: _controller),
                  _PesertaTab(turnamen: turnamen, controller: _controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Turnamen turnamen;
  const _Header({required this.turnamen});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: turnamen,
      builder: (context, child) {
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          turnamen.nama,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StatusChip(turnamen.status),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------- Tab Klasemen ----------------
class _KlasemenTab extends StatelessWidget {
  final List<KlasemenItem> klasemen;
  const _KlasemenTab({required this.klasemen});

  @override
  Widget build(BuildContext context) {
    if (klasemen.isEmpty) {
      return const Center(child: Text('Belum ada peserta.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                const _BarisKlasemen(
                  kolom: ['#', 'Tim', 'Main', 'M', 'S', 'K', 'SG', 'Poin'],
                  header: true,
                ),
                const Divider(height: 1),
                for (var indeks = 0; indeks < klasemen.length; indeks++)
                  _BarisKlasemen(
                    juara: indeks == 0 && klasemen[indeks].main > 0,
                    kolom: [
                      '${indeks + 1}',
                      klasemen[indeks].nama,
                      '${klasemen[indeks].main}',
                      '${klasemen[indeks].menang}',
                      '${klasemen[indeks].seri}',
                      '${klasemen[indeks].kalah}',
                      klasemen[indeks].selisihGol > 0
                          ? '+${klasemen[indeks].selisihGol}'
                          : '${klasemen[indeks].selisihGol}',
                      '${klasemen[indeks].poin}',
                    ],
                  ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'M = menang, S = seri, K = kalah, SG = selisih gol.\n'
            'Menang 3 poin, seri 1 poin.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _BarisKlasemen extends StatelessWidget {
  final List<String> kolom;
  final bool header;
  final bool juara;

  const _BarisKlasemen({
    required this.kolom,
    this.header = false,
    this.juara = false,
  });

  @override
  Widget build(BuildContext context) {
    final gayaTeks = TextStyle(
      fontSize: 13,
      fontWeight: header || juara ? FontWeight.bold : FontWeight.normal,
      color: header ? Colors.white70 : Colors.white,
    );

    Widget selKolom(String teks, {double lebarKolom = 30, bool bold = false}) {
      return ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: lebarKolom),
        child: Text(
          teks,
          textAlign: TextAlign.center,
          style: bold
              ? gayaTeks.copyWith(fontWeight: FontWeight.bold)
              : gayaTeks,
        ),
      );
    }

    return Container(
      color: juara ? AppColors.primary.withValues(alpha: 0.12) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          selKolom(kolom[0], lebarKolom: 22),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                children: [
                  if (!header) ...[
                    LogoKlub(kolom[1], ukuran: 18),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      kolom[1],
                      style: gayaTeks,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          selKolom(kolom[2], lebarKolom: 36),
          selKolom(kolom[3]),
          selKolom(kolom[4]),
          selKolom(kolom[5]),
          selKolom(kolom[6], lebarKolom: 34),
          selKolom(kolom[7], lebarKolom: 38, bold: true),
        ],
      ),
    );
  }
}

// ---------------- Tab Peserta ----------------
class _PesertaTab extends StatelessWidget {
  final Turnamen turnamen;
  final DetailTurnamenController controller;
  const _PesertaTab({required this.turnamen, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: turnamen,
      builder: (context, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                onPressed: () => controller.dialogPeserta(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Tambah Peserta'),
              ),
            ),
            if (turnamen.peserta.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Belum ada peserta.')),
              ),
            for (var indeks = 0; indeks < turnamen.peserta.length; indeks++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: LogoKlub(turnamen.peserta[indeks].nama, ukuran: 36),
                  title: Text(turnamen.peserta[indeks].nama),
                  subtitle: Text('Peserta ${indeks + 1}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit peserta',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => controller.dialogPeserta(
                          context,
                          ubah: turnamen.peserta[indeks],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hapus peserta',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => controller.hapusPeserta(
                          context,
                          turnamen.peserta[indeks],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------- Tab Pertandingan ----------------
class _PertandinganTab extends StatelessWidget {
  final Turnamen turnamen;
  final DetailTurnamenController controller;
  const _PertandinganTab({required this.turnamen, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: turnamen,
      builder: (context, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (turnamen.pertandingan.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Belum ada hasil pertandingan.')),
              ),
            for (final pertandingan in turnamen.pertandingan)
              _BarisHasil(
                turnamen: turnamen,
                pertandingan: pertandingan,
                controller: controller,
              ),
          ],
        );
      },
    );
  }
}

class _BarisHasil extends StatelessWidget {
  final Turnamen turnamen;
  final Pertandingan pertandingan;
  final DetailTurnamenController controller;
  const _BarisHasil({
    required this.turnamen,
    required this.pertandingan,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: turnamen,
      builder: (context, child) {
        final skorA = pertandingan.skorA;
        final skorB = pertandingan.skorB;
        final namaA = turnamen.namaPeserta(pertandingan.idA);
        final namaB = turnamen.namaPeserta(pertandingan.idB);
        final menangA = (skorA != null && skorB != null) && skorA > skorB;
        final menangB = (skorA != null && skorB != null) && skorB > skorA;
        FontWeight tebal(bool menang) =>
            menang ? FontWeight.bold : FontWeight.normal;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: turnamen.status == 'Selesai'
                ? null
                : () => controller.dialogSkor(context, pertandingan),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            namaA,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontWeight: tebal(menangA)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        LogoKlub(namaA, ukuran: 24),
                      ],
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: Text(
                      pertandingan.selesai ? '$skorA - $skorB' : 'vs',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 2,
                    child: Row(
                      children: [
                        LogoKlub(namaB, ukuran: 24),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            namaB,
                            style: TextStyle(fontWeight: tebal(menangB)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
