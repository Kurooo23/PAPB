import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:rivnet/models/match.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  static const _dbName = 'rivnet_uts.db';
  static const _dbVersion = 2;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE turnamen (
        id_turnamen    TEXT PRIMARY KEY,
        nama_turnamen  TEXT NOT NULL,
        deskripsi      TEXT,
        tipe_game      TEXT NOT NULL DEFAULT 'Sepak Bola / Futsal',
        format_bracket TEXT NOT NULL,
        jumlah_leg     INTEGER NOT NULL DEFAULT 1,
        tanggal_mulai  TEXT NOT NULL,
        kuota          INTEGER NOT NULL,
        status         TEXT NOT NULL DEFAULT 'Akan Datang',
        is_finished    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE peserta (
        id_peserta   TEXT PRIMARY KEY,
        id_turnamen  TEXT NOT NULL,
        urutan       INTEGER NOT NULL DEFAULT 0,
        nama_peserta TEXT NOT NULL,
        is_wo        INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (id_turnamen) REFERENCES turnamen(id_turnamen) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pertandingan (
        id_pertandingan        TEXT PRIMARY KEY,
        id_turnamen            TEXT NOT NULL,
        id_peserta_1           TEXT,
        id_peserta_2           TEXT,
        babak                  TEXT NOT NULL,
        leg                    INTEGER NOT NULL DEFAULT 1,
        skor_peserta_1         INTEGER NOT NULL DEFAULT 0,
        skor_peserta_2         INTEGER NOT NULL DEFAULT 0,
        skor_penalti_peserta_1 INTEGER,
        skor_penalti_peserta_2 INTEGER,
        status                 TEXT NOT NULL DEFAULT 'Belum Mulai',
        urutan                 INTEGER NOT NULL DEFAULT 0,
        next_pertandingan_id   TEXT,
        FOREIGN KEY (id_turnamen)  REFERENCES turnamen(id_turnamen) ON DELETE CASCADE,
        FOREIGN KEY (id_peserta_1) REFERENCES peserta(id_peserta) ON DELETE SET NULL,
        FOREIGN KEY (id_peserta_2) REFERENCES peserta(id_peserta) ON DELETE SET NULL
      )
    ''');
  }

  // versi 2: tambah kolom is_wo untuk peserta yang dihapus (walkover)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE peserta ADD COLUMN is_wo INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<String> insertTournament({
    required String nama,
    required String format,
    required int leg,
    required int kuota,
    required List<String> peserta,
  }) async {
    final db = await database;
    final id = 'trn_${DateTime.now().microsecondsSinceEpoch}';

    final pesertaRows = <Map<String, Object?>>[];

    await db.transaction((txn) async {
      await txn.insert('turnamen', {
        'id_turnamen': id,
        'nama_turnamen': nama,
        'format_bracket': format,
        'jumlah_leg': leg,
        'tanggal_mulai': DateTime.now().toIso8601String(),
        'kuota': kuota,
      });
      for (var i = 0; i < peserta.length; i++) {
        final pRow = {
          'id_peserta': '${id}_p$i',
          'id_turnamen': id,
          'urutan': i,
          'nama_peserta': peserta[i],
        };
        pesertaRows.add(pRow);
        await txn.insert('peserta', pRow);
      }
    });

    // Otomatis buat jadwal pertandingan setelah turnamen & peserta disimpan
    await generateMatchesForTournament(
      idTurnamen: id,
      format: format,
      jumlahLeg: leg,
      pesertaRows: pesertaRows,
    );

    return id;
  }

  Future<List<Map<String, Object?>>> generateMatchesForTournament({
    required String idTurnamen,
    required String format,
    required int jumlahLeg,
    required List<Map<String, Object?>> pesertaRows,
  }) async {
    final pesertaIds = [for (final p in pesertaRows) p['id_peserta'] as String];

    final rows = <Map<String, Object?>>[];
    int urutanCounter = 1;

    if (format == 'Single Elimination' || format == 'Knockout') {
      final kuota = pesertaIds.length;

      final listNamaBabak = <String>[];
      int currentCount = kuota ~/ 2;

      String namaBabak(int count) {
        if (count == 8) return '16 Besar';
        if (count == 4) return 'Perempat Final';
        if (count == 2) return 'Semifinal';
        if (count == 1) return 'Final';
        return 'Babak $count';
      }

      while (currentCount >= 1) {
        listNamaBabak.add(namaBabak(currentCount));
        currentCount = currentCount ~/ 2;
      }

      final Map<String, List<String>> roundMatchIds = {};
      for (final bNama in listNamaBabak) {
        int countInRound = (bNama == '16 Besar')
            ? 8
            : (bNama == 'Perempat Final')
            ? 4
            : (bNama == 'Semifinal')
            ? 2
            : 1;
        roundMatchIds[bNama] = List.generate(
          countInRound,
          (i) => '${idTurnamen}_m_${bNama.replaceAll(' ', '_')}_$i',
        );
      }

      if (kuota >= 4) {
        roundMatchIds['Perebutan Juara 3'] = ['${idTurnamen}_m_juara3_0'];
      }

      for (int r = 0; r < listNamaBabak.length; r++) {
        final bNama = listNamaBabak[r];
        final mIds = roundMatchIds[bNama]!;
        final isFirstRound = (r == 0);
        final nextRoundIds = (r + 1 < listNamaBabak.length)
            ? roundMatchIds[listNamaBabak[r + 1]]
            : null;

        for (int i = 0; i < mIds.length; i++) {
          final mId = mIds[i];
          final nextId = nextRoundIds != null ? nextRoundIds[i ~/ 2] : null;

          for (int leg = 1; leg <= jumlahLeg; leg++) {
            final prefixBabak = jumlahLeg > 1 ? 'Leg $leg - ' : '';
            rows.add({
              'id_pertandingan': jumlahLeg > 1 ? '${mId}_leg$leg' : mId,
              'id_turnamen': idTurnamen,
              'id_peserta_1': isFirstRound
                  ? (leg == 2 ? pesertaIds[i * 2 + 1] : pesertaIds[i * 2])
                  : null,
              'id_peserta_2': isFirstRound
                  ? (leg == 2 ? pesertaIds[i * 2] : pesertaIds[i * 2 + 1])
                  : null,
              'babak': '$prefixBabak$bNama',
              'leg': leg,
              'skor_peserta_1': 0,
              'skor_peserta_2': 0,
              'status': 'Belum Mulai',
              'urutan': urutanCounter++,
              'next_pertandingan_id': nextId,
            });
          }
        }
      }

      if (kuota >= 4) {
        final j3Id = roundMatchIds['Perebutan Juara 3']!.first;
        for (int leg = 1; leg <= jumlahLeg; leg++) {
          final prefixBabak = jumlahLeg > 1 ? 'Leg $leg - ' : '';
          rows.add({
            'id_pertandingan': jumlahLeg > 1 ? '${j3Id}_leg$leg' : j3Id,
            'id_turnamen': idTurnamen,
            'id_peserta_1': null,
            'id_peserta_2': null,
            'babak': '${prefixBabak}Perebutan Juara 3',
            'leg': leg,
            'skor_peserta_1': 0,
            'skor_peserta_2': 0,
            'status': 'Belum Mulai',
            'urutan': urutanCounter++,
            'next_pertandingan_id': null,
          });
        }
      }
    } else {
      // Format Liga
      int n = pesertaIds.length;
      for (int leg = 1; leg <= jumlahLeg; leg++) {
        for (int i = 0; i < n; i++) {
          for (int j = i + 1; j < n; j++) {
            final p1 = (leg == 1) ? pesertaIds[i] : pesertaIds[j];
            final p2 = (leg == 1) ? pesertaIds[j] : pesertaIds[i];
            rows.add({
              'id_pertandingan': '${idTurnamen}_liga_${leg}_${i}_$j',
              'id_turnamen': idTurnamen,
              'id_peserta_1': p1,
              'id_peserta_2': p2,
              'babak': 'Pekan ${rows.length + 1}',
              'leg': leg,
              'skor_peserta_1': 0,
              'skor_peserta_2': 0,
              'status': 'Belum Mulai',
              'urutan': urutanCounter++,
              'next_pertandingan_id': null,
            });
          }
        }
      }
    }

    await insertMatches(rows);
    return rows;
  }

  Future<void> updateMatchScore({
    required Pertandingan match,
    required int skor1,
    required int skor2,
    int? penalti1,
    int? penalti2,
  }) async {
    final db = await database;

    await db.update(
      'pertandingan',
      {
        'skor_peserta_1': skor1,
        'skor_peserta_2': skor2,
        'skor_penalti_peserta_1': penalti1,
        'skor_penalti_peserta_2': penalti2,
        'status': 'Selesai',
      },
      where: 'id_pertandingan = ?',
      whereArgs: [match.id],
    );

    // Lanjutkan pemenang ke pertandingan berikutnya jika knockout
    if (match.nextId != null) {
      String? winnerId;
      String? loserId;

      if (skor1 > skor2) {
        winnerId = match.idPeserta1;
        loserId = match.idPeserta2;
      } else if (skor2 > skor1) {
        winnerId = match.idPeserta2;
        loserId = match.idPeserta1;
      } else if (penalti1 != null && penalti2 != null) {
        if (penalti1 > penalti2) {
          winnerId = match.idPeserta1;
          loserId = match.idPeserta2;
        } else if (penalti2 > penalti1) {
          winnerId = match.idPeserta2;
          loserId = match.idPeserta1;
        }
      }

      if (winnerId != null) {
        final nextMatchRows = await db.query(
          'pertandingan',
          where: 'id_pertandingan = ?',
          whereArgs: [match.nextId],
        );

        if (nextMatchRows.isNotEmpty) {
          final nextRow = nextMatchRows.first;
          final p1 = nextRow['id_peserta_1'] as String?;

          if (match.urutan % 2 != 0 || p1 == null) {
            await db.update(
              'pertandingan',
              {'id_peserta_1': winnerId},
              where: 'id_pertandingan = ?',
              whereArgs: [match.nextId],
            );
          } else {
            await db.update(
              'pertandingan',
              {'id_peserta_2': winnerId},
              where: 'id_pertandingan = ?',
              whereArgs: [match.nextId],
            );
          }
        }
      }

      if (loserId != null && match.babak.contains('Semifinal')) {
        final j3Rows = await db.query(
          'pertandingan',
          where: "id_turnamen = ? AND babak LIKE '%Perebutan Juara 3%'",
          whereArgs: [match.idTurnamen],
        );

        if (j3Rows.isNotEmpty) {
          final j3Row = j3Rows.first;
          final j3Id = j3Row['id_pertandingan'] as String;
          final p1 = j3Row['id_peserta_1'] as String?;

          if (p1 == null) {
            await db.update(
              'pertandingan',
              {'id_peserta_1': loserId},
              where: 'id_pertandingan = ?',
              whereArgs: [j3Id],
            );
          } else {
            await db.update(
              'pertandingan',
              {'id_peserta_2': loserId},
              where: 'id_pertandingan = ?',
              whereArgs: [j3Id],
            );
          }
        }
      }
    }
  }

  // status null = Semua (yang belum selesai)
  Future<List<Map<String, Object?>>> getTournaments({String? status}) async {
    final db = await database;
    if (status == null) {
      return db.query(
        'turnamen',
        where: "status != 'Selesai'",
        orderBy: 'tanggal_mulai DESC',
      );
    }
    return db.query(
      'turnamen',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'tanggal_mulai DESC',
    );
  }

  Future<List<Map<String, Object?>>> getPeserta(String idTurnamen) async {
    final db = await database;
    return db.query(
      'peserta',
      where: 'id_turnamen = ?',
      whereArgs: [idTurnamen],
      orderBy: 'urutan',
    );
  }

  Future<List<Map<String, Object?>>> getMatches(String idTurnamen) async {
    final db = await database;
    return db.query(
      'pertandingan',
      where: 'id_turnamen = ?',
      whereArgs: [idTurnamen],
      orderBy: 'urutan, leg',
    );
  }

  // Simpan banyak pertandingan sekaligus
  Future<void> insertMatches(List<Map<String, Object?>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('pertandingan', row);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTournament(String id) async {
    final db = await database;
    await db.delete('turnamen', where: 'id_turnamen = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
