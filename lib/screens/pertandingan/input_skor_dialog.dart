import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/pertandingan_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';
import '../widgets/common_widgets.dart';

class InputSkorDialog extends StatefulWidget {
  final PertandinganModel match;
  final bool isPrivate;
  final bool isKnockout;
  final bool isTwoLeg;
  final int? previousLegScore1;
  final int? previousLegScore2;

  /// Basket: tiap game diisi per kuarter (Q1–Q4 + Overtime).
  final bool isBasket;

  /// Best of: 1 = satu game, 3/5/7 = seri. Skor yang disimpan untuk seri
  /// adalah jumlah game yang dimenangkan.
  final int bestOf;

  /// Catur (seri BO): game 1..N-1 boleh remis (menang 1, remis ½ poin).
  /// Game ke-N jadi penentu tanpa remis, hanya muncul kalau poin sama.
  final bool isChess;
  final VoidCallback onSaved;

  const InputSkorDialog({
    super.key,
    required this.match,
    this.isPrivate = false,
    this.isKnockout = false,
    this.isTwoLeg = false,
    this.previousLegScore1,
    this.previousLegScore2,
    this.isBasket = false,
    this.bestOf = 1,
    this.isChess = false,
    required this.onSaved,
  });

  @override
  State<InputSkorDialog> createState() => _InputSkorDialogState();
}

class _InputSkorDialogState extends State<InputSkorDialog> {
  late int _score1 = widget.match.skorPeserta1;
  late int _score2 = widget.match.skorPeserta2;
  late String _status =
      widget.match.status == 'Belum Mulai' ? 'Berlangsung' : widget.match.status;
  bool _isSaving = false;
  late final _penalty1Controller =
      TextEditingController(text: widget.match.skorPenaltiPeserta1?.toString() ?? '');
  late final _penalty2Controller =
      TextEditingController(text: widget.match.skorPenaltiPeserta2?.toString() ?? '');

  late final int _games = widget.bestOf < 1 ? 1 : widget.bestOf;

  // Basket: skor kuarter per game. _gq1[game][babak], babak 0–3 = Q1–Q4, 4+ = OT.
  final List<List<TextEditingController>> _gq1 = [];
  final List<List<TextEditingController>> _gq2 = [];

  // Non-basket seri: hasil tiap game (1 / 2 / 0 = remis catur / null = belum).
  late final List<int?> _gameWinner = List<int?>.filled(_games, null);

  // Basket seri yang dibuka ulang: rincian lama tidak tersimpan, jadi skor
  // lama dipakai sampai pengguna mulai mengisi ulang.
  bool _seriesTouched = false;

  bool get _isSeries => _games > 1;
  bool get _isChessSeries => widget.isChess && _isSeries;
  int get _target => _games ~/ 2 + 1;

  /// Catur: jumlah game utama (yang boleh remis) sebelum game penentu.
  int get _regularGames => _games - 1;

  /// Poin catur dalam satuan ½ (menang = 2, remis = 1), supaya tetap int.
  (int, int) _chessHalfPoints(int games) {
    int h1 = 0, h2 = 0;
    for (int g = 0; g < games; g++) {
      final r = _gameWinner[g];
      if (r == 1) h1 += 2;
      if (r == 2) h2 += 2;
      if (r == 0) {
        h1++;
        h2++;
      }
    }
    return (h1, h2);
  }

  /// Catur: game ditampilkan sampai game yang belum diisi, sampai salah satu
  /// pemain tidak terkejar lagi, atau sampai game penentu kalau poin sama.
  int get _chessVisibleGames {
    for (int g = 0; g < _regularGames; g++) {
      if (_gameWinner[g] == null) return g + 1;
      final (h1, h2) = _chessHalfPoints(g + 1);
      final remainingHalves = (_regularGames - g - 1) * 2;
      if ((h1 - h2).abs() > remainingHalves) return g + 1;
    }
    final (h1, h2) = _chessHalfPoints(_regularGames);
    return h1 == h2 ? _games : _regularGames;
  }
  bool get _hasOldScore => _score1 > 0 || _score2 > 0;
  bool get _keepOldBasketSeries =>
      widget.isBasket && _isSeries && !_seriesTouched && _hasOldScore;

  static String _labelBabak(int index) => index < 4 ? 'Q${index + 1}' : 'OT${index - 3}';

  int _sum(List<TextEditingController> cs) =>
      cs.fold(0, (sum, c) => sum + (int.tryParse(c.text.trim()) ?? 0));

  bool _gameFilled(int g) => _sum(_gq1[g]) + _sum(_gq2[g]) > 0;

  /// Pemenang game ke-g: 1, 2, atau null kalau belum ada / masih seri.
  int? _winnerOf(int g) {
    if (!widget.isBasket) return _gameWinner[g];
    if (!_gameFilled(g)) return null;
    final a = _sum(_gq1[g]);
    final b = _sum(_gq2[g]);
    if (a == b) return null;
    return a > b ? 1 : 2;
  }

  /// Game yang ditampilkan: sampai game pertama yang belum ada pemenangnya,
  /// atau sampai salah satu peserta mencapai target kemenangan.
  int get _visibleGames {
    if (!_isSeries) return 1;
    if (_isChessSeries) return _chessVisibleGames;
    int w1 = 0, w2 = 0;
    for (int g = 0; g < _games; g++) {
      final w = _winnerOf(g);
      if (w == null) return g + 1;
      if (w == 1) {
        w1++;
      } else {
        w2++;
      }
      if (w1 >= _target || w2 >= _target) return g + 1;
    }
    return _games;
  }

  (int, int) get _seriesWins {
    int w1 = 0, w2 = 0;
    for (int g = 0; g < _visibleGames; g++) {
      final w = _winnerOf(g);
      if (w == 1) w1++;
      if (w == 2) w2++;
    }
    return (w1, w2);
  }

  int get _total1 {
    if (_keepOldBasketSeries) return _score1;
    if (_isSeries) return _seriesWins.$1;
    if (widget.isBasket) return _sum(_gq1[0]);
    return _score1;
  }

  int get _total2 {
    if (_keepOldBasketSeries) return _score2;
    if (_isSeries) return _seriesWins.$2;
    if (widget.isBasket) return _sum(_gq2[0]);
    return _score2;
  }

  bool get _needsPenaltyShootout {
    // Basket & seri BO tidak pakai adu penalti.
    if (widget.isBasket || _isSeries) return false;
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

    if (widget.isBasket) {
      for (int g = 0; g < _games; g++) {
        // BO1: skor lama dimasukkan ke Q1 supaya totalnya tetap sama.
        final prefill = !_isSeries && g == 0 && _hasOldScore;
        List<TextEditingController> quarters(int score) => [
              for (int i = 0; i < 4; i++)
                TextEditingController(text: prefill && i == 0 ? '$score' : ''),
            ];
        _gq1.add(quarters(_score1));
        _gq2.add(quarters(_score2));
      }
    } else if (_isSeries) {
      // Isi ulang pemenang tiap game dari skor seri yang tersimpan.
      // Kemenangan pihak yang kalah diletakkan di depan supaya game
      // penentu tetap milik pemenang (contoh 2-1 → P2, P1, P1).
      final loser = _score1 >= _score2 ? 2 : 1;
      final winner = loser == 1 ? 2 : 1;
      final loserWins = loser == 1 ? _score1 : _score2;
      final winnerWins = winner == 1 ? _score1 : _score2;
      int g = 0;
      for (int i = 0; i < loserWins && g < _games; i++) {
        _gameWinner[g++] = loser;
      }
      // Catur yang sudah selesai: remis tidak tersimpan (yang disimpan jumlah
      // menang), jadi game utama yang tersisa diisi remis. Selisih poin tetap
      // sama karena remis memberi ½ ke kedua pemain.
      if (_isChessSeries && widget.match.status == 'Selesai' && _hasOldScore) {
        final draws = _regularGames - loserWins - winnerWins;
        for (int i = 0; i < draws && g < _regularGames; i++) {
          _gameWinner[g++] = 0;
        }
      }
      for (int i = 0; i < winnerWins && g < _games; i++) {
        _gameWinner[g++] = winner;
      }
    }
  }

  @override
  void dispose() {
    _penalty1Controller.dispose();
    _penalty2Controller.dispose();
    for (final c in [..._gq1, ..._gq2].expand((list) => list)) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOvertime(int g) {
    setState(() {
      _seriesTouched = true;
      _gq1[g].add(TextEditingController());
      _gq2[g].add(TextEditingController());
    });
  }

  void _removeLastOvertime(int g) {
    if (_gq1[g].length <= 4) return;
    setState(() {
      _gq1[g].removeLast().dispose();
      _gq2[g].removeLast().dispose();
    });
  }

  /// Pesan error kalau status Selesai belum sah, null kalau aman.
  String? _validateFinished() {
    if (_status != 'Selesai' || _keepOldBasketSeries) return null;

    if (_isChessSeries) {
      final visible = _visibleGames;
      final (h1, h2) = _chessHalfPoints(visible);
      if (_gameWinner[visible - 1] == null || h1 == h2) {
        return 'Pertandingan catur belum selesai. Isi hasil semua game sampai ada pemenang.';
      }
      return null;
    }

    if (_isSeries) {
      if (widget.isBasket) {
        for (int g = 0; g < _visibleGames; g++) {
          if (_gameFilled(g) && _sum(_gq1[g]) == _sum(_gq2[g])) {
            return 'Game ${g + 1} masih seri. Tambahkan babak Overtime.';
          }
        }
      }
      final (w1, w2) = _seriesWins;
      if (w1 < _target && w2 < _target) {
        return 'Seri belum selesai. Pemenang butuh $_target kemenangan (BO$_games).';
      }
      return null;
    }

    if (!widget.isBasket) return null;

    // Basket 2 leg di babak gugur: Leg 1 boleh seri, pemenang ditentukan
    // dari agregat. Kalau agregat seri, Leg 2 dilanjutkan dengan Overtime
    // (basket tidak punya adu penalti).
    final knockoutTwoLeg = widget.isKnockout && widget.isTwoLeg;
    final isFirstLeg = widget.match.babak.startsWith('Leg 1 - ');
    if (_total1 == _total2 && !(knockoutTwoLeg && isFirstLeg)) {
      return 'Skor masih seri ($_total1-$_total2). Tambahkan babak Overtime.';
    }
    final prev1 = widget.previousLegScore1;
    final prev2 = widget.previousLegScore2;
    if (knockoutTwoLeg && !isFirstLeg && prev1 != null && prev2 != null &&
        _total1 + prev1 == _total2 + prev2) {
      return 'Agregat seri (${_total1 + prev1}-${_total2 + prev2}). '
          'Tambahkan babak Overtime di Leg 2.';
    }
    return null;
  }

  Future<void> _saveScore() async {
    final error = _validateFinished();
    if (error != null) {
      context.showSnack(error, color: AppColors.error);
      return;
    }

    // Yang disimpan cuma total: poin (BO1) atau jumlah game menang (seri).
    final skor1 = _total1;
    final skor2 = _total2;
    final penalty1 = _needsPenaltyShootout ? int.tryParse(_penalty1Controller.text) : null;
    final penalty2 = _needsPenaltyShootout ? int.tryParse(_penalty2Controller.text) : null;

    setState(() => _isSaving = true);
    try {
      if (widget.isPrivate) {
        await LocalTournamentService.instance.updateHasilPertandingan(
          idPertandingan: widget.match.idPertandingan,
          skor1: skor1,
          skor2: skor2,
          status: _status,
          skorPenalti1: penalty1,
          skorPenalti2: penalty2,
        );
      } else {
        await ApiService.instance.updateHasilPertandingan(
          idPertandingan: widget.match.idPertandingan,
          skor1: skor1,
          skor2: skor2,
          status: _status,
          skorPenalti1: penalty1,
          skorPenalti2: penalty2,
        );
      }
      if (!mounted) return;
      widget.onSaved();
      // GetX: tutup dialog
      Get.back();
      context.showSnack(
        widget.isPrivate
            ? 'Hasil skor berhasil disimpan ke database lokal HP!'
            : 'Hasil skor berhasil disimpan ke backend server!',
        color: AppColors.success,
      );
    } catch (e) {
      if (mounted) context.showSnack('Gagal menyimpan skor: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ===================== BUILD =====================

  Widget _buildBasketGame(int g, String p1Name, String p2Name) {
    final isTied = _gameFilled(g) && _sum(_gq1[g]) == _sum(_gq2[g]);
    final color = isTied ? AppColors.warning : AppColors.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuarterTable(
          name1: p1Name,
          name2: p2Name,
          labels: [for (int i = 0; i < _gq1[g].length; i++) _labelBabak(i)],
          controllers1: _gq1[g],
          controllers2: _gq2[g],
          onChanged: () => setState(() => _seriesTouched = true),
          onRemoveLast: _gq1[g].length > 4 ? () => _removeLastOvertime(g) : null,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _addOvertime(g),
          icon: const Icon(Icons.more_time_rounded, size: 18),
          label: Text(isTied ? 'Skor seri, tambah Overtime' : 'Tambah Overtime'),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  /// Pilihan hasil game ke-g, dibagi rata. Ketuk lagi untuk batal.
  /// Catur (selain game penentu): ada pilihan Remis di tengah.
  Widget _buildWinnerPicker(int g, String p1Name, String p2Name) {
    Widget option(int result, String label, String selectedLabel, Color color) {
      final selected = _gameWinner[g] == result;
      return Expanded(
        child: SelectBox(
          label: selected ? selectedLabel : label,
          selected: selected,
          onTap: () => setState(() => _gameWinner[g] = selected ? null : result),
          color: color.withValues(alpha: 0.2),
          borderColor: color,
          textColor: color,
          minHeight: 44,
        ),
      );
    }

    final allowDraw = _isChessSeries && g < _regularGames;
    return Row(
      children: [
        option(1, p1Name, '✓ $p1Name menang', AppColors.success),
        const SizedBox(width: 8),
        if (allowDraw) ...[
          option(0, 'Remis', '✓ Remis (½)', AppColors.secondary),
          const SizedBox(width: 8),
        ],
        option(2, p2Name, '✓ $p2Name menang', AppColors.success),
      ],
    );
  }

  Widget _statusOption(String status) {
    return Expanded(
      child: SelectBox(
        label: status,
        selected: _status == status,
        onTap: () => setState(() => _status = status),
        borderColor: AppColors.primaryLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ukuran dari MediaQuery: jarak ke tepi 5% lebar / 4% tinggi layar,
    // padding 5% lebar (14–22), angka skor 8% lebar layar (24–36).
    final screen = MediaQuery.sizeOf(context);
    final scoreFontSize = (screen.width * 0.08).clamp(24.0, 36.0);
    final p1Name = widget.match.displayNama1 ?? 'TBD';
    final p2Name = widget.match.displayNama2 ?? 'TBD';
    final total1 = _total1;
    final total2 = _total2;

    // Catur: kartu menampilkan poin (menang 1, remis ½), bukan jumlah menang.
    final (half1, half2) = _chessHalfPoints(_isChessSeries ? _visibleGames : 0);
    final score1 = _isChessSeries ? formatHalfPoints(half1) : '$total1';
    final score2 = _isChessSeries ? formatHalfPoints(half2) : '$total2';

    // Tombol +/- cuma untuk mode biasa (bukan basket, bukan seri BO).
    final manualScore = !widget.isBasket && !_isSeries;
    final caption = _isChessSeries ? 'Poin' : (_isSeries ? 'Game menang' : 'Total skor');

    final card1 = _ScoreCard(
      name: p1Name,
      score: score1,
      caption: caption,
      scoreFontSize: scoreFontSize,
      isLeading: total1 > total2 && _status == 'Selesai',
      onIncrement: manualScore ? () => setState(() => _score1++) : null,
      onDecrement: manualScore
          ? () {
              if (_score1 > 0) setState(() => _score1--);
            }
          : null,
    );
    final card2 = _ScoreCard(
      name: p2Name,
      score: score2,
      caption: caption,
      scoreFontSize: scoreFontSize,
      isLeading: total2 > total1 && _status == 'Selesai',
      onIncrement: manualScore ? () => setState(() => _score2++) : null,
      onDecrement: manualScore
          ? () {
              if (_score2 > 0) setState(() => _score2--);
            }
          : null,
    );

    return Dialog(
      backgroundColor: AppColors.bgDarkSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width * 0.05,
        vertical: screen.height * 0.04,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        // Bisa discroll supaya tidak overflow saat keyboard muncul.
        child: SingleChildScrollView(
          padding: EdgeInsets.all((screen.width * 0.05).clamp(14.0, 22.0)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Judul + tombol tutup
              Row(
                children: [
                  const Icon(Icons.sports_score_rounded, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isSeries ? '${widget.match.babak} · BO$_games' : widget.match.babak,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: screen.width < 360 ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),

              // Skor total: dua kartu dibagi rata 1:1 dengan "VS" di tengah.
              // Layar sangat sempit (< 330 dp): kartu ditumpuk atas-bawah.
              if (screen.width < 330)
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

              if (_isSeries) ...[
                const SizedBox(height: 12),
                Text(
                  _isChessSeries
                      ? 'Best of $_games: $_regularGames game utama (menang 1 poin, remis ½ poin). '
                          'Jika poin sama, Game $_games jadi penentu tanpa remis.'
                      : 'Best of $_games: pemenang seri adalah yang pertama menang $_target game.',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                if (_keepOldBasketSeries) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Skor seri tersimpan: $_score1-$_score2. Isi ulang skor per game kalau mau mengubah.',
                    style: const TextStyle(color: AppColors.warning, fontSize: 11),
                  ),
                ],
                for (int g = 0; g < _visibleGames; g++) ...[
                  const SizedBox(height: 14),
                  _GameSection(
                    title: _isChessSeries && g == _regularGames
                        ? 'Game ${g + 1} · Penentu'
                        : 'Game ${g + 1}',
                    result: switch (_winnerOf(g)) {
                      1 => '🏆 $p1Name',
                      2 => '🏆 $p2Name',
                      0 => '🤝 Remis',
                      _ => null,
                    },
                    child: widget.isBasket
                        ? _buildBasketGame(g, p1Name, p2Name)
                        : _buildWinnerPicker(g, p1Name, p2Name),
                  ),
                ],
              ] else if (widget.isBasket) ...[
                const SizedBox(height: 16),
                _buildBasketGame(0, p1Name, p2Name),
              ],
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
                  _statusOption('Berlangsung'),
                  const SizedBox(width: 10),
                  _statusOption('Selesai'),
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
                    Expanded(child: _PenaltyField(controller: _penalty1Controller, label: p1Name)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '–',
                        style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(child: _PenaltyField(controller: _penalty2Controller, label: p2Name)),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              LoadingButton(
                label: 'Simpan Hasil',
                isLoading: _isSaving,
                onPressed: _saveScore,
                height: 48,
                radius: 12,
                fontSize: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== WIDGET STATELESS =====================

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
        style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.name,
    required this.score,
    required this.caption,
    required this.scoreFontSize,
    required this.isLeading,
    this.onIncrement,
    this.onDecrement,
  });

  final String name;
  final String score;
  final String caption;
  final double scoreFontSize;
  final bool isLeading;

  /// Null = skor dihitung otomatis, tombol +/- diganti [caption].
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final editable = onIncrement != null && onDecrement != null;

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
            score,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: scoreFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (editable)
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
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(caption, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

/// Satu game dalam seri BO: judul, hasil (kalau sudah ada), dan isinya.
class _GameSection extends StatelessWidget {
  const _GameSection({required this.title, required this.result, required this.child});

  final String title;
  final String? result;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Tabel skor per kuarter. Tiap baris: label (Q1/OT1) : skor peserta 1 :
/// skor peserta 2, dengan kolom skor dibagi rata 1:1.
class _QuarterTable extends StatelessWidget {
  const _QuarterTable({
    required this.name1,
    required this.name2,
    required this.labels,
    required this.controllers1,
    required this.controllers2,
    required this.onChanged,
    required this.onRemoveLast,
  });

  final String name1;
  final String name2;
  final List<String> labels;
  final List<TextEditingController> controllers1;
  final List<TextEditingController> controllers2;
  final VoidCallback onChanged;

  /// Null kalau belum ada Overtime (Q1–Q4 tidak bisa dihapus).
  final VoidCallback? onRemoveLast;

  static const _labelWidth = 44.0;
  static const _actionWidth = 36.0;
  static const _headerStyle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  Widget _name(String name) => Expanded(
        child: Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _headerStyle,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final last = controllers1.length - 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: _labelWidth, child: Text('Babak', style: _headerStyle)),
              _name(name1),
              const SizedBox(width: 8),
              _name(name2),
              const SizedBox(width: _actionWidth),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i <= last; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: i < 4 ? AppColors.textPrimary : AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(child: _QuarterField(controller: controllers1[i], onChanged: onChanged)),
                  const SizedBox(width: 8),
                  Expanded(child: _QuarterField(controller: controllers2[i], onChanged: onChanged)),
                  SizedBox(
                    width: _actionWidth,
                    // Hanya baris Overtime terakhir yang bisa dihapus.
                    child: i == last && onRemoveLast != null
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: 'Hapus Overtime',
                            onPressed: onRemoveLast,
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                          )
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuarterField extends StatelessWidget {
  const _QuarterField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      textAlign: TextAlign.center,
      onChanged: (_) => onChanged(),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: '0',
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.bgDarkSecondary,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
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
