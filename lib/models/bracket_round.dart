import 'package:rivnet/models/bracket_tie.dart';
import 'package:rivnet/models/match.dart';

// Satu babak di bagan (Perempat Final, Semifinal, Final, ...).
class BracketRound {
  static const namaJuara3 = 'Perebutan Juara 3';

  final String nama;
  final List<BracketTie> ties;

  const BracketRound(this.nama, this.ties);

  /// 'Leg 1 - Semifinal' -> 'Semifinal'
  static String namaBabak(String babak) =>
      babak.replaceFirst(RegExp(r'^Leg [12] - '), '');

  // satu pertemuan = jumlahLeg baris pertandingan berurutan
  static List<BracketTie> _pecah(
    List<Pertandingan> list,
    int jumlahLeg,
    bool babakPertama,
  ) => [
    for (var i = 0; i < list.length; i += jumlahLeg)
      BracketTie(
        list.skip(i).take(jumlahLeg).toList(),
        babakPertama: babakPertama,
      ),
  ];

  /// Menyusun semua pertandingan menjadi babak-babak (Final paling akhir)
  /// dan, kalau ada, perebutan juara 3 secara terpisah.
  static ({List<BracketRound> rounds, BracketRound? juara3}) susun(
    List<Pertandingan> matches,
    int jumlahLeg,
  ) {
    final sorted = [...matches]..sort((a, b) => a.urutan.compareTo(b.urutan));

    final perBabak = <String, List<Pertandingan>>{};
    for (final m in sorted) {
      perBabak.putIfAbsent(namaBabak(m.babak), () => []).add(m);
    }

    final listJuara3 = perBabak.remove(namaJuara3);

    final entries = perBabak.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Final') return 1;
        if (b.key == 'Final') return -1;
        return a.value.first.urutan.compareTo(b.value.first.urutan);
      });

    return (
      rounds: [
        for (var r = 0; r < entries.length; r++)
          BracketRound(
            entries[r].key,
            _pecah(entries[r].value, jumlahLeg, r == 0),
          ),
      ],
      juara3: listJuara3 == null
          ? null
          : BracketRound(namaJuara3, _pecah(listJuara3, jumlahLeg, false)),
    );
  }
}
