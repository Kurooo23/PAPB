import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rivnet.db');

    return openDatabase(
      path,
      version: 4,
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
        tipe_game      TEXT NOT NULL DEFAULT 'E-Sports',
        format_bracket TEXT NOT NULL,
        jumlah_leg     INTEGER NOT NULL DEFAULT 1,
        tanggal_mulai  TEXT NOT NULL,
        kuota          INTEGER NOT NULL,
        status         TEXT NOT NULL DEFAULT 'Akan Datang',
        is_private     INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE peserta (
        id_peserta   TEXT PRIMARY KEY,
        id_turnamen  TEXT NOT NULL,
        nama_peserta TEXT NOT NULL,
        FOREIGN KEY (id_turnamen) REFERENCES turnamen(id_turnamen) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pertandingan (
        id_pertandingan      TEXT PRIMARY KEY,
        id_turnamen          TEXT NOT NULL,
        id_peserta_1         TEXT,
        id_peserta_2         TEXT,
        babak                TEXT NOT NULL,
        skor_peserta_1       INTEGER DEFAULT 0,
        skor_peserta_2       INTEGER DEFAULT 0,
        status               TEXT NOT NULL DEFAULT 'Belum Mulai',
        urutan               INTEGER DEFAULT 0,
        next_pertandingan_id TEXT,
        FOREIGN KEY (id_turnamen)  REFERENCES turnamen(id_turnamen) ON DELETE CASCADE,
        FOREIGN KEY (id_peserta_1) REFERENCES peserta(id_peserta) ON DELETE SET NULL,
        FOREIGN KEY (id_peserta_2) REFERENCES peserta(id_peserta) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_session (
        id_user      TEXT PRIMARY KEY,
        email        TEXT NOT NULL,
        nickname     TEXT NOT NULL,
        avatar_index INTEGER NOT NULL DEFAULT 0,
        token        TEXT,
        last_login   TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS user_session');
      await db.execute('DROP TABLE IF EXISTS pertandingan');
      await db.execute('DROP TABLE IF EXISTS peserta');
      await db.execute('DROP TABLE IF EXISTS turnamen');
      await _onCreate(db, newVersion);
      return;
    }

    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE turnamen ADD COLUMN tipe_game TEXT NOT NULL DEFAULT 'E-Sports'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE turnamen ADD COLUMN jumlah_leg INTEGER NOT NULL DEFAULT 1");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE turnamen ADD COLUMN is_private INTEGER NOT NULL DEFAULT 1");
      } catch (_) {}
    }

    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_session (
            id_user      TEXT PRIMARY KEY,
            email        TEXT NOT NULL,
            nickname     TEXT NOT NULL,
            avatar_index INTEGER NOT NULL DEFAULT 0,
            token        TEXT,
            last_login   TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
  }

  // === MANAJEMEN SESI USER LOKAL (OFFLINE) ===
  Future<void> saveUserSession(Map<String, dynamic> user, {String? token}) async {
    final db = await database;
    await db.insert(
      'user_session',
      {
        'id_user': user['id_user']?.toString() ?? user['id']?.toString() ?? 'guest',
        'email': user['email']?.toString() ?? '',
        'nickname': user['nickname']?.toString() ?? user['nama']?.toString() ?? 'Pemain',
        'avatar_index': user['avatar_index'] is int ? user['avatar_index'] as int : 0,
        'token': token ?? user['token']?.toString(),
        'last_login': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUserSession() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'user_session',
      orderBy: 'last_login DESC',
      limit: 1,
    );
    if (results.isNotEmpty) {
      return Map<String, dynamic>.from(results.first);
    }
    return null;
  }

  Future<void> clearUserSession() async {
    final db = await database;
    await db.delete('user_session');
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
