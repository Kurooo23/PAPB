import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/peserta_model.dart';

class PesertaDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertPeserta(PesertaModel peserta) async {
    final db = await _dbHelper.database;
    return await db.insert('peserta', peserta.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertBatchPeserta(List<PesertaModel> pesertaList) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final peserta in pesertaList) {
      batch.insert('peserta', peserta.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<PesertaModel>> getPesertaByTurnamen(String idTurnamen) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'peserta',
      where: 'id_turnamen = ?',
      whereArgs: [idTurnamen],
    );
    return results.map((map) => PesertaModel.fromMap(map)).toList();
  }

  Future<int> deletePeserta(String idPeserta) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'peserta',
      where: 'id_peserta = ?',
      whereArgs: [idPeserta],
    );
  }
}
