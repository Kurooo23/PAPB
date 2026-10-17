import 'package:rivnet/models/match.dart';

// Satu pertemuan di bagan: 1 leg, atau 2 leg yang berurutan.
// Semua perhitungan (agregat, penalti, pemenang, bye) ada di sini
// supaya tampilan cukup membaca hasilnya.
class BracketTie {
  final List<Pertandingan> legs;

  /// true kalau pertemuan ini ada di babak pertama bagan.
  /// Slot kosong di babak pertama = BYE, di babak lain = TBD.
  final bool babakPertama;

  const BracketTie(this.legs, {this.babakPertama = false});

  // peserta 1 / 2 mengikuti susunan leg pertama
  String? get idPeserta1 => legs.first.idPeserta1;
  String? get idPeserta2 => legs.first.idPeserta2;

  // lawan kosong di babak pertama -> peserta lain lolos otomatis
  bool get bye1 => babakPertama && idPeserta1 != null && idPeserta2 == null;
  bool get bye2 => babakPertama && idPeserta1 == null && idPeserta2 != null;
  bool get tanpaSkor => bye1 || bye2;

  bool get adaSelesai => legs.any((l) => l.status == 'Selesai');
  bool get semuaSelesai => legs.every((l) => l.status == 'Selesai');

  // Agregat skor semua leg yang sudah selesai.
  // Di leg 2 kandang-tandang tertukar, jadi dicek lewat id peserta.
  int get skor1 => _agregat(untukPeserta1: true);
  int get skor2 => _agregat(untukPeserta1: false);

  int _agregat({required bool untukPeserta1}) {
    var total = 0;
    for (final leg in legs) {
      if (leg.status != 'Selesai') continue;
      final searah = leg.idPeserta1 == idPeserta1;
      total += (searah == untukPeserta1) ? leg.skor1 : leg.skor2;
    }
    return total;
  }

  /// Skor tiap leg dari sudut pandang peserta 1, contoh ['2-1', '0-0'].
  List<String> get skorPerLeg => [
    for (final leg in legs)
      if (leg.status == 'Selesai')
        leg.idPeserta1 == idPeserta1
            ? '${leg.skor1}-${leg.skor2}'
            : '${leg.skor2}-${leg.skor1}',
  ];

  /// Skor adu penalti dari sudut pandang peserta 1: (peserta1, peserta2).
  /// null kalau tidak ada penalti.
  (int, int)? get penalti {
    for (final leg in legs.reversed) {
      final p1 = leg.penalti1;
      final p2 = leg.penalti2;
      if (p1 == null || p2 == null) continue;
      return leg.idPeserta1 == idPeserta1 ? (p1, p2) : (p2, p1);
    }
    return null;
  }

  /// 1 = peserta 1 menang, 2 = peserta 2 menang, null = belum ada pemenang.
  int? get pemenang {
    if (bye1) return 1;
    if (bye2) return 2;
    if (!semuaSelesai || idPeserta1 == null || idPeserta2 == null) return null;

    if (skor1 != skor2) return skor1 > skor2 ? 1 : 2;

    final p = penalti; // agregat imbang -> adu penalti
    if (p == null || p.$1 == p.$2) return null;
    return p.$1 > p.$2 ? 1 : 2;
  }

  String? get idPemenang => switch (pemenang) {
    1 => idPeserta1,
    2 => idPeserta2,
    _ => null,
  };

  /// Laga yang diisi skornya: leg pertama yang belum selesai, atau leg terakhir.
  Pertandingan get legDapatDiisi =>
      legs.firstWhere((l) => l.status != 'Selesai', orElse: () => legs.last);
}
