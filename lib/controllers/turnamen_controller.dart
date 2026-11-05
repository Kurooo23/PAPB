import 'package:flutter/foundation.dart';

import 'package:rivnet/data/dummy_data.dart';
import 'package:rivnet/models/turnamen.dart';

class TurnamenController extends ChangeNotifier {
  static final TurnamenController instance = TurnamenController._();

  TurnamenController._() {
    turnamen.addAll(dummyTurnamen.map(_buatTurnamen));
  }

  final List<Turnamen> turnamen = [];

  Turnamen _buatTurnamen(DataDummyTurnamen data) {
    final daftarPeserta = [
      for (final namaPeserta in data.peserta)
        Peserta(id: buatId('peserta'), nama: namaPeserta),
    ];
    final daftarPertandingan = [
      for (final hasil in data.hasil)
        Pertandingan(
          id: buatId('pertandingan'),
          idA: daftarPeserta[hasil[0]].id,
          idB: daftarPeserta[hasil[1]].id,
          skorA: hasil[2],
          skorB: hasil[3],
        ),
    ];

    return Turnamen(
      id: buatId('turnamen'),
      nama: data.nama,
      game: data.game,
      status: data.status,
      leg: data.leg,
      peserta: daftarPeserta,
      pertandingan: daftarPertandingan,
    );
  }

  void tambahTurnamen(Turnamen turnamenBaru) {
    turnamen.insert(0, turnamenBaru);
  }

  void hapus(String idTurnamen) {
    turnamen.removeWhere((item) => item.id == idTurnamen);
  }

  Turnamen? cari(String idTurnamen) {
    for (final item in turnamen) {
      if (item.id == idTurnamen) return item;
    }
    return null;
  }
}
