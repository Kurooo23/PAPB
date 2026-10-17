import 'package:flutter/material.dart';

import 'package:rivnet/models/bracket_round.dart';
import 'package:rivnet/models/bracket_tie.dart';
import 'package:rivnet/models/klasemen.dart';
import 'package:rivnet/models/klasemen_item.dart';
import 'package:rivnet/models/match.dart';
import 'package:rivnet/models/peserta.dart';
import 'package:rivnet/models/tournament.dart';
import 'package:rivnet/themes/color.dart';

/// Tampilan saja. Semua perhitungan ada di folder models:
/// - Liga               -> Klasemen.hitung()  -> tabel klasemen
/// - Single Elimination -> BracketRound.susun() -> bagan per babak
class Bracket extends StatelessWidget {
  final Tournament turnamen;
  final List<Peserta> peserta;
  final List<Pertandingan> matches;

  /// Dipanggil saat kartu pertandingan di bagan ditekan (opsional),
  /// misalnya untuk membuka dialog input skor.
  final ValueChanged<Pertandingan>? onTapMatch;

  const Bracket({
    super.key,
    required this.turnamen,
    required this.peserta,
    required this.matches,
    this.onTapMatch,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return turnamen.isKnockout ? _bagan(size) : _klasemen(size);
  }

  // ========================================================================
  // LIGA: KLASEMEN
  // ========================================================================

  // # : Tim : M : W : D : L : GF : GA : GD : PTS
  static const List<int> _flexKolom = [1, 6, 1, 1, 1, 1, 1, 1, 2, 2];

  Widget _klasemen(Size size) {
    final data = Klasemen.hitung(peserta: peserta, matches: matches);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(size.width * 0.03),
      decoration: BoxDecoration(
        color: AppColors.kNavBar,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barisTabel(size, [
            '#',
            'Tim',
            'M',
            'W',
            'D',
            'L',
            'GF',
            'GA',
            'GD',
            'PTS',
          ], header: true),
          const Divider(height: 1, color: Colors.white24),
          for (var i = 0; i < data.length; i++)
            _barisTabel(size, _kolomKlasemen(i + 1, data[i]), peringkat: i + 1),
          SizedBox(height: size.height * 0.01),
          const Text(
            'M = Main  •  W = Menang  •  D = Seri  •  L = Kalah  •  '
            'GF = Gol Masuk  •  GA = Gol Kebobolan  •  GD = Selisih Gol  •  '
            'PTS = Poin',
            style: TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  List<String> _kolomKlasemen(int rank, KlasemenItem k) => [
    '$rank',
    k.namaPeserta,
    '${k.main}',
    '${k.menang}',
    '${k.seri}',
    '${k.kalah}',
    '${k.gm}',
    '${k.gk}',
    k.sg > 0 ? '+${k.sg}' : '${k.sg}',
    '${k.poin}',
  ];

  Widget _barisTabel(
    Size size,
    List<String> kolom, {
    bool header = false,
    int? peringkat,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.009),
      child: Row(
        children: [
          for (var i = 0; i < kolom.length; i++)
            Expanded(
              flex: _flexKolom[i],
              child: Text(
                kolom[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: i == 1 ? TextAlign.start : TextAlign.center,
                style: TextStyle(
                  fontSize: header ? 11 : 12,
                  color: header
                      ? Colors.white70
                      : (i == 0 && peringkat == 1)
                      ? AppColors.kTeal
                      : Colors.white,
                  fontWeight: (header || i == 9 || (i == 0 && peringkat == 1))
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========================================================================
  // SINGLE ELIMINATION: BAGAN
  // ========================================================================

  Widget _bagan(Size size) {
    if (matches.isEmpty) {
      return const Text(
        'Belum ada pertandingan.',
        style: TextStyle(fontSize: 12, color: Colors.white70),
      );
    }

    final susunan = BracketRound.susun(matches, turnamen.jumlahLeg);
    final nama = Peserta.petaNama(peserta);
    final rounds = susunan.rounds;
    final juara3 = susunan.juara3;

    // Judul Babak (Semifinal, Final, dll) dengan warna kuning terang
    Widget judulBabak(String teks) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.amberAccent, // Kuning Terang
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var r = 0; r < rounds.length; r++) ...[
            SizedBox(
              width: size.width * 0.6, // lebar tiap kolom babak
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  judulBabak(rounds[r].nama),
                  for (final tie in rounds[r].ties) _kartuTie(size, tie, nama),
                  // perebutan juara 3 ditaruh di bawah kolom semifinal
                  if (rounds[r].nama.contains('Semifinal') &&
                      juara3 != null) ...[
                    SizedBox(height: size.height * 0.01),
                    judulBabak(juara3.nama),
                    for (final tie in juara3.ties) _kartuTie(size, tie, nama),
                  ],
                ],
              ),
            ),
            if (r < rounds.length - 1)
              SizedBox(
                width: size.width * 0.07,
                child: const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: Colors.white38,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _kartuTie(Size size, BracketTie tie, Map<String, String> nama) {
    final kosong = tie.babakPertama ? 'BYE' : 'TBD';
    final nama1 = tie.idPeserta1 == null
        ? kosong
        : (nama[tie.idPeserta1] ?? kosong);
    final nama2 = tie.idPeserta2 == null
        ? kosong
        : (nama[tie.idPeserta2] ?? kosong);

    final skor1 = tie.tanpaSkor ? '' : (tie.adaSelesai ? '${tie.skor1}' : '-');
    final skor2 = tie.tanpaSkor ? '' : (tie.adaSelesai ? '${tie.skor2}' : '-');

    final penalti = tie.penalti;
    final keterangan = [
      if (tie.legs.length > 1 && tie.skorPerLeg.isNotEmpty)
        'Leg: ${tie.skorPerLeg.join(' · ')}',
      if (penalti != null) 'Penalti ${penalti.$1}-${penalti.$2}',
    ].join('  •  ');

    return Padding(
      padding: EdgeInsets.only(bottom: size.height * 0.012),
      child: Material(
        color: AppColors.kNavBar,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white24),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTapMatch == null
              ? null
              : () => onTapMatch!(tie.legDapatDiisi),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.03,
              vertical: size.height * 0.01,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _barisTim(nama1, skor1, tie.pemenang == 1),
                const SizedBox(height: 4),
                _barisTim(nama2, skor2, tie.pemenang == 2),
                if (keterangan.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      keterangan,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Pemenang match diberi warna kuning terang (amberAccent)
  Widget _barisTim(String nama, String skor, bool menang) {
    final warna = menang ? Colors.amberAccent : Colors.white;
    final tebal = menang ? FontWeight.bold : FontWeight.normal;

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            nama,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: warna, fontWeight: tebal, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            skor,
            textAlign: TextAlign.end,
            style: TextStyle(color: warna, fontWeight: tebal, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
