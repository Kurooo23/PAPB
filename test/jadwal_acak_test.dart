import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rivnet/models/turnamen.dart';

List<Peserta> _buatPeserta(int jumlah) => [
  for (var i = 1; i <= jumlah; i++) Peserta(id: 'p$i', nama: 'Peserta $i'),
];

void main() {
  group('buatJadwalRoundRobin acak', () {
    test('4 peserta 1 leg: semua pasangan tepat sekali dan teracak', () {
      final peserta = _buatPeserta(4);
      final jadwal1 = buatJadwalRoundRobin(peserta, 1, random: Random(1));
      final jadwal2 = buatJadwalRoundRobin(peserta, 1, random: Random(99));

      expect(jadwal1, hasLength(6));
      expect(jadwal2, hasLength(6));

      final pasangan = <String>{};
      for (final laga in jadwal1) {
        expect(laga.idA, isNot(equals(laga.idB)));
        final urut = [laga.idA, laga.idB]..sort();
        pasangan.add('${urut[0]}-${urut[1]}');
      }
      expect(pasangan, hasLength(6));

      final urutan1 = [for (final l in jadwal1) '${l.idA}>${l.idB}'];
      final urutan2 = [for (final l in jadwal2) '${l.idA}>${l.idB}'];
      expect(urutan1, isNot(equals(urutan2)));
    });

    test('5 peserta (ganjil) 2 leg: 20 laga, leg 2 membalik kandang/tandang', () {
      final peserta = _buatPeserta(5);
      final jadwal = buatJadwalRoundRobin(peserta, 2, random: Random(7));

      // 5 * 4 / 2 = 10 laga per leg -> 20 laga untuk 2 leg.
      expect(jadwal, hasLength(20));

      final leg1 = {
        for (final l in jadwal.where((m) => m.babak == 1)) '${l.idA}>${l.idB}',
      };
      final leg2 = {
        for (final l in jadwal.where((m) => m.babak == 2)) '${l.idA}>${l.idB}',
      };

      expect(leg1, hasLength(10));
      expect(leg2, hasLength(10));
      for (final kunci in leg1) {
        final bagian = kunci.split('>');
        expect(leg2.contains('${bagian[1]}>${bagian[0]}'), isTrue);
      }
    });
  });

  group('buatBracketSingleElimination acak', () {
    test('4 peserta: 2 semifinal + juara 3 + final dengan peserta unik & teracak', () {
      final peserta = _buatPeserta(4);
      final b1 = buatBracketSingleElimination(peserta, random: Random(1));
      final b2 = buatBracketSingleElimination(peserta, random: Random(42));

      expect(b1, hasLength(4));
      final semi1 = b1.where((m) => m.babak == 1).toList();
      final semi2 = b2.where((m) => m.babak == 1).toList();
      expect(semi1, hasLength(2));
      expect(b1.where((m) => m.babak == 2), hasLength(1));
      expect(b1.where((m) => m.babak == 3), hasLength(1));

      final idDiBabak1 = {
        for (final m in semi1) ...[m.idA, m.idB],
      };
      expect(idDiBabak1, equals({'p1', 'p2', 'p3', 'p4'}));

      final susunan1 = [for (final m in semi1) '${m.idA}-${m.idB}'];
      final susunan2 = [for (final m in semi2) '${m.idA}-${m.idB}'];
      expect(susunan1, isNot(equals(susunan2)));
    });

    test('5 peserta: 3 BYE langsung lolos ke babak 2 dan tanpa BYE vs BYE', () {
      final peserta = _buatPeserta(5);
      final bracket = buatBracketSingleElimination(peserta, random: Random(5));

      // Bracket 8: 4 (QF) + 2 (SF) + 1 (Juara 3) + 1 (Final) = 8 laga
      expect(bracket, hasLength(8));

      final babak1 = bracket.where((m) => m.babak == 1).toList();
      final babak2 = bracket.where((m) => m.babak == 2).toList();
      expect(babak1, hasLength(4));

      var jumlahBye = 0;
      for (final m in babak1) {
        expect(m.idA == idPesertaBye && m.idB == idPesertaBye, isFalse);
        if (m.adaBye) jumlahBye++;
      }
      expect(jumlahBye, equals(3));

      final lolosOtomatis = [
        for (final m in babak2) ...[
          if (m.idA.isNotEmpty) m.idA,
          if (m.idB.isNotEmpty) m.idB,
        ],
      ];
      expect(lolosOtomatis, hasLength(3));
    });
  });
}

