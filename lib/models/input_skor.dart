import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rivnet/database/database_helper.dart';
import 'package:rivnet/models/match.dart';
import 'package:rivnet/models/peserta.dart';
import 'package:rivnet/themes/color.dart';

class InputSkor {
  /// Menampilkan dialog modal untuk input skor pertandingan
  static Future<bool?> showDialogInput({
    required Pertandingan match,
    required List<Peserta> peserta,
  }) {
    final petaNama = Peserta.petaNama(peserta);
    final nama1 = match.idPeserta1 == null
        ? 'TBD'
        : (petaNama[match.idPeserta1] ?? 'TBD');
    final nama2 = match.idPeserta2 == null
        ? 'TBD'
        : (petaNama[match.idPeserta2] ?? 'TBD');

    final skor1Controller = TextEditingController(text: '${match.skor1}');
    final skor2Controller = TextEditingController(text: '${match.skor2}');
    final penalti1Controller = TextEditingController(
      text: match.penalti1 != null ? '${match.penalti1}' : '',
    );
    final penalti2Controller = TextEditingController(
      text: match.penalti2 != null ? '${match.penalti2}' : '',
    );

    bool butuhPenalti = match.skor1 == match.skor2;

    return Get.dialog<bool>(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.kNavBar,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Input Skor - ${match.babak}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Input Skor Tim 1 vs Tim 2
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              nama1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: skor1Controller,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (val) {
                                final s1 =
                                    int.tryParse(skor1Controller.text) ?? 0;
                                final s2 =
                                    int.tryParse(skor2Controller.text) ?? 0;
                                setState(() {
                                  butuhPenalti = (s1 == s2);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.kTeal,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              nama2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: skor2Controller,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (val) {
                                final s1 =
                                    int.tryParse(skor1Controller.text) ?? 0;
                                final s2 =
                                    int.tryParse(skor2Controller.text) ?? 0;
                                setState(() {
                                  butuhPenalti = (s1 == s2);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Input Penalti jika skor imbang
                  if (butuhPenalti) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Adu Penalti (Skor Imbang)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.kTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: penalti1Controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Penalti 1',
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: penalti2Controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Penalti 2',
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final s1 = int.tryParse(skor1Controller.text) ?? 0;
                  final s2 = int.tryParse(skor2Controller.text) ?? 0;
                  final p1 = int.tryParse(penalti1Controller.text);
                  final p2 = int.tryParse(penalti2Controller.text);

                  await DatabaseHelper.instance.updateMatchScore(
                    match: match,
                    skor1: s1,
                    skor2: s2,
                    penalti1: p1,
                    penalti2: p2,
                  );

                  Get.back(result: true);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }
}
