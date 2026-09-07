import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database_helper.dart';
import '../models/pertandingan_model.dart';
import '../models/peserta_model.dart';
import '../models/turnamen_model.dart';

class LocalTournamentService {
  static final LocalTournamentService instance = LocalTournamentService._internal();
  LocalTournamentService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const _uuid = Uuid();

  // === Helper: Nama Babak Eliminasi ===
  static String _getEliminationRoundName(int matchesInRound, {String prefix = ''}) {
    if (matchesInRound == 1) return '${prefix}Final'.trim();
    if (matchesInRound == 2) return '${prefix}Semifinal'.trim();
    if (matchesInRound == 4) return '${prefix}Perempat Final'.trim();
    if (matchesInRound == 8) return '${prefix}Babak 16 Besar'.trim();
    if (matchesInRound == 16) return '${prefix}Babak 32 Besar'.trim();
    return '${prefix}Babak ${matchesInRound * 2} Besar'.trim();
  }

  // === Generator: Single Elimination ===
  static void _generateSingleElimination(
    Batch batch,
    String idTurnamen,
    List<PesertaModel> pesertaList,
    int jumlahLeg,
  ) {
    final count = pesertaList.length;
    int matchCountInRound = count ~/ 2;
    int order = 1;
    final List<List<Map<String, dynamic>>> rounds = [];

    while (matchCountInRound >= 1) {
      final roundName = _getEliminationRoundName(matchCountInRound);
      final List<Map<String, dynamic>> currentRound = [];

      for (int i = 0; i < matchCountInRound; i++) {
        currentRound.add({
          'id_pertandingan': _uuid.v4(),
          'id_turnamen': idTurnamen,
          'id_peserta_1': null,
          'id_peserta_2': null,
          'babak': jumlahLeg == 2 ? 'Leg 1 - $roundName' : roundName,
          'skor_peserta_1': 0,
          'skor_peserta_2': 0,
          'status': 'Belum Mulai',
          'urutan': order++,
          'next_pertandingan_id': null,
        });

        if (jumlahLeg == 2) {
          currentRound.add({
            'id_pertandingan': _uuid.v4(),
            'id_turnamen': idTurnamen,
            'id_peserta_1': null,
            'id_peserta_2': null,
            'babak': 'Leg 2 - $roundName',
            'skor_peserta_1': 0,
            'skor_peserta_2': 0,
            'status': 'Belum Mulai',
            'urutan': order++,
            'next_pertandingan_id': null,
          });
        }
      }
      rounds.add(currentRound);
      matchCountInRound = matchCountInRound ~/ 2;
    }

    // Isi peserta babak pertama
    final step = jumlahLeg == 2 ? 2 : 1;
    for (int i = 0; i < rounds[0].length ~/ step; i++) {
      final p1 = (i * 2 < count) ? pesertaList[i * 2].idPeserta : null;
      final p2 = (i * 2 + 1 < count) ? pesertaList[i * 2 + 1].idPeserta : null;
      rounds[0][i * step]['id_peserta_1'] = p1;
      rounds[0][i * step]['id_peserta_2'] = p2;
      if (jumlahLeg == 2) {
        rounds[0][i * step + 1]['id_peserta_1'] = p2;
        rounds[0][i * step + 1]['id_peserta_2'] = p1;
      }
    }

    // Hubungkan next_pertandingan_id antar babak
    for (int r = 0; r < rounds.length - 1; r++) {
      for (int i = 0; i < rounds[r].length; i++) {
        final matchPairIdx = i ~/ (step * 2);
        final targetMatchIdx = (matchPairIdx * step).clamp(0, rounds[r + 1].length - 1);
        rounds[r][i]['next_pertandingan_id'] = rounds[r + 1][targetMatchIdx]['id_pertandingan'];
      }
    }

    // Batch insert
    for (final round in rounds) {
      for (final m in round) {
        batch.insert('pertandingan', m, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  // === Generator: Double Elimination ===
  static void _generateDoubleElimination(
    Batch batch,
    String idTurnamen,
    List<PesertaModel> pesertaList,
    int jumlahLeg,
  ) {
    final count = pesertaList.length;
    int order = 1;

    // --- Winners Bracket ---
    int wbMatchCount = count ~/ 2;
    final List<List<Map<String, dynamic>>> wbRounds = [];

    while (wbMatchCount >= 1) {
      final roundName = _getEliminationRoundName(wbMatchCount, prefix: 'WB ');
      final List<Map<String, dynamic>> currentRound = [];

      for (int i = 0; i < wbMatchCount; i++) {
        currentRound.add({
          'id_pertandingan': _uuid.v4(),
          'id_turnamen': idTurnamen,
          'id_peserta_1': null,
          'id_peserta_2': null,
          'babak': jumlahLeg == 2 ? 'Leg 1 - $roundName' : roundName,
          'skor_peserta_1': 0,
          'skor_peserta_2': 0,
          'status': 'Belum Mulai',
          'urutan': order++,
          'next_pertandingan_id': null,
        });

        if (jumlahLeg == 2) {
          currentRound.add({
            'id_pertandingan': _uuid.v4(),
            'id_turnamen': idTurnamen,
            'id_peserta_1': null,
            'id_peserta_2': null,
            'babak': 'Leg 2 - $roundName',
            'skor_peserta_1': 0,
            'skor_peserta_2': 0,
            'status': 'Belum Mulai',
            'urutan': order++,
            'next_pertandingan_id': null,
          });
        }
      }
      wbRounds.add(currentRound);
      wbMatchCount = wbMatchCount ~/ 2;
    }

    final step = jumlahLeg == 2 ? 2 : 1;
    for (int i = 0; i < wbRounds[0].length ~/ step; i++) {
      final p1 = (i * 2 < count) ? pesertaList[i * 2].idPeserta : null;
      final p2 = (i * 2 + 1 < count) ? pesertaList[i * 2 + 1].idPeserta : null;
      wbRounds[0][i * step]['id_peserta_1'] = p1;
      wbRounds[0][i * step]['id_peserta_2'] = p2;
      if (jumlahLeg == 2) {
        wbRounds[0][i * step + 1]['id_peserta_1'] = p2;
        wbRounds[0][i * step + 1]['id_peserta_2'] = p1;
      }
    }

    for (int r = 0; r < wbRounds.length - 1; r++) {
      for (int i = 0; i < wbRounds[r].length; i++) {
        final targetIdx = (i ~/ 2).clamp(0, wbRounds[r + 1].length - 1);
        wbRounds[r][i]['next_pertandingan_id'] = wbRounds[r + 1][targetIdx]['id_pertandingan'];
      }
    }

    // --- Losers Bracket ---
    final List<List<Map<String, dynamic>>> lbRounds = [];
    if (count > 2) {
      final lbRoundCount = (wbRounds.length - 1) * 2 > 0 ? (wbRounds.length - 1) * 2 : 1;
      int lbMatchCount = (count ~/ 4) > 0 ? (count ~/ 4) : 1;

      for (int lr = 0; lr < lbRoundCount; lr++) {
        final roundName = 'LB Babak ${lr + 1}';
        final List<Map<String, dynamic>> currentRound = [];
        final mc = lbMatchCount > 0 ? lbMatchCount : 1;

        for (int i = 0; i < mc; i++) {
          currentRound.add({
            'id_pertandingan': _uuid.v4(),
            'id_turnamen': idTurnamen,
            'id_peserta_1': null,
            'id_peserta_2': null,
            'babak': jumlahLeg == 2 ? 'Leg 1 - $roundName' : roundName,
            'skor_peserta_1': 0,
            'skor_peserta_2': 0,
            'status': 'Belum Mulai',
            'urutan': order++,
            'next_pertandingan_id': null,
          });

          if (jumlahLeg == 2) {
            currentRound.add({
              'id_pertandingan': _uuid.v4(),
              'id_turnamen': idTurnamen,
              'id_peserta_1': null,
              'id_peserta_2': null,
              'babak': 'Leg 2 - $roundName',
              'skor_peserta_1': 0,
              'skor_peserta_2': 0,
              'status': 'Belum Mulai',
              'urutan': order++,
              'next_pertandingan_id': null,
            });
          }
        }
        lbRounds.add(currentRound);
        if (lr % 2 == 1) lbMatchCount = lbMatchCount ~/ 2;
      }

      for (int r = 0; r < lbRounds.length - 1; r++) {
        for (int i = 0; i < lbRounds[r].length; i++) {
          final nextIdx = i.clamp(0, lbRounds[r + 1].length - 1);
          lbRounds[r][i]['next_pertandingan_id'] = lbRounds[r + 1][nextIdx]['id_pertandingan'];
        }
      }
    }

    // --- Grand Final ---
    final gf1 = <String, dynamic>{
      'id_pertandingan': _uuid.v4(),
      'id_turnamen': idTurnamen,
      'id_peserta_1': null,
      'id_peserta_2': null,
      'babak': jumlahLeg == 2 ? 'Leg 1 - Grand Final' : 'Grand Final',
      'skor_peserta_1': 0,
      'skor_peserta_2': 0,
      'status': 'Belum Mulai',
      'urutan': order++,
      'next_pertandingan_id': null,
    };
    final List<Map<String, dynamic>> gfMatches = [gf1];
    if (jumlahLeg == 2) {
      gfMatches.add({
        'id_pertandingan': _uuid.v4(),
        'id_turnamen': idTurnamen,
        'id_peserta_1': null,
        'id_peserta_2': null,
        'babak': 'Leg 2 - Grand Final',
        'skor_peserta_1': 0,
        'skor_peserta_2': 0,
        'status': 'Belum Mulai',
        'urutan': order++,
        'next_pertandingan_id': null,
      });
    }

    if (wbRounds.isNotEmpty && wbRounds.last.isNotEmpty) {
      wbRounds.last[0]['next_pertandingan_id'] = gf1['id_pertandingan'];
    }
    if (lbRounds.isNotEmpty && lbRounds.last.isNotEmpty) {
      lbRounds.last[0]['next_pertandingan_id'] = gf1['id_pertandingan'];
    }

    final allRounds = [...wbRounds, ...lbRounds, gfMatches];
    for (final round in allRounds) {
      for (final m in round) {
        batch.insert('pertandingan', m, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  // === Generator: Round Robin ===
  static void _generateRoundRobin(
    Batch batch,
    String idTurnamen,
    List<PesertaModel> pesertaList,
    int jumlahLeg,
  ) {
    int order = 1;
    int matchNum = 1;

    // Leg 1 (Home)
    for (int i = 0; i < pesertaList.length; i++) {
      for (int j = i + 1; j < pesertaList.length; j++) {
        final babak = jumlahLeg == 2 ? 'Leg 1 - Match $matchNum' : 'Match $matchNum';
        batch.insert(
          'pertandingan',
          {
            'id_pertandingan': _uuid.v4(),
            'id_turnamen': idTurnamen,
            'id_peserta_1': pesertaList[i].idPeserta,
            'id_peserta_2': pesertaList[j].idPeserta,
            'babak': babak,
            'skor_peserta_1': 0,
            'skor_peserta_2': 0,
            'status': 'Belum Mulai',
            'urutan': order++,
            'next_pertandingan_id': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        matchNum++;
      }
    }

    // Leg 2 (Away) jika 2 leg
    if (jumlahLeg == 2) {
      matchNum = 1;
      for (int i = 0; i < pesertaList.length; i++) {
        for (int j = i + 1; j < pesertaList.length; j++) {
          batch.insert(
            'pertandingan',
            {
              'id_pertandingan': _uuid.v4(),
              'id_turnamen': idTurnamen,
              'id_peserta_1': pesertaList[j].idPeserta,
              'id_peserta_2': pesertaList[i].idPeserta,
              'babak': 'Leg 2 - Match $matchNum',
              'skor_peserta_1': 0,
              'skor_peserta_2': 0,
              'status': 'Belum Mulai',
              'urutan': order++,
              'next_pertandingan_id': null,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          matchNum++;
        }
      }
    }
  }

  // === Generator: Swiss System ===
  static void _generateSwissSystem(
    Batch batch,
    String idTurnamen,
    List<PesertaModel> pesertaList,
    int jumlahLeg,
  ) {
    int order = 1;
    final count = pesertaList.length;
    final matchCount = count ~/ 2;

    for (int i = 0; i < matchCount; i++) {
      final p1 = (i * 2 < count) ? pesertaList[i * 2].idPeserta : null;
      final p2 = (i * 2 + 1 < count) ? pesertaList[i * 2 + 1].idPeserta : null;
      final babak1 = jumlahLeg == 2 ? 'Swiss Ronde 1 - Leg 1' : 'Swiss Ronde 1';

      batch.insert(
        'pertandingan',
        {
          'id_pertandingan': _uuid.v4(),
          'id_turnamen': idTurnamen,
          'id_peserta_1': p1,
          'id_peserta_2': p2,
          'babak': babak1,
          'skor_peserta_1': 0,
          'skor_peserta_2': 0,
          'status': 'Belum Mulai',
          'urutan': order++,
          'next_pertandingan_id': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (jumlahLeg == 2) {
        batch.insert(
          'pertandingan',
          {
            'id_pertandingan': _uuid.v4(),
            'id_turnamen': idTurnamen,
            'id_peserta_1': p2,
            'id_peserta_2': p1,
            'babak': 'Swiss Ronde 1 - Leg 2',
            'skor_peserta_1': 0,
            'skor_peserta_2': 0,
            'status': 'Belum Mulai',
            'urutan': order++,
            'next_pertandingan_id': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  // ==========================================================
  // 1. POST Buat Turnamen Privat Baru (Simpan ke SQLite Lokal)
  // ==========================================================
  Future<TurnamenModel> createTurnamen({
    required String namaTurnamen,
    String? deskripsi,
    String tipeGame = 'E-Sports',
    required String formatBracket,
    int jumlahLeg = 1,
    required DateTime tanggalMulai,
    required int kuota,
    required List<String> peserta,
  }) async {
    final db = await _dbHelper.database;
    final idTurnamen = _uuid.v4();
    final legCount = (jumlahLeg == 2) ? 2 : 1;
    const status = 'Akan Datang';

    final turnamen = TurnamenModel(
      idTurnamen: idTurnamen,
      namaTurnamen: namaTurnamen,
      deskripsi: deskripsi,
      tipeGame: tipeGame,
      formatBracket: formatBracket,
      jumlahLeg: legCount,
      tanggalMulai: tanggalMulai,
      kuota: kuota,
      status: status,
      isPrivate: true,
    );

    await db.transaction((txn) async {
      // 1. Insert turnamen
      await txn.insert('turnamen', turnamen.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Insert peserta
      final List<PesertaModel> pesertaList = [];
      for (int i = 0; i < kuota; i++) {
        final nama = (i < peserta.length && peserta[i].trim().isNotEmpty)
            ? peserta[i].trim()
            : 'Peserta ${i + 1}';
        final p = PesertaModel(
          idPeserta: _uuid.v4(),
          idTurnamen: idTurnamen,
          namaPeserta: nama,
        );
        pesertaList.add(p);
        await txn.insert('peserta', p.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 3. Generate matches & brackets
      final batch = txn.batch();
      if (formatBracket == 'Single Elimination') {
        _generateSingleElimination(batch, idTurnamen, pesertaList, legCount);
      } else if (formatBracket == 'Double Elimination') {
        _generateDoubleElimination(batch, idTurnamen, pesertaList, legCount);
      } else if (formatBracket == 'Liga') {
        _generateRoundRobin(batch, idTurnamen, pesertaList, legCount);
      } else if (formatBracket == 'Swiss System') {
        _generateSwissSystem(batch, idTurnamen, pesertaList, legCount);
      } else {
        _generateRoundRobin(batch, idTurnamen, pesertaList, legCount);
      }
      await batch.commit(noResult: true);
    });

    return turnamen;
  }

  // ==========================================================
  // 2. GET Semua Turnamen Privat
  // ==========================================================
  Future<List<TurnamenModel>> getAllTurnamen({String? search, String? status}) async {
    final db = await _dbHelper.database;
    String whereClause = 'is_private = 1';
    final List<dynamic> whereArgs = [];

    if (search != null && search.trim().isNotEmpty) {
      whereClause += ' AND nama_turnamen LIKE ?';
      whereArgs.add('%${search.trim()}%');
    }

    if (status != null && status != 'Semua') {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    final results = await db.query(
      'turnamen',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'tanggal_mulai DESC',
    );

    return results.map((m) => TurnamenModel.fromMap(m)).toList();
  }

  // ==========================================================
  // 3. GET Turnamen Privat Aktif
  // ==========================================================
  Future<List<TurnamenModel>> getTurnamenAktif({String? search, String? statusFilter}) async {
    final db = await _dbHelper.database;
    String whereClause = "is_private = 1 AND status != 'Selesai'";
    final List<dynamic> whereArgs = [];

    if (search != null && search.trim().isNotEmpty) {
      whereClause += ' AND nama_turnamen LIKE ?';
      whereArgs.add('%${search.trim()}%');
    }

    if (statusFilter != null && statusFilter != 'Semua') {
      whereClause += ' AND status = ?';
      whereArgs.add(statusFilter);
    }

    final results = await db.query(
      'turnamen',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'tanggal_mulai ASC',
    );

    return results.map((m) => TurnamenModel.fromMap(m)).toList();
  }

  // ==========================================================
  // 4. GET Riwayat Turnamen Privat (Selesai)
  // ==========================================================
  Future<List<TurnamenModel>> getRiwayatTurnamen({String? search}) async {
    final db = await _dbHelper.database;
    String whereClause = "is_private = 1 AND status = 'Selesai'";
    final List<dynamic> whereArgs = [];

    if (search != null && search.trim().isNotEmpty) {
      whereClause += ' AND nama_turnamen LIKE ?';
      whereArgs.add('%${search.trim()}%');
    }

    final results = await db.query(
      'turnamen',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'tanggal_mulai DESC',
    );

    return results.map((m) => TurnamenModel.fromMap(m)).toList();
  }

  // ==========================================================
  // 5. GET Detail Turnamen Privat (Turnamen + Peserta + Pertandingan)
  // ==========================================================
  Future<Map<String, dynamic>> getTurnamenDetail(String idTurnamen) async {
    final db = await _dbHelper.database;

    final tResults = await db.query(
      'turnamen',
      where: 'id_turnamen = ?',
      whereArgs: [idTurnamen],
    );

    if (tResults.isEmpty) {
      throw Exception('Turnamen privat tidak ditemukan di database lokal.');
    }

    final turnamen = TurnamenModel.fromMap(tResults.first);

    final pResults = await db.query(
      'peserta',
      where: 'id_turnamen = ?',
      whereArgs: [idTurnamen],
    );
    final pesertaList = pResults.map((p) => PesertaModel.fromMap(p)).toList();

    final mResults = await db.rawQuery('''
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

    final pertandinganList =
        mResults.map((m) => PertandinganModel.fromMap(m)).toList();

    return {
      'turnamen': turnamen,
      'peserta': pesertaList,
      'pertandingan': pertandinganList,
    };
  }

  // ==========================================================
  // 6. PUT Edit Turnamen Privat
  // ==========================================================
  Future<TurnamenModel> updateTurnamen(TurnamenModel turnamen) async {
    final db = await _dbHelper.database;
    await db.update(
      'turnamen',
      {
        'nama_turnamen': turnamen.namaTurnamen,
        'deskripsi': turnamen.deskripsi,
        'tipe_game': turnamen.tipeGame,
        'status': turnamen.status,
      },
      where: 'id_turnamen = ?',
      whereArgs: [turnamen.idTurnamen],
    );
    return turnamen;
  }

  // ==========================================================
  // 7. DELETE Hapus Turnamen Privat
  // ==========================================================
  Future<void> deleteTurnamen(String idTurnamen) async {
    final db = await _dbHelper.database;
    await db.delete(
      'turnamen',
      where: 'id_turnamen = ?',
      whereArgs: [idTurnamen],
    );
  }

  // ==========================================================
  // 8. PUT Update Hasil Pertandingan (Skor & Status)
  // ==========================================================
  Future<PertandinganModel> updateHasilPertandingan({
    required String idPertandingan,
    required int skor1,
    required int skor2,
    required String status,
  }) async {
    final db = await _dbHelper.database;

    final mResults = await db.rawQuery('''
      SELECT 
        m.*,
        p1.nama_peserta AS nama_peserta_1,
        p2.nama_peserta AS nama_peserta_2
      FROM pertandingan m
      LEFT JOIN peserta p1 ON m.id_peserta_1 = p1.id_peserta
      LEFT JOIN peserta p2 ON m.id_peserta_2 = p2.id_peserta
      WHERE m.id_pertandingan = ?
    ''', [idPertandingan]);

    if (mResults.isEmpty) {
      throw Exception('Pertandingan tidak ditemukan di database lokal.');
    }

    final currentMatch = PertandinganModel.fromMap(mResults.first);

    await db.transaction((txn) async {
      // 1. Update skor & status pertandingan
      await txn.update(
        'pertandingan',
        {
          'skor_peserta_1': skor1,
          'skor_peserta_2': skor2,
          'status': status,
        },
        where: 'id_pertandingan = ?',
        whereArgs: [idPertandingan],
      );

      // 2. Ubah status turnamen ke 'Berlangsung' jika masih 'Akan Datang'
      await txn.update(
        'turnamen',
        {'status': 'Berlangsung'},
        where: "id_turnamen = ? AND status = 'Akan Datang'",
        whereArgs: [currentMatch.idTurnamen],
      );

      // 3. Majukan pemenang jika pertandingan Selesai dan ada next_pertandingan_id
      if (status == 'Selesai' && currentMatch.nextPertandinganId != null) {
        String? winnerId;
        if (skor1 > skor2) {
          winnerId = currentMatch.idPeserta1;
        } else if (skor2 > skor1) {
          winnerId = currentMatch.idPeserta2;
        }

        if (winnerId != null) {
          final siblings = await txn.query(
            'pertandingan',
            where: 'next_pertandingan_id = ?',
            whereArgs: [currentMatch.nextPertandinganId],
            orderBy: 'urutan ASC',
          );

          if (siblings.isNotEmpty) {
            final isSlot1 = siblings.first['id_pertandingan'] == idPertandingan;
            final updateField = isSlot1 ? 'id_peserta_1' : 'id_peserta_2';

            await txn.update(
              'pertandingan',
              {updateField: winnerId},
              where: 'id_pertandingan = ?',
              whereArgs: [currentMatch.nextPertandinganId],
            );
          }
        }
      }

      // 4. Cek apakah seluruh pertandingan dalam turnamen ini sudah selesai
      final allMatches = await txn.query(
        'pertandingan',
        where: 'id_turnamen = ?',
        whereArgs: [currentMatch.idTurnamen],
      );

      final isAllFinished =
          allMatches.isNotEmpty && allMatches.every((m) => m['status'] == 'Selesai');

      if (isAllFinished) {
        await txn.update(
          'turnamen',
          {'status': 'Selesai'},
          where: 'id_turnamen = ?',
          whereArgs: [currentMatch.idTurnamen],
        );
      }
    });

    final updated = await db.rawQuery('''
      SELECT 
        m.*,
        p1.nama_peserta AS nama_peserta_1,
        p2.nama_peserta AS nama_peserta_2
      FROM pertandingan m
      LEFT JOIN peserta p1 ON m.id_peserta_1 = p1.id_peserta
      LEFT JOIN peserta p2 ON m.id_peserta_2 = p2.id_peserta
      WHERE m.id_pertandingan = ?
    ''', [idPertandingan]);

    return PertandinganModel.fromMap(updated.first);
  }
}
