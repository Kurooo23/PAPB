import 'dart:math';

import 'package:flutter/foundation.dart';

int _counterIdOtomatis = 0;
String buatId(String awalanId) =>
    '$awalanId-${DateTime.now().microsecondsSinceEpoch}-${++_counterIdOtomatis}';

class Peserta {
  final String id;
  String nama;
  Peserta({required this.id, required this.nama});

  factory Peserta.fromMap(Map<String, dynamic> map) {
    return Peserta(
      id: map['id'] as String,
      nama: map['nama'] as String,
    );
  }

  Map<String, dynamic> toMap({
    required String turnamenId,
    required int urutan,
  }) {
    return {
      'id': id,
      'turnamen_id': turnamenId,
      'nama': nama,
      'urutan': urutan,
    };
  }
}

const String idPesertaBye = '__BYE__';

class Pertandingan {
  final String id;
  String idA;
  String idB;
  int? skorA;
  int? skorB;
  int babak;

  Pertandingan({
    required this.id,
    required this.idA,
    required this.idB,
    this.skorA,
    this.skorB,
    this.babak = 1,
  });

  bool get selesai => skorA != null && skorB != null;
  bool get adaBye => idA == idPesertaBye || idB == idPesertaBye;
  bool get siapDimainkan => idA.isNotEmpty && idB.isNotEmpty && !adaBye;

  String? get pemenangId {
    if (idB == idPesertaBye && idA.isNotEmpty && idA != idPesertaBye) {
      return idA;
    }
    if (idA == idPesertaBye && idB.isNotEmpty && idB != idPesertaBye) {
      return idB;
    }
    if (!selesai || skorA == skorB) return null;
    return skorA! > skorB! ? idA : idB;
  }

  String? get kalahId {
    if (!siapDimainkan || !selesai || skorA == skorB) return null;
    return skorA! < skorB! ? idA : idB;
  }

  factory Pertandingan.fromMap(Map<String, dynamic> map) {
    return Pertandingan(
      id: map['id'] as String,
      idA: map['id_a'] as String,
      idB: map['id_b'] as String,
      skorA: map['skor_a'] as int?,
      skorB: map['skor_b'] as int?,
      babak: (map['babak'] as int?) ?? 1,
    );
  }

  Map<String, dynamic> toMap({
    required String turnamenId,
    required int urutan,
  }) {
    return {
      'id': id,
      'turnamen_id': turnamenId,
      'id_a': idA,
      'id_b': idB,
      'skor_a': skorA,
      'skor_b': skorB,
      'babak': babak,
      'urutan': urutan,
    };
  }
}

class Turnamen extends ChangeNotifier {
  static const daftarStatus = ['Akan Datang', 'Berlangsung', 'Selesai'];
  static const formatLiga = 'Liga';
  static const formatSingleElimination = 'Single Elimination';
  static const daftarFormat = [formatLiga, formatSingleElimination];

  final String id;
  String nama;
  String game;
  String format;
  int leg;
  String status;
  final List<Peserta> peserta;
  final List<Pertandingan> pertandingan;

  Turnamen({
    required this.id,
    required this.nama,
    required this.game,
    this.format = formatLiga,
    this.leg = 1,
    this.status = 'Akan Datang',
    List<Peserta>? peserta,
    List<Pertandingan>? pertandingan,
  }) : peserta = peserta ?? [],
       pertandingan = pertandingan ?? [];

  factory Turnamen.fromMap(
    Map<String, dynamic> map, {
    List<Peserta>? peserta,
    List<Pertandingan>? pertandingan,
  }) {
    final statusTersimpan = map['status'] as String? ?? 'Akan Datang';
    final formatTersimpan = map['format'] as String? ?? formatLiga;
    return Turnamen(
      id: map['id'] as String,
      nama: map['nama'] as String,
      game: map['game'] as String? ?? 'Sepak Bola',
      format: daftarFormat.contains(formatTersimpan)
          ? formatTersimpan
          : formatLiga,
      leg: (map['leg'] as int?) ?? 1,
      status: daftarStatus.contains(statusTersimpan)
          ? statusTersimpan
          : 'Akan Datang',
      peserta: peserta,
      pertandingan: pertandingan,
    );
  }

  Map<String, dynamic> toMap({int? createdAt}) {
    return {
      'id': id,
      'nama': nama,
      'game': game,
      'format': format,
      'leg': leg,
      'status': status,
      'created_at': createdAt ?? DateTime.now().microsecondsSinceEpoch,
    };
  }

  void perbaruiTampilan() => notifyListeners();

  bool get apakahSingleElimination => format == formatSingleElimination;
  bool get terkunci => status == 'Selesai';
  bool get adaPertandinganSelesai => pertandingan.any((laga) => laga.selesai);

  /// Untuk Single Elimination, tambah/hapus peserta hanya diizinkan
  /// ketika belum ada pertandingan yang skornya diisi.
  bool get bisaKelolaJumlahPeserta =>
      !terkunci && (!apakahSingleElimination || !adaPertandinganSelesai);

  /// True jika jadwal sudah ada dan semua laga non-BYE sudah memiliki skor.
  bool get semuaPertandinganSelesai =>
      pertandingan.isNotEmpty &&
      pertandingan.every((laga) => laga.adaBye || laga.selesai);

  String namaPeserta(String idPeserta) {
    if (idPeserta == idPesertaBye) return 'BYE';
    if (idPeserta.isEmpty) return 'TBD';
    for (final itemPeserta in peserta) {
      if (itemPeserta.id == idPeserta) return itemPeserta.nama;
    }
    return '-';
  }

  int get _babakTerakhirBracket {
    var totalBabak = 1;
    for (final laga in pertandingan) {
      if (laga.babak > totalBabak) totalBabak = laga.babak;
    }
    return totalBabak;
  }

  /// True jika bracket memiliki babak Perebutan Juara 3 sebelum Final.
  bool get apakahAdaPerebutanJuara3 {
    if (!apakahSingleElimination || pertandingan.isEmpty) return false;
    final totalBabak = _babakTerakhirBracket;
    if (totalBabak < 3) return false;
    final jumlahSebelumFinal = pertandingan
        .where((laga) => laga.babak == totalBabak - 1)
        .length;
    final jumlahFinal = pertandingan
        .where((laga) => laga.babak == totalBabak)
        .length;
    return jumlahSebelumFinal == 1 && jumlahFinal == 1;
  }

  int? get babakPerebutanJuara3 =>
      apakahAdaPerebutanJuara3 ? _babakTerakhirBracket - 1 : null;

  String namaBabak(int babak) {
    if (!apakahSingleElimination || pertandingan.isEmpty) return 'Babak $babak';
    final totalBabak = _babakTerakhirBracket;
    if (apakahAdaPerebutanJuara3) {
      if (babak == totalBabak) return 'Final';
      if (babak == totalBabak - 1) return 'Perebutan Juara 3';
      if (babak == totalBabak - 2) return 'Semifinal';
      if (babak == totalBabak - 3) return 'Perempat Final';
      return 'Babak $babak';
    }
    if (babak == totalBabak) return 'Final';
    if (babak == totalBabak - 1) return 'Semifinal';
    if (babak == totalBabak - 2) return 'Perempat Final';
    return 'Babak $babak';
  }

  String? get idJuara {
    if (!apakahSingleElimination || pertandingan.isEmpty) return null;
    final babakTerakhir = _babakTerakhirBracket;
    final finalMatches = pertandingan.where(
      (laga) => laga.babak == babakTerakhir,
    );
    if (finalMatches.isEmpty) return null;
    return finalMatches.first.pemenangId;
  }

  String? get idJuara3 {
    final babak3 = babakPerebutanJuara3;
    if (babak3 == null) return null;
    final matches = pertandingan.where((laga) => laga.babak == babak3);
    if (matches.isEmpty) return null;
    return matches.first.pemenangId;
  }

  String get namaTurnamen => nama;
  set namaTurnamen(String nilai) => nama = nilai;

  String get gameTurnamen => game;
  set gameTurnamen(String nilai) => game = nilai;

  String get formatTurnamen => format;
  set formatTurnamen(String nilai) {
    if (daftarFormat.contains(nilai)) format = nilai;
  }

  int get jumlahLeg => leg;
  set jumlahLeg(int nilai) => leg = nilai;

  String get statusTurnamen => status;
  set statusTurnamen(String nilai) {
    if (daftarStatus.contains(nilai)) status = nilai;
  }
}

/// Membuat jadwal liga acak per pekan (circle method) sesuai jumlah leg (1 atau 2).
/// Setiap peserta tetap saling bertemu, namun urutan lawan, urutan laga,
/// dan status kandang/tandang diacak agar tidak berurutan (1 vs 2, 1 vs 3, dst.).
List<Pertandingan> buatJadwalRoundRobin(
  List<Peserta> daftarPeserta,
  int leg, {
  Random? random,
}) {
  if (daftarPeserta.length < 2) return [];

  final acak = random ?? Random();
  final slot = <Peserta?>[...daftarPeserta]..shuffle(acak);
  if (slot.length.isOdd) slot.add(null);

  final jumlahSlot = slot.length;
  final jumlahPekan = jumlahSlot - 1;
  final daftarPekanDasar = <List<({Peserta home, Peserta away})>>[];

  for (var pekan = 0; pekan < jumlahPekan; pekan++) {
    final lagaPekan = <({Peserta home, Peserta away})>[];
    for (var indeksSlot = 0; indeksSlot < jumlahSlot ~/ 2; indeksSlot++) {
      final timAtas = slot[indeksSlot];
      final timBawah = slot[jumlahSlot - 1 - indeksSlot];
      if (timAtas == null || timBawah == null) continue;
      final tukar = acak.nextBool();
      lagaPekan.add(
        (home: tukar ? timBawah : timAtas, away: tukar ? timAtas : timBawah),
      );
    }
    lagaPekan.shuffle(acak);
    daftarPekanDasar.add(lagaPekan);

    final terakhir = slot.removeLast();
    slot.insert(1, terakhir);
  }

  final hasil = <Pertandingan>[];
  for (var putaran = 0; putaran < leg; putaran++) {
    final urutanPekan = List.of(daftarPekanDasar)..shuffle(acak);
    for (final lagaPekan in urutanPekan) {
      final lagaAcak = List.of(lagaPekan)..shuffle(acak);
      for (final laga in lagaAcak) {
        final home = putaran.isEven ? laga.home : laga.away;
        final away = putaran.isEven ? laga.away : laga.home;
        hasil.add(
          Pertandingan(
            id: buatId('pertandingan'),
            idA: home.id,
            idB: away.id,
            babak: putaran + 1,
          ),
        );
      }
    }
  }
  return hasil;
}

/// Membuat struktur bracket Single Elimination acak dari babak 1 hingga Final.
List<Pertandingan> buatBracketSingleElimination(
  List<Peserta> daftarPeserta, {
  Random? random,
}) {
  if (daftarPeserta.length < 2) return [];

  final acak = random ?? Random();
  final pesertaAcak = List<Peserta>.from(daftarPeserta)..shuffle(acak);

  var ukuranBracket = 2;
  while (ukuranBracket < pesertaAcak.length) {
    ukuranBracket *= 2;
  }

  final jumlahMatchBabak1 = ukuranBracket ~/ 2;
  final jumlahBye = ukuranBracket - pesertaAcak.length;
  final perBabak = <int, List<Pertandingan>>{};

  // Babak 1 (peserta & posisi BYE diacak, tidak berurutan 1 vs 2, dst.)
  final matchBabak1 = <Pertandingan>[];
  var indeksPeserta = 0;
  for (var indeksMatch = 0; indeksMatch < jumlahMatchBabak1; indeksMatch++) {
    final idA = pesertaAcak[indeksPeserta++].id;
    final idB = indeksMatch < jumlahBye
        ? idPesertaBye
        : pesertaAcak[indeksPeserta++].id;
    matchBabak1.add(
      Pertandingan(
        id: buatId('pertandingan'),
        idA: idA,
        idB: idB,
        babak: 1,
      ),
    );
  }
  matchBabak1.shuffle(acak);
  perBabak[1] = matchBabak1;

  // Babak berikutnya sampai Final (+ Perebutan Juara 3 sebelum Final jika ada Semifinal)
  var babak = 2;
  var jumlahMatch = jumlahMatchBabak1 ~/ 2;
  while (jumlahMatch >= 1) {
    if (jumlahMatch == 1 && jumlahMatchBabak1 >= 2) {
      perBabak[babak] = [
        Pertandingan(
          id: buatId('pertandingan'),
          idA: '',
          idB: '',
          babak: babak,
        ),
      ];
      babak++;
    }
    perBabak[babak] = [
      for (var indeksMatch = 0; indeksMatch < jumlahMatch; indeksMatch++)
        Pertandingan(
          id: buatId('pertandingan'),
          idA: '',
          idB: '',
          babak: babak,
        ),
    ];
    babak++;
    jumlahMatch ~/= 2;
  }

  // Otomatis loloskan peserta yang mendapat BYE di babak 1 ke babak eliminasi berikutnya.
  final babakTujuanBye = jumlahMatchBabak1 == 2 ? perBabak[3] : perBabak[2];
  if (babakTujuanBye != null) {
    for (var indeksMatch = 0; indeksMatch < matchBabak1.length; indeksMatch++) {
      final pemenangBye = matchBabak1[indeksMatch].pemenangId;
      if (pemenangBye != null) {
        final target = babakTujuanBye[indeksMatch ~/ 2];
        if (indeksMatch.isEven) {
          target.idA = pemenangBye;
        } else {
          target.idB = pemenangBye;
        }
      }
    }
  }

  return [
    for (final kunciBabak in perBabak.keys.toList()..sort())
      ...perBabak[kunciBabak]!,
  ];
}
