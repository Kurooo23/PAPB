import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database_helper.dart';
import '../models/pertandingan_model.dart';
import '../models/peserta_model.dart';

class PertandinganDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const _uuid = Uuid();

  Future<List<PertandinganModel>> getPertandinganByTurnamen(String idTurnamen) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        m.*,
        p1.nama_peserta AS nama_peserta_1,
        p2.nama_peserta AS nama_peserta_2
      FROM pertandingan m
      LEFT JOIN peserta p1 ON m.id_peserta_1 = p1.id_peserta
      LEFT JOIN peserta p2 ON m.id_peserta_2 = p2.id_peserta
      WHERE m.id_turnamen = ?
      ORDER BY m.urutan ASC
    ''', [idTurnamen]);

    return results.map((map) => PertandinganModel.fromMap(map)).toList();
  }

  Future<PertandinganModel?> getPertandinganById(String idPertandingan) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        m.*,
        p1.nama_peserta AS nama_peserta_1,
        p2.nama_peserta AS nama_peserta_2
      FROM pertandingan m
      LEFT JOIN peserta p1 ON m.id_peserta_1 = p1.id_peserta
      LEFT JOIN peserta p2 ON m.id_peserta_2 = p2.id_peserta
      WHERE m.id_pertandingan = ?
    ''', [idPertandingan]);

    if (results.isNotEmpty) {
      return PertandinganModel.fromMap(results.first);
    }
    return null;
  }

  Future<void> generateBracketSingleElimination(
      String idTurnamen, List<PesertaModel> pesertaList) async {
    final db = await _dbHelper.database;
    final int count = pesertaList.length;

    // Hitung ronde yang dibutuhkan
    List<List<PertandinganModel>> rounds = [];
    int matchCountInRound = count ~/ 2;
    int order = 1;

    String getRoundName(int totalInRound) {
      if (totalInRound == 1) return 'Final';
      if (totalInRound == 2) return 'Semifinal';
      if (totalInRound == 4) return 'Perempat Final';
      if (totalInRound == 8) return 'Babak 16 Besar';
      return 'Babak $totalInRound';
    }

    // Generate struktur semua babak
    while (matchCountInRound >= 1) {
      final roundName = getRoundName(matchCountInRound);
      List<PertandinganModel> currentRoundMatches = [];

      for (int i = 0; i < matchCountInRound; i++) {
        final matchId = _uuid.v4();
        currentRoundMatches.add(
          PertandinganModel(
            idPertandingan: matchId,
            idTurnamen: idTurnamen,
            idPeserta1: null,
            idPeserta2: null,
            babak: roundName,
            status: 'Belum Mulai',
            urutan: order++,
          ),
        );
      }
      rounds.add(currentRoundMatches);
      matchCountInRound = matchCountInRound ~/ 2;
    }

    // Isi peserta ronde pertama
    for (int i = 0; i < rounds[0].length; i++) {
      final p1Index = i * 2;
      final p2Index = i * 2 + 1;

      final p1 = p1Index < count ? pesertaList[p1Index].idPeserta : null;
      final p2 = p2Index < count ? pesertaList[p2Index].idPeserta : null;

      rounds[0][i] = rounds[0][i].copyWith(
        idPeserta1: p1,
        idPeserta2: p2,
      );
    }

    // Hubungkan next_pertandingan_id antar ronde
    for (int r = 0; r < rounds.length - 1; r++) {
      for (int i = 0; i < rounds[r].length; i++) {
        final nextMatchIndex = i ~/ 2;
        final nextMatchId = rounds[r + 1][nextMatchIndex].idPertandingan;
        rounds[r][i] = rounds[r][i].copyWith(nextPertandinganId: nextMatchId);
      }
    }

    // Simpan semua pertandingan ke SQLite menggunakan batch
    final batch = db.batch();
    for (final round in rounds) {
      for (final match in round) {
        batch.insert('pertandingan', match.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> generateRoundRobin(
      String idTurnamen, List<PesertaModel> pesertaList) async {
    final db = await _dbHelper.database;
    final int count = pesertaList.length;
    int order = 1;
    final batch = db.batch();

    int roundNum = 1;
    for (int i = 0; i < count; i++) {
      for (int j = i + 1; j < count; j++) {
        final match = PertandinganModel(
          idPertandingan: _uuid.v4(),
          idTurnamen: idTurnamen,
          idPeserta1: pesertaList[i].idPeserta,
          idPeserta2: pesertaList[j].idPeserta,
          babak: 'Match $roundNum',
          status: 'Belum Mulai',
          urutan: order++,
        );
        batch.insert('pertandingan', match.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        roundNum++;
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateHasilPertandingan({
    required String idPertandingan,
    required int skor1,
    required int skor2,
    required String status,
  }) async {
    final db = await _dbHelper.database;

    // Ambil data pertandingan saat ini
    final currentMatch = await getPertandinganById(idPertandingan);
    if (currentMatch == null) return;

    // Update skor & status pertandingan
    await db.update(
      'pertandingan',
      {
        'skor_peserta_1': skor1,
        'skor_peserta_2': skor2,
        'status': status,
      },
      where: 'id_pertandingan = ?',
      whereArgs: [idPertandingan],
    );

    // Otomatis ubah status turnamen ke 'Berlangsung' jika masih 'Akan Datang'
    await db.update(
      'turnamen',
      {'status': 'Berlangsung'},
      where: 'id_turnamen = ? AND status = ?',
      whereArgs: [currentMatch.idTurnamen, 'Akan Datang'],
    );

    // Jika pertandingan selesai dan ada ronde berikutnya, majukan pemenang
    if (status == 'Selesai' && currentMatch.nextPertandinganId != null) {
      String? winnerId;
      if (skor1 > skor2) {
        winnerId = currentMatch.idPeserta1;
      } else if (skor2 > skor1) {
        winnerId = currentMatch.idPeserta2;
      }

      if (winnerId != null) {
        // Cek apakah pertandingan ini urutan ganjil (slot 1) atau genap (slot 2)
        // Cari posisi di antara sibling matches yang mengarah ke nextMatch
        final siblings = await db.query(
          'pertandingan',
          where: 'next_pertandingan_id = ?',
          whereArgs: [currentMatch.nextPertandinganId],
          orderBy: 'urutan ASC',
        );

        if (siblings.isNotEmpty) {
          final isSlot1 = siblings.first['id_pertandingan'] == idPertandingan;
          final updateField = isSlot1 ? 'id_peserta_1' : 'id_peserta_2';

          await db.update(
            'pertandingan',
            {updateField: winnerId},
            where: 'id_pertandingan = ?',
            whereArgs: [currentMatch.nextPertandinganId],
          );
        }
      }
    }

    // Cek apakah semua pertandingan dalam turnamen ini sudah selesai
    final allMatches = await db.query(
      'pertandingan',
      where: 'id_turnamen = ?',
      whereArgs: [currentMatch.idTurnamen],
    );

    final allFinished = allMatches.every((m) => m['status'] == 'Selesai');
    if (allFinished && allMatches.isNotEmpty) {
      await db.update(
        'turnamen',
        {'status': 'Selesai'},
        where: 'id_turnamen = ?',
        whereArgs: [currentMatch.idTurnamen],
      );
    }
  }

  Future<int> deletePertandingan(String idPertandingan) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'pertandingan',
      where: 'id_pertandingan = ?',
      whereArgs: [idPertandingan],
    );
  }
}
