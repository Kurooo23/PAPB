import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database_helper.dart';
import '../models/pertandingan_model.dart';
import '../models/peserta_model.dart';
import '../models/turnamen_model.dart';

class LocalTournamentService {
  static final LocalTournamentService instance =
      LocalTournamentService._internal();
  LocalTournamentService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const _uuid = Uuid();

  // === Helper: Nama Babak Eliminasi ===
  static String _getEliminationRoundName(
    int matchesInRound, {
    String prefix = '',
  }) {
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
      for (int tieIdx = 0; tieIdx < rounds[r].length ~/ step; tieIdx++) {
        final targetTieIdx = (tieIdx ~/ 2).clamp(
          0,
          rounds[r + 1].length ~/ step - 1,
        );
        final targetMatchIdx = targetTieIdx * step;
        for (int leg = 0; leg < step; leg++) {
          rounds[r][tieIdx * step + leg]['next_pertandingan_id'] =
              rounds[r + 1][targetMatchIdx]['id_pertandingan'];
        }
      }
    }

    final matches = rounds.expand((round) => round).toList();
    if (count >= 4) {
      final thirdPlaceMatches = <Map<String, dynamic>>[];
      for (int leg = 1; leg <= jumlahLeg; leg++) {
        thirdPlaceMatches.add({
          'id_pertandingan': _uuid.v4(),
          'id_turnamen': idTurnamen,
          'id_peserta_1': null,
          'id_peserta_2': null,
          'babak': jumlahLeg == 2
              ? 'Leg $leg - Perebutan Juara 3'
              : 'Perebutan Juara 3',
          'skor_peserta_1': 0,
          'skor_peserta_2': 0,
          'status': 'Belum Mulai',
          'urutan': 0,
          'next_pertandingan_id': null,
        });
      }

      final finalIndex = matches.indexWhere(
        (match) =>
            (match['babak'] as String).replaceFirst(
              RegExp(r'^Leg [12] - '),
              '',
            ) ==
            'Final',
      );
      matches.insertAll(finalIndex, thirdPlaceMatches);
      for (var i = 0; i < matches.length; i++) {
        matches[i]['urutan'] = i + 1;
      }
    }

    for (final match in matches) {
      batch.insert(
        'pertandingan',
        match,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
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
        wbRounds[r][i]['next_pertandingan_id'] =
            wbRounds[r + 1][targetIdx]['id_pertandingan'];
      }
    }

    // --- Losers Bracket ---
    final List<List<Map<String, dynamic>>> lbRounds = [];
    if (count > 2) {
      final lbRoundCount = (wbRounds.length - 1) * 2 > 0
          ? (wbRounds.length - 1) * 2
          : 1;
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
          lbRounds[r][i]['next_pertandingan_id'] =
              lbRounds[r + 1][nextIdx]['id_pertandingan'];
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
        batch.insert(
          'pertandingan',
          m,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
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
        final babak = jumlahLeg == 2
            ? 'Leg 1 - Match $matchNum'
            : 'Match $matchNum';
        batch.insert('pertandingan', {
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
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        matchNum++;
      }
    }

    // Leg 2 (Away) jika 2 leg
    if (jumlahLeg == 2) {
      matchNum = 1;
      for (int i = 0; i < pesertaList.length; i++) {
        for (int j = i + 1; j < pesertaList.length; j++) {
          batch.insert('pertandingan', {
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
          }, conflictAlgorithm: ConflictAlgorithm.replace);
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

      batch.insert('pertandingan', {
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
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (jumlahLeg == 2) {
        batch.insert('pertandingan', {
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
        }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    String emailUser = '',
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
      emailUser: emailUser,
    );

    await db.transaction((txn) async {
      // 1. Insert turnamen
      await txn.insert(
        'turnamen',
        turnamen.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

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
        await txn.insert(
          'peserta',
          p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
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
  Future<List<TurnamenModel>> getAllTurnamen({
    String? search,
    String? status,
    String emailUser = '',
  }) async {
    final db = await _dbHelper.database;
    String whereClause = 'is_private = 1 AND email_user = ?';
    final List<dynamic> whereArgs = [emailUser];

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
      whereArgs: whereArgs,
      orderBy: 'tanggal_mulai DESC',
    );

    return results.map((m) => TurnamenModel.fromMap(m)).toList();
  }

  // ==========================================================
  // 3. GET Turnamen Privat Aktif
  // ==========================================================
  Future<List<TurnamenModel>> getTurnamenAktif({
    String? search,
    String? statusFilter,
    String emailUser = '',
  }) async {
    final db = await _dbHelper.database;
    String whereClause =
        "is_private = 1 AND status != 'Selesai' AND email_user = ?";
    final List<dynamic> whereArgs = [emailUser];

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
      whereArgs: whereArgs,
      orderBy: 'tanggal_mulai ASC',
    );

    return results.map((m) => TurnamenModel.fromMap(m)).toList();
  }

  // ==========================================================
  // 4. GET Riwayat Turnamen Privat (Selesai)
  // ==========================================================
  Future<List<TurnamenModel>> getRiwayatTurnamen({
    String? search,
    String emailUser = '',
  }) async {
    final db = await _dbHelper.database;
    String whereClause =
        "is_private = 1 AND status = 'Selesai' AND email_user = ?";
    final List<dynamic> whereArgs = [emailUser];

    if (search != null && search.trim().isNotEmpty) {
      whereClause += ' AND nama_turnamen LIKE ?';
      whereArgs.add('%${search.trim()}%');
    }

    final results = await db.query(
      'turnamen',
      where: whereClause,
      whereArgs: whereArgs,
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

    var mResults = await db.rawQuery(
      '''
      SELECT 
        m.*,
        p1.nama_peserta AS nama_peserta_1,
        p2.nama_peserta AS nama_peserta_2
      FROM pertandingan m
      LEFT JOIN peserta p1 ON m.id_peserta_1 = p1.id_peserta
      LEFT JOIN peserta p2 ON m.id_peserta_2 = p2.id_peserta
      WHERE m.id_turnamen = ?
      ORDER BY m.urutan ASC
    ''',
      [idTurnamen],
    );

    if (turnamen.formatBracket == 'Single Elimination' &&
        turnamen.jumlahLeg == 2) {
      final matches = mResults
          .map((match) => Map<String, Object?>.from(match))
          .toList();
      final roundNames = matches
          .where((match) => (match['babak'] as String).startsWith('Leg 1 - '))
          .map(
            (match) => (match['babak'] as String).replaceFirst('Leg 1 - ', ''),
          )
          .toSet();

      await db.transaction((txn) async {
        for (final roundName in roundNames) {
          final firstLegs =
              matches
                  .where((match) => match['babak'] == 'Leg 1 - $roundName')
                  .toList()
                ..sort(
                  (a, b) => (a['urutan'] as int).compareTo(b['urutan'] as int),
                );
          final secondLegs =
              matches
                  .where((match) => match['babak'] == 'Leg 2 - $roundName')
                  .toList()
                ..sort(
                  (a, b) => (a['urutan'] as int).compareTo(b['urutan'] as int),
                );

          for (var i = 0; i < firstLegs.length && i < secondLegs.length; i++) {
            final firstLeg = firstLegs[i];
            final secondLeg = secondLegs[i];
            final firstParticipant = firstLeg['id_peserta_1'];
            final secondParticipant = firstLeg['id_peserta_2'];
            if (secondLeg['status'] == 'Selesai' ||
                firstParticipant == null ||
                secondParticipant == null ||
                (secondLeg['id_peserta_1'] == secondParticipant &&
                    secondLeg['id_peserta_2'] == firstParticipant)) {
              continue;
            }

            await txn.update(
              'pertandingan',
              {
                'id_peserta_1': secondParticipant,
                'id_peserta_2': firstParticipant,
              },
              where: 'id_pertandingan = ?',
              whereArgs: [secondLeg['id_pertandingan']],
            );
            secondLeg['id_peserta_1'] = secondParticipant;
            secondLeg['id_peserta_2'] = firstParticipant;
          }
        }
      });

      mResults = await db.rawQuery(
        '''
        SELECT
          m.*,
          p1.nama_peserta AS nama_peserta_1,
          p2.nama_peserta AS nama_peserta_2
        FROM pertandingan m
        LEFT JOIN peserta p1 ON m.id_peserta_1 = p1.id_peserta
        LEFT JOIN peserta p2 ON m.id_peserta_2 = p2.id_peserta
        WHERE m.id_turnamen = ?
        ORDER BY m.urutan ASC
      ''',
        [idTurnamen],
      );
    }

    final pertandinganList = mResults
        .map((m) => PertandinganModel.fromMap(m))
        .toList();

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
        'is_locked': turnamen.isLocked ? 1 : 0,
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
    int? skorPenalti1,
    int? skorPenalti2,
  }) async {
    final db = await _dbHelper.database;

    final mResults = await db.rawQuery(
      '''
      SELECT 
        m.*,
        p1.nama_peserta AS nama_peserta_1,
        p2.nama_peserta AS nama_peserta_2
      FROM pertandingan m
      LEFT JOIN peserta p1 ON m.id_peserta_1 = p1.id_peserta
      LEFT JOIN peserta p2 ON m.id_peserta_2 = p2.id_peserta
      WHERE m.id_pertandingan = ?
    ''',
      [idPertandingan],
    );

    if (mResults.isEmpty) {
      throw Exception('Pertandingan tidak ditemukan di database lokal.');
    }

    final currentMatch = PertandinganModel.fromMap(mResults.first);
    final tournamentRows = await db.query(
      'turnamen',
      columns: ['format_bracket', 'jumlah_leg'],
      where: 'id_turnamen = ?',
      whereArgs: [currentMatch.idTurnamen],
      limit: 1,
    );
    if (tournamentRows.isEmpty) {
      throw Exception('Turnamen untuk pertandingan ini tidak ditemukan.');
    }
    final tournament = tournamentRows.first;
    final isKnockout = tournament['format_bracket'] == 'Single Elimination';

    if ((skorPenalti1 != null && skorPenalti1 < 0) ||
        (skorPenalti2 != null && skorPenalti2 < 0)) {
      throw Exception('Skor adu penalti harus berupa angka nol atau lebih.');
    }

    if (status == 'Selesai' && isKnockout) {
      final isTwoLeg = tournament['jumlah_leg'] == 2;
      if (!isTwoLeg) {
        if (skor1 == skor2) {
          if (skorPenalti1 == null || skorPenalti2 == null) {
            throw Exception(
              'Skor seri. Masukkan skor adu penalti untuk menentukan pemenang.',
            );
          }
          if (skorPenalti1 == skorPenalti2) {
            throw Exception('Adu penalti tidak boleh berakhir seri.');
          }
        }
      } else if (currentMatch.babak.startsWith('Leg 2 - ')) {
        final roundName = currentMatch.babak.replaceFirst('Leg 2 - ', '');
        final firstLegs = await db.query(
          'pertandingan',
          where: 'id_turnamen = ? AND babak = ?',
          whereArgs: [currentMatch.idTurnamen, 'Leg 1 - $roundName'],
        );
        Map<String, Object?>? firstLeg;
        for (final leg in firstLegs) {
          if (leg['id_peserta_1'] == currentMatch.idPeserta2 &&
              leg['id_peserta_2'] == currentMatch.idPeserta1) {
            firstLeg = leg;
            break;
          }
        }

        if (firstLeg == null || firstLeg['status'] != 'Selesai') {
          throw Exception(
            'Selesaikan Leg 1 terlebih dahulu sebelum menyelesaikan Leg 2.',
          );
        }

        final previousScore1 =
            firstLeg['id_peserta_1'] == currentMatch.idPeserta1
            ? firstLeg['skor_peserta_1'] as int
            : firstLeg['skor_peserta_2'] as int;
        final previousScore2 =
            firstLeg['id_peserta_1'] == currentMatch.idPeserta2
            ? firstLeg['skor_peserta_1'] as int
            : firstLeg['skor_peserta_2'] as int;
        final aggregateIsTied =
            skor1 + previousScore1 == skor2 + previousScore2;
        if (skor1 == skor2 || aggregateIsTied) {
          if (skorPenalti1 == null || skorPenalti2 == null) {
            throw Exception(
              aggregateIsTied
                  ? 'Agregat seri. Masukkan skor adu penalti untuk menentukan pemenang.'
                  : 'Skor Leg 2 seri. Masukkan skor adu penalti.',
            );
          }
          if (skorPenalti1 == skorPenalti2) {
            throw Exception('Adu penalti tidak boleh berakhir seri.');
          }
        }
      }
    }

    await db.transaction((txn) async {
      // 1. Update skor & status pertandingan
      await txn.update(
        'pertandingan',
        {
          'skor_peserta_1': skor1,
          'skor_peserta_2': skor2,
          'skor_penalti_peserta_1': skorPenalti1,
          'skor_penalti_peserta_2': skorPenalti2,
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
        final tournamentRows = await txn.query(
          'turnamen',
          columns: ['format_bracket', 'jumlah_leg'],
          where: 'id_turnamen = ?',
          whereArgs: [currentMatch.idTurnamen],
          limit: 1,
        );
        final isTwoLegSingleElimination =
            tournamentRows.isNotEmpty &&
            tournamentRows.first['format_bracket'] == 'Single Elimination' &&
            tournamentRows.first['jumlah_leg'] == 2;

        if (isTwoLegSingleElimination) {
          final siblings = await txn.query(
            'pertandingan',
            where: 'next_pertandingan_id = ?',
            whereArgs: [currentMatch.nextPertandinganId],
            orderBy: 'urutan ASC',
          );
          final currentIndex = siblings.indexWhere(
            (sibling) => sibling['id_pertandingan'] == idPertandingan,
          );
          final tieIndex = currentIndex ~/ 2;
          final tieLegs = siblings.skip(tieIndex * 2).take(2).toList();

          if (currentIndex >= 0 &&
              tieLegs.length == 2 &&
              tieLegs.every((leg) => leg['status'] == 'Selesai')) {
            final homeId = tieLegs.first['id_peserta_1'] as String?;
            final awayId = tieLegs.first['id_peserta_2'] as String?;
            var homeScore = 0;
            var awayScore = 0;

            for (final leg in tieLegs) {
              if (leg['id_peserta_1'] == homeId) {
                homeScore += leg['skor_peserta_1'] as int;
                awayScore += leg['skor_peserta_2'] as int;
              } else {
                awayScore += leg['skor_peserta_1'] as int;
                homeScore += leg['skor_peserta_2'] as int;
              }
            }

            Map<String, Object?>? penaltyLeg;
            for (final leg in tieLegs) {
              if (leg['skor_penalti_peserta_1'] != null &&
                  leg['skor_penalti_peserta_2'] != null) {
                penaltyLeg = leg;
                break;
              }
            }
            if (homeId != null &&
                awayId != null &&
                (homeScore != awayScore || penaltyLeg != null)) {
              final winnerId = homeScore == awayScore
                  ? ((penaltyLeg!['skor_penalti_peserta_1'] as int) >
                            (penaltyLeg['skor_penalti_peserta_2'] as int)
                        ? penaltyLeg['id_peserta_1'] as String
                        : penaltyLeg['id_peserta_2'] as String)
                  : (homeScore > awayScore ? homeId : awayId);
              final targetSlot = tieIndex % 2;
              final targets = await txn.query(
                'pertandingan',
                where: 'id_pertandingan = ?',
                whereArgs: [currentMatch.nextPertandinganId],
                limit: 1,
              );

              if (targets.isNotEmpty) {
                final target = targets.first;
                final firstLegField = targetSlot == 0
                    ? 'id_peserta_1'
                    : 'id_peserta_2';
                await txn.update(
                  'pertandingan',
                  {firstLegField: winnerId},
                  where: 'id_pertandingan = ?',
                  whereArgs: [currentMatch.nextPertandinganId],
                );

                final secondLegs = await txn.query(
                  'pertandingan',
                  where: 'id_turnamen = ? AND urutan = ? AND babak LIKE ?',
                  whereArgs: [
                    currentMatch.idTurnamen,
                    (target['urutan'] as int) + 1,
                    'Leg 2 - %',
                  ],
                  limit: 1,
                );

                if (secondLegs.isNotEmpty) {
                  final secondLegField = targetSlot == 0
                      ? 'id_peserta_2'
                      : 'id_peserta_1';
                  await txn.update(
                    'pertandingan',
                    {secondLegField: winnerId},
                    where: 'id_pertandingan = ?',
                    whereArgs: [secondLegs.first['id_pertandingan']],
                  );
                }
              }
            }
          }
        } else {
          String? winnerId;
          if (skor1 > skor2) {
            winnerId = currentMatch.idPeserta1;
          } else if (skor2 > skor1) {
            winnerId = currentMatch.idPeserta2;
          } else if (skorPenalti1 != null && skorPenalti2 != null) {
            winnerId = skorPenalti1 > skorPenalti2
                ? currentMatch.idPeserta1
                : currentMatch.idPeserta2;
          }

          if (winnerId != null) {
            final siblings = await txn.query(
              'pertandingan',
              where: 'next_pertandingan_id = ?',
              whereArgs: [currentMatch.nextPertandinganId],
              orderBy: 'urutan ASC',
            );

            if (siblings.isNotEmpty) {
              final isSlot1 =
                  siblings.first['id_pertandingan'] == idPertandingan;
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
      }

      if (currentMatch.babak.contains('Semifinal')) {
        final tournaments = await txn.query(
          'turnamen',
          columns: ['format_bracket', 'jumlah_leg'],
          where: 'id_turnamen = ?',
          whereArgs: [currentMatch.idTurnamen],
          limit: 1,
        );

        if (tournaments.isNotEmpty &&
            tournaments.first['format_bracket'] == 'Single Elimination') {
          final legCount = tournaments.first['jumlah_leg'] == 2 ? 2 : 1;
          final semifinalMatches = await txn.query(
            'pertandingan',
            where: 'id_turnamen = ? AND babak LIKE ?',
            whereArgs: [currentMatch.idTurnamen, '%Semifinal%'],
            orderBy: 'urutan ASC',
          );
          final thirdPlaceMatches = await txn.query(
            'pertandingan',
            where: 'id_turnamen = ? AND babak LIKE ?',
            whereArgs: [currentMatch.idTurnamen, '%Perebutan Juara 3%'],
            orderBy: 'urutan ASC',
          );

          if (semifinalMatches.length == legCount * 2 &&
              thirdPlaceMatches.length == legCount) {
            final semifinalLosers = <String>[];

            for (var i = 0; i < semifinalMatches.length; i += legCount) {
              final legs = semifinalMatches.skip(i).take(legCount).toList();
              if (legs.any((leg) => leg['status'] != 'Selesai') ||
                  legs.any(
                    (leg) =>
                        leg['id_peserta_1'] == null ||
                        leg['id_peserta_2'] == null,
                  )) {
                return;
              }

              final homeId = legs.first['id_peserta_1'] as String;
              final awayId = legs.first['id_peserta_2'] as String;
              var homeScore = 0;
              var awayScore = 0;

              for (final leg in legs) {
                if (leg['id_peserta_1'] == homeId) {
                  homeScore += leg['skor_peserta_1'] as int;
                  awayScore += leg['skor_peserta_2'] as int;
                } else {
                  awayScore += leg['skor_peserta_1'] as int;
                  homeScore += leg['skor_peserta_2'] as int;
                }
              }

              if (homeScore == awayScore) {
                final penaltyLeg = legs.firstWhere(
                  (leg) =>
                      leg['skor_penalti_peserta_1'] != null &&
                      leg['skor_penalti_peserta_2'] != null,
                  orElse: () => <String, Object?>{},
                );
                if (penaltyLeg.isEmpty) return;
                semifinalLosers.add(
                  (penaltyLeg['skor_penalti_peserta_1'] as int) <
                          (penaltyLeg['skor_penalti_peserta_2'] as int)
                      ? penaltyLeg['id_peserta_1'] as String
                      : penaltyLeg['id_peserta_2'] as String,
                );
              } else {
                semifinalLosers.add(homeScore < awayScore ? homeId : awayId);
              }
            }

            for (var i = 0; i < thirdPlaceMatches.length; i++) {
              final participants = legCount == 2 && i == 1
                  ? [semifinalLosers[1], semifinalLosers[0]]
                  : semifinalLosers;
              await txn.update(
                'pertandingan',
                {
                  'id_peserta_1': participants[0],
                  'id_peserta_2': participants[1],
                },
                where: 'id_pertandingan = ?',
                whereArgs: [thirdPlaceMatches[i]['id_pertandingan']],
              );
            }
          }
        }
      }

      // Catatan: Status 'Selesai' dan kunci skor turnamen sekarang dilakukan
      // secara manual melalui konfirmasi tombol 'Akhiri Turnamen'.
    });

    final updated = await db.rawQuery(
      '''
      SELECT 
        m.*,
        p1.nama_peserta AS nama_peserta_1,
        p2.nama_peserta AS nama_peserta_2
      FROM pertandingan m
      LEFT JOIN peserta p1 ON m.id_peserta_1 = p1.id_peserta
      LEFT JOIN peserta p2 ON m.id_peserta_2 = p2.id_peserta
      WHERE m.id_pertandingan = ?
    ''',
      [idPertandingan],
    );

    return PertandinganModel.fromMap(updated.first);
  }
}
