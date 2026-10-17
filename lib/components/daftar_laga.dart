import 'package:flutter/material.dart';
import 'package:rivnet/models/match.dart';
import 'package:rivnet/models/peserta.dart';
import 'package:rivnet/themes/color.dart';

class DaftarLagaCard extends StatelessWidget {
  final List<Pertandingan> matches;
  final List<Peserta> peserta;
  final ValueChanged<Pertandingan>? onTapMatch;

  const DaftarLagaCard({
    super.key,
    required this.matches,
    required this.peserta,
    this.onTapMatch,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final petaNama = Peserta.petaNama(peserta);

    // Urutkan: Perebutan Juara 3 tampil sebelum Final
    final sorted = [...matches]..sort((a, b) {
      int prio(String b) {
        if (b.contains('Perebutan Juara 3')) return 2;
        if (b.contains('Final')) return 3;
        return 1;
      }
      final cmp = prio(a.babak).compareTo(prio(b.babak));
      if (cmp != 0) return cmp;
      return a.urutan.compareTo(b.urutan);
    });

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: AppColors.kNavBar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Text(
                'Pertandingan (${matches.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: size.height * 0.015),
          if (sorted.isEmpty)
            const Text(
              'Belum ada pertandingan.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            )
          else
            for (var i = 0; i < sorted.length; i++) ...[
              _itemLaga(size, sorted[i], petaNama),
              if (i < sorted.length - 1)
                const Divider(height: 16, color: Colors.white10),
            ],
        ],
      ),
    );
  }

  Widget _itemLaga(Size size, Pertandingan m, Map<String, String> petaNama) {
    final nama1 = m.idPeserta1 == null
        ? 'TBD'
        : (petaNama[m.idPeserta1] ?? 'TBD');
    final nama2 = m.idPeserta2 == null
        ? 'TBD'
        : (petaNama[m.idPeserta2] ?? 'TBD');

    final selesai = m.status == 'Selesai';
    final skorText = selesai ? '${m.skor1} - ${m.skor2}' : 'VS';

    return InkWell(
      onTap: onTapMatch == null ? null : () => onTapMatch!(m),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.babak,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.kTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    nama1,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selesai ? AppColors.kTeal : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    skorText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selesai ? Colors.black : Colors.white70,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    nama2,
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
