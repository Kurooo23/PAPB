import 'package:flutter/material.dart';

import 'package:rivnet/models/turnamen.dart';
import 'package:rivnet/routes/app_routes.dart';
import 'package:rivnet/themes/color.dart';
import 'package:rivnet/widgets/logo_klub.dart';

Color tentukanWarnaStatus(String statusTurnamen) {
  switch (statusTurnamen) {
    case 'Akan Datang':
      return AppColors.primary;
    case 'Berlangsung':
      return AppColors.accent;
    default:
      return Colors.grey;
  }
}
      
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final warna = tentukanWarnaStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warna.withValues(alpha: 0.6)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: warna,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class TurnamenCard extends StatelessWidget {
  final Turnamen turnamen;
  const TurnamenCard({super.key, required this.turnamen});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Named Route pakai Navigator.pushNamed (bukan Get.toNamed)
        onTap: () => Navigator.pushNamed(
          context,
          Routes.detailTurnament,
          arguments: turnamen.id,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedBuilder(
            animation: turnamen, // Turnamen extends ChangeNotifier
            builder: (context, child) {
              final jumlahPertandinganSelesai = turnamen.pertandingan
                  .where((pertandingan) => pertandingan.selesai)
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          turnamen.nama,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StatusChip(turnamen.status),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 16,
                          color: Colors.white54,
                        ),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              '${turnamen.format} • ${turnamen.peserta.length} peserta • '
                              '$jumlahPertandinganSelesai'
                              '/${turnamen.pertandingan.length} match selesai',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (turnamen.peserta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          for (final peserta in turnamen.peserta.take(5))
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: LogoKlub(peserta.nama, ukuran: 20),
                            ),
                          if (turnamen.peserta.length > 5)
                            Text(
                              '+${turnamen.peserta.length - 5}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
