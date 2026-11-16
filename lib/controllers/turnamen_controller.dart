import 'package:flutter/foundation.dart';

import 'package:rivnet/database/database_helper.dart';
import 'package:rivnet/models/turnamen.dart';

class TurnamenController extends ChangeNotifier {
  static final TurnamenController instance = TurnamenController._();

  TurnamenController._();

  final List<Turnamen> turnamen = [];
  bool _sudahDimuat = false;
  bool _sedangMemuat = false;
  String? _errorMuat;
  Future<void>? _prosesMuat;

  bool get sudahDimuat => _sudahDimuat;
  bool get sedangMemuat => _sedangMemuat;
  String? get errorMuat => _errorMuat;

  Future<void> muatDariDatabase({bool paksa = false}) {
    if (_sudahDimuat && !paksa) return Future.value();
    if (_prosesMuat != null) return _prosesMuat!;

    _sedangMemuat = true;
    _errorMuat = null;

    final future = _eksekusiMuat();
    _prosesMuat = future;
    return future;
  }

  Future<void> _eksekusiMuat() async {
    try {
      final daftarDariDb = await DatabaseHelper.instance.ambilSemuaTurnamen();
      turnamen
        ..clear()
        ..addAll(daftarDariDb);
      _sudahDimuat = true;
      _errorMuat = null;
    } catch (error, stackTrace) {
      _errorMuat = error.toString();
      debugPrint('[TurnamenController] Gagal muat SQLite: $error\n$stackTrace');
    } finally {
      _sedangMemuat = false;
      _prosesMuat = null;
      notifyListeners();
    }
  }

  @visibleForTesting
  void resetUntukTest() {
    turnamen.clear();
    _sudahDimuat = false;
    _sedangMemuat = false;
    _errorMuat = null;
    _prosesMuat = null;
  }

  Future<Turnamen> buatTurnamen({
    required String nama,
    required int leg,
    required List<String> namaPeserta,
    String format = Turnamen.formatLiga,
    String game = 'Sepak Bola',
  }) async {
    final daftarPeserta = [
      for (final namaTim in namaPeserta)
        Peserta(id: buatId('peserta'), nama: namaTim),
    ];
    final legEfektif = format == Turnamen.formatSingleElimination ? 1 : leg;
    final daftarPertandingan = format == Turnamen.formatSingleElimination
        ? buatBracketSingleElimination(daftarPeserta)
        : buatJadwalRoundRobin(daftarPeserta, legEfektif);

    final turnamenBaru = Turnamen(
      id: buatId('turnamen'),
      nama: nama,
      game: game,
      format: format,
      leg: legEfektif,
      status: 'Akan Datang',
      peserta: daftarPeserta,
      pertandingan: daftarPertandingan,
    );

    await DatabaseHelper.instance.simpanTurnamenBaru(turnamenBaru);
    turnamen.insert(0, turnamenBaru);
    _sudahDimuat = true;
    notifyListeners();
    return turnamenBaru;
  }

  Future<void> editTurnamen(
    Turnamen target, {
    required String nama,
    required int leg,
    required List<String> namaPeserta,
    String? format,
  }) async {
    final formatLama = target.format;
    final jumlahPesertaLama = target.peserta.length;
    final formatBaru = format ?? target.format;

    target.namaTurnamen = nama;
    target.formatTurnamen = formatBaru;
    target.jumlahLeg = formatBaru == Turnamen.formatSingleElimination ? 1 : leg;

    // Pertahankan ID peserta lama agar skor pertandingan yang sudah ada tetap aman.
    for (var indeks = 0; indeks < namaPeserta.length; indeks++) {
      if (indeks < jumlahPesertaLama) {
        target.peserta[indeks].nama = namaPeserta[indeks];
      } else {
        target.peserta.add(
          Peserta(id: buatId('peserta'), nama: namaPeserta[indeks]),
        );
      }
    }
    if (namaPeserta.length < jumlahPesertaLama) {
      target.peserta.removeRange(namaPeserta.length, jumlahPesertaLama);
    }

    if (target.apakahSingleElimination) {
      if (formatLama != formatBaru ||
          namaPeserta.length != jumlahPesertaLama ||
          target.pertandingan.isEmpty) {
        target.pertandingan
          ..clear()
          ..addAll(buatBracketSingleElimination(target.peserta));
      }
    } else {
      if (formatLama != formatBaru) {
        target.pertandingan
          ..clear()
          ..addAll(buatJadwalRoundRobin(target.peserta, target.leg));
      } else {
        _sinkronkanPertandingan(target);
      }
    }

    await DatabaseHelper.instance.perbaruiTurnamen(target);
    target.perbaruiTampilan();
    notifyListeners();
  }

  void _sinkronkanPertandingan(Turnamen target) {
    final idPesertaAktif = {for (final peserta in target.peserta) peserta.id};
    final pertandinganLama = target.pertandingan
        .where(
          (laga) =>
              idPesertaAktif.contains(laga.idA) &&
              idPesertaAktif.contains(laga.idB),
        )
        .toList();

    final hasil = <Pertandingan>[];
    final terpakai = <String>{};

    // Kelompokkan pertandingan yang masih valid berdasarkan pasangan peserta.
    for (var putaran = 0; putaran < target.leg; putaran++) {
      for (var indeksA = 0; indeksA < target.peserta.length; indeksA++) {
        for (
          var indeksB = indeksA + 1;
          indeksB < target.peserta.length;
          indeksB++
        ) {
          final idHome = putaran.isEven
              ? target.peserta[indeksA].id
              : target.peserta[indeksB].id;
          final idAway = putaran.isEven
              ? target.peserta[indeksB].id
              : target.peserta[indeksA].id;

          Pertandingan? cocok;
          for (final laga in pertandinganLama) {
            if (terpakai.contains(laga.id)) continue;
            final samaArah = laga.idA == idHome && laga.idB == idAway;
            final balikArah = laga.idA == idAway && laga.idB == idHome;
            if (samaArah || (putaran == 0 && balikArah)) {
              cocok = laga;
              break;
            }
          }

          if (cocok != null) {
            terpakai.add(cocok.id);
            hasil.add(cocok);
          } else {
            hasil.add(
              Pertandingan(
                id: buatId('pertandingan'),
                idA: idHome,
                idB: idAway,
              ),
            );
          }
        }
      }
    }

    target.pertandingan
      ..clear()
      ..addAll(hasil);
  }

  Future<void> hapusTurnamen(String idTurnamen) async {
    await DatabaseHelper.instance.hapusTurnamen(idTurnamen);
    turnamen.removeWhere((item) => item.id == idTurnamen);
    notifyListeners();
  }

  Future<void> akhiriTurnamen(Turnamen target) async {
    target.statusTurnamen = 'Selesai';
    await DatabaseHelper.instance.perbaruiStatusTurnamen(
      target.id,
      target.status,
    );
    target.perbaruiTampilan();
    notifyListeners();
  }

  Future<void> tambahPeserta(Turnamen target, String namaPeserta) async {
    if (!target.bisaKelolaJumlahPeserta) return;
    final pesertaLama = List<Peserta>.from(target.peserta);
    final pesertaBaru = Peserta(id: buatId('peserta'), nama: namaPeserta);
    final urutanPeserta = target.peserta.length;

    await DatabaseHelper.instance.tambahPeserta(
      target.id,
      pesertaBaru,
      urutanPeserta,
    );
    target.peserta.add(pesertaBaru);

    if (target.apakahSingleElimination) {
      final bracketBaru = buatBracketSingleElimination(target.peserta);
      await DatabaseHelper.instance.gantiSemuaPertandingan(
        target.id,
        bracketBaru,
      );
      target.pertandingan
        ..clear()
        ..addAll(bracketBaru);
    } else {
      // Tambahkan jadwal pertandingan untuk peserta baru terhadap peserta yang sudah ada.
      final pertandinganBaru = <Pertandingan>[];
      for (var putaran = 0; putaran < target.leg; putaran++) {
        for (final lawan in pesertaLama) {
          pertandinganBaru.add(
            Pertandingan(
              id: buatId('pertandingan'),
              idA: putaran.isEven ? lawan.id : pesertaBaru.id,
              idB: putaran.isEven ? pesertaBaru.id : lawan.id,
              babak: putaran + 1,
            ),
          );
        }
      }

      if (pertandinganBaru.isNotEmpty) {
        await DatabaseHelper.instance.tambahDaftarPertandingan(
          target.id,
          pertandinganBaru,
          target.pertandingan.length,
        );
        target.pertandingan.addAll(pertandinganBaru);
      }
    }

    target.perbaruiTampilan();
    notifyListeners();
  }

  Future<void> ubahPeserta(
    Turnamen target,
    Peserta peserta,
    String namaBaru,
  ) async {
    peserta.nama = namaBaru;
    await DatabaseHelper.instance.perbaruiPeserta(peserta);
    target.perbaruiTampilan();
    notifyListeners();
  }

  Future<void> hapusPeserta(Turnamen target, Peserta peserta) async {
    if (!target.bisaKelolaJumlahPeserta) return;
    await DatabaseHelper.instance.hapusPeserta(peserta.id);
    target.peserta.removeWhere((item) => item.id == peserta.id);
    if (target.apakahSingleElimination) {
      final bracketBaru = buatBracketSingleElimination(target.peserta);
      await DatabaseHelper.instance.gantiSemuaPertandingan(
        target.id,
        bracketBaru,
      );
      target.pertandingan
        ..clear()
        ..addAll(bracketBaru);
    } else {
      target.pertandingan.removeWhere(
        (item) => item.idA == peserta.id || item.idB == peserta.id,
      );
    }
    target.perbaruiTampilan();
    notifyListeners();
  }

  Future<void> buatUlangPertandingan(Turnamen target) async {
    final daftarBaru = target.apakahSingleElimination
        ? buatBracketSingleElimination(target.peserta)
        : buatJadwalRoundRobin(target.peserta, target.leg);
    await DatabaseHelper.instance.gantiSemuaPertandingan(target.id, daftarBaru);
    target.pertandingan
      ..clear()
      ..addAll(daftarBaru);
    target.perbaruiTampilan();
    notifyListeners();
  }

  Future<void> simpanSkor(
    Turnamen target,
    Pertandingan pertandingan,
    int skorA,
    int skorB,
  ) async {
    pertandingan.skorA = skorA;
    pertandingan.skorB = skorB;

    if (target.apakahSingleElimination) {
      final berubah = <Pertandingan>[pertandingan];
      _majukanPemenangBracket(target, pertandingan, berubah);
      await DatabaseHelper.instance.perbaruiDaftarPertandingan(berubah);
    } else {
      await DatabaseHelper.instance.perbaruiSkorPertandingan(
        pertandingan.id,
        skorA,
        skorB,
      );
    }

    if (target.status == 'Akan Datang') {
      target.statusTurnamen = 'Berlangsung';
      await DatabaseHelper.instance.perbaruiStatusTurnamen(
        target.id,
        target.status,
      );
    }
    target.perbaruiTampilan();
    notifyListeners();
  }

  void _majukanPemenangBracket(
    Turnamen target,
    Pertandingan matchSumber,
    List<Pertandingan> berubah,
  ) {
    final perBabak = <int, List<Pertandingan>>{};
    for (final laga in target.pertandingan) {
      perBabak.putIfAbsent(laga.babak, () => []).add(laga);
    }

    final babakJuara3 = target.babakPerebutanJuara3;
    final daftarBabakEliminasi = [
      for (final nomorBabak in perBabak.keys.toList()..sort())
        if (nomorBabak != babakJuara3) nomorBabak,
    ];

    final posBabak = daftarBabakEliminasi.indexOf(matchSumber.babak);
    if (posBabak < 0 || posBabak + 1 >= daftarBabakEliminasi.length) return;

    final daftarBabakIni = perBabak[matchSumber.babak]!;
    final daftarBabakBerikut = perBabak[daftarBabakEliminasi[posBabak + 1]]!;
    final indeks = daftarBabakIni.indexOf(matchSumber);
    if (indeks < 0) return;

    final indeksBerikut = indeks ~/ 2;
    if (indeksBerikut < daftarBabakBerikut.length) {
      final matchBerikut = daftarBabakBerikut[indeksBerikut];
      final pemenangBaru = matchSumber.pemenangId ?? '';
      if (_isiSlotBracket(matchBerikut, indeks.isEven, pemenangBaru, berubah)) {
        _majukanPemenangBracket(target, matchBerikut, berubah);
      }
    }

    // Jika laga ini adalah Semifinal, tim yang kalah masuk ke Perebutan Juara 3.
    final apakahSemifinal = posBabak == daftarBabakEliminasi.length - 2;
    if (apakahSemifinal && babakJuara3 != null) {
      final daftarJuara3 = perBabak[babakJuara3];
      if (daftarJuara3 != null && daftarJuara3.isNotEmpty) {
        final matchJuara3 = daftarJuara3.first;
        final kalahBaru = matchSumber.kalahId ?? '';
        _isiSlotBracket(matchJuara3, indeks.isEven, kalahBaru, berubah);
      }
    }
  }

  bool _isiSlotBracket(
    Pertandingan matchTarget,
    bool slotAtas,
    String idPesertaBaru,
    List<Pertandingan> berubah,
  ) {
    final slotBerubah = slotAtas
        ? matchTarget.idA != idPesertaBaru
        : matchTarget.idB != idPesertaBaru;
    if (!slotBerubah) return false;

    if (slotAtas) {
      matchTarget.idA = idPesertaBaru;
    } else {
      matchTarget.idB = idPesertaBaru;
    }
    matchTarget.skorA = null;
    matchTarget.skorB = null;
    berubah.add(matchTarget);
    return true;
  }

  Turnamen? cari(String idTurnamen) {
    for (final item in turnamen) {
      if (item.id == idTurnamen) return item;
    }
    return null;
  }
}
