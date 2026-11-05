import 'package:rivnet/models/turnamen.dart';

class KlasemenItem {
  final String nama;
  int main = 0;
  int menang = 0;
  int seri = 0;
  int kalah = 0;
  int golMasuk = 0;
  int golKebobolan = 0;

  KlasemenItem(this.nama);

  int get selisihGol => golMasuk - golKebobolan;
  int get poin => menang * 3 + seri;
}

List<KlasemenItem> hitungKlasemen(Turnamen turnamen) {
  final petaKlasemenPeserta = {
    for (final peserta in turnamen.peserta)
      peserta.id: KlasemenItem(peserta.nama),
  };

  for (final pertandingan in turnamen.pertandingan) {
    final skorA = pertandingan.skorA;
    final skorB = pertandingan.skorB;
    if (skorA == null || skorB == null) continue;

    final pesertaA = petaKlasemenPeserta[pertandingan.idA];
    final pesertaB = petaKlasemenPeserta[pertandingan.idB];
    if (pesertaA == null || pesertaB == null) continue;

    pesertaA.main++;
    pesertaB.main++;
    pesertaA.golMasuk += skorA;
    pesertaA.golKebobolan += skorB;
    pesertaB.golMasuk += skorB;
    pesertaB.golKebobolan += skorA;

    if (skorA > skorB) {
      pesertaA.menang++;
      pesertaB.kalah++;
    } else if (skorB > skorA) {
      pesertaB.menang++;
      pesertaA.kalah++;
    } else {
      pesertaA.seri++;
      pesertaB.seri++;
    }
  }

  return petaKlasemenPeserta.values.toList()
    ..sort((pesertaA, pesertaB) {
      if (pesertaB.poin != pesertaA.poin) {
        return pesertaB.poin.compareTo(pesertaA.poin);
      }
      if (pesertaB.selisihGol != pesertaA.selisihGol) {
        return pesertaB.selisihGol.compareTo(pesertaA.selisihGol);
      }
      if (pesertaB.golMasuk != pesertaA.golMasuk) {
        return pesertaB.golMasuk.compareTo(pesertaA.golMasuk);
      }
      return pesertaA.nama.compareTo(pesertaB.nama);
    });
}
