import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/turnamen_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';

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

  final List<String> _statusOptions = [
    'Akan Datang',
    'Berlangsung',
    'Selesai',
  ];

  final List<String> _gameTypes = [
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
        Navigator.pop(context, true);
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
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Edit Turnamen'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionTitle('Informasi Turnamen'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _namaController,
                label: 'Nama Turnamen',
                hint: 'Masukkan nama turnamen',
                icon: Icons.emoji_events_rounded,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Nama turnamen wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _deskripsiController,
                label: 'Deskripsi (Opsional)',
                hint: 'Tuliskan catatan atau aturan turnamen...',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              _buildSectionTitle('Tipe Game / Cabang Olahraga'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _gameTypes.contains(_tipeGame) ? _tipeGame : _gameTypes.last,
                    dropdownColor: AppColors.bgDarkSecondary,
                    isExpanded: true,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    items: _gameTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _tipeGame = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildSectionTitle('Status Turnamen'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ubah Status Turnamen:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: _statusOptions.map((opt) {
                        final isSelected = _status == opt;
                        Color statusColor = AppColors.primary;
                        if (opt == 'Berlangsung') statusColor = AppColors.secondary;
                        if (opt == 'Selesai') statusColor = AppColors.success;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(opt),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _status = opt),
                              selectedColor: statusColor,
                              backgroundColor: AppColors.bgDarkSecondary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _isLoading ? null : _updateTurnamen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 22),
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}
