import 'package:flutter_test/flutter_test.dart';
import 'package:app_papb/data/models/turnamen_model.dart';
import 'package:app_papb/data/models/peserta_model.dart';
import 'package:app_papb/data/models/pertandingan_model.dart';

void main() {
  group('TurnamenModel Tests', () {
    test('toMap and fromMap should correctly serialize and deserialize', () {
      final turnamen = TurnamenModel(
        idTurnamen: '1',
        namaTurnamen: 'Liga Futsal ITK',
        deskripsi: 'Turnamen Futsal',
        tipeGame: 'Sepak Bola',
        formatBracket: 'Liga',
        tanggalMulai: DateTime(2026, 9, 1),
        kuota: 8,
        status: 'Akan Datang',
      );

      final map = turnamen.toMap();
      final fromMap = TurnamenModel.fromMap(map);

      expect(fromMap.idTurnamen, '1');
      expect(fromMap.namaTurnamen, 'Liga Futsal ITK');
      expect(fromMap.tipeGame, 'Sepak Bola');
      expect(fromMap.kuota, 8);
    });

    test('copyWith should properly update fields', () {
      final turnamen = TurnamenModel(
        idTurnamen: '1',
        namaTurnamen: 'Catur ITK',
        tipeGame: 'Catur',
        formatBracket: 'Swiss System',
        tanggalMulai: DateTime(2026, 9, 1),
        kuota: 6,
      );

      final updated = turnamen.copyWith(namaTurnamen: 'Catur ITK 2026', status: 'Berlangsung');
      expect(updated.namaTurnamen, 'Catur ITK 2026');
      expect(updated.status, 'Berlangsung');
      expect(updated.tipeGame, 'Catur');
    });
  });

  group('PesertaModel Tests', () {
    test('toMap and fromMap should work correctly', () {
      final peserta = PesertaModel(
        idPeserta: 'p1',
        idTurnamen: 't1',
        namaPeserta: 'Real Madrid',
      );

      final map = peserta.toMap();
      final fromMap = PesertaModel.fromMap(map);

      expect(fromMap.namaPeserta, 'Real Madrid');
    });
  });

  group('PertandinganModel Tests', () {
    test('toMap and fromMap should handle nullable participants', () {
      final match = PertandinganModel(
        idPertandingan: 'm1',
        idTurnamen: 't1',
        babak: 'Final',
        urutan: 1,
      );

      final map = match.toMap();
      final fromMap = PertandinganModel.fromMap(map);

      expect(fromMap.idPeserta1, isNull);
      expect(fromMap.status, 'Belum Mulai');
    });
  });
}
