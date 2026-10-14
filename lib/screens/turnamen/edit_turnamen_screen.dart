import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/turnamen_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';

/// Layout form edit dari MediaQuery: padding 5% lebar layar, isi maks 900 dp,
/// dan di layar >= 600 dp section dipasang berdampingan 1:1.
class _EditLayout {
  const _EditLayout._({
    required this.sidePadding,
    required this.isWide,
    required this.gap,
    required this.sectionGap,
    required this.isNarrow,
  });

  factory _EditLayout.of(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    const maxContentWidth = 900.0;

    final contentWidth =
        screen.width > maxContentWidth ? maxContentWidth : screen.width;
    final extraSpace =
        screen.width > maxContentWidth ? (screen.width - maxContentWidth) / 2 : 0.0;

    return _EditLayout._(
      sidePadding: extraSpace + contentWidth * 0.05,
      isWide: contentWidth >= 600,
      gap: contentWidth * 0.03,
      sectionGap: screen.height < 640 ? 14 : 20,
      isNarrow: screen.width < 340,
    );
  }

  final double sidePadding;
  final bool isWide;
  final double gap;
  final double sectionGap;
  final bool isNarrow;
}

class EditTurnamenScreen extends StatefulWidget {
  final TurnamenModel turnamen;

  const EditTurnamenScreen({super.key, required this.turnamen});

  @override
  State<EditTurnamenScreen> createState() => _EditTurnamenScreenState();
}

class _EditTurnamenScreenState extends State<EditTurnamenScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _deskripsiController;
  late String _tipeGame;
  late String _status;
  bool _isLoading = false;

  final ApiService _apiService = ApiService.instance;
  final LocalTournamentService _localService = LocalTournamentService.instance;

  static const List<String> _statusOptions = ['Akan Datang', 'Berlangsung', 'Selesai'];

  static const List<String> _gameTypes = [
    'Sepak Bola / Futsal',
    'Bulu Tangkis',
    'Bola Basket',
    'Bola Voli',
    'Catur',
    'E-Sports',
    'Lainnya (Custom)',
  ];

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.turnamen.namaTurnamen);
    _deskripsiController = TextEditingController(text: widget.turnamen.deskripsi ?? '');
    _tipeGame = widget.turnamen.tipeGame;
    _status = widget.turnamen.status;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _updateTurnamen() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updated = widget.turnamen.copyWith(
        namaTurnamen: _namaController.text.trim(),
        deskripsi: _deskripsiController.text.trim().isEmpty
            ? null
            : _deskripsiController.text.trim(),
        tipeGame: _tipeGame,
        status: _status,
      );

      if (widget.turnamen.isPrivate) {
        await _localService.updateTurnamen(updated);
      } else {
        await _apiService.updateTurnamen(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.turnamen.isPrivate
                ? 'Turnamen privat berhasil diperbarui di database lokal HP!'
                : 'Turnamen publik berhasil diperbarui di server!'),
            backgroundColor: AppColors.success,
          ),
        );
        // GetX: kembali + bawa hasil
        Get.back(result: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui turnamen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = _EditLayout.of(context);

    final infoSection = _EditSection(
      title: 'Informasi Turnamen',
      child: Column(
        children: [
          _EditTextField(
            controller: _namaController,
            label: 'Nama Turnamen',
            hint: 'Masukkan nama turnamen',
            icon: Icons.emoji_events_rounded,
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Nama turnamen wajib diisi' : null,
          ),
          const SizedBox(height: 14),
          _EditTextField(
            controller: _deskripsiController,
            label: 'Deskripsi (Opsional)',
            hint: 'Tuliskan catatan atau aturan turnamen...',
            icon: Icons.notes_rounded,
            maxLines: 3,
          ),
        ],
      ),
    );

    final settingSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditSection(
          title: 'Tipe Game / Cabang Olahraga',
          child: _GameTypeDropdown(
            options: _gameTypes,
            value: _gameTypes.contains(_tipeGame) ? _tipeGame : _gameTypes.last,
            onChanged: (val) => setState(() => _tipeGame = val),
          ),
        ),
        SizedBox(height: layout.sectionGap),
        _EditSection(
          title: 'Status Turnamen',
          child: _StatusSelector(
            options: _statusOptions,
            selected: _status,
            stackVertically: layout.isNarrow,
            onSelected: (val) => setState(() => _status = val),
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
            padding: EdgeInsets.symmetric(
              horizontal: layout.sidePadding,
              vertical: layout.sectionGap,
            ),
            children: [
              // Layar lebar: Informasi | Pengaturan (1:1). HP: ditumpuk.
              if (layout.isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: infoSection),
                    SizedBox(width: layout.gap),
                    Expanded(child: settingSection),
                  ],
                )
              else ...[
                infoSection,
                SizedBox(height: layout.sectionGap),
                settingSection,
              ],
              SizedBox(height: layout.sectionGap + 8),
              _SaveButton(isLoading: _isLoading, onPressed: _updateTurnamen),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== WIDGET STATELESS =====================

class _EditSection extends StatelessWidget {
  const _EditSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.sizeOf(context).width < 360 ? 15.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _EditTextField extends StatelessWidget {
  const _EditTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 22),
        filled: true,
        fillColor: AppColors.bgCard,
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _GameTypeDropdown extends StatelessWidget {
  const _GameTypeDropdown({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: AppColors.bgDarkSecondary,
          isExpanded: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          items: [
            for (final type in options)
              DropdownMenuItem<String>(
                value: type,
                child: Text(type, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.options,
    required this.selected,
    required this.stackVertically,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final bool stackVertically;
  final ValueChanged<String> onSelected;

  static Color colorOf(String status) {
    if (status == 'Berlangsung') return AppColors.secondary;
    if (status == 'Selesai') return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final opt in options)
        _StatusOption(
          label: opt,
          color: colorOf(opt),
          selected: selected == opt,
          onTap: () => onSelected(opt),
        ),
    ];

    return Container(
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
          // Normal: 3 status dibagi rata 1:1:1 dalam Row.
          // Layar < 340 dp: ditumpuk supaya label tidak terpotong.
          if (stackVertically)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final chip in chips)
                  Padding(padding: const EdgeInsets.only(bottom: 6), child: chip),
              ],
            )
          else
            Row(
              children: [
                for (int i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: chips[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : AppColors.bgDarkSecondary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
          : const Text(
              'Simpan Perubahan',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}