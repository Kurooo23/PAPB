import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:rivnet/controllers/turnamen_controller.dart';
import 'package:rivnet/controllers/form_turnamen_controller.dart';
import 'package:rivnet/controllers/detail_turnamen_controller.dart';
import 'package:rivnet/screen/turnamen/create_turnament.dart';
import 'package:rivnet/screen/turnamen/detail_turnament.dart';
import 'package:rivnet/themes/color.dart';

class HomeScreen extends GetView<TurnamenController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = size.width * 0.04;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: EdgeInsets.all(padding),
              child: Obx(() => Row(
                children: controller.filters.map((f) {
                  return Expanded(flex: 1, child: _chip(f, size.width));
                }).toList(),
              )),
            ),
            Expanded(
              child: Obx(() => controller.tournaments.isEmpty
                  ? _kosong(size)
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        padding, 0, padding, size.height * 0.1,
                      ),
                      itemCount: controller.tournaments.length,
                      itemBuilder: (context, i) {
                        final t = controller.tournaments[i];
                        return Card(
                          child: ListTile(
                            title: Text(t['nama_turnamen'] as String),
                            subtitle: Text(
                              '${t['format_bracket']} • ${t['kuota']} peserta • ${t['status']}',
                            ),
                            onTap: () async {
                              final berubah = await Get.to(
                                () => const DetailTurnamentScreen(),
                                arguments: t,
                                binding: BindingsBuilder(() =>
                                    Get.lazyPut(() => DetailTurnamenController())),
                              );
                              if (berubah == true) controller.load();
                            },
                          ),
                        );
                      },
                    )),
            ),
          ],
        ),
        Positioned(
          right: padding,
          bottom: padding,
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.kPurple,
            onPressed: () async {
              final berhasil = await Get.to(
                () => const CreateTurnamentScreen(),
                binding: BindingsBuilder(() =>
                    Get.lazyPut(() => FormTurnamenController())),
              );
              if (berhasil == true) controller.load();
            },
            label: Row(
              children: const [
                Icon(Icons.add, size: 20),
                SizedBox(width: 8),
                Text('Buat Turnamen'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kosong(Size size) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined,
              size: size.width * 0.14, color: Colors.white),
          SizedBox(height: size.height * 0.02),
          const Text('Belum ada turnamen',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            "Klik 'Buat Tumamen' untuk memulai.",
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, double lebar) {
    final aktif = controller.filter.value == label;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: lebar * 0.01),
      child: GestureDetector(
        onTap: () => controller.gantiFilter(label),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: lebar * 0.02),
          decoration: BoxDecoration(
            color: aktif ? AppColors.kTeal : Colors.transparent,
            border: Border.all(color: aktif ? AppColors.kTeal : Colors.white54),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (aktif) const Icon(Icons.check, size: 14, color: Colors.black),
              if (aktif) const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: aktif ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
