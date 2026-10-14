import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/pertandingan_model.dart';
import '../../data/models/peserta_model.dart';
import '../../data/models/turnamen_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';
import '../../routes/app_routes.dart';
import '../pertandingan/input_skor_dialog.dart';

class KlasemenItem {
  final String idPeserta;
  final String namaPeserta;
  int main;
  int menang;
  int seri;
  int kalah;
  int gm; // Gol/Skor Masuk
  int gk; // Gol/Skor Kemasukan
  int get sg => gm - gk; // Selisih Skor
  int get poin => (menang * 3) + (seri * 1);

  KlasemenItem({
    required this.idPeserta,
    required this.namaPeserta,
    this.main = 0,
    this.menang = 0,
    this.seri = 0,
    this.kalah = 0,
    this.gm = 0,
    this.gk = 0,
  });
}

/// Ukuran layout detail dihitung dari MediaQuery.
/// - Padding samping = 4% lebar layar, isi dibatasi 1100 dp.
/// - Daftar laga & peserta: 1 kolom di HP, 2 kolom (1:1) di layar >= 720 dp.
/// - Lebar kolom bagan = 62% lebar layar (200–280 dp), bukan angka tetap.
class _DetailLayout {
  const _DetailLayout._({
    required this.sidePadding,
    required this.listColumns,
    required this.gap,
    required this.bracketColumnWidth,
    required this.bracketConnectorWidth,
    required this.showTabIcons,
  });

  factory _DetailLayout.of(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    const maxContentWidth = 1100.0;

    final contentWidth =
        screen.width > maxContentWidth ? maxContentWidth : screen.width;
    final extraSpace =
        screen.width > maxContentWidth ? (screen.width - maxContentWidth) / 2 : 0.0;

    return _DetailLayout._(
      sidePadding: extraSpace + contentWidth * 0.04,
      listColumns: contentWidth >= 720 ? 2 : 1,
      gap: contentWidth * 0.03,
      bracketColumnWidth: (contentWidth * 0.62).clamp(200.0, 280.0),
      bracketConnectorWidth: (contentWidth * 0.07).clamp(20.0, 40.0),
      // Di layar sempit ikon tab disembunyikan supaya label tidak terpotong.
      showTabIcons: screen.width >= 380,
    );
  }

  final double sidePadding;
  final int listColumns;
  final double gap;
  final double bracketColumnWidth;
  final double bracketConnectorWidth;
  final bool showTabIcons;
}

class DetailTurnamenScreen extends StatefulWidget {
  final String idTurnamen;
  final bool? isPrivate;

  const DetailTurnamenScreen({
    super.key,
    required this.idTurnamen,
    this.isPrivate,
  });

  @override
  State<DetailTurnamenScreen> createState() => _DetailTurnamenScreenState();
}

class _DetailTurnamenScreenState extends State<DetailTurnamenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TurnamenModel? _turnamen;
  List<PertandinganModel> _pertandinganList = [];
  List<PesertaModel> _pesertaList = [];
  bool _isLoading = true;
  String? _errorMessage;
  late bool _isPrivate;

  bool get _isKnockoutFormat =>
      _turnamen?.formatBracket == 'Single Elimination' ||
      _turnamen?.formatBracket == 'Double Elimination';

  final ApiService _apiService = ApiService.instance;
  final LocalTournamentService _localService = LocalTournamentService.instance;

  @override
  void initState() {
    super.initState();
    _isPrivate = widget.isPrivate ?? false;
    _tabController = TabController(length: 3, vsync: this);
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

    try {
      Map<String, dynamic> detail;
      if (_isPrivate) {
        detail = await _localService.getTurnamenDetail(widget.idTurnamen);
      } else {
        try {
          detail = await _apiService.getTurnamenDetail(widget.idTurnamen);
        } catch (e) {
          // Fallback ke SQLite lokal kalau backend gagal
          detail = await _localService.getTurnamenDetail(widget.idTurnamen);
          _isPrivate = true;
        }
      }

      if (mounted) {
        final loadedTurnamen = detail['turnamen'] as TurnamenModel;
        setState(() {
          _turnamen = loadedTurnamen;
          _isPrivate = loadedTurnamen.isPrivate;
          _pesertaList = detail['peserta'] as List<PesertaModel>;
          _pertandinganList = detail['pertandingan'] as List<PertandinganModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<KlasemenItem> _calculateKlasemen() {
    final Map<String, KlasemenItem> stats = {
      for (final p in _pesertaList)
        p.idPeserta: KlasemenItem(idPeserta: p.idPeserta, namaPeserta: p.namaPeserta),
    };

    for (final m in _pertandinganList) {
      if (m.status != 'Selesai' || m.idPeserta1 == null || m.idPeserta2 == null) continue;
      final p1 = stats[m.idPeserta1];
      final p2 = stats[m.idPeserta2];
      if (p1 == null || p2 == null) continue;

      p1.main++;
      p2.main++;
      p1.gm += m.skorPeserta1;
      p1.gk += m.skorPeserta2;
      p2.gm += m.skorPeserta2;
      p2.gk += m.skorPeserta1;

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

    final list = stats.values.toList()
      ..sort((a, b) {
        if (b.poin != a.poin) return b.poin.compareTo(a.poin);
        if (b.sg != a.sg) return b.sg.compareTo(a.sg);
        if (b.gm != a.gm) return b.gm.compareTo(a.gm);
        if (b.menang != a.menang) return b.menang.compareTo(a.menang);
        return a.namaPeserta.compareTo(b.namaPeserta);
      });
    return list;
  }

  Map<String, List<PertandinganModel>> _groupedMatches() {
    final Map<String, List<PertandinganModel>> grouped = {};
    for (final match in _pertandinganList) {
      final roundName = _isKnockoutFormat
          ? match.babak.replaceFirst(RegExp(r'^Leg [12] - '), '')
          : match.babak;
      grouped.putIfAbsent(roundName, () => []).add(match);
    }

    if (!_isKnockoutFormat) return grouped;

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDarkSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Hapus Turnamen',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus turnamen "${_turnamen?.namaTurnamen}"? '
          'Semua data peserta dan jadwal pertandingan di '
          '${_isPrivate ? 'database lokal HP' : 'server backend'} akan dihapus secara permanen.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (_isPrivate) {
        await _localService.deleteTurnamen(widget.idTurnamen);
      } else {
        await _apiService.deleteTurnamen(widget.idTurnamen);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isPrivate
                ? 'Turnamen berhasil dihapus dari database lokal HP'
                : 'Turnamen berhasil dihapus dari backend server'),
            backgroundColor: AppColors.success,
          ),
        );
        // Push/Pop: kembali + bawa hasil
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _openInputSkor(PertandinganModel match) {
    if (_turnamen?.isLocked == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turnamen telah diakhiri. Skor tidak dapat diedit lagi.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (match.idPeserta1 == null || match.idPeserta2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peserta pertandingan ini belum ditentukan (menunggu babak sebelumnya).'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    int? previousLegScore1;
    int? previousLegScore2;
    if (_turnamen?.jumlahLeg == 2 && match.babak.startsWith('Leg 2 - ')) {
      final roundName = match.babak.replaceFirst('Leg 2 - ', '');
      for (final previousLeg in _pertandinganList) {
        if (previousLeg.babak == 'Leg 1 - $roundName' &&
            previousLeg.idPeserta1 == match.idPeserta2 &&
            previousLeg.idPeserta2 == match.idPeserta1) {
          previousLegScore1 = previousLeg.skorPeserta2;
          previousLegScore2 = previousLeg.skorPeserta1;
          break;
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => InputSkorDialog(
        match: match,
        isPrivate: _isPrivate,
        isKnockout: _turnamen?.formatBracket == 'Single Elimination',
        isTwoLeg: _turnamen?.jumlahLeg == 2,
        previousLegScore1: previousLegScore1,
        previousLegScore2: previousLegScore2,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _akhiriTurnamen() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDarkSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Akhiri Turnamen?',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Setelah turnamen diakhiri, semua skor akan dikunci dan tidak dapat diedit lagi.\n\nApakah kamu yakin ingin mengakhiri turnamen ini?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Akhiri Turnamen', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final updated = _turnamen!.copyWith(status: 'Selesai', isLocked: true);
      if (_isPrivate) {
        await _localService.updateTurnamen(updated);
      } else {
        await _apiService.updateTurnamen(updated);
      }
      if (mounted) {
        setState(() => _turnamen = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turnamen telah diakhiri! Skor telah dikunci.'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengakhiri turnamen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    final layout = _DetailLayout.of(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_errorMessage != null || _turnamen == null) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(title: const Text('Detail Turnamen')),
        body: _ErrorView(
          message: _errorMessage ?? 'Data tidak ditemukan',
          onRetry: _loadData,
        ),
      );
    }

    final t = _turnamen!;
    final selesaiCount = _pertandinganList.where((m) => m.status == 'Selesai').length;
    final totalCount = _pertandinganList.length;

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
              padding: EdgeInsets.fromLTRB(layout.sidePadding, 8, layout.sidePadding, 12),
              child: _HeaderCard(
                turnamen: t,
                isPrivate: _isPrivate,
                selesaiCount: selesaiCount,
                totalCount: totalCount,
                onAkhiri: _akhiriTurnamen,
              ),
            ),
            // Baris 2: tab bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: layout.sidePadding),
              child: _DetailTabBar(
                controller: _tabController,
                isKnockout: _isKnockoutFormat,
                matchCount: _pertandinganList.length,
                pesertaCount: _pesertaList.length,
                showIcons: layout.showTabIcons,
              ),
            ),
            const SizedBox(height: 12),
            // Baris 3: isi tab (ambil sisa tinggi)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  if (_isKnockoutFormat)
                    _BracketView(
                      matches: _pertandinganList,
                      legCount: t.jumlahLeg,
                      columnWidth: layout.bracketColumnWidth,
                      connectorWidth: layout.bracketConnectorWidth,
                      sidePadding: layout.sidePadding,
                      onTapMatch: _openInputSkor,
                    )
                  else
                    _KlasemenView(
                      klasemen: _calculateKlasemen(),
                      sidePadding: layout.sidePadding,
                    ),
                  _MatchListView(
                    grouped: _groupedMatches(),
                    isLocked: t.isLocked,
                    columns: layout.listColumns,
                    gap: layout.gap,
                    sidePadding: layout.sidePadding,
                    onTapMatch: _openInputSkor,
                  ),
                  _PesertaListView(
                    peserta: _pesertaList,
                    columns: layout.listColumns,
                    gap: layout.gap,
                    sidePadding: layout.sidePadding,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== WIDGET STATELESS: UMUM =====================

/// Susun widget jadi grid N kolom dibagi rata (Row + Expanded).
class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.columns,
    required this.gap,
    required this.children,
  });

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int start = 0; start < children.length; start += columns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < columns; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: start + i < children.length
                      ? children[start + i]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(width * 0.06),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: (width * 0.12).clamp(40.0, 56.0),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

  static Color statusColor(String status) {
    switch (status) {
      case 'Berlangsung':
        return AppColors.secondary;
      case 'Selesai':
        return AppColors.success;
      default:
        return const Color(0xFF818CF8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = turnamen;
    final progress = totalCount > 0 ? selesaiCount / totalCount : 0.0;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final width = MediaQuery.sizeOf(context).width;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((width * 0.04).clamp(12.0, 20.0)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
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
              _StatusPill(status: t.status, color: statusColor(t.status)),
              _PrivacyPill(isPrivate: isPrivate),
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
                text: '${t.kuota} Peserta · ${t.formatBracket} '
                    '(${t.jumlahLeg == 2 ? "2 Leg Home & Away" : "1 Leg"})',
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
                  dateFormat.format(t.tanggalMulai),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          if (t.deskripsi != null && t.deskripsi!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              t.deskripsi!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          _ProgressSection(
            selesaiCount: selesaiCount,
            totalCount: totalCount,
            progress: progress,
          ),
          if (t.isLocked) ...[
            const SizedBox(height: 12),
            const _LockedBanner(),
          ] else if (progress == 1.0 && totalCount > 0) ...[
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPill extends StatelessWidget {
  const _PrivacyPill({required this.isPrivate});

  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    final color = isPrivate ? const Color(0xFF10B981) : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPrivate ? Icons.lock_rounded : Icons.public_rounded, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            isPrivate ? 'Privat (Lokal HP)' : 'Publik',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
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

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.selesaiCount,
    required this.totalCount,
    required this.progress,
  });

  final int selesaiCount;
  final int totalCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? AppColors.success : AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 14, color: AppColors.success),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Turnamen Telah Berakhir — Skor Dikunci',
              style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF4F46E5)]),
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
          _TabLabel(
            icon: isKnockout ? Icons.account_tree_rounded : Icons.leaderboard_rounded,
            text: isKnockout ? 'Bagan' : 'Klasemen',
            showIcon: showIcons,
          ),
          _TabLabel(
            icon: Icons.sports_esports_rounded,
            text: 'Laga ($matchCount)',
            showIcon: showIcons,
          ),
          _TabLabel(
            icon: Icons.groups_rounded,
            text: 'Peserta ($pesertaCount)',
            showIcon: showIcons,
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.icon, required this.text, required this.showIcon});

  final IconData icon;
  final String text;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
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
    required this.columnWidth,
    required this.connectorWidth,
    required this.sidePadding,
    required this.onTapMatch,
  });

  final List<PertandinganModel> matches;
  final int legCount;
  final double columnWidth;
  final double connectorWidth;
  final double sidePadding;
  final ValueChanged<PertandinganModel> onTapMatch;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const _EmptyText('Belum ada pertandingan');

    final matchesByRound = <String, List<PertandinganModel>>{};
    for (final match in [...matches]..sort((a, b) => a.urutan.compareTo(b.urutan))) {
      final roundName = match.babak.replaceFirst(RegExp(r'^Leg [12] - '), '');
      matchesByRound.putIfAbsent(roundName, () => []).add(match);
    }
    final thirdPlaceMatches = matchesByRound.remove('Perebutan Juara 3') ?? [];
    final roundEntries = matchesByRound.entries.toList()
      ..sort((a, b) {
        if (a.key == 'Final') return 1;
        if (b.key == 'Final') return -1;
        return a.value.first.urutan.compareTo(b.value.first.urutan);
      });

    List<Widget> ties(List<PertandinganModel> list) => [
          for (var i = 0; i < list.length; i += legCount)
            _BracketTie(
              legs: list.skip(i).take(legCount).toList(),
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
            for (final roundEntry in roundEntries) ...[
              // Lebar kolom babak dari MediaQuery, bukan 236 tetap
              SizedBox(
                width: columnWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RoundTitle(roundEntry.key),
                    ...ties(roundEntry.value),
                    if (roundEntry.key.contains('Semifinal') &&
                        thirdPlaceMatches.isNotEmpty) ...[
                      const _RoundTitle('Perebutan Juara 3', topPadding: 4),
                      ...ties(thirdPlaceMatches),
                    ],
                  ],
                ),
              ),
              if (roundEntry.key != roundEntries.last.key)
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
  const _BracketTie({required this.legs, required this.onTap});

  final List<PertandinganModel> legs;
  final ValueChanged<PertandinganModel> onTap;

  @override
  Widget build(BuildContext context) {
    final firstLeg = legs.first;
    final homeId = firstLeg.idPeserta1;
    final awayId = firstLeg.idPeserta2;
    final homeName = firstLeg.displayNama1 ?? 'Menunggu pemenang';
    final awayName = firstLeg.displayNama2 ?? 'Menunggu pemenang';

    var homeScore = 0;
    var awayScore = 0;
    var allLegsFinished = true;
    for (final leg in legs) {
      allLegsFinished &= leg.status == 'Selesai';
      if (homeId != null && leg.idPeserta1 == homeId) {
        homeScore += leg.skorPeserta1;
        awayScore += leg.skorPeserta2;
      } else if (awayId != null && leg.idPeserta1 == awayId) {
        awayScore += leg.skorPeserta1;
        homeScore += leg.skorPeserta2;
      }
    }

    var homeWon = allLegsFinished && homeScore > awayScore;
    var awayWon = allLegsFinished && awayScore > homeScore;
    if (allLegsFinished && homeScore == awayScore) {
      for (final leg in legs) {
        final penalty1 = leg.skorPenaltiPeserta1;
        final penalty2 = leg.skorPenaltiPeserta2;
        if (penalty1 == null || penalty2 == null) continue;
        final legHomePenalty = leg.idPeserta1 == homeId ? penalty1 : penalty2;
        final legAwayPenalty = leg.idPeserta1 == homeId ? penalty2 : penalty1;
        homeWon = legHomePenalty > legAwayPenalty;
        awayWon = legAwayPenalty > legHomePenalty;
        break;
      }
    }

    final editableLeg = legs.firstWhere(
      (leg) => leg.status != 'Selesai',
      orElse: () => legs.last,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTap(editableLeg),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _BracketParticipant(name: homeName, score: homeScore, isWinner: homeWon),
                const Divider(color: Colors.white10, height: 16),
                _BracketParticipant(name: awayName, score: awayScore, isWinner: awayWon),
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

class _BracketParticipant extends StatelessWidget {
  const _BracketParticipant({required this.name, required this.score, required this.isWinner});

  final String name;
  final int score;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 5),
            child: Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 14),
          ),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isWinner ? const Color(0xFFFFD700) : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$score',
          style: TextStyle(
            color: isWinner ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ===================== WIDGET STATELESS: KLASEMEN =====================

/// Lebar kolom tabel klasemen dihitung dari lebar yang tersedia.
/// Di layar < 360 dp kolom GF & GA disembunyikan supaya nama tetap terbaca.
class _KlasemenCols {
  const _KlasemenCols({
    required this.rank,
    required this.stat,
    required this.goal,
    required this.gd,
    required this.pts,
    required this.showGoals,
  });

  factory _KlasemenCols.fromWidth(double width) {
    final unit = (width * 0.06).clamp(20.0, 36.0);
    return _KlasemenCols(
      rank: unit * 1.2,
      stat: unit,
      goal: unit * 1.1,
      gd: unit * 1.3,
      pts: unit * 1.5,
      showGoals: width >= 360,
    );
  }

  final double rank;
  final double stat;
  final double goal;
  final double gd;
  final double pts;
  final bool showGoals;
}

class _KlasemenView extends StatelessWidget {
  const _KlasemenView({required this.klasemen, required this.sidePadding});

  final List<KlasemenItem> klasemen;
  final double sidePadding;

  @override
  Widget build(BuildContext context) {
    if (klasemen.isEmpty) return const _EmptyText('Belum ada data klasemen');

    return ListView(
      padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 24),
      children: [
        _KlasemenTable(klasemen: klasemen),
        const SizedBox(height: 14),
        const _KlasemenLegend(),
      ],
    );
  }
}

class _KlasemenTable extends StatelessWidget {
  const _KlasemenTable({required this.klasemen});

  final List<KlasemenItem> klasemen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _KlasemenCols.fromWidth(constraints.maxWidth);

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
              _KlasemenHeader(cols: cols),
              for (int i = 0; i < klasemen.length; i++)
                _KlasemenRow(
                  item: klasemen[i],
                  rank: i + 1,
                  isLast: i == klasemen.length - 1,
                  cols: cols,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.text,
    required this.width,
    this.color = AppColors.textSecondary,
    this.bold = true,
  });

  final String text;
  final double width;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
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
}

class _KlasemenHeader extends StatelessWidget {
  const _KlasemenHeader({required this.cols});

  final _KlasemenCols cols;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: cols.rank,
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
          _Cell(text: 'M', width: cols.stat),
          _Cell(text: 'W', width: cols.stat, color: AppColors.success),
          _Cell(text: 'D', width: cols.stat, color: AppColors.secondary),
          _Cell(text: 'L', width: cols.stat, color: AppColors.error),
          if (cols.showGoals) ...[
            _Cell(text: 'GF', width: cols.goal),
            _Cell(text: 'GA', width: cols.goal),
          ],
          _Cell(text: 'GD', width: cols.gd),
          _Cell(text: 'PTS', width: cols.pts, color: Colors.white),
        ],
      ),
    );
  }
}

class _KlasemenRow extends StatelessWidget {
  const _KlasemenRow({
    required this.item,
    required this.rank,
    required this.isLast,
    required this.cols,
  });

  final KlasemenItem item;
  final int rank;
  final bool isLast;
  final _KlasemenCols cols;

  @override
  Widget build(BuildContext context) {
    Color? rowBgColor;
    if (rank == 1) rowBgColor = const Color(0xFFFFD700).withValues(alpha: 0.05);
    if (rank == 2) rowBgColor = const Color(0xFFC0C0C0).withValues(alpha: 0.03);
    if (rank == 3) rowBgColor = const Color(0xFFCD7F32).withValues(alpha: 0.03);

    final gdColor = item.sg > 0
        ? AppColors.success
        : (item.sg < 0 ? AppColors.error : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: rowBgColor ??
            (rank.isOdd ? Colors.white.withValues(alpha: 0.015) : Colors.transparent),
        borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(16)) : null,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(
        children: [
          SizedBox(width: cols.rank, child: _RankBadge(rank: rank)),
          Expanded(
            child: Text(
              item.namaPeserta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: rank == 1 ? const Color(0xFFFFD700) : AppColors.textPrimary,
                fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          _Cell(text: '${item.main}', width: cols.stat, color: AppColors.textPrimary, bold: false),
          _Cell(text: '${item.menang}', width: cols.stat, color: AppColors.success),
          _Cell(text: '${item.seri}', width: cols.stat, color: AppColors.secondary),
          _Cell(text: '${item.kalah}', width: cols.stat, color: AppColors.error),
          if (cols.showGoals) ...[
            _Cell(text: '${item.gm}', width: cols.goal, color: AppColors.textPrimary, bold: false),
            _Cell(text: '${item.gk}', width: cols.goal, color: AppColors.textMuted, bold: false),
          ],
          _Cell(
            text: item.sg > 0 ? '+${item.sg}' : '${item.sg}',
            width: cols.gd,
            color: gdColor,
          ),
          SizedBox(
            width: cols.pts,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                gradient: rank == 1
                    ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)])
                    : null,
                color: rank != 1 ? AppColors.primary.withValues(alpha: 0.2) : null,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '${item.poin}',
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
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    const gradients = {
      1: [Color(0xFFFFD700), Color(0xFFF59E0B)],
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
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          shape: BoxShape.circle,
        ),
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
  const _KlasemenLegend();

  @override
  Widget build(BuildContext context) {
    const items = [
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
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
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
    required this.columns,
    required this.gap,
    required this.sidePadding,
    required this.onTapMatch,
  });

  final Map<String, List<PertandinganModel>> grouped;
  final bool isLocked;
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
            _ResponsiveGrid(
              columns: columns,
              gap: gap,
              children: [
                for (final m in round.value)
                  _MatchCard(match: m, isLocked: isLocked, onTap: () => onTapMatch(m)),
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
          Text(
            '$count Laga',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.isLocked, required this.onTap});

  final PertandinganModel match;
  final bool isLocked;
  final VoidCallback onTap;

  bool _wins(int own, int other, int? ownPen, int? otherPen) {
    if (match.status != 'Selesai') return false;
    if (own > other) return true;
    return own == other && ownPen != null && otherPen != null && ownPen > otherPen;
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = match.status == 'Selesai';
    final isP1Winner = _wins(match.skorPeserta1, match.skorPeserta2,
        match.skorPenaltiPeserta1, match.skorPenaltiPeserta2);
    final isP2Winner = _wins(match.skorPeserta2, match.skorPeserta1,
        match.skorPenaltiPeserta2, match.skorPenaltiPeserta1);

    Color badgeColor = AppColors.textMuted;
    if (match.status == 'Berlangsung') badgeColor = AppColors.secondary;
    if (match.status == 'Selesai') badgeColor = AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocked
              ? Colors.white.withValues(alpha: 0.04)
              : isFinished
                  ? AppColors.success.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
        ),
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
                        'Laga #${match.urutan}',
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
                        match.status,
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
                _ParticipantScoreRow(
                  name: match.displayNama1 ?? 'TBD',
                  score: match.skorPeserta1,
                  isWinner: isP1Winner,
                  isFinished: isFinished,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _ParticipantScoreRow(
                  name: match.displayNama2 ?? 'TBD',
                  score: match.skorPeserta2,
                  isWinner: isP2Winner,
                  isFinished: isFinished,
                ),
                if (match.skorPenaltiPeserta1 != null && match.skorPenaltiPeserta2 != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Adu penalti ${match.skorPenaltiPeserta1}-${match.skorPenaltiPeserta2}',
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

class _ParticipantScoreRow extends StatelessWidget {
  const _ParticipantScoreRow({
    required this.name,
    required this.score,
    required this.isWinner,
    required this.isFinished,
  });

  final String name;
  final int score;
  final bool isWinner;
  final bool isFinished;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 16),
          ),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isWinner
                  ? const Color(0xFFFFD700)
                  : (isFinished ? AppColors.textSecondary : AppColors.textPrimary),
              fontSize: 13,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isWinner ? AppColors.primary.withValues(alpha: 0.35) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isWinner ? AppColors.primary : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Text(
            '$score',
            style: TextStyle(
              color: isWinner ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ===================== WIDGET STATELESS: PESERTA =====================

class _PesertaListView extends StatelessWidget {
  const _PesertaListView({
    required this.peserta,
    required this.columns,
    required this.gap,
    required this.sidePadding,
  });

  final List<PesertaModel> peserta;
  final int columns;
  final double gap;
  final double sidePadding;

  @override
  Widget build(BuildContext context) {
    if (peserta.isEmpty) return const _EmptyText('Belum ada peserta terdaftar');

    return ListView(
      padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 20),
      children: [
        _ResponsiveGrid(
          columns: columns,
          gap: gap,
          children: [
            for (int i = 0; i < peserta.length; i++)
              _PesertaTile(number: i + 1, nama: peserta[i].namaPeserta),
          ],
        ),
      ],
    );
  }
}

class _PesertaTile extends StatelessWidget {
  const _PesertaTile({required this.number, required this.nama});

  final int number;
  final String nama;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF4F46E5)]),
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