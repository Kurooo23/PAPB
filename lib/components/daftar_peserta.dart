import 'package:flutter/material.dart';
import 'package:rivnet/models/peserta.dart';
import 'package:rivnet/themes/color.dart';

class DaftarPesertaCard extends StatelessWidget {
  final List<Peserta> peserta;

  const DaftarPesertaCard({super.key, required this.peserta});

  @override
  Widget build(BuildContext context) {
    if (peserta.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.kNavBar,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Belum ada peserta.',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < peserta.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.kNavBar,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                // Kotak nomor ungu
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.kPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Nama Peserta
                Expanded(
                  child: Text(
                    peserta[i].nama,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: peserta[i].isWo
                          ? TextDecoration.lineThrough
                          : null,
                      color: peserta[i].isWo ? Colors.white38 : Colors.white,
                    ),
                  ),
                ),

                // Ikon Perisai di kanan (atau label WO)
                if (peserta[i].isWo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(50),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'WO',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.shield_outlined,
                    color: Colors.white38,
                    size: 22,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
