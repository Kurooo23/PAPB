import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/turnamen_model.dart';

class TurnamenDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertTurnamen(TurnamenModel turnamen) async {
    final db = await _dbHelper.database;
    return await db.insert('turnamen', turnamen.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateTurnamen(TurnamenModel turnamen) async {
    final db = await _dbHelper.database;
    return await db.update(
      'turnamen',
      turnamen.toMap(),
      where: 'id_turnamen = ?',
      whereArgs: [turnamen.idTurnamen],
    );
  }

  Future<int> updateStatusTurnamen(String idTurnamen, String status) async {
    final db = await _dbHelper.database;
    return await db.update(
      'turnamen',
      {'status': status},
      where: 'id_turnamen = ?',
      whereArgs: [idTurnamen],
    );
  }

  Future<int> deleteTurnamen(String idTurnamen) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'turnamen',
      where: 'id_turnamen = ?',
      whereArgs: [idTurnamen],
    );
  }

  Future<TurnamenModel?> getTurnamenById(String idTurnamen) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'turnamen',
      where: 'id_turnamen = ?',
      whereArgs: [idTurnamen],
    );
    if (results.isNotEmpty) {
      return TurnamenModel.fromMap(results.first);
    }
    return null;
  }

  Future<List<TurnamenModel>> getAllTurnamen() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'turnamen',
      orderBy: 'tanggal_mulai DESC',
    );
    return results.map((map) => TurnamenModel.fromMap(map)).toList();
  }

  Future<List<TurnamenModel>> getTurnamenAktif() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'turnamen',
      where: 'status != ?',
      whereArgs: ['Selesai'],
      orderBy: 'tanggal_mulai ASC',
    );
    return results.map((map) => TurnamenModel.fromMap(map)).toList();
  }

  Future<List<TurnamenModel>> getRiwayatTurnamen() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'turnamen',
      where: 'status = ?',
      whereArgs: ['Selesai'],
      orderBy: 'tanggal_mulai DESC',
    );
    return results.map((map) => TurnamenModel.fromMap(map)).toList();
  }

  Future<List<TurnamenModel>> searchTurnamen(String query, {String? statusFilter}) async {
    final db = await _dbHelper.database;
    String whereClause = 'nama_turnamen LIKE ?';
    List<dynamic> whereArgs = ['%$query%'];

    if (statusFilter != null && statusFilter != 'Semua') {
      whereClause += ' AND status = ?';
      whereArgs.add(statusFilter);
    }

    final List<Map<String, dynamic>> results = await db.query(
      'turnamen',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'tanggal_mulai DESC',
    );
    return results.map((map) => TurnamenModel.fromMap(map)).toList();
  }
}
