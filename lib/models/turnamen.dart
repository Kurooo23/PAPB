import 'package:flutter/foundation.dart';

int _counterIdOtomatis = 0;
String buatId(String awalanId) => '$awalanId-${++_counterIdOtomatis}';

class Peserta {
  final String id;
  String nama;
  Peserta({required this.id, required this.nama});
}

class Pertandingan {
  final String id;
  final String idA;
  final String idB;
  int? skorA;
  int? skorB;

  Pertandingan({
    required this.id,
    required this.idA,
    required this.idB,
    this.skorA,
    this.skorB,
  });

  bool get selesai => skorA != null && skorB != null;
}

class Turnamen extends ChangeNotifier {
  static const daftarStatus = ['Akan Datang', 'Berlangsung', 'Selesai'];

  final String id;
  String nama;
  String game;
  int leg;
  String status;
  final List<Peserta> peserta;
  final List<Pertandingan> pertandingan;

  Turnamen({
    required this.id,
    required this.nama,
    required this.game,
    this.leg = 1,
    this.status = 'Akan Datang',
    List<Peserta>? peserta,
    List<Pertandingan>? pertandingan,
  }) : peserta = peserta ?? [],
       pertandingan = pertandingan ?? [];

  String namaPeserta(String idPeserta) {
    for (final itemPeserta in peserta) {
      if (itemPeserta.id == idPeserta) return itemPeserta.nama;
    }
    return '-';
  }

  String get namaTurnamen => nama;
  set namaTurnamen(String nilai) => nama = nilai;

  String get gameTurnamen => game;
  set gameTurnamen(String nilai) => game = nilai;

  int get jumlahLeg => leg;
  set jumlahLeg(int nilai) => leg = nilai;

  String get statusTurnamen => status;
  set statusTurnamen(String nilai) {
    if (daftarStatus.contains(nilai)) status = nilai;
  }
}
