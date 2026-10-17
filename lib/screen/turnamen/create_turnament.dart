import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:rivnet/controllers/form_turnamen_controller.dart';
import 'package:rivnet/themes/color.dart';

class CreateTurnamentScreen extends GetView<FormTurnamenController> {
  const CreateTurnamentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = size.width * 0.04;
    final jarak = size.height * 0.02;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Expanded(
              flex: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Get.back(),
                    ),
                    SizedBox(width: size.width * 0.02),
                    Text(
                      'Buat Turnamen',
                      style: TextStyle(
                        fontSize: size.width * 0.05,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FORM
            Expanded(
              flex: 8,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller.namaController,
                      decoration: InputDecoration(
                        labelText: 'Nama Turnamen',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(height: jarak),

                    // Format bagan
                    _label('Format Bagan Turnamen'),
                    Obx(() => Row(
                      children: controller.formatList.map((f) {
                        return Expanded(
                          flex: 1,
                          child: _pilihan(
                            f,
                            controller.format.value == f,
                            () => controller.format.value = f,
                            size,
                          ),
                        );
                      }).toList(),
                    )),
                    SizedBox(height: jarak),

                    // Jumlah leg
                    _label('Jumlah Leg'),
                    Obx(() => Row(
                      children: controller.legList.map((l) {
                        return Expanded(
                          flex: 1,
                          child: _pilihan(
                            '$l Leg',
                            controller.leg.value == l,
                            () => controller.leg.value = l,
                            size,
                          ),
                        );
                      }).toList(),
                    )),
                    SizedBox(height: jarak),

                    // Kuota peserta
                    _label('Jumlah Kuota Peserta'),
                    Obx(() => Row(
                      children: controller.kuotaList.map((k) {
                        return Expanded(
                          flex: 1,
                          child: _pilihan(
                            '$k',
                            controller.kuota.value == k,
                            () => controller.ubahKuota(k),
                            size,
                          ),
                        );
                      }).toList(),
                    )),
                    SizedBox(height: jarak),

                    // Nama peserta
                    _label('Nama Peserta'),
                    Obx(() => Column(
                      children: List.generate(controller.kuota.value, (i) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: size.height * 0.012),
                          child: TextField(
                            controller: controller.pesertaControllers[i],
                            decoration: InputDecoration(
                              labelText: 'Peserta ${i + 1}',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        );
                      }),
                    )),
                  ],
                ),
              ),
            ),

            // FOOTER
            Expanded(
              flex: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: size.height * 0.01,
                ),
                child: SizedBox.expand(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: controller.simpan,
                    child: const Text('Simpan Turnamen'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String teks) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        teks,
        style: const TextStyle(fontSize: 13, color: Colors.white70),
      ),
    );
  }

  Widget _pilihan(
      String label, bool aktif, VoidCallback onTap, Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.01),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: size.width * 0.03),
          decoration: BoxDecoration(
            color: aktif ? AppColors.kTeal : Colors.transparent,
            border: Border.all(color: aktif ? AppColors.kTeal : Colors.white54),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: aktif ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
