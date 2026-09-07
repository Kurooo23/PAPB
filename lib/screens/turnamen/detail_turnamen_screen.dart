import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/pertandingan_model.dart';
import '../../data/models/peserta_model.dart';
import '../../data/models/turnamen_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';
import '../pertandingan/input_skor_dialog.dart';
import 'edit_turnamen_screen.dart';

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
          // Fallback coba muat dari database SQLite lokal jika gagal di backend
          try {
            detail = await _localService.getTurnamenDetail(widget.idTurnamen);
            _isPrivate = true;
          } catch (_) {
            rethrow;
          }
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
    final Map<String, KlasemenItem> stats = {};
    for (final p in _pesertaList) {
      stats[p.idPeserta] = KlasemenItem(
        idPeserta: p.idPeserta,
        namaPeserta: p.namaPeserta,
      );
    }

    for (final m in _pertandinganList) {
      if (m.status == 'Selesai' && m.idPeserta1 != null && m.idPeserta2 != null) {
        final p1 = stats[m.idPeserta1];
        final p2 = stats[m.idPeserta2];

        if (p1 != null && p2 != null) {
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
      }
    }

    final list = stats.values.toList();
    list.sort((a, b) {
      if (b.poin != a.poin) return b.poin.compareTo(a.poin);
      if (b.sg != a.sg) return b.sg.compareTo(a.sg);
      if (b.gm != a.gm) return b.gm.compareTo(a.gm);
      if (b.menang != a.menang) return b.menang.compareTo(a.menang);
      return a.namaPeserta.compareTo(b.namaPeserta);
    });

    return list;
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
            Text('Hapus Turnamen', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: Text(
          _isPrivate
              ? 'Apakah kamu yakin ingin menghapus turnamen "${_turnamen?.namaTurnamen}"? Semua data peserta dan jadwal pertandingan di database lokal HP akan dihapus secara permanen.'
              : 'Apakah kamu yakin ingin menghapus turnamen "${_turnamen?.namaTurnamen}"? Semua data peserta dan jadwal pertandingan di server backend akan dihapus secara permanen.',
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

    if (confirm == true) {
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
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _openInputSkor(PertandinganModel match) {
    if (match.idPeserta1 == null || match.idPeserta2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peserta pertandingan ini belum ditentukan (menunggu babak sebelumnya).'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => InputSkorDialog(
        match: match,
        isPrivate: _isPrivate,
        onSaved: _loadData,
      ),
    );
  }

  Color _getStatusColor(String status) {
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text(_errorMessage ?? 'Data tidak ditemukan',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final t = _turnamen!;
    final statusColor = _getStatusColor(t.status);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final selesaiCount = _pertandinganList.where((m) => m.status == 'Selesai').length;
    final totalCount = _pertandinganList.length;
    final double progress = totalCount > 0 ? (selesaiCount / totalCount) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(
          t.namaTurnamen,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.textPrimary),
            tooltip: 'Edit Turnamen',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTurnamenScreen(turnamen: t),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
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
            // === HEADER INFO CARD MODERN ===
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              padding: const EdgeInsets.all(16),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t.status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isPrivate
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isPrivate
                                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                    : AppColors.secondary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                                  size: 11,
                                  color: _isPrivate ? const Color(0xFF10B981) : AppColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isPrivate ? 'Privat (Lokal HP)' : 'Publik',
                                  style: TextStyle(
                                    color: _isPrivate ? const Color(0xFF10B981) : AppColors.secondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Format & Kuota Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${t.tipeGame} · ${t.kuota} Peserta · ${t.formatBracket} (${t.jumlahLeg == 2 ? "2 Leg Home & Away" : "1 Leg"})',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(t.tanggalMulai),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  if (t.deskripsi != null && t.deskripsi!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      t.deskripsi!,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Progress Bar Laga
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progress Turnamen',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
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
                  ),
                ],
              ),
            ),

            // === TAB BAR MODERN ===
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF4F46E5)],
                  ),
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
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.leaderboard_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Klasemen'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sports_esports_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Laga (${_pertandinganList.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.groups_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Peserta (${_pesertaList.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildKlasemenTab(),
                  _buildPertandinganTab(),
                  _buildPesertaTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === TAB KLASEMEN / STANDINGS YANG DIPERBAGUS ===
  Widget _buildKlasemenTab() {
    final klasemen = _calculateKlasemen();
    if (klasemen.isEmpty) {
      return const Center(
        child: Text('Belum ada data klasemen', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // Card Tabel Klasemen
        Container(
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
              // Header Table Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text('#', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Expanded(
                      child: Text('KLUB / PESERTA', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('M', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('W', textAlign: TextAlign.center, style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('D', textAlign: TextAlign.center, style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('L', textAlign: TextAlign.center, style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    SizedBox(
                      width: 38,
                      child: Text('+/-', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text('PTS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),

              // Rows Klasemen
              ...List.generate(klasemen.length, (index) {
                final item = klasemen[index];
                final rank = index + 1;
                final isLast = index == klasemen.length - 1;

                // Rank Badge Widget
                Widget rankWidget;
                Color? rowBgColor;

                if (rank == 1) {
                  rowBgColor = const Color(0xFFFFD700).withValues(alpha: 0.05);
                  rankWidget = Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFF59E0B)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('1', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  );
                } else if (rank == 2) {
                  rowBgColor = const Color(0xFFC0C0C0).withValues(alpha: 0.03);
                  rankWidget = Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFE2E8F0), Color(0xFF94A3B8)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('2', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  );
                } else if (rank == 3) {
                  rowBgColor = const Color(0xFFCD7F32).withValues(alpha: 0.03);
                  rankWidget = Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFF97316), Color(0xFFB45309)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  );
                } else {
                  rankWidget = Text('$rank', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12));
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: rowBgColor ?? (index.isEven ? Colors.white.withValues(alpha: 0.015) : Colors.transparent),
                    borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(16)) : null,
                    border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
                  ),
                  child: Row(
                    children: [
                      // Posisi
                      SizedBox(
                        width: 32,
                        child: rankWidget,
                      ),
                      // Nama Peserta / Tim
                      Expanded(
                        child: Text(
                          item.namaPeserta,
                          style: TextStyle(
                            color: rank == 1 ? const Color(0xFFFFD700) : AppColors.textPrimary,
                            fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Main
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${item.main}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Menang (W)
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${item.menang}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      // Seri (D)
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${item.seri}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                      // Kalah (L)
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${item.kalah}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                      // Selisih Skor (+/-)
                      SizedBox(
                        width: 38,
                        child: Text(
                          item.sg > 0 ? '+${item.sg}' : '${item.sg}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: item.sg > 0 ? AppColors.success : (item.sg < 0 ? AppColors.error : AppColors.textSecondary),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // PTS
                      SizedBox(
                        width: 42,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            gradient: rank == 1
                                ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)])
                                : null,
                            color: rank != 1 ? AppColors.primary.withValues(alpha: 0.2) : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.poin}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Keterangan / Legend Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: AppColors.secondary),
                  SizedBox(width: 6),
                  Text(
                    'Keterangan & Sistem Poin',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('• M = Main', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  Text('• W = Menang (3 Poin)', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                  Text('• D = Seri (1 Poin)', style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  Text('• L = Kalah (0 Poin)', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: 4),
              Text(
                '• +/- = Selisih Skor Masuk vs Kemasukan | PTS = Total Poin',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // === TAB PERTANDINGAN YANG LEBIH BAGUS ===
  Widget _buildPertandinganTab() {
    if (_pertandinganList.isEmpty) {
      return const Center(
        child: Text('Belum ada pertandingan', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final Map<String, List<PertandinganModel>> grouped = {};
    for (final match in _pertandinganList) {
      grouped.putIfAbsent(match.babak, () => []).add(match);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final babak = grouped.keys.elementAt(index);
        final matchesInRound = grouped[babak]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
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
                  Text(
                    babak,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${matchesInRound.length} Laga',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            ...matchesInRound.map((m) => _buildMatchCard(m)),
          ],
        );
      },
    );
  }

  Widget _buildMatchCard(PertandinganModel match) {
    final p1Name = match.namaPeserta1 ?? 'TBD';
    final p2Name = match.namaPeserta2 ?? 'TBD';
    final isFinished = match.status == 'Selesai';
    final isP1Winner = isFinished && match.skorPeserta1 > match.skorPeserta2;
    final isP2Winner = isFinished && match.skorPeserta2 > match.skorPeserta1;

    Color badgeColor = AppColors.textMuted;
    if (match.status == 'Berlangsung') badgeColor = AppColors.secondary;
    if (match.status == 'Selesai') badgeColor = AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFinished ? AppColors.success.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
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
          onTap: () => _openInputSkor(match),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Laga #${match.urutan}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            match.status,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.secondary),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildParticipantRow(p1Name, match.skorPeserta1, isP1Winner, isFinished),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                _buildParticipantRow(p2Name, match.skorPeserta2, isP2Winner, isFinished),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantRow(String name, int score, bool isWinner, bool isFinished) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (isWinner)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 16),
                ),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: isWinner
                        ? const Color(0xFFFFD700)
                        : (isFinished ? AppColors.textSecondary : AppColors.textPrimary),
                    fontSize: 13,
                    fontWeight: isWinner ? FontWeight.bold : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
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

  // === TAB PESERTA YANG LEBIH BAGUS ===
  Widget _buildPesertaTab() {
    if (_pesertaList.isEmpty) {
      return const Center(
        child: Text('Belum ada peserta terdaftar', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: _pesertaList.length,
      itemBuilder: (context, index) {
        final p = _pesertaList[index];
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
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.namaPeserta,
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
      },
    );
  }
}
