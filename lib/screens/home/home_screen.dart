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
import '../widgets/common_widgets.dart';

const _sourcePrivate = '🔒 Privat (Lokal)';
const _sourcePublic = '🌐 Publik (Server)';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  int _currentNavIndex = 0; // 0 = Turnamen Aktif, 1 = Riwayat
  String _selectedFilter = 'Semua';
  String _selectedSourceFilter = 'Semua';
  bool _isLoading = true;
  String? _errorMessage;
  bool _backendOffline = false;
  List<TurnamenModel> _tournaments = [];

  bool get _isHistory => _currentNavIndex == 1;

  // Provider: user diambil dari AuthProvider
  Map<String, dynamic>? get _currentUser => context.read<AuthProvider>().user;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
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
      _backendOffline = false;
    });

    final query = _searchController.text.trim();

    // 1. Turnamen privat dari SQLite lokal
    var localData = <TurnamenModel>[];
    try {
      final local = LocalTournamentService.instance;
      final emailUser = _currentUser?['email']?.toString() ?? '';
      localData = _isHistory
          ? await local.getRiwayatTurnamen(search: query, emailUser: emailUser)
          : await local.getTurnamenAktif(
              search: query,
              statusFilter: _selectedFilter,
              emailUser: emailUser,
            );
    } catch (e) {
      debugPrint('Error memuat turnamen lokal: $e');
    }

    // 2. Turnamen publik dari backend
    var remoteData = <TurnamenModel>[];
    String? backendError;
    try {
      final api = ApiService.instance;
      remoteData = _isHistory
          ? await api.getRiwayatTurnamen(search: query)
          : await api.getTurnamenAktif(search: query, statusFilter: _selectedFilter);
    } catch (e) {
      backendError = errorText(e);
    }

    // 3. Gabungkan, filter sumber, urutkan dari yang terbaru
    final combined = [
      for (final t in [...localData, ...remoteData])
        if (_selectedSourceFilter == 'Semua' ||
            t.isPrivate == (_selectedSourceFilter == _sourcePrivate))
          t,
    ]..sort((a, b) => b.tanggalMulai.compareTo(a.tanggalMulai));

    if (!mounted) return;
    setState(() {
      _tournaments = combined;
      _isLoading = false;
      _backendOffline = backendError != null;
      _errorMessage = combined.isEmpty && _selectedSourceFilter != _sourcePrivate
          ? backendError
          : null;
    });
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
    if (!mounted) return;
    await context.read<AuthProvider>().loadSession();
    if (mounted) _loadTournaments();
  }

  void _promptLogin() {
    showLoginRequiredDialog(
      message: 'Fitur pencarian turnamen hanya dapat digunakan oleh pengguna yang '
          'telah login. Silakan masuk ke akun Anda.',
      onLogin: _openLogin,
    );
  }

  void _changeTab(int index) {
    setState(() {
      _currentNavIndex = index;
      _selectedFilter = 'Semua';
      _searchController.clear();
    });
    _loadTournaments();
  }

  // ===================== DIALOG (GetX) =====================

  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: ApiConfig.baseUrl);

    Get.dialog(
      AppDialog(
        leading: const Icon(Icons.dns_rounded, color: AppColors.secondary, size: 22),
        title: 'Pengaturan Server API',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '• Emulator Android: http://10.0.2.2:3000/api\n'
                '• Windows/Web: http://localhost:3000/api\n'
                '• HP Fisik: http://IP_LAPTOP:3000/api',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          DialogTextButton(
            'Reset Default',
            onPressed: () {
              ApiConfig.resetToDefault();
              Get.back();
              _loadTournaments();
            },
          ),
          DialogFilledButton(
            'Simpan',
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ApiConfig.baseUrl = controller.text.trim();
              }
              Get.back();
              _loadTournaments();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    // Provider: logout lewat AuthProvider
    await context.read<AuthProvider>().logout();
    if (Get.isDialogOpen ?? false) Get.back();
    if (!mounted) return;

    _searchController.clear();
    _loadTournaments();
    context.showSnack('Anda telah keluar akun dan kembali ke mode tamu.');
  }

  void _showUserProfileDialog() {
    final user = _currentUser;

    Get.dialog(
      AppDialog(
        leading: CircleAvatar(
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
        title: user != null ? 'Profil Pengguna' : 'Belum Masuk Akun',
        content: user != null ? _ProfileInfo(user: user) : null,
        message: 'Anda belum masuk akun. Masuk akun agar data turnamen offline '
            'dapat dikaitkan dengan profil Anda.',
        actions: user != null
            ? [
                DialogTextButton('Keluar Akun', color: AppColors.error, onPressed: _logout),
                DialogFilledButton('Tutup', onPressed: () => Get.back()),
              ]
            : [
                const DialogTextButton('Batal'),
                DialogFilledButton(
                  'Login Sekarang',
                  onPressed: () {
                    Get.back();
                    _openLogin();
                  },
                ),
              ],
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    // Provider: rebuild otomatis saat status login berubah
    final user = context.watch<AuthProvider>().user;
    final isGuest = user == null;
    final layout = PageLayout.of(context);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: _AppBarTitle(
          title: _isHistory ? 'Riwayat Turnamen' : 'RivNet Turnamen',
          fontSize: layout.isNarrow ? 16 : 18,
        ),
        actions: [_ProfileButton(user: user, onPressed: _showUserProfileDialog)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Baris 1: pencarian
            Padding(
              padding: EdgeInsets.fromLTRB(
                layout.sidePadding,
                layout.isShort ? 8 : 12,
                layout.sidePadding,
                8,
              ),
              child: _SearchBar(
                controller: _searchController,
                isGuest: isGuest,
                hintText: isGuest
                    ? 'Login untuk mencari turnamen...'
                    : (_isHistory ? 'Cari riwayat turnamen...' : 'Cari turnamen aktif...'),
                onLocked: _promptLogin,
                onChanged: _loadTournaments,
                onClear: () {
                  _searchController.clear();
                  _loadTournaments();
                },
              ),
            ),

            // Baris 2: filter (rata kiri)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: layout.sidePadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FilterChips(
                      filters: const ['Semua', _sourcePrivate, _sourcePublic],
                      selected: _selectedSourceFilter,
                      onSelected: (value) {
                        setState(() => _selectedSourceFilter = value);
                        _loadTournaments();
                      },
                    ),
                    if (!_isHistory) ...[
                      const SizedBox(height: 8),
                      _FilterChips(
                        small: true,
                        filters: const ['Semua', 'Akan Datang', 'Berlangsung'],
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
            ),

            if (_backendOffline)
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
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: _changeTab,
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
      floatingActionButton: _isHistory
          ? null
          : FloatingActionButton.extended(
              onPressed: _openBuatTurnamen,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Buat Turnamen',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  Widget _buildContent(PageLayout layout) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_errorMessage != null) {
      return StateMessage(
        icon: Icons.cloud_off_rounded,
        iconColor: AppColors.error,
        title: 'Gagal Terhubung ke Backend',
        message: _errorMessage!,
        actions: [
          OutlinedButton.icon(
            onPressed: _showServerSettingsDialog,
            icon: const Icon(Icons.settings_rounded, size: 16),
            label: const Text('Ganti URL API'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary),
          ),
          ElevatedButton.icon(
            onPressed: _loadTournaments,
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
            label: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      );
    }
    if (_tournaments.isEmpty) {
      return StateMessage(
        icon: _isHistory ? Icons.history_toggle_off_rounded : Icons.emoji_events_outlined,
        title: _isHistory ? 'Belum Ada Riwayat Turnamen' : 'Belum Ada Turnamen Aktif',
        message: _isHistory
            ? 'Turnamen yang telah selesai akan otomatis muncul di sini.'
            : 'Klik tombol "Buat Turnamen" di bawah untuk memulai turnamen baru.',
      );
    }

    // Jumlah kolom kartu dari MediaQuery: HP = 1, tablet = 2, layar lebar = 3.
    final columns = layout.contentWidth >= 900 ? 3 : (layout.isWide ? 2 : 1);
    // Kotak ikon status = 13% lebar kartu, dibatasi 40–56 dp.
    final iconBoxSize = (layout.contentWidth / columns * 0.13).clamp(40.0, 56.0);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadTournaments,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(layout.sidePadding, 4, layout.sidePadding, 80),
        children: [
          ResponsiveGrid(
            columns: columns,
            gap: layout.gap,
            children: [
              for (final t in _tournaments)
                _TournamentCard(
                  turnamen: t,
                  iconBoxSize: iconBoxSize,
                  titleFontSize: layout.isNarrow ? 14 : 15,
                  onTap: () => _openDetail(t),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================== WIDGET STATELESS =====================

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.title, required this.fontSize});

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
    final user = this.user;

    return IconButton(
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: user != null
            ? privateColor.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        child: Icon(
          user != null
              ? AvatarHelper.getIcon(user['avatar_index'] as int?)
              : Icons.person_outline_rounded,
          size: 16,
          color: user != null ? privateColor : AppColors.textSecondary,
        ),
      ),
      tooltip: user != null ? (user['nickname']?.toString() ?? 'Profil') : 'Masuk',
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
        const ColorBadge(
          text: 'Sesi Login Tersimpan di HP (Offline-Ready)',
          color: privateColor,
          icon: Icons.check_circle_rounded,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
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
        // Tamu tidak bisa mengetik: ketukan membuka dialog login.
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
              : controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                      onPressed: onClear,
                    )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// Chip filter. Normal untuk sumber data, [small] untuk filter status.
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filters,
    required this.selected,
    required this.onSelected,
    this.small = false,
  });

  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool small;

  Widget _chip(String filter) {
    final isSelected = filter == selected;
    final Color borderColor;
    if (small) {
      borderColor = isSelected ? AppColors.secondary : Colors.transparent;
    } else {
      borderColor = isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.06);
    }

    return ChoiceChip(
      label: Text(filter),
      selected: isSelected,
      onSelected: (_) => onSelected(filter),
      backgroundColor: small ? AppColors.bgDarkSecondary : AppColors.bgCard,
      selectedColor: small
          ? AppColors.secondary.withValues(alpha: 0.3)
          : (filter == _sourcePrivate ? privateColorDark : AppColors.primary),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (small ? AppColors.textMuted : AppColors.textSecondary),
        fontSize: small ? 11 : 12,
        fontWeight: isSelected
            ? FontWeight.bold
            : (small ? FontWeight.normal : FontWeight.w500),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(small ? 8 : 10),
        side: BorderSide(color: borderColor),
      ),
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 8)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap: di HP chip turun ke baris berikut kalau tidak muat.
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [for (final filter in filters) _chip(filter)],
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

  static IconData _statusIcon(String status) => switch (status) {
        'Berlangsung' => Icons.play_circle_fill_rounded,
        'Selesai' => Icons.emoji_events_rounded,
        _ => Icons.schedule_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = turnamen;
    final color = statusColor(t.status);
    final tanggal = DateFormat('dd MMM yyyy, HH:mm').format(t.tanggalMulai);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.isPrivate
              ? privateColor.withValues(alpha: 0.25)
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
                  child: Icon(_statusIcon(t.status), color: color, size: iconBoxSize * 0.5),
                ),
                const SizedBox(width: 12),
                // Kolom 2: info turnamen (ambil sisa lebar)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrivacyBadge(isPrivate: t.isPrivate, small: true),
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
                        '${t.tipeGame} · ${t.kuota} Tim · $tanggal',
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
                ColorBadge(text: t.status, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
