import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/klasemen_model.dart';
import '../../data/models/pertandingan_model.dart';
import '../../data/models/peserta_model.dart';
import '../../data/models/turnamen_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';
import '../../routes/app_routes.dart';
import '../pertandingan/input_skor_dialog.dart';
import '../widgets/common_widgets.dart';

const _gold = Color(0xFFFFD700);
const _primaryGradient = LinearGradient(colors: [AppColors.primary, Color(0xFF4F46E5)]);

/// Teks skor sebuah laga. Catur seri BO: poin pecahan (1½ – ½) dihitung dari
/// jumlah menang yang tersimpan. Cabang lain: skor apa adanya.
(String, String) _scoreTexts(PertandinganModel m, int? chessBestOf) {
  if (chessBestOf == null) return ('${m.skorPeserta1}', '${m.skorPeserta2}');
  final (h1, h2) = chessHalfPoints(
    wins1: m.skorPeserta1,
    wins2: m.skorPeserta2,
    bestOf: chessBestOf,
    isFinished: m.status == 'Selesai',
  );
  return (formatHalfPoints(h1), formatHalfPoints(h2));
}

/// Nama babak tanpa awalan "Leg 1 - " / "Leg 2 - ".
String _roundName(String babak) => babak.replaceFirst(RegExp(r'^Leg [12] - '), '');

class DetailTurnamenScreen extends StatefulWidget {
  const DetailTurnamenScreen({super.key, required this.idTurnamen, this.isPrivate});

  final String idTurnamen;
  final bool? isPrivate;

  @override
  State<DetailTurnamenScreen> createState() => _DetailTurnamenScreenState();
}

class _DetailTurnamenScreenState extends State<DetailTurnamenScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);
  late bool _isPrivate = widget.isPrivate ?? false;
  TurnamenModel? _turnamen;
  List<PertandinganModel> _pertandinganList = [];
  List<PesertaModel> _pesertaList = [];
  bool _isLoading = true;
  String? _errorMessage;

  /// BO catur kalau turnamen catur seri (BO3/5/7), null untuk lainnya.
  int? get _chessBestOf {
    final t = _turnamen;
    return t != null && t.tipeGame == 'Catur' && t.bestOf > 1 ? t.bestOf : null;
  }

  bool get _isKnockout =>
      _turnamen?.formatBracket == 'Single Elimination' ||
      _turnamen?.formatBracket == 'Double Elimination';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ===================== DATA =====================

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final local = LocalTournamentService.instance;
    try {
      Map<String, dynamic> detail;
      if (_isPrivate) {
        detail = await local.getTurnamenDetail(widget.idTurnamen);
      } else {
        try {
          detail = await ApiService.instance.getTurnamenDetail(widget.idTurnamen);
        } catch (_) {
          // Fallback ke SQLite lokal kalau backend gagal
          detail = await local.getTurnamenDetail(widget.idTurnamen);
        }
      }

      if (!mounted) return;
      setState(() {
        _turnamen = detail['turnamen'] as TurnamenModel;
        _isPrivate = _turnamen!.isPrivate;
        _pesertaList = detail['peserta'] as List<PesertaModel>;
        _pertandinganList = detail['pertandingan'] as List<PertandinganModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = errorText(e);
        _isLoading = false;
      });
    }
  }

  List<KlasemenItem> _calculateKlasemen() {
    final stats = {
      for (final p in _pesertaList)
        p.idPeserta: KlasemenItem(
          idPeserta: p.idPeserta,
          namaPeserta: p.namaPeserta,
          isChess: _chessBestOf != null,
        ),
    };

    for (final m in _pertandinganList) {
      if (m.status != 'Selesai') continue;
      final p1 = stats[m.idPeserta1];
      final p2 = stats[m.idPeserta2];
      if (p1 == null || p2 == null) continue;

      // Catur: dihitung per game. Skor tersimpan = jumlah game menang; game
      // utama yang tidak dimenangkan siapa pun dihitung remis.
      final chessBestOf = _chessBestOf;
      if (chessBestOf != null) {
        final wins1 = m.skorPeserta1;
        final wins2 = m.skorPeserta2;
        final draws = max(0, chessBestOf - 1 - wins1 - wins2);
        final games = wins1 + wins2 + draws;
        p1
          ..main += games
          ..menang += wins1
          ..seri += draws
          ..kalah += wins2;
        p2
          ..main += games
          ..menang += wins2
          ..seri += draws
          ..kalah += wins1;
        continue;
      }

      p1
        ..main += 1
        ..gm += m.skorPeserta1
        ..gk += m.skorPeserta2;
      p2
        ..main += 1
        ..gm += m.skorPeserta2
        ..gk += m.skorPeserta1;

      if (m.skorPeserta1 > m.skorPeserta2) {
        p1.menang++;
        p2.kalah++;
      } else if (m.skorPeserta2 > m.skorPeserta1) {
        p2.menang++;
        p1.kalah++;
      } else {
        p1.seri++;
        p2.seri++;
      }
    }

    // Urutan: poin, selisih gol, gol masuk, menang, lalu nama.
    // (Catur: gol selalu 0, jadi langsung poin lalu menang.)
    return stats.values.toList()
      ..sort((a, b) {
        if (b.poin != a.poin) return b.poin.compareTo(a.poin);
        if (b.sg != a.sg) return b.sg.compareTo(a.sg);
        if (b.gm != a.gm) return b.gm.compareTo(a.gm);
        if (b.menang != a.menang) return b.menang.compareTo(a.menang);
        return a.namaPeserta.compareTo(b.namaPeserta);
      });
  }

  Map<String, List<PertandinganModel>> _groupedMatches() {
    final grouped = <String, List<PertandinganModel>>{};
    for (final match in _pertandinganList) {
      final round = _isKnockout ? _roundName(match.babak) : match.babak;
      grouped.putIfAbsent(round, () => []).add(match);
    }
    if (!_isKnockout) return grouped;

    // Babak gugur: urut sesuai laga pertama, Juara 3 sebelum Final.
    final rounds = grouped.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Final' && b.key == 'Perebutan Juara 3') return 1;
        if (a.key == 'Perebutan Juara 3' && b.key == 'Final') return -1;
        return a.value.first.urutan.compareTo(b.value.first.urutan);
      });
    return Map.fromEntries(rounds);
  }

  // ===================== AKSI =====================

  Future<void> _openEdit(TurnamenModel t) async {
    // Named Route + arguments
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.editTurnamen,
      arguments: {'turnamen': t},
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteTurnamen() async {
    final confirmed = await showConfirmDialog(
      icon: Icons.warning_amber_rounded,
      color: AppColors.error,
      title: 'Hapus Turnamen',
      message: 'Apakah kamu yakin ingin menghapus turnamen "${_turnamen?.namaTurnamen}"? '
          'Semua data peserta dan jadwal pertandingan di '
          '${_isPrivate ? 'database lokal HP' : 'server backend'} akan dihapus secara permanen.',
      confirmLabel: 'Hapus',
    );
    if (!confirmed) return;

    try {
      if (_isPrivate) {
        await LocalTournamentService.instance.deleteTurnamen(widget.idTurnamen);
      } else {
        await ApiService.instance.deleteTurnamen(widget.idTurnamen);
      }
      if (!mounted) return;
      context.showSnack(
        _isPrivate
            ? 'Turnamen berhasil dihapus dari database lokal HP'
            : 'Turnamen berhasil dihapus dari backend server',
        color: AppColors.success,
      );
      // Push/Pop: kembali + bawa hasil
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) context.showSnack('Gagal menghapus: $e', color: AppColors.error);
    }
  }

  Future<void> _akhiriTurnamen() async {
    final confirmed = await showConfirmDialog(
      icon: Icons.lock_rounded,
      color: AppColors.warning,
      title: 'Akhiri Turnamen?',
      message: 'Setelah turnamen diakhiri, semua skor akan dikunci dan tidak dapat diedit '
          'lagi.\n\nApakah kamu yakin ingin mengakhiri turnamen ini?',
      confirmLabel: 'Ya, Akhiri Turnamen',
      confirmTextColor: Colors.black,
    );
    if (!confirmed) return;

    try {
      final updated = _turnamen!.copyWith(status: 'Selesai', isLocked: true);
      if (_isPrivate) {
        await LocalTournamentService.instance.updateTurnamen(updated);
      } else {
        await ApiService.instance.updateTurnamen(updated);
      }
      if (!mounted) return;
      setState(() => _turnamen = updated);
      context.showSnack('Turnamen telah diakhiri! Skor telah dikunci.', color: AppColors.success);
      _loadData();
    } catch (e) {
      if (mounted) context.showSnack('Gagal mengakhiri turnamen: $e', color: AppColors.error);
    }
  }

  void _openInputSkor(PertandinganModel match) {
    final t = _turnamen!;
    if (t.isLocked) {
      context.showSnack(
        'Turnamen telah diakhiri. Skor tidak dapat diedit lagi.',
        color: AppColors.error,
      );
      return;
    }
    if (match.idPeserta1 == null || match.idPeserta2 == null) {
      context.showSnack(
        'Peserta pertandingan ini belum ditentukan (menunggu babak sebelumnya).',
        color: AppColors.warning,
      );
      return;
    }

    // Leg 2: cari skor Leg 1 (posisi kandang/tandang terbalik) untuk agregat.
    PertandinganModel? previousLeg;
    if (t.jumlahLeg == 2 && match.babak.startsWith('Leg 2 - ')) {
      final round = _roundName(match.babak);
      previousLeg = _pertandinganList
          .where((leg) =>
              leg.babak == 'Leg 1 - $round' &&
              leg.idPeserta1 == match.idPeserta2 &&
              leg.idPeserta2 == match.idPeserta1)
          .firstOrNull;
    }

    // GetX: buka dialog tanpa context
    Get.dialog(
      InputSkorDialog(
        match: match,
        isPrivate: _isPrivate,
        isKnockout: t.formatBracket == 'Single Elimination',
        isTwoLeg: t.jumlahLeg == 2,
        previousLegScore1: previousLeg?.skorPeserta2,
        previousLegScore2: previousLeg?.skorPeserta1,
        isBasket: t.tipeGame == 'Bola Basket',
        bestOf: t.bestOf,
        isChess: t.tipeGame == 'Catur',
        onSaved: _loadData,
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final t = _turnamen;
    if (_errorMessage != null || t == null) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(title: const Text('Detail Turnamen')),
        body: StateMessage(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          message: _errorMessage ?? 'Data tidak ditemukan',
          actions: [
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    // MediaQuery: padding 4% lebar layar, isi maks 1100 dp. Daftar laga &
    // peserta 2 kolom di layar >= 720 dp. Lebar kolom bagan = 62% lebar isi.
    final layout = PageLayout.of(context);
    final side = layout.sidePadding;
    final listColumns = layout.contentWidth >= 720 ? 2 : 1;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(t.namaTurnamen, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.textPrimary),
            tooltip: 'Edit Turnamen',
            onPressed: () => _openEdit(t),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: 'Hapus Turnamen',
            onPressed: _deleteTurnamen,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Baris 1: kartu info
            Padding(
              padding: EdgeInsets.fromLTRB(side, 8, side, 12),
              child: _HeaderCard(
                turnamen: t,
                isPrivate: _isPrivate,
                selesaiCount: _pertandinganList.where((m) => m.status == 'Selesai').length,
                totalCount: _pertandinganList.length,
                onAkhiri: _akhiriTurnamen,
              ),
            ),
            // Baris 2: tab bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: side),
              child: _DetailTabBar(
                controller: _tabController,
                isKnockout: _isKnockout,
                matchCount: _pertandinganList.length,
                pesertaCount: _pesertaList.length,
                // Di layar sempit ikon tab disembunyikan supaya label tidak terpotong.
                showIcons: layout.screen.width >= 380,
              ),
            ),
            const SizedBox(height: 12),
            // Baris 3: isi tab (ambil sisa tinggi)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  if (_isKnockout)
                    _BracketView(
                      matches: _pertandinganList,
                      legCount: t.jumlahLeg,
                      chessBestOf: _chessBestOf,
                      columnWidth: (layout.contentWidth * 0.62).clamp(200.0, 280.0),
                      connectorWidth: (layout.contentWidth * 0.07).clamp(20.0, 40.0),
                      sidePadding: side,
                      onTapMatch: _openInputSkor,
                    )
                  else
                    _KlasemenView(
                      klasemen: _calculateKlasemen(),
                      isChess: _chessBestOf != null,
                      sidePadding: side,
                    ),
                  _MatchListView(
                    grouped: _groupedMatches(),
                    isLocked: t.isLocked,
                    chessBestOf: _chessBestOf,
                    columns: listColumns,
                    gap: layout.gap,
                    sidePadding: side,
                    onTapMatch: _openInputSkor,
                  ),
                  _peserta(listColumns, layout.gap, side),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _peserta(int columns, double gap, double side) {
    if (_pesertaList.isEmpty) return const _EmptyText('Belum ada peserta terdaftar');

    return ListView(
      padding: EdgeInsets.fromLTRB(side, 0, side, 20),
      children: [
        ResponsiveGrid(
          columns: columns,
          gap: gap,
          children: [
            for (int i = 0; i < _pesertaList.length; i++)
              _PesertaTile(number: i + 1, nama: _pesertaList[i].namaPeserta),
          ],
        ),
      ],
    );
  }
}

// ===================== WIDGET STATELESS: UMUM =====================

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Kotak gelap dengan sudut membulat dan garis tepi tipis.
BoxDecoration _cardDecoration({double radius = 16, double borderAlpha = 0.06}) {
  return BoxDecoration(
    color: AppColors.bgCard,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: borderAlpha)),
  );
}

// ===================== WIDGET STATELESS: HEADER =====================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.turnamen,
    required this.isPrivate,
    required this.selesaiCount,
    required this.totalCount,
    required this.onAkhiri,
  });

  final TurnamenModel turnamen;
  final bool isPrivate;
  final int selesaiCount;
  final int totalCount;
  final VoidCallback onAkhiri;

  @override
  Widget build(BuildContext context) {
    final t = turnamen;
    final progress = totalCount > 0 ? selesaiCount / totalCount : 0.0;
    final isComplete = progress == 1.0;
    final width = MediaQuery.sizeOf(context).width;
    final seri = t.bestOf > 1
        ? 'Best of ${t.bestOf}'
        : (t.jumlahLeg == 2 ? '2 Leg Home & Away' : '1 Leg');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((width * 0.04).clamp(12.0, 20.0)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.bgCard, Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ColorBadge(
                text: t.status,
                color: statusColor(t.status, fallback: AppColors.primaryLight),
                dot: true,
                radius: 20,
                borderAlpha: 0.4,
              ),
              PrivacyBadge(isPrivate: isPrivate),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _TagChip(
                text: t.tipeGame,
                background: Colors.white.withValues(alpha: 0.08),
                color: AppColors.textSecondary,
              ),
              _TagChip(
                text: '${t.kuota} Peserta · ${t.formatBracket} ($seri)',
                background: AppColors.primary.withValues(alpha: 0.15),
                color: AppColors.primaryLight,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(t.tanggalMulai),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          if (t.deskripsi?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              t.deskripsi!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          // Progress turnamen
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progress Turnamen',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$selesaiCount / $totalCount Laga (${(progress * 100).toInt()}%)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(
                isComplete ? AppColors.success : AppColors.secondary,
              ),
            ),
          ),
          if (t.isLocked) ...[
            const SizedBox(height: 12),
            const ColorBadge(
              text: 'Turnamen Telah Berakhir — Skor Dikunci',
              color: AppColors.success,
              icon: Icons.lock_rounded,
              radius: 10,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ] else if (isComplete && totalCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAkhiri,
                icon: const Icon(Icons.flag_rounded, size: 16),
                label: const Text(
                  'Akhiri Turnamen & Kunci Skor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text, required this.background, required this.color});

  final String text;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ===================== WIDGET STATELESS: TAB BAR =====================

class _DetailTabBar extends StatelessWidget {
  const _DetailTabBar({
    required this.controller,
    required this.isKnockout,
    required this.matchCount,
    required this.pesertaCount,
    required this.showIcons,
  });

  final TabController controller;
  final bool isKnockout;
  final int matchCount;
  final int pesertaCount;
  final bool showIcons;

  Tab _tab(IconData icon, String text) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcons) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: _cardDecoration(radius: 14, borderAlpha: 0.05),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          gradient: _primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: [
          isKnockout
              ? _tab(Icons.account_tree_rounded, 'Bagan')
              : _tab(Icons.leaderboard_rounded, 'Klasemen'),
          _tab(Icons.sports_esports_rounded, 'Laga ($matchCount)'),
          _tab(Icons.groups_rounded, 'Peserta ($pesertaCount)'),
        ],
      ),
    );
  }
}

// ===================== WIDGET STATELESS: BAGAN =====================

class _BracketView extends StatelessWidget {
  const _BracketView({
    required this.matches,
    required this.legCount,
    required this.chessBestOf,
    required this.columnWidth,
    required this.connectorWidth,
    required this.sidePadding,
    required this.onTapMatch,
  });

  final List<PertandinganModel> matches;
  final int legCount;
  final int? chessBestOf;
  final double columnWidth;
  final double connectorWidth;
  final double sidePadding;
  final ValueChanged<PertandinganModel> onTapMatch;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const _EmptyText('Belum ada pertandingan');

    final matchesByRound = <String, List<PertandinganModel>>{};
    for (final match in [...matches]..sort((a, b) => a.urutan.compareTo(b.urutan))) {
      matchesByRound.putIfAbsent(_roundName(match.babak), () => []).add(match);
    }
    // Juara 3 ditampilkan di bawah kolom Semifinal; Final selalu paling kanan.
    final thirdPlace = matchesByRound.remove('Perebutan Juara 3') ?? [];
    final rounds = matchesByRound.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Final') return 1;
        if (b.key == 'Final') return -1;
        return a.value.first.urutan.compareTo(b.value.first.urutan);
      });

    // Satu kotak pertemuan = [legCount] laga berurutan.
    List<Widget> ties(List<PertandinganModel> list) => [
          for (var i = 0; i < list.length; i += legCount)
            _BracketTie(
              legs: list.skip(i).take(legCount).toList(),
              chessBestOf: chessBestOf,
              onTap: onTapMatch,
            ),
        ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final round in rounds) ...[
              SizedBox(
                width: columnWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RoundTitle(round.key),
                    ...ties(round.value),
                    if (round.key.contains('Semifinal') && thirdPlace.isNotEmpty) ...[
                      const _RoundTitle('Perebutan Juara 3', topPadding: 4),
                      ...ties(thirdPlace),
                    ],
                  ],
                ),
              ),
              if (round.key != rounds.last.key)
                SizedBox(
                  width: connectorWidth,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 64),
                    child: Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted, size: 20),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundTitle extends StatelessWidget {
  const _RoundTitle(this.text, {this.topPadding = 0});

  final String text;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 2, top: topPadding, bottom: 12),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _BracketTie extends StatelessWidget {
  const _BracketTie({required this.legs, required this.chessBestOf, required this.onTap});

  final List<PertandinganModel> legs;
  final int? chessBestOf;
  final ValueChanged<PertandinganModel> onTap;

  @override
  Widget build(BuildContext context) {
    final firstLeg = legs.first;
    final homeId = firstLeg.idPeserta1;
    final awayId = firstLeg.idPeserta2;

    // Skor agregat semua leg, dilihat dari sisi tim kandang leg pertama.
    var homeScore = 0;
    var awayScore = 0;
    for (final leg in legs) {
      if (homeId != null && leg.idPeserta1 == homeId) {
        homeScore += leg.skorPeserta1;
        awayScore += leg.skorPeserta2;
      } else if (awayId != null && leg.idPeserta1 == awayId) {
        awayScore += leg.skorPeserta1;
        homeScore += leg.skorPeserta2;
      }
    }

    final allFinished = legs.every((leg) => leg.status == 'Selesai');
    var homeWon = allFinished && homeScore > awayScore;
    var awayWon = allFinished && awayScore > homeScore;
    // Agregat seri: pemenang dari adu penalti.
    if (allFinished && homeScore == awayScore) {
      final penaltyLeg = legs
          .where((leg) => leg.skorPenaltiPeserta1 != null && leg.skorPenaltiPeserta2 != null)
          .firstOrNull;
      if (penaltyLeg != null) {
        final homeIsP1 = penaltyLeg.idPeserta1 == homeId;
        final homePenalty = homeIsP1 ? penaltyLeg.skorPenaltiPeserta1! : penaltyLeg.skorPenaltiPeserta2!;
        final awayPenalty = homeIsP1 ? penaltyLeg.skorPenaltiPeserta2! : penaltyLeg.skorPenaltiPeserta1!;
        homeWon = homePenalty > awayPenalty;
        awayWon = awayPenalty > homePenalty;
      }
    }

    // Catur seri cuma 1 laga per pertemuan: tampilkan poinnya.
    final (homeText, awayText) = chessBestOf != null
        ? _scoreTexts(firstLeg, chessBestOf)
        : ('$homeScore', '$awayScore');

    // Ketukan membuka leg pertama yang belum selesai.
    final editableLeg = legs.firstWhere(
      (leg) => leg.status != 'Selesai',
      orElse: () => legs.last,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecoration(radius: 12, borderAlpha: 0.08),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTap(editableLeg),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _ScoreLine(
                  name: firstLeg.displayNama1 ?? 'Menunggu pemenang',
                  score: homeText,
                  isWinner: homeWon,
                  compact: true,
                ),
                const Divider(color: Colors.white10, height: 16),
                _ScoreLine(
                  name: firstLeg.displayNama2 ?? 'Menunggu pemenang',
                  score: awayText,
                  isWinner: awayWon,
                  compact: true,
                ),
                if (legs.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    legs.map((leg) => '${leg.skorPeserta1}-${leg.skorPeserta2}').join(' · '),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
                for (final leg in legs)
                  if (leg.skorPenaltiPeserta1 != null && leg.skorPenaltiPeserta2 != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        'Penalti ${leg.skorPenaltiPeserta1}-${leg.skorPenaltiPeserta2}',
                        style: const TextStyle(color: AppColors.warning, fontSize: 10),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu baris peserta + skor. [compact] untuk kotak bagan, normal untuk
/// kartu laga (skor di dalam kotak).
class _ScoreLine extends StatelessWidget {
  const _ScoreLine({
    required this.name,
    required this.score,
    required this.isWinner,
    this.isFinished = false,
    this.compact = false,
  });

  final String name;
  final String score;
  final bool isWinner;
  final bool isFinished;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scoreText = Text(
      score,
      style: TextStyle(
        color: isWinner ? Colors.white : AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );

    return Row(
      children: [
        if (isWinner)
          Padding(
            padding: EdgeInsets.only(right: compact ? 5 : 6),
            child: Icon(Icons.emoji_events_rounded, color: _gold, size: compact ? 14 : 16),
          ),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isWinner
                  ? _gold
                  : (isFinished ? AppColors.textSecondary : AppColors.textPrimary),
              fontSize: compact ? 12 : 13,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (compact)
          scoreText
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isWinner
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isWinner ? AppColors.primary : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: scoreText,
          ),
      ],
    );
  }
}

// ===================== WIDGET STATELESS: KLASEMEN =====================

class _KlasemenView extends StatelessWidget {
  const _KlasemenView({
    required this.klasemen,
    required this.isChess,
    required this.sidePadding,
  });

  final List<KlasemenItem> klasemen;
  final bool isChess;
  final double sidePadding;

  @override
  Widget build(BuildContext context) {
    if (klasemen.isEmpty) return const _EmptyText('Belum ada data klasemen');

    return ListView(
      padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 24),
      children: [
        // LayoutBuilder: lebar kolom tabel dihitung dari lebar yang tersedia.
        LayoutBuilder(
          builder: (context, constraints) => _KlasemenTable(
            klasemen: klasemen,
            isChess: isChess,
            unit: (constraints.maxWidth * 0.06).clamp(20.0, 36.0),
            // Layar < 360 dp: kolom GF & GA disembunyikan. Catur tanpa gol.
            showGoals: !isChess && constraints.maxWidth >= 360,
          ),
        ),
        const SizedBox(height: 14),
        _KlasemenLegend(isChess: isChess),
      ],
    );
  }
}

class _KlasemenTable extends StatelessWidget {
  const _KlasemenTable({
    required this.klasemen,
    required this.isChess,
    required this.unit,
    required this.showGoals,
  });

  final List<KlasemenItem> klasemen;

  /// Catur: kolom GF, GA, GD disembunyikan; PTS berupa poin pecahan (1½).
  final bool isChess;

  /// Lebar dasar kolom angka.
  final double unit;
  final bool showGoals;

  Widget _cell(String text, double widthFactor, {Color color = AppColors.textSecondary, bool bold = true}) {
    return SizedBox(
      width: unit * widthFactor,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  String _num(int value, {bool signed = false}) {
    final text = isChess ? formatHalfPoints(value.abs()) : '${value.abs()}';
    if (value < 0) return '-$text';
    return signed && value > 0 ? '+$text' : text;
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: unit * 1.2,
            child: const Text(
              '#',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'KLUB / PESERTA',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _cell('M', 1),
          _cell('W', 1, color: AppColors.success),
          _cell('D', 1, color: AppColors.secondary),
          _cell('L', 1, color: AppColors.error),
          if (showGoals) ...[_cell('GF', 1.1), _cell('GA', 1.1)],
          if (!isChess) _cell('GD', 1.3),
          _cell('PTS', 1.5, color: Colors.white),
        ],
      ),
    );
  }

  Widget _row(KlasemenItem item, int rank) {
    final isLast = rank == klasemen.length;
    const podiumColors = {1: Color(0x0DFFD700), 2: Color(0x08C0C0C0), 3: Color(0x08CD7F32)};
    final gdColor = item.sg > 0
        ? AppColors.success
        : (item.sg < 0 ? AppColors.error : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: podiumColors[rank] ??
            (rank.isOdd ? Colors.white.withValues(alpha: 0.015) : Colors.transparent),
        borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(16)) : null,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(
        children: [
          SizedBox(width: unit * 1.2, child: _RankBadge(rank: rank)),
          Expanded(
            child: Text(
              item.namaPeserta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: rank == 1 ? _gold : AppColors.textPrimary,
                fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          _cell('${item.main}', 1, color: AppColors.textPrimary, bold: false),
          _cell('${item.menang}', 1, color: AppColors.success),
          _cell('${item.seri}', 1, color: AppColors.secondary),
          _cell('${item.kalah}', 1, color: AppColors.error),
          if (showGoals) ...[
            _cell(_num(item.gm), 1.1, color: AppColors.textPrimary, bold: false),
            _cell(_num(item.gk), 1.1, color: AppColors.textMuted, bold: false),
          ],
          if (!isChess) _cell(_num(item.sg, signed: true), 1.3, color: gdColor),
          SizedBox(
            width: unit * 1.5,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                gradient: rank == 1 ? _primaryGradient : null,
                color: rank != 1 ? AppColors.primary.withValues(alpha: 0.2) : null,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _num(item.poin),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF182234),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _header(),
          for (int i = 0; i < klasemen.length; i++) _row(klasemen[i], i + 1),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    const gradients = {
      1: [_gold, Color(0xFFF59E0B)],
      2: [Color(0xFFE2E8F0), Color(0xFF94A3B8)],
      3: [Color(0xFFF97316), Color(0xFFB45309)],
    };
    final colors = gradients[rank];

    if (colors == null) {
      return Text(
        '$rank',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors), shape: BoxShape.circle),
        child: Text(
          '$rank',
          style: TextStyle(
            color: rank == 3 ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _KlasemenLegend extends StatelessWidget {
  const _KlasemenLegend({required this.isChess});

  final bool isChess;

  @override
  Widget build(BuildContext context) {
    final items = isChess
        ? const [
            ('• M = Game Dimainkan', AppColors.textSecondary),
            ('• W = Menang (1 Poin)', AppColors.success),
            ('• D = Remis (½ Poin)', AppColors.secondary),
            ('• L = Kalah (0 Poin)', AppColors.error),
            ('• PTS = Total Poin', AppColors.primaryLight),
          ]
        : const [
            ('• M = Main', AppColors.textSecondary),
            ('• W = Menang (3 Poin)', AppColors.success),
            ('• D = Seri (1 Poin)', AppColors.secondary),
            ('• L = Kalah (0 Poin)', AppColors.error),
            ('• GF = Gol Masuk', AppColors.textSecondary),
            ('• GA = Gol Kebobolan', AppColors.textSecondary),
            ('• GD = Selisih Gol (GF - GA)', AppColors.textSecondary),
            ('• PTS = Total Poin', AppColors.primaryLight),
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: AppColors.secondary),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Keterangan & Sistem Poin',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final (text, color) in items)
                Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================== WIDGET STATELESS: LAGA =====================

class _MatchListView extends StatelessWidget {
  const _MatchListView({
    required this.grouped,
    required this.isLocked,
    required this.chessBestOf,
    required this.columns,
    required this.gap,
    required this.sidePadding,
    required this.onTapMatch,
  });

  final Map<String, List<PertandinganModel>> grouped;
  final bool isLocked;
  final int? chessBestOf;
  final int columns;
  final double gap;
  final double sidePadding;
  final ValueChanged<PertandinganModel> onTapMatch;

  @override
  Widget build(BuildContext context) {
    if (grouped.isEmpty) return const _EmptyText('Belum ada pertandingan');

    final rounds = grouped.entries.toList();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 20),
      itemCount: rounds.length,
      itemBuilder: (context, index) {
        final round = rounds[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundHeader(title: round.key, count: round.value.length),
            // Kartu laga: 1 kolom di HP, 2 kolom di layar lebar
            ResponsiveGrid(
              columns: columns,
              gap: gap,
              children: [
                for (final m in round.value)
                  _MatchCard(
                    match: m,
                    isLocked: isLocked,
                    chessBestOf: chessBestOf,
                    onTap: () => onTapMatch(m),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RoundHeader extends StatelessWidget {
  const _RoundHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.sports_esports_rounded, size: 16, color: AppColors.secondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text('$count Laga', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.isLocked,
    required this.chessBestOf,
    required this.onTap,
  });

  final PertandinganModel match;
  final bool isLocked;
  final int? chessBestOf;
  final VoidCallback onTap;

  /// Menang kalau skor lebih tinggi, atau seri tapi menang adu penalti.
  bool _wins(int own, int other, int? ownPen, int? otherPen) {
    if (match.status != 'Selesai') return false;
    if (own > other) return true;
    return own == other && ownPen != null && otherPen != null && ownPen > otherPen;
  }

  @override
  Widget build(BuildContext context) {
    final m = match;
    final isFinished = m.status == 'Selesai';
    final (score1, score2) = _scoreTexts(m, chessBestOf);
    final badgeColor = statusColor(m.status, fallback: AppColors.textMuted);
    final Color borderColor;
    if (isLocked) {
      borderColor = Colors.white.withValues(alpha: 0.04);
    } else if (isFinished) {
      borderColor = AppColors.success.withValues(alpha: 0.2);
    } else {
      borderColor = Colors.white.withValues(alpha: 0.06);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Laga #${m.urutan}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m.status,
                        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isLocked ? Icons.lock_rounded : Icons.edit_note_rounded,
                      size: isLocked ? 14 : 16,
                      color: isLocked ? AppColors.textMuted : AppColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ScoreLine(
                  name: m.displayNama1 ?? 'TBD',
                  score: score1,
                  isWinner: _wins(m.skorPeserta1, m.skorPeserta2,
                      m.skorPenaltiPeserta1, m.skorPenaltiPeserta2),
                  isFinished: isFinished,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _ScoreLine(
                  name: m.displayNama2 ?? 'TBD',
                  score: score2,
                  isWinner: _wins(m.skorPeserta2, m.skorPeserta1,
                      m.skorPenaltiPeserta2, m.skorPenaltiPeserta1),
                  isFinished: isFinished,
                ),
                if (m.skorPenaltiPeserta1 != null && m.skorPenaltiPeserta2 != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Adu penalti ${m.skorPenaltiPeserta1}-${m.skorPenaltiPeserta2}',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== WIDGET STATELESS: PESERTA =====================

class _PesertaTile extends StatelessWidget {
  const _PesertaTile({required this.number, required this.nama});

  final int number;
  final String nama;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _cardDecoration(radius: 14, borderAlpha: 0.05),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: _primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nama,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.shield_outlined, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
