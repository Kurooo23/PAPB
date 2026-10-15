import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/turnamen_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';
import '../widgets/common_widgets.dart';

const _statusOptions = ['Akan Datang', 'Berlangsung', 'Selesai'];

const _gameTypes = [
  'Sepak Bola / Futsal',
  'Bulu Tangkis',
  'Bola Basket',
  'Bola Voli',
  'Catur',
  'E-Sports',
  'Lainnya (Custom)',
];

class EditTurnamenScreen extends StatefulWidget {
  const EditTurnamenScreen({super.key, required this.turnamen});

  final TurnamenModel turnamen;

  @override
  State<EditTurnamenScreen> createState() => _EditTurnamenScreenState();
}

class _EditTurnamenScreenState extends State<EditTurnamenScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _namaController = TextEditingController(text: widget.turnamen.namaTurnamen);
  late final _deskripsiController = TextEditingController(text: widget.turnamen.deskripsi ?? '');
  late String _tipeGame = widget.turnamen.tipeGame;
  late String _status = widget.turnamen.status;
  bool _isLoading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _updateTurnamen() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final isPrivate = widget.turnamen.isPrivate;
    try {
      final deskripsi = _deskripsiController.text.trim();
      final updated = widget.turnamen.copyWith(
        namaTurnamen: _namaController.text.trim(),
        deskripsi: deskripsi.isEmpty ? null : deskripsi,
        tipeGame: _tipeGame,
        status: _status,
      );

      if (isPrivate) {
        await LocalTournamentService.instance.updateTurnamen(updated);
      } else {
        await ApiService.instance.updateTurnamen(updated);
      }

      if (!mounted) return;
      context.showSnack(
        isPrivate
            ? 'Turnamen privat berhasil diperbarui di database lokal HP!'
            : 'Turnamen publik berhasil diperbarui di server!',
        color: AppColors.success,
      );
      // GetX: kembali + bawa hasil
      Get.back(result: true);
    } catch (e) {
      if (mounted) context.showSnack('Gagal memperbarui turnamen: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery: padding 5% lebar layar, isi maks 900 dp, dan di layar
    // >= 600 dp section dipasang berdampingan 1:1.
    final layout = PageLayout.of(context, maxWidth: 900, paddingRatio: 0.05);
    final sectionGap = layout.isShort ? 14.0 : 20.0;

    final infoSection = Section(
      title: 'Informasi Turnamen',
      child: Column(
        children: [
          AppTextField(
            controller: _namaController,
            label: 'Nama Turnamen',
            hint: 'Masukkan nama turnamen',
            icon: Icons.emoji_events_rounded,
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Nama turnamen wajib diisi' : null,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _deskripsiController,
            label: 'Deskripsi (Opsional)',
            hint: 'Tuliskan catatan atau aturan turnamen...',
            icon: Icons.notes_rounded,
            maxLines: 3,
          ),
        ],
      ),
    );

    final statusOptions = [
      for (final status in _statusOptions)
        SelectBox(
          label: status,
          selected: _status == status,
          color: statusColor(status),
          background: AppColors.bgDarkSecondary,
          onTap: () => setState(() => _status = status),
        ),
    ];

    final settingSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Section(
          title: 'Tipe Game / Cabang Olahraga',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                // Tipe game di luar daftar ditampilkan sebagai "Lainnya (Custom)".
                value: _gameTypes.contains(_tipeGame) ? _tipeGame : _gameTypes.last,
                dropdownColor: AppColors.bgDarkSecondary,
                isExpanded: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                items: [
                  for (final type in _gameTypes)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _tipeGame = val);
                },
              ),
            ),
          ),
        ),
        SizedBox(height: sectionGap),
        Section(
          title: 'Status Turnamen',
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ubah Status Turnamen:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                // Normal: 3 status dibagi rata 1:1:1. Layar < 340 dp: ditumpuk.
                if (layout.screen.width < 340)
                  for (final option in statusOptions)
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: option)
                else
                  ResponsiveGrid(columns: 3, gap: 8, children: statusOptions),
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Edit Turnamen')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: layout.sidePadding, vertical: sectionGap),
            children: [
              // Layar lebar: Informasi | Pengaturan (1:1). HP: ditumpuk.
              ResponsivePair(
                isWide: layout.isWide,
                gap: layout.gap,
                verticalGap: sectionGap,
                left: infoSection,
                right: settingSection,
              ),
              SizedBox(height: sectionGap + 8),
              LoadingButton(
                label: 'Simpan Perubahan',
                isLoading: _isLoading,
                onPressed: _updateTurnamen,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
