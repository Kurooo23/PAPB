import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rivnet/database/database_helper.dart';

class FormTurnamenController extends GetxController {
  final namaController = TextEditingController();

  final formatList = ['Single Elimination', 'Liga'];
  final legList = [1, 2];
  final kuotaList = [4, 8, 16];

  var format = 'Single Elimination'.obs;
  var leg = 1.obs;
  var kuota = 4.obs;

  late List<TextEditingController> pesertaControllers;

  @override
  void onInit() {
    pesertaControllers =
        List.generate(kuota.value, (_) => TextEditingController());
    super.onInit();
  }

  @override
  void onClose() {
    namaController.dispose();
    for (final c in pesertaControllers) {
      c.dispose();
    }
    super.onClose();
  }

  void ubahKuota(int kuotaBaru) {
    final dibuang = <TextEditingController>[];

    while (pesertaControllers.length < kuotaBaru) {
      pesertaControllers.add(TextEditingController());
    }
    while (pesertaControllers.length > kuotaBaru) {
      dibuang.add(pesertaControllers.removeLast());
    }
    kuota.value = kuotaBaru;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in dibuang) {
        c.dispose();
      }
    });
  }

  Future<void> simpan() async {
    final nama = namaController.text.trim();
    if (nama.isEmpty) {
      Get.snackbar('Peringatan', 'Nama turnamen harus diisi');
      return;
    }

    final peserta = [
      for (var i = 0; i < pesertaControllers.length; i++)
        pesertaControllers[i].text.trim().isEmpty
            ? 'Peserta ${i + 1}'
            : pesertaControllers[i].text.trim(),
    ];

    await DatabaseHelper.instance.insertTournament(
      nama: nama,
      format: format.value,
      leg: leg.value,
      kuota: kuota.value,
      peserta: peserta,
    );

    Get.back(result: true);
  }
}
