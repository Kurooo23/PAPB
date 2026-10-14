import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/pertandingan_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';

class InputSkorDialog extends StatefulWidget {
  final PertandinganModel match;
  final bool isPrivate;
  final bool isKnockout;
  final bool isTwoLeg;
  final int? previousLegScore1;
  final int? previousLegScore2;
  final VoidCallback onSaved;

  const InputSkorDialog({
    super.key,
    required this.match,
    this.isPrivate = false,
    this.isKnockout = false,
    this.isTwoLeg = false,
    this.previousLegScore1,
    this.previousLegScore2,
    required this.onSaved,
  });

  @override
  State<InputSkorDialog> createState() => _InputSkorDialogState();
}

class _InputSkorDialogState extends State<InputSkorDialog> {
  late int _score1;
  late int _score2;
  late String _status;
  bool _isSaving = false;
  final TextEditingController _penaltyScore1Controller =
      TextEditingController();
  final TextEditingController _penaltyScore2Controller =
      TextEditingController();

  final ApiService _apiService = ApiService.instance;
  final LocalTournamentService _localService = LocalTournamentService.instance;

  bool get _needsPenaltyShootout {
    if (!widget.isKnockout || _status != 'Selesai') return false;
    if (!widget.isTwoLeg) return _score1 == _score2;
    if (!widget.match.babak.startsWith('Leg 2 - ')) return false;
    final legScoreIsTied = _score1 == _score2;
    final aggregateIsTied =
        widget.previousLegScore1 != null &&
        widget.previousLegScore2 != null &&
        _score1 + widget.previousLegScore1! ==
            _score2 + widget.previousLegScore2!;
    return legScoreIsTied || aggregateIsTied;
  }

  @override
  void initState() {
    super.initState();
    _score1 = widget.match.skorPeserta1;
    _score2 = widget.match.skorPeserta2;
    _status = widget.match.status == 'Belum Mulai'
        ? 'Berlangsung'
        : widget.match.status;
    _penaltyScore1Controller.text =
        widget.match.skorPenaltiPeserta1?.toString() ?? '';
    _penaltyScore2Controller.text =
        widget.match.skorPenaltiPeserta2?.toString() ?? '';
  }

  @override
  void dispose() {
    _penaltyScore1Controller.dispose();
    _penaltyScore2Controller.dispose();
    super.dispose();
  }

  Future<void> _saveScore() async {
    final penaltyScore1 = _needsPenaltyShootout
        ? int.tryParse(_penaltyScore1Controller.text)
        : null;
    final penaltyScore2 = _needsPenaltyShootout
        ? int.tryParse(_penaltyScore2Controller.text)
        : null;
    setState(() => _isSaving = true);
    try {
      if (widget.isPrivate) {
        await _localService.updateHasilPertandingan(
          idPertandingan: widget.match.idPertandingan,
          skor1: _score1,
          skor2: _score2,
          status: _status,
          skorPenalti1: penaltyScore1,
          skorPenalti2: penaltyScore2,
        );
      } else {
        await _apiService.updateHasilPertandingan(
          idPertandingan: widget.match.idPertandingan,
          skor1: _score1,
          skor2: _score2,
          status: _status,
          skorPenalti1: penaltyScore1,
          skorPenalti2: penaltyScore2,
        );
      }
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isPrivate
                  ? 'Hasil skor berhasil disimpan ke database lokal HP!'
                  : 'Hasil skor berhasil disimpan ke backend server!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan skor: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p1Name = widget.match.displayNama1 ?? 'TBD';
    final p2Name = widget.match.displayNama2 ?? 'TBD';

    return Dialog(
      backgroundColor: AppColors.bgDarkSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sports_score_rounded,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.match.babak,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildParticipantScoreColumn(
                    name: p1Name,
                    score: _score1,
                    isLeading: _score1 > _score2 && _status == 'Selesai',
                    onIncrement: () => setState(() => _score1++),
                    onDecrement: () {
                      if (_score1 > 0) setState(() => _score1--);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildParticipantScoreColumn(
                    name: p2Name,
                    score: _score2,
                    isLeading: _score2 > _score1 && _status == 'Selesai',
                    onIncrement: () => setState(() => _score2++),
                    onDecrement: () {
                      if (_score2 > 0) setState(() => _score2--);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Status Pertandingan',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusChip('Berlangsung'),
                const SizedBox(width: 10),
                _buildStatusChip('Selesai'),
              ],
            ),
            if (_needsPenaltyShootout) ...[
              const SizedBox(height: 16),
              Text(
                widget.isTwoLeg
                    ? 'Skor Leg 2 atau agregat seri — skor adu penalti'
                    : 'Skor seri — skor adu penalti',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPenaltyField(
                      controller: _penaltyScore1Controller,
                      label: p1Name,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '–',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildPenaltyField(
                      controller: _penaltyScore2Controller,
                      label: p2Name,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveScore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Simpan Hasil',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPenaltyField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintText: 'Penalti',
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    final isSelected = _status == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primaryLight : Colors.white12,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantScoreColumn({
    required String name,
    required int score,
    required bool isLeading,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLeading ? AppColors.success : Colors.white10,
          width: isLeading ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: isLeading ? AppColors.success : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            '$score',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onDecrement,
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: AppColors.textMuted,
                ),
                iconSize: 26,
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.secondary,
                ),
                iconSize: 26,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
