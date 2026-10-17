import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rivnet/database/database_helper.dart';
import 'package:rivnet/models/input_skor.dart';
import 'package:rivnet/models/match.dart';
import 'package:rivnet/models/peserta.dart';
import 'package:rivnet/models/tournament.dart';

class DetailTurnamenController extends GetxController {
  late Tournament turnamen;
  var peserta = <Peserta>[].obs;
  var matches = <Pertandingan>[].obs;
  var loading = true.obs;
  var tabIndex = 0.obs;

  @override
  void onInit() {
    turnamen = Tournament.fromMap(
      Get.arguments as Map<String, Object?>,
      const [],
    );
    load();
    super.onInit();
  }

  Future<void> load() async {
    final db = DatabaseHelper.instance;
    final pesertaRows = await db.getPeserta(turnamen.id!);
    final matchRows = await db.getMatches(turnamen.id!);

    peserta.value = [for (final r in pesertaRows) Peserta.fromMap(r)];
    matches.value = [for (final r in matchRows) Pertandingan.fromMap(r)];
    loading.value = false;
  }

  Future<void> inputSkor(Pertandingan match) async {
    final updated = await InputSkor.showDialogInput(
      match: match,
      peserta: peserta.toList(),
    );
    if (updated == true) load();
  }

  Future<void> hapus() async {
    final yakin = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Hapus turnamen?'),
        content: const Text(
          'Semua peserta dan pertandingan di turnamen ini ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (yakin != true) return;

    await DatabaseHelper.instance.deleteTournament(turnamen.id!);
    Get.back(result: true);
  }

  String tanggal(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}
