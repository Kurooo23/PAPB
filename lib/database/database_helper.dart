import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

import 'package:rivnet/models/turnamen.dart';

/// Mengelola penyimpanan lokal SQLite untuk turnamen, peserta, dan pertandingan.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _namaDatabase = 'rivnet_local.db';
  static const _versiDatabase = 2;

  static const tabelTurnamen = 'turnamen';
  static const tabelPeserta = 'peserta';
  static const tabelPertandingan = 'pertandingan';

  Database? _db;
  Future<Database>? _membukaDb;
  String? _overridePath;
  bool _sudahInitFactory = false;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    return _membukaDb ??= _bukaDatabase();
  }

  /// Mengatur database khusus untuk kebutuhan unit/widget test.
  @visibleForTesting
  Future<void> setTestDatabase({
    String? path,
    DatabaseFactory? factory,
  }) async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
    _membukaDb = null;
    _overridePath = path ?? inMemoryDatabasePath;
    if (factory != null) {
      databaseFactory = factory;
      _sudahInitFactory = true;
    }
  }

  Future<Database> _bukaDatabase() async {
    try {
      if (!_sudahInitFactory &&
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        _sudahInitFactory = true;
      }

      final dbPath =
          _overridePath ?? join(await getDatabasesPath(), _namaDatabase);

      _db = await openDatabase(
        dbPath,
        version: _versiDatabase,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _buatTabel,
        onUpgrade: _upgradeTabel,
        onOpen: (db) async {
          await _buatTabel(db, _versiDatabase);
          await _pastikanKolom(db);
        },
      );
      return _db!;
    } finally {
      _membukaDb = null;
    }
  }

  Future<void> _upgradeTabel(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await _buatTabel(db, newVersion);
    await _pastikanKolom(db);
  }

  Future<void> _pastikanKolom(Database db) async {
    final kolomTurnamen = await db.rawQuery('PRAGMA table_info($tabelTurnamen)');
    final namaKolomTurnamen = {
      for (final row in kolomTurnamen) row['name'] as String,
    };
    if (!namaKolomTurnamen.contains('format')) {
      await db.execute(
        "ALTER TABLE $tabelTurnamen ADD COLUMN format TEXT NOT NULL DEFAULT 'Liga'",
      );
    }

    final kolomPertandingan = await db.rawQuery(
      'PRAGMA table_info($tabelPertandingan)',
    );
    final namaKolomPertandingan = {
      for (final row in kolomPertandingan) row['name'] as String,
    };
    if (!namaKolomPertandingan.contains('babak')) {
      await db.execute(
        'ALTER TABLE $tabelPertandingan ADD COLUMN babak INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  Future<void> _buatTabel(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tabelTurnamen (
        id TEXT PRIMARY KEY,
        nama TEXT NOT NULL,
        game TEXT NOT NULL,
        format TEXT NOT NULL DEFAULT 'Liga',
        leg INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tabelPeserta (
        id TEXT PRIMARY KEY,
        turnamen_id TEXT NOT NULL,
        nama TEXT NOT NULL,
        urutan INTEGER NOT NULL,
        FOREIGN KEY (turnamen_id) REFERENCES $tabelTurnamen (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tabelPertandingan (
        id TEXT PRIMARY KEY,
        turnamen_id TEXT NOT NULL,
        id_a TEXT NOT NULL,
        id_b TEXT NOT NULL,
        skor_a INTEGER,
        skor_b INTEGER,
        babak INTEGER NOT NULL DEFAULT 1,
        urutan INTEGER NOT NULL,
        FOREIGN KEY (turnamen_id) REFERENCES $tabelTurnamen (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<List<Turnamen>> ambilSemuaTurnamen() async {
    final db = await database;
    final barisTurnamen = await db.query(
      tabelTurnamen,
      orderBy: 'created_at DESC',
    );
    if (barisTurnamen.isEmpty) return [];

    final barisPeserta = await db.query(
      tabelPeserta,
      orderBy: 'urutan ASC',
    );
    final barisPertandingan = await db.query(
      tabelPertandingan,
      orderBy: 'urutan ASC',
    );

    final petaPeserta = <String, List<Peserta>>{};
    for (final row in barisPeserta) {
      final turnamenId = row['turnamen_id'] as String;
      petaPeserta.putIfAbsent(turnamenId, () => []).add(Peserta.fromMap(row));
    }

    final petaPertandingan = <String, List<Pertandingan>>{};
    for (final row in barisPertandingan) {
      final turnamenId = row['turnamen_id'] as String;
      petaPertandingan
          .putIfAbsent(turnamenId, () => [])
          .add(Pertandingan.fromMap(row));
    }

    return [
      for (final row in barisTurnamen)
        Turnamen.fromMap(
          row,
          peserta: petaPeserta[row['id'] as String] ?? [],
          pertandingan: petaPertandingan[row['id'] as String] ?? [],
        ),
    ];
  }

  Future<void> simpanTurnamenBaru(Turnamen turnamen) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        tabelTurnamen,
        turnamen.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var indeks = 0; indeks < turnamen.peserta.length; indeks++) {
        await txn.insert(
          tabelPeserta,
          turnamen.peserta[indeks].toMap(
            turnamenId: turnamen.id,
            urutan: indeks,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (var indeks = 0; indeks < turnamen.pertandingan.length; indeks++) {
        await txn.insert(
          tabelPertandingan,
          turnamen.pertandingan[indeks].toMap(
            turnamenId: turnamen.id,
            urutan: indeks,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> perbaruiTurnamen(Turnamen turnamen) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        tabelTurnamen,
        {
          'nama': turnamen.nama,
          'game': turnamen.game,
          'format': turnamen.format,
          'leg': turnamen.leg,
          'status': turnamen.status,
        },
        where: 'id = ?',
        whereArgs: [turnamen.id],
      );

      await txn.delete(
        tabelPeserta,
        where: 'turnamen_id = ?',
        whereArgs: [turnamen.id],
      );
      for (var indeks = 0; indeks < turnamen.peserta.length; indeks++) {
        await txn.insert(
          tabelPeserta,
          turnamen.peserta[indeks].toMap(
            turnamenId: turnamen.id,
            urutan: indeks,
          ),
        );
      }

      await txn.delete(
        tabelPertandingan,
        where: 'turnamen_id = ?',
        whereArgs: [turnamen.id],
      );
      for (var indeks = 0; indeks < turnamen.pertandingan.length; indeks++) {
        await txn.insert(
          tabelPertandingan,
          turnamen.pertandingan[indeks].toMap(
            turnamenId: turnamen.id,
            urutan: indeks,
          ),
        );
      }
    });
  }

  Future<void> perbaruiStatusTurnamen(String idTurnamen, String status) async {
    final db = await database;
    await db.update(
      tabelTurnamen,
      {'status': status},
      where: 'id = ?',
      whereArgs: [idTurnamen],
    );
  }

  Future<void> hapusTurnamen(String idTurnamen) async {
    final db = await database;
    await db.delete(
      tabelTurnamen,
      where: 'id = ?',
      whereArgs: [idTurnamen],
    );
  }

  Future<void> tambahPeserta(
    String idTurnamen,
    Peserta peserta,
    int urutan,
  ) async {
    final db = await database;
    await db.insert(
      tabelPeserta,
      peserta.toMap(turnamenId: idTurnamen, urutan: urutan),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> perbaruiPeserta(Peserta peserta) async {
    final db = await database;
    await db.update(
      tabelPeserta,
      {'nama': peserta.nama},
      where: 'id = ?',
      whereArgs: [peserta.id],
    );
  }

  Future<void> hapusPeserta(String idPeserta) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        tabelPertandingan,
        where: 'id_a = ? OR id_b = ?',
        whereArgs: [idPeserta, idPeserta],
      );
      await txn.delete(
        tabelPeserta,
        where: 'id = ?',
        whereArgs: [idPeserta],
      );
    });
  }

  Future<void> gantiSemuaPertandingan(
    String idTurnamen,
    List<Pertandingan> daftarPertandingan,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        tabelPertandingan,
        where: 'turnamen_id = ?',
        whereArgs: [idTurnamen],
      );
      for (var indeks = 0; indeks < daftarPertandingan.length; indeks++) {
        await txn.insert(
          tabelPertandingan,
          daftarPertandingan[indeks].toMap(
            turnamenId: idTurnamen,
            urutan: indeks,
          ),
        );
      }
    });
  }

  Future<void> tambahDaftarPertandingan(
    String idTurnamen,
    List<Pertandingan> daftarPertandingan,
    int urutanAwal,
  ) async {
    if (daftarPertandingan.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (var indeks = 0; indeks < daftarPertandingan.length; indeks++) {
        await txn.insert(
          tabelPertandingan,
          daftarPertandingan[indeks].toMap(
            turnamenId: idTurnamen,
            urutan: urutanAwal + indeks,
          ),
        );
      }
    });
  }

  Future<void> perbaruiSkorPertandingan(
    String idPertandingan,
    int? skorA,
    int? skorB,
  ) async {
    final db = await database;
    await db.update(
      tabelPertandingan,
      {'skor_a': skorA, 'skor_b': skorB},
      where: 'id = ?',
      whereArgs: [idPertandingan],
    );
  }

  Future<void> perbaruiDaftarPertandingan(List<Pertandingan> daftar) async {
    if (daftar.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final laga in daftar) {
        await txn.update(
          tabelPertandingan,
          {
            'id_a': laga.idA,
            'id_b': laga.idB,
            'skor_a': laga.skorA,
            'skor_b': laga.skorB,
            'babak': laga.babak,
          },
          where: 'id = ?',
          whereArgs: [laga.id],
        );
      }
    });
  }
}
