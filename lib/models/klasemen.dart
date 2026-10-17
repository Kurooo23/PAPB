import 'package:rivnet/models/klasemen_item.dart';
import 'package:rivnet/models/match.dart';
import 'package:rivnet/models/peserta.dart';

// Menghitung klasemen liga dari daftar peserta dan pertandingan.
class Klasemen {
  Klasemen._();

  /// Menang = 3 poin, seri = 1, kalah = 0.
  /// Urutan: poin, selisih gol, gol masuk, jumlah menang, nama.
  /// Peserta yang dihapus (WO) tidak masuk klasemen.
  static List<KlasemenItem> hitung({
    required List<Peserta> peserta,
    required List<Pertandingan> matches,
  }) {
    final stats = {
      for (final p in peserta)
        p.id: KlasemenItem(idPeserta: p.id, namaPeserta: p.nama),
    };

    for (final m in matches) {
      if (m.status != 'Selesai') continue;
      final a = stats[m.idPeserta1];
      final b = stats[m.idPeserta2];
      if (a == null || b == null) continue;

      a
        ..main += 1
        ..gm += m.skor1
        ..gk += m.skor2;
      b
        ..main += 1
        ..gm += m.skor2
        ..gk += m.skor1;

      if (m.skor1 > m.skor2) {
        a.menang++;
        b.kalah++;
      } else if (m.skor2 > m.skor1) {
        b.menang++;
        a.kalah++;
      } else {
        a.seri++;
        b.seri++;
      }
    }

    stats.removeWhere((id, _) => peserta.any((p) => p.id == id && p.isWo));

    return stats.values.toList()..sort((a, b) {
      if (b.poin != a.poin) return b.poin.compareTo(a.poin);
      if (b.sg != a.sg) return b.sg.compareTo(a.sg);
      if (b.gm != a.gm) return b.gm.compareTo(a.gm);
      if (b.menang != a.menang) return b.menang.compareTo(a.menang);
      return a.namaPeserta.compareTo(b.namaPeserta);
    });
  }
}
