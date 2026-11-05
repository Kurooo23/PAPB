import 'package:get/get.dart';

int _no = 0;
String buatId(String prefix) => '$prefix-${++_no}';

class Peserta {
  final String id;
  final RxString nama;
  Peserta({required this.id, required String nama}) : nama = nama.obs;
}

class Pertandingan {
  final String id;
  final String idA;
  final String idB;
  final int skorA;
  final int skorB;
  const Pertandingan({
    required this.id,
    required this.idA,
    required this.idB,
    required this.skorA,
    required this.skorB,
  });
}

class Turnamen {
  static const daftarStatus = ['Akan Datang', 'Berlangsung', 'Selesai'];

  final String id;
  final RxString nama;
  final RxString game;
  final RxString lokasi;
  final RxString status;
  final peserta = <Peserta>[].obs;
  final pertandingan = <Pertandingan>[].obs;

  Turnamen({
    required this.id,
    required String nama,
    required String game,
    required String lokasi,
    String status = 'Akan Datang',
  }) : nama = nama.obs,
       game = game.obs,
       lokasi = lokasi.obs,
       status = status.obs;

  String namaPeserta(String idPeserta) =>
      peserta.firstWhereOrNull((p) => p.id == idPeserta)?.nama.value ?? '-';
}
