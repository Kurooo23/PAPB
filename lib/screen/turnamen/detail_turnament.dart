import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:rivnet/components/bracket.dart';
import 'package:rivnet/components/daftar_laga.dart';
import 'package:rivnet/components/daftar_peserta.dart';
import 'package:rivnet/controllers/detail_turnamen_controller.dart';
import 'package:rivnet/models/tournament.dart';
import 'package:rivnet/themes/color.dart';

class DetailTurnamentScreen extends GetView<DetailTurnamenController> {
  const DetailTurnamentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = size.width * 0.04;
    final t = controller.turnamen;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: size.height * 0.01,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Get.back(),
                  ),
                  SizedBox(width: size.width * 0.02),
                  Expanded(
                    child: Text(
                      t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: size.width * 0.05,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Hapus Turnamen',
                    onPressed: controller.hapus,
                  ),
                ],
              ),
            ),

            // BODY
            Expanded(
              child: Obx(() => controller.loading.value
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kartuInfo(size, t),
                          SizedBox(height: size.height * 0.02),
                          _tabBarContainer(size),
                          SizedBox(height: size.height * 0.02),
                          if (controller.tabIndex.value == 0)
                            _kotakBagan(size)
                          else if (controller.tabIndex.value == 1)
                            DaftarLagaCard(
                              matches: controller.matches.toList(),
                              peserta: controller.peserta.toList(),
                              onTapMatch: controller.inputSkor,
                            )
                          else
                            DaftarPesertaCard(
                                peserta: controller.peserta.toList()),
                          SizedBox(height: size.height * 0.025),
                        ],
                      ),
                    )),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------ BAGIAN UI --------------------------------

  Widget _tabBarContainer(Size size) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.kNavBar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _tabItem(
            0,
            Icons.account_tree_outlined,
            controller.turnamen.isKnockout ? 'Bagan' : 'Klasemen',
          ),
          _tabItem(
            1,
            Icons.sports_esports_outlined,
            'Laga (${controller.matches.length})',
          ),
          _tabItem(2, Icons.people_outline, 'Peserta'),
        ],
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label) {
    final active = controller.tabIndex.value == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => controller.tabIndex.value = index,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.kPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color: active ? Colors.white : Colors.white60,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kartuInfo(Size size, Tournament t) {
    final warnaStatus = t.status == 'Berlangsung'
        ? AppColors.kTeal
        : t.status == 'Selesai'
            ? Colors.white54
            : AppColors.kPurple;

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
              Expanded(
                child: Text(
                  t.game,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.03,
                  vertical: size.width * 0.01,
                ),
                decoration: BoxDecoration(
                  color: warnaStatus,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t.status,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: size.height * 0.015),
          _barisInfo('Format', t.format),
          _barisInfo('Jumlah Leg', '${t.jumlahLeg}'),
          _barisInfo('Kuota Peserta', '${t.kuota}'),
          _barisInfo('Tanggal Mulai', controller.tanggal(t.date)),
          if (t.deskripsi?.isNotEmpty ?? false)
            _barisInfo('Deskripsi', t.deskripsi!),
        ],
      ),
    );
  }

  Widget _kotakBagan(Size size) {
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
                controller.turnamen.isKnockout
                    ? 'Bagan Turnamen'
                    : 'Tabel Klasemen',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: size.height * 0.015),
          Bracket(
            turnamen: controller.turnamen,
            peserta: controller.peserta.toList(),
            matches: controller.matches.toList(),
            onTapMatch: controller.inputSkor,
          ),
        ],
      ),
    );
  }

  // label : nilai = 1 : 2
  Widget _barisInfo(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(nilai, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
