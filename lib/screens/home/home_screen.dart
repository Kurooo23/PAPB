import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/avatar_helper.dart';
import '../../data/models/turnamen_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

/// Ukuran layout Home dihitung dari MediaQuery.
/// - Padding samping = 4% lebar layar.
/// - Di layar lebar, isi dibatasi 1100 dp dan diletakkan di tengah.
/// - Jumlah kolom kartu: HP = 1, tablet = 2, layar lebar = 3
///   (tiap kolom dibagi rata 1:1 / 1:1:1 pakai Row + Expanded).
class _HomeLayout {
  const _HomeLayout._({
    required this.sidePadding,
    required this.columns,
    required this.gap,
    required this.iconBoxSize,
    required this.titleFontSize,
    required this.appBarFontSize,
    required this.isCompact,
  });

  factory _HomeLayout.of(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    const maxContentWidth = 1100.0;

    final contentWidth =
        screen.width > maxContentWidth ? maxContentWidth : screen.width;
    final extraSpace =
        screen.width > maxContentWidth ? (screen.width - maxContentWidth) / 2 : 0.0;
    final columns = contentWidth >= 900
        ? 3
        : contentWidth >= 600
            ? 2
            : 1;
    final cardWidth = contentWidth / columns;

    return _HomeLayout._(
      sidePadding: extraSpace + contentWidth * 0.04,
      columns: columns,
      gap: contentWidth * 0.03,
      // Kotak ikon status = 13% lebar kartu, dibatasi 40–56 dp.
      iconBoxSize: (cardWidth * 0.13).clamp(40.0, 56.0),
      titleFontSize: screen.width < 360 ? 14 : 15,
      appBarFontSize: screen.width < 360 ? 16 : 18,
      isCompact: screen.height < 640,
    );
  }

  final double sidePadding;
  final int columns;
  final double gap;
  final double iconBoxSize;
  final double titleFontSize;
  final double appBarFontSize;
  final bool isCompact;
}

const _loginRequiredMessage =
    'Fitur pencarian turnamen hanya dapat digunakan oleh pengguna yang telah login. Silakan masuk ke akun Anda.';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService.instance;
  final LocalTournamentService _localService = LocalTournamentService.instance;

  // Provider: user diambil dari AuthProvider
  Map<String, dynamic>? get _currentUser => context.read<AuthProvider>().user;

  int _currentNavIndex = 0; // 0 = Turnamen Aktif, 1 = Riwayat
  String _selectedFilter = 'Semua';
  String _selectedSourceFilter = 'Semua';
  bool _isLoading = true;
  String? _errorMessage;
  bool _backendOfflineNotice = false;
  List<TurnamenModel> _tournaments = [];

  static const List<String> _filters = ['Semua', 'Akan Datang', 'Berlangsung'];
  static const List<String> _sourceFilters = [
    'Semua',
    '🔒 Privat (Lokal)',
    '🌐 Publik (Server)',
  ];

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadUserSession() async {
    await context.read<AuthProvider>().loadSession();
    if (mounted) _loadTournaments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _backendOfflineNotice = false;
    });

    try {
      final query = _searchController.text.trim();

      // 1. Turnamen privat dari SQLite lokal
      List<TurnamenModel> localData = [];
      try {
        final emailUser = _currentUser?['email']?.toString() ?? '';
        if (_currentNavIndex == 1) {
          localData = await _localService.getRiwayatTurnamen(
            search: query,
            emailUser: emailUser,
          );
        } else {
          localData = await _localService.getTurnamenAktif(
            search: query,
            statusFilter: _selectedFilter,
            emailUser: emailUser,
          );
        }
      } catch (e) {
        debugPrint('Error memuat turnamen lokal: $e');
      }

      // 2. Turnamen publik dari backend
      List<TurnamenModel> remoteData = [];
      String? backendError;
      try {
        if (_currentNavIndex == 1) {
          remoteData = await _apiService.getRiwayatTurnamen(search: query);
        } else {
          remoteData = await _apiService.getTurnamenAktif(
            search: query,
            statusFilter: _selectedFilter,
          );
        }
      } catch (e) {
        backendError = e.toString().replaceFirst('Exception: ', '');
      }

      // 3. Gabungkan dan filter sumber
      List<TurnamenModel> combined = [...localData, ...remoteData];
      if (_selectedSourceFilter == '🔒 Privat (Lokal)') {
        combined = combined.where((t) => t.isPrivate).toList();
      } else if (_selectedSourceFilter == '🌐 Publik (Server)') {
        combined = combined.where((t) => !t.isPrivate).toList();
      }
      combined.sort((a, b) => b.tanggalMulai.compareTo(a.tanggalMulai));

      if (mounted) {
        setState(() {
          _tournaments = combined;
          _isLoading = false;
          _backendOfflineNotice = backendError != null;
          _errorMessage = (combined.isEmpty &&
                  backendError != null &&
                  _selectedSourceFilter != '🔒 Privat (Lokal)')
              ? backendError
              : null;
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

  // ===================== NAVIGASI =====================

  Future<void> _openDetail(TurnamenModel t) async {
    // Named Route + kirim data lewat arguments
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.detailTurnamen,
      arguments: {'idTurnamen': t.idTurnamen, 'isPrivate': t.isPrivate},
    );
    if (result == true || result == null) _loadTournaments();
  }

  Future<void> _openBuatTurnamen() async {
    // GetX
    final result = await Get.toNamed(AppRoutes.buatTurnamen);
    if (result == true) _loadTournaments();
  }

  Future<void> _openLogin() async {
    // Named Route
    await Navigator.pushNamed(context, AppRoutes.login);
    _loadUserSession();
  }

  // ===================== DIALOG =====================

  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: ApiConfig.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDarkSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: AppColors.secondary, size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Pengaturan Server API',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alamat URL Backend Express.js (SQLite):',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bgCard,
                  hintText: 'http://10.0.2.2:3000/api',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '• Emulator Android: http://10.0.2.2:3000/api\n• Windows/Web: http://localhost:3000/api\n• HP Fisik: http://IP_LAPTOP:3000/api',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ApiConfig.resetToDefault();
              Navigator.pop(ctx);
              _loadTournaments();
            },
            child: const Text(
              'Reset Default',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ApiConfig.baseUrl = controller.text.trim();
              }
              Navigator.pop(ctx);
              _loadTournaments();
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUserProfileDialog() {
    final user = _currentUser;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDarkSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Icon(
                user != null
                    ? AvatarHelper.getIcon(user['avatar_index'] as int?)
                    : Icons.person_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                user != null ? 'Profil Pengguna' : 'Belum Masuk Akun',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: user != null
            ? _ProfileInfo(user: user)
            : const Text(
                'Anda belum masuk akun. Masuk akun agar data turnamen offline dapat dikaitkan dengan profil Anda.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
        actions: user != null
            ? [
                TextButton(
                  onPressed: () async {
                    // Provider: logout lewat AuthProvider
                    await context.read<AuthProvider>().logout();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!mounted) return;

                    setState(() => _searchController.clear());
                    _loadTournaments();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Anda telah keluar akun dan kembali ke mode tamu.'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  child: const Text(
                    'Keluar Akun',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup', style: TextStyle(color: Colors.white)),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openLogin();
                  },
                  child: const Text(
                    'Login Sekarang',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
      ),
    );
  }

  void _promptLogin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDarkSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.secondary, size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Login Diperlukan',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          _loginRequiredMessage,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              _openLogin();
            },
            child: const Text(
              'Login Sekarang',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    // Provider: rebuild otomatis saat status login berubah
    context.watch<AuthProvider>();
    final layout = _HomeLayout.of(context);
    final user = _currentUser;
    final isGuest = user == null;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: _HomeAppBarTitle(
          title: _currentNavIndex == 0 ? 'RivNet Turnamen' : 'Riwayat Turnamen',
          fontSize: layout.appBarFontSize,
        ),
        actions: [
          _ProfileButton(user: user, onPressed: _showUserProfileDialog),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Baris 1: pencarian
            Padding(
              padding: EdgeInsets.fromLTRB(
                layout.sidePadding,
                layout.isCompact ? 8 : 12,
                layout.sidePadding,
                8,
              ),
              child: _HomeSearchBar(
                controller: _searchController,
                isGuest: isGuest,
                hintText: isGuest
                    ? 'Login untuk mencari turnamen...'
                    : (_currentNavIndex == 0
                        ? 'Cari turnamen aktif...'
                        : 'Cari riwayat turnamen...'),
                onLocked: _promptLogin,
                onChanged: () {
                  if (isGuest) {
                    _searchController.clear();
                    _promptLogin();
                    return;
                  }
                  _loadTournaments();
                },
                onClear: () {
                  _searchController.clear();
                  _loadTournaments();
                },
              ),
            ),

            // Baris 2: filter
            Padding(
              padding: EdgeInsets.symmetric(horizontal: layout.sidePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SourceFilterChips(
                    filters: _sourceFilters,
                    selected: _selectedSourceFilter,
                    onSelected: (value) {
                      setState(() => _selectedSourceFilter = value);
                      _loadTournaments();
                    },
                  ),
                  if (_currentNavIndex == 0) ...[
                    const SizedBox(height: 8),
                    _StatusFilterChips(
                      filters: _filters,
                      selected: _selectedFilter,
                      onSelected: (value) {
                        setState(() => _selectedFilter = value);
                        _loadTournaments();
                      },
                    ),
                  ],
                ],
              ),
            ),

            if (_backendOfflineNotice)
              Padding(
                padding: EdgeInsets.fromLTRB(layout.sidePadding, 8, layout.sidePadding, 0),
                child: const _OfflineNotice(),
              ),
            const SizedBox(height: 10),

            // Baris 3: daftar turnamen (ambil sisa tinggi layar)
            Expanded(child: _buildContent(layout)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bgDarkSecondary,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            setState(() {
              _currentNavIndex = index;
              _selectedFilter = 'Semua';
              _searchController.clear();
            });
            _loadTournaments();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: AppColors.textMuted,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Daftar Turnamen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'Riwayat Selesai',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentNavIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openBuatTurnamen,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Buat Turnamen',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildContent(_HomeLayout layout) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_errorMessage != null) {
      return _ErrorState(
        message: _errorMessage!,
        onChangeUrl: _showServerSettingsDialog,
        onRetry: _loadTournaments,
      );
    }
    if (_tournaments.isEmpty) {
      return _EmptyState(isHistory: _currentNavIndex == 1);
    }

    final cols = layout.columns;
    final rowCount = (_tournaments.length / cols).ceil();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadTournaments,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(layout.sidePadding, 4, layout.sidePadding, 80),
        itemCount: rowCount,
        itemBuilder: (context, row) {
          final start = row * cols;
          // Satu baris berisi 1/2/3 kartu, lebarnya dibagi rata (Expanded).
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cols; i++) ...[
                if (i > 0) SizedBox(width: layout.gap),
                Expanded(
                  child: start + i < _tournaments.length
                      ? _TournamentCard(
                          turnamen: _tournaments[start + i],
                          iconBoxSize: layout.iconBoxSize,
                          titleFontSize: layout.titleFontSize,
                          onTap: () => _openDetail(_tournaments[start + i]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ===================== WIDGET STATELESS =====================

class _HomeAppBarTitle extends StatelessWidget {
  const _HomeAppBarTitle({required this.title, required this.fontSize});

  final String title;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/icons/rivnet_logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
          ),
        ),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.user, required this.onPressed});

  final Map<String, dynamic>? user;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final loggedIn = user != null;

    return IconButton(
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: loggedIn
            ? const Color(0xFF10B981).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        child: Icon(
          loggedIn
              ? AvatarHelper.getIcon(user!['avatar_index'] as int?)
              : Icons.person_outline_rounded,
          size: 16,
          color: loggedIn ? const Color(0xFF10B981) : AppColors.textSecondary,
        ),
      ),
      tooltip: loggedIn ? (user!['nickname']?.toString() ?? 'Profil') : 'Masuk',
      onPressed: onPressed,
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user['nickname']?.toString() ?? 'Pemain',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user['email']?.toString() ?? '',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Sesi Login Tersimpan di HP (Offline-Ready)',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({
    required this.controller,
    required this.isGuest,
    required this.hintText,
    required this.onLocked,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool isGuest;
  final String hintText;
  final VoidCallback onLocked;
  final VoidCallback onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Tinggi minimal 48 dp, ikut membesar kalau font sistem diperbesar.
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: controller,
        readOnly: isGuest,
        onTap: isGuest ? onLocked : null,
        onChanged: (_) => onChanged(),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(
            isGuest ? Icons.lock_outline_rounded : Icons.search_rounded,
            color: isGuest ? AppColors.secondary : AppColors.textMuted,
            size: 22,
          ),
          suffixIcon: isGuest
              ? TextButton(
                  onPressed: onLocked,
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : (controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 18),
                      onPressed: onClear,
                    )
                  : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SourceFilterChips extends StatelessWidget {
  const _SourceFilterChips({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // Wrap: di HP chip turun ke baris berikut kalau tidak muat,
    // di layar lebar semua chip sebaris.
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final filter in filters)
          ChoiceChip(
            label: Text(filter),
            selected: filter == selected,
            onSelected: (_) => onSelected(filter),
            backgroundColor: AppColors.bgCard,
            selectedColor: filter.contains('Privat')
                ? const Color(0xFF059669)
                : AppColors.primary,
            labelStyle: TextStyle(
              color: filter == selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: filter == selected ? FontWeight.bold : FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: filter == selected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          ),
      ],
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final filter in filters)
          ChoiceChip(
            label: Text(filter),
            selected: filter == selected,
            onSelected: (_) => onSelected(filter),
            backgroundColor: AppColors.bgDarkSecondary,
            selectedColor: AppColors.secondary.withValues(alpha: 0.3),
            labelStyle: TextStyle(
              color: filter == selected ? Colors.white : AppColors.textMuted,
              fontSize: 11,
              fontWeight: filter == selected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: filter == selected ? AppColors.secondary : Colors.transparent,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
      ],
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Backend server offline. Menampilkan turnamen lokal di HP.',
              style: TextStyle(color: AppColors.warning, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({
    required this.turnamen,
    required this.iconBoxSize,
    required this.titleFontSize,
    required this.onTap,
  });

  final TurnamenModel turnamen;
  final double iconBoxSize;
  final double titleFontSize;
  final VoidCallback onTap;

  static const _privateColor = Color(0xFF10B981);

  static Color statusColor(String status) {
    switch (status) {
      case 'Berlangsung':
        return AppColors.secondary;
      case 'Selesai':
        return AppColors.success;
      default:
        return const Color(0xFF6366F1);
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case 'Berlangsung':
        return Icons.play_circle_fill_rounded;
      case 'Selesai':
        return Icons.emoji_events_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = turnamen;
    final color = statusColor(t.status);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.isPrivate
              ? _privateColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Kolom 1: ikon status (ukuran dari MediaQuery)
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon(t.status), color: color, size: iconBoxSize * 0.5),
                ),
                const SizedBox(width: 12),
                // Kolom 2: info turnamen (ambil sisa lebar)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SourceBadge(isPrivate: t.isPrivate),
                      const SizedBox(height: 4),
                      Text(
                        t.namaTurnamen,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.tipeGame} · ${t.kuota} Tim · ${dateFormat.format(t.tanggalMulai)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      if (t.formatBracket.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${t.formatBracket} (${t.jumlahLeg == 2 ? "2 Leg" : "1 Leg"})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Kolom 3: status
                _StatusBadge(status: t.status, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.isPrivate});

  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    final color = isPrivate ? const Color(0xFF10B981) : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPrivate ? Icons.lock_rounded : Icons.public_rounded,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isPrivate ? 'Privat (Lokal HP)' : 'Publik',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isHistory});

  final bool isHistory;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(width * 0.08),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isHistory
                    ? Icons.history_toggle_off_rounded
                    : Icons.emoji_events_outlined,
                color: AppColors.textMuted,
                size: (width * 0.14).clamp(44.0, 64.0),
              ),
              const SizedBox(height: 16),
              Text(
                isHistory ? 'Belum Ada Riwayat Turnamen' : 'Belum Ada Turnamen Aktif',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isHistory
                    ? 'Turnamen yang telah selesai akan otomatis muncul di sini.'
                    : 'Klik tombol "Buat Turnamen" di bawah untuk memulai turnamen baru.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onChangeUrl,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onChangeUrl;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(width * 0.08),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: AppColors.error,
                size: (width * 0.14).clamp(44.0, 64.0),
              ),
              const SizedBox(height: 16),
              const Text(
                'Gagal Terhubung ke Backend',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              // Wrap: dua tombol sebaris, turun ke bawah kalau layar sempit.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onChangeUrl,
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('Ganti URL API'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary),
                  ),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                    label: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}