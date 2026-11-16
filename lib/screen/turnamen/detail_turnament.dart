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
            AnimatedBuilder(
              animation: turnamen,
              builder: (context, child) => turnamen.terkunci
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Edit turnamen',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _controller.ubahTurnamen(context),
                    ),
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
              builder: (context, child) =>
                  turnamen.status != 'Selesai' &&
                      turnamen.semuaPertandinganSelesai
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
            Flexible(
              child: AnimatedBuilder(
                animation: turnamen,
                builder: (context, child) {
                  final apakahBracket = turnamen.apakahSingleElimination;
                  return Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: apakahBracket ? 'Bracket' : 'Klasemen'),
                          Tab(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Pertandingan (${turnamen.pertandingan.length})',
                              ),
                            ),
                          ),
                          const Tab(text: 'Peserta'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            apakahBracket
                                ? _BracketTab(
                                    turnamen: turnamen,
                                    controller: _controller,
                                  )
                                : _KlasemenTab(turnamen: turnamen),
                            _PertandinganTab(
                              turnamen: turnamen,
                              controller: _controller,
                            ),
                            _PesertaTab(
                              turnamen: turnamen,
                              controller: _controller,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
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
                      Expanded(
                        child: Text(
                          turnamen.nama,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(turnamen.status),
                    ],
                  ),
                ),
                Text(
                  turnamen.apakahSingleElimination
                      ? '${turnamen.format} • ${turnamen.peserta.length} peserta'
                      : '${turnamen.format} • ${turnamen.leg} Leg • ${turnamen.peserta.length} peserta',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
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
  final Turnamen turnamen;
  const _KlasemenTab({required this.turnamen});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: turnamen,
      builder: (context, child) {
        final klasemen = hitungKlasemen(turnamen);
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
                        peringkat: indeks + 1,
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
      },
    );
  }
}

class _BarisKlasemen extends StatelessWidget {
  final List<String> kolom;
  final bool header;
  final int? peringkat;

  // Rasio kolom tabel klasemen: # : Tim : Main : M : S : K : SG : Poin
  static const double _rasioNo = 10;
  static const double _rasioTim = 44;
  static const double _rasioMain = 12;
  static const double _rasioMenang = 9;
  static const double _rasioSeri = 9;
  static const double _rasioKalah = 9;
  static const double _rasioSg = 11;
  static const double _rasioPoin = 13;
  static const double _totalRasio =
      _rasioNo +
      _rasioTim +
      _rasioMain +
      _rasioMenang +
      _rasioSeri +
      _rasioKalah +
      _rasioSg +
      _rasioPoin;

  const _BarisKlasemen({
    required this.kolom,
    this.header = false,
    this.peringkat,
  });

  Color? _warnaLatarPodium() {
    switch (peringkat) {
      case 1:
        return AppColors.podiumGold;
      case 2:
        return AppColors.podiumSilver;
      case 3:
        return AppColors.podiumBronze;
      default:
        return (peringkat != null && peringkat!.isOdd)
            ? Colors.white.withValues(alpha: 0.015)
            : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final apakahPodium = !header && peringkat != null && peringkat! <= 3;
    // Lebar tabel dihitung responsif dari MediaQuery lalu dibagi sesuai rasio kolom.
    final lebarTabel =
        (MediaQuery.of(context).size.width - 32 - 24 - 1).clamp(260.0, 960.0);
    double lebarBagian(double rasio) => lebarTabel * (rasio / _totalRasio);

    final gayaTeks = TextStyle(
      fontSize: 12,
      fontWeight: header || apakahPodium ? FontWeight.bold : FontWeight.normal,
      color: header ? Colors.white70 : AppColors.textPrimary,
    );

    Widget selKolom(
      String teks, {
      required double rasio,
      bool bold = false,
      Color? warnaTeks,
    }) {
      return SizedBox(
        width: lebarBagian(rasio),
        child: Text(
          teks,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: gayaTeks.copyWith(
            fontWeight: bold ? FontWeight.bold : gayaTeks.fontWeight,
            color: warnaTeks ?? gayaTeks.color,
          ),
        ),
      );
    }

    Widget selPoin() {
      if (header) return selKolom(kolom[7], rasio: _rasioPoin, bold: true);
      return SizedBox(
        width: lebarBagian(_rasioPoin),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            gradient: peringkat == 1 ? AppColors.primaryGradient : null,
            color: peringkat != 1
                ? AppColors.primary.withValues(alpha: 0.2)
                : null,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            kolom[7],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Container(
      color: header ? null : _warnaLatarPodium(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          header
              ? selKolom(kolom[0], rasio: _rasioNo)
              : SizedBox(
                  width: lebarBagian(_rasioNo),
                  child: Center(child: _BadgePeringkat(peringkat: peringkat!)),
                ),
          SizedBox(
            width: lebarBagian(_rasioTim),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  if (!header) ...[
                    LogoKlub(kolom[1], ukuran: 18),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      kolom[1],
                      style: gayaTeks.copyWith(
                        color: !header && peringkat == 1
                            ? AppColors.gold
                            : gayaTeks.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          selKolom(kolom[2], rasio: _rasioMain),
          selKolom(kolom[3], rasio: _rasioMenang),
          selKolom(kolom[4], rasio: _rasioSeri),
          selKolom(kolom[5], rasio: _rasioKalah),
          selKolom(kolom[6], rasio: _rasioSg),
          selPoin(),
        ],
      ),
    );
  }
}

class _BadgePeringkat extends StatelessWidget {
  final int peringkat;
  const _BadgePeringkat({required this.peringkat});

  @override
  Widget build(BuildContext context) {
    const gradien = {
      1: [AppColors.gold, AppColors.warning],
      2: [AppColors.silver, AppColors.textSecondary],
      3: [AppColors.bronze, AppColors.bronzeDark],
    };
    final warna = gradien[peringkat];

    if (warna == null) {
      return Text(
        '$peringkat',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      );
    }

    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: warna),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$peringkat',
        style: TextStyle(
          color: peringkat == 3 ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
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
        final terkunci = turnamen.terkunci;
        final bisaKelolaJumlah = turnamen.bisaKelolaJumlahPeserta;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (bisaKelolaJumlah)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.icon(
                  onPressed: () => controller.dialogPeserta(context),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Tambah Peserta'),
                ),
              )
            else if (!terkunci && turnamen.apakahSingleElimination)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Tambah & hapus peserta dikunci karena sudah ada skor pertandingan.',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
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
                  trailing: terkunci
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit peserta',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => controller.dialogPeserta(
                                context,
                                pesertaYangDiubah: turnamen.peserta[indeks],
                              ),
                            ),
                            if (bisaKelolaJumlah)
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
            if (turnamen.status != 'Selesai')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.icon(
                  onPressed: () => controller.buatPertandingan(context),
                  icon: const Icon(Icons.shuffle),
                  label: Text(
                    turnamen.pertandingan.isEmpty
                        ? 'Buat Pertandingan'
                        : 'Buat Ulang Pertandingan',
                  ),
                ),
              ),
            if (turnamen.pertandingan.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Belum ada hasil pertandingan.')),
              ),
            if (turnamen.apakahSingleElimination)
              ..._daftarPertandinganPerBabak()
            else
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

  List<Widget> _daftarPertandinganPerBabak() {
    final perBabak = <int, List<Pertandingan>>{};
    for (final laga in turnamen.pertandingan) {
      perBabak.putIfAbsent(laga.babak, () => []).add(laga);
    }
    final daftarBabak = perBabak.keys.toList()..sort();
    return [
      for (final babak in daftarBabak) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            turnamen.namaBabak(babak),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),
        for (final pertandingan in perBabak[babak]!)
          _BarisHasil(
            turnamen: turnamen,
            pertandingan: pertandingan,
            controller: controller,
          ),
      ],
    ];
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
        final pemenang = pertandingan.pemenangId;
        final menangA = pemenang != null && pemenang == pertandingan.idA;
        final menangB = pemenang != null && pemenang == pertandingan.idB;
        final bisaInputSkor =
            turnamen.status != 'Selesai' && pertandingan.siapDimainkan;
        FontWeight tebal(bool menang) =>
            menang ? FontWeight.bold : FontWeight.normal;

        final teksTengah = pertandingan.adaBye
            ? 'BYE'
            : (pertandingan.selesai ? '$skorA - $skorB' : 'vs');

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: bisaInputSkor
                ? () => controller.dialogSkor(context, pertandingan)
                : null,
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
                        if (pertandingan.idA.isNotEmpty &&
                            pertandingan.idA != idPesertaBye)
                          LogoKlub(namaA, ukuran: 24),
                      ],
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: Text(
                      teksTengah,
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
                        if (pertandingan.idB.isNotEmpty &&
                            pertandingan.idB != idPesertaBye)
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

// ---------------- Tab Bracket (Row & Column) ----------------
class _BracketTab extends StatelessWidget {
  final Turnamen turnamen;
  final DetailTurnamenController controller;

  const _BracketTab({required this.turnamen, required this.controller});

  @override
  Widget build(BuildContext context) {
    final ukuranLayar = MediaQuery.of(context).size;
    final lebarKolomBabak = (ukuranLayar.width * 0.56).clamp(190.0, 260.0);
    final lebarKonektor = (ukuranLayar.width * 0.075).clamp(24.0, 36.0);
    final tinggiSlotBabak1 = (ukuranLayar.height * 0.16).clamp(116.0, 148.0);

    return AnimatedBuilder(
      animation: turnamen,
      builder: (context, child) {
        if (turnamen.pertandingan.isEmpty) {
          return const Center(
            child: Text('Belum ada bracket (minimal 2 peserta).'),
          );
        }

        final perBabak = <int, List<Pertandingan>>{};
        for (final laga in turnamen.pertandingan) {
          perBabak.putIfAbsent(laga.babak, () => []).add(laga);
        }
        final babakJuara3 = turnamen.babakPerebutanJuara3;
        final daftarBabakEliminasi = [
          for (final nomorBabak in perBabak.keys.toList()..sort())
            if (nomorBabak != babakJuara3) nomorBabak,
        ];
        final matchJuara3 = babakJuara3 != null
            ? (perBabak[babakJuara3]?.firstOrNull)
            : null;
        final jumlahMatchAwal = perBabak[daftarBabakEliminasi.first]!.length;
        final tinggiBracket = jumlahMatchAwal * tinggiSlotBabak1;
        final idJuara = turnamen.idJuara;
        final idJuara3 = turnamen.idJuara3;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (idJuara != null)
                Card(
                  margin: EdgeInsets.only(bottom: idJuara3 != null ? 8 : 16),
                  color: AppColors.gold.withValues(alpha: 0.14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: AppColors.gold,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Juara Turnamen',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                turnamen.namaPeserta(idJuara),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (idJuara3 != null)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: AppColors.bronze.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.bronze.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.military_tech,
                          color: AppColors.bronze,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Juara 3',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                turnamen.namaPeserta(idJuara3),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.bronze,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Babak (Row)
                    Row(
                      children: [
                        for (
                          var indeksBabak = 0;
                          indeksBabak < daftarBabakEliminasi.length;
                          indeksBabak++
                        ) ...[
                          SizedBox(
                            width: lebarKolomBabak,
                            child: Text(
                              turnamen.namaBabak(
                                daftarBabakEliminasi[indeksBabak],
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          if (indeksBabak < daftarBabakEliminasi.length - 1)
                            SizedBox(width: lebarKonektor),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Isi Bracket: Setiap Babak adalah Column di dalam Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var indeksBabak = 0;
                          indeksBabak < daftarBabakEliminasi.length;
                          indeksBabak++
                        ) ...[
                          SizedBox(
                            width: lebarKolomBabak,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: tinggiBracket,
                                  child: Column(
                                    children: [
                                      for (final pertandingan
                                          in perBabak[daftarBabakEliminasi[indeksBabak]]!)
                                        Expanded(
                                          child: Center(
                                            child: _KartuBracketMatch(
                                              turnamen: turnamen,
                                              pertandingan: pertandingan,
                                              controller: controller,
                                              babakFinal:
                                                  indeksBabak ==
                                                  daftarBabakEliminasi.length -
                                                      1,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (matchJuara3 != null &&
                                    indeksBabak ==
                                        daftarBabakEliminasi.length - 2) ...[
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Perebutan Juara 3',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _KartuBracketMatch(
                                    turnamen: turnamen,
                                    pertandingan: matchJuara3,
                                    controller: controller,
                                    babakFinal: false,
                                    perebutanJuara3: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (indeksBabak < daftarBabakEliminasi.length - 1)
                            SizedBox(
                              width: lebarKonektor,
                              height: tinggiBracket,
                              child: Column(
                                children: [
                                  for (
                                    var pasangan = 0;
                                    pasangan <
                                        perBabak[daftarBabakEliminasi[indeksBabak]]!
                                                .length ~/
                                            2;
                                    pasangan++
                                  )
                                    const Expanded(child: _KonektorBracket()),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KonektorBracket extends StatelessWidget {
  const _KonektorBracket();

  @override
  Widget build(BuildContext context) {
    final garis = Colors.white.withValues(alpha: 0.25);
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              const Expanded(child: SizedBox()),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: garis, width: 1.5),
                      right: BorderSide(color: garis, width: 1.5),
                      bottom: BorderSide(color: garis, width: 1.5),
                    ),
                  ),
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              const Expanded(child: SizedBox()),
              Container(height: 1.5, color: garis),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ],
    );
  }
}

class _KartuBracketMatch extends StatelessWidget {
  final Turnamen turnamen;
  final Pertandingan pertandingan;
  final DetailTurnamenController controller;
  final bool babakFinal;
  final bool perebutanJuara3;

  const _KartuBracketMatch({
    required this.turnamen,
    required this.pertandingan,
    required this.controller,
    required this.babakFinal,
    this.perebutanJuara3 = false,
  });

  @override
  Widget build(BuildContext context) {
    final pemenangId = pertandingan.pemenangId;
    final bisaEdit = turnamen.status != 'Selesai' && pertandingan.siapDimainkan;
    final warnaBorder = babakFinal && pemenangId != null
        ? AppColors.gold.withValues(alpha: 0.65)
        : (perebutanJuara3 && pemenangId != null
              ? AppColors.bronze.withValues(alpha: 0.75)
              : Colors.white.withValues(alpha: 0.12));

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: warnaBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: bisaEdit
            ? () => controller.dialogSkor(context, pertandingan)
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BarisTimBracket(
              nama: turnamen.namaPeserta(pertandingan.idA),
              idPeserta: pertandingan.idA,
              skor: pertandingan.skorA,
              menang: pemenangId != null && pemenangId == pertandingan.idA,
            ),
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            _BarisTimBracket(
              nama: turnamen.namaPeserta(pertandingan.idB),
              idPeserta: pertandingan.idB,
              skor: pertandingan.skorB,
              menang: pemenangId != null && pemenangId == pertandingan.idB,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisTimBracket extends StatelessWidget {
  final String nama;
  final String idPeserta;
  final int? skor;
  final bool menang;

  const _BarisTimBracket({
    required this.nama,
    required this.idPeserta,
    required this.skor,
    required this.menang,
  });

  @override
  Widget build(BuildContext context) {
    final apakahKosong = idPeserta.isEmpty || idPeserta == idPesertaBye;
    return Container(
      color: menang ? AppColors.primary.withValues(alpha: 0.16) : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          if (!apakahKosong) ...[
            LogoKlub(nama, ukuran: 20),
            const SizedBox(width: 8),
          ] else ...[
            const Icon(
              Icons.hourglass_empty,
              size: 16,
              color: Colors.white38,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              nama,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: menang ? FontWeight.bold : FontWeight.normal,
                color: apakahKosong
                    ? Colors.white38
                    : (menang ? Colors.white : Colors.white70),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            skor?.toString() ?? '-',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: menang ? AppColors.accent : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
