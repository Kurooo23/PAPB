import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/pertandingan_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';

/// Ukuran dialog dari MediaQuery: jarak ke tepi 5% lebar / 4% tinggi layar,
/// lebar maks 460 dp, angka skor 8% lebar layar (24–36).
class _SkorSize {
  const _SkorSize._({
    required this.insetHorizontal,
    required this.insetVertical,
    required this.padding,
    required this.scoreFontSize,
    required this.stackParticipants,
  });

  factory _SkorSize.of(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return _SkorSize._(
      insetHorizontal: screen.width * 0.05,
      insetVertical: screen.height * 0.04,
      padding: (screen.width * 0.05).clamp(14.0, 22.0),
      scoreFontSize: (screen.width * 0.08).clamp(24.0, 36.0),
      // Layar sangat sempit: kartu skor ditumpuk atas-bawah.
      stackParticipants: screen.width < 330,
    );
  }

  final double insetHorizontal;
  final double insetVertical;
  final double padding;
  final double scoreFontSize;
  final bool stackParticipants;
}

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
  final TextEditingController _penaltyScore1Controller = TextEditingController();
  final TextEditingController _penaltyScore2Controller = TextEditingController();

  final ApiService _apiService = ApiService.instance;
  final LocalTournamentService _localService = LocalTournamentService.instance;

  bool get _needsPenaltyShootout {
    if (!widget.isKnockout || _status != 'Selesai') return false;
    if (!widget.isTwoLeg) return _score1 == _score2;
    if (!widget.match.babak.startsWith('Leg 2 - ')) return false;
    final legScoreIsTied = _score1 == _score2;
    final aggregateIsTied = widget.previousLegScore1 != null &&
        widget.previousLegScore2 != null &&
        _score1 + widget.previousLegScore1! == _score2 + widget.previousLegScore2!;
    return legScoreIsTied || aggregateIsTied;
  }

  @override
  void initState() {
    super.initState();
    _score1 = widget.match.skorPeserta1;
    _score2 = widget.match.skorPeserta2;
    _status = widget.match.status == 'Belum Mulai' ? 'Berlangsung' : widget.match.status;
    _penaltyScore1Controller.text = widget.match.skorPenaltiPeserta1?.toString() ?? '';
    _penaltyScore2Controller.text = widget.match.skorPenaltiPeserta2?.toString() ?? '';
  }

  @override
  void dispose() {
    _penaltyScore1Controller.dispose();
    _penaltyScore2Controller.dispose();
    super.dispose();
  }

  Future<void> _saveScore() async {
    final penaltyScore1 =
        _needsPenaltyShootout ? int.tryParse(_penaltyScore1Controller.text) : null;
    final penaltyScore2 =
        _needsPenaltyShootout ? int.tryParse(_penaltyScore2Controller.text) : null;
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
            content: Text(widget.isPrivate
                ? 'Hasil skor berhasil disimpan ke database lokal HP!'
                : 'Hasil skor berhasil disimpan ke backend server!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan skor: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _SkorSize.of(context);
    final p1Name = widget.match.displayNama1 ?? 'TBD';
    final p2Name = widget.match.displayNama2 ?? 'TBD';

    final card1 = _ScoreCard(
      name: p1Name,
      score: _score1,
      scoreFontSize: size.scoreFontSize,
      isLeading: _score1 > _score2 && _status == 'Selesai',
      onIncrement: () => setState(() => _score1++),
      onDecrement: () {
        if (_score1 > 0) setState(() => _score1--);
      },
    );
    final card2 = _ScoreCard(
      name: p2Name,
      score: _score2,
      scoreFontSize: size.scoreFontSize,
      isLeading: _score2 > _score1 && _status == 'Selesai',
      onIncrement: () => setState(() => _score2++),
      onDecrement: () {
        if (_score2 > 0) setState(() => _score2--);
      },
    );

    return Dialog(
      backgroundColor: AppColors.bgDarkSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.insetHorizontal,
        vertical: size.insetVertical,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        // Bisa discroll supaya tidak overflow saat keyboard penalti muncul.
        child: SingleChildScrollView(
          padding: EdgeInsets.all(size.padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogHeader(
                title: widget.match.babak,
                onClose: () => Navigator.pop(context),
              ),
              const Divider(color: Colors.white12, height: 24),

              // Skor: dua kartu dibagi rata 1:1 dengan "VS" di tengah.
              if (size.stackParticipants)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [card1, const _VsLabel(vertical: true), card2],
                )
              else
                Row(
                  children: [
                    Expanded(child: card1),
                    const _VsLabel(vertical: false),
                    Expanded(child: card2),
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
                  Expanded(
                    child: _StatusOption(
                      label: 'Berlangsung',
                      selected: _status == 'Berlangsung',
                      onTap: () => setState(() => _status = 'Berlangsung'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatusOption(
                      label: 'Selesai',
                      selected: _status == 'Selesai',
                      onTap: () => setState(() => _status = 'Selesai'),
                    ),
                  ),
                ],
              ),

              if (_needsPenaltyShootout) ...[
                const SizedBox(height: 16),
                Text(
                  widget.isTwoLeg
                      ? 'Skor Leg 2 atau agregat seri — skor adu penalti'
                      : 'Skor seri — skor adu penalti',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PenaltyField(controller: _penaltyScore1Controller, label: p1Name),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '–',
                        style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: _PenaltyField(controller: _penaltyScore2Controller, label: p2Name),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              _SaveScoreButton(isSaving: _isSaving, onPressed: _saveScore),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== WIDGET STATELESS =====================

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 18.0;

    return Row(
      children: [
        const Icon(Icons.sports_score_rounded, color: AppColors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Tutup',
          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _VsLabel extends StatelessWidget {
  const _VsLabel({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 10),
      child: const Text(
        'VS',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.name,
    required this.score,
    required this.scoreFontSize,
    required this.isLeading,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String name;
  final int score;
  final double scoreFontSize;
  final bool isLeading;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
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
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isLeading ? AppColors.success : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$score',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: scoreFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Tombol kurang & tambah dibagi rata 1:1
          Row(
            children: [
              Expanded(
                child: IconButton(
                  onPressed: onDecrement,
                  tooltip: 'Kurangi skor',
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.textMuted),
                  iconSize: 26,
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: onIncrement,
                  tooltip: 'Tambah skor',
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary),
                  iconSize: 26,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.primaryLight : Colors.white12),
          ),
          child: Text(
            label,
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

class _PenaltyField extends StatelessWidget {
  const _PenaltyField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
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
}

class _SaveScoreButton extends StatelessWidget {
  const _SaveScoreButton({required this.isSaving, required this.onPressed});

  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isSaving ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Text(
              'Simpan Hasil',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
    );
  }
}