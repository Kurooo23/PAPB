import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/avatar_helper.dart';
import '../../data/database_helper.dart';
import '../../data/models/turnamen_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';
import '../auth/login_screen.dart';
import '../turnamen/buat_turnamen_screen.dart';
import '../turnamen/detail_turnamen_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const HomeScreen({super.key, this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService.instance;
  final LocalTournamentService _localService = LocalTournamentService.instance;

  Map<String, dynamic>? _currentUser;
  int _currentNavIndex = 0; // 0 = Turnamen Aktif, 1 = Riwayat
  String _selectedFilter = 'Semua';
  String _selectedSourceFilter = 'Semua'; // 'Semua', 'Privat (Lokal)', 'Publik (Server)'
  bool _isLoading = true;
  String? _errorMessage;
  bool _backendOfflineNotice = false;
  List<TurnamenModel> _tournaments = [];

  final List<String> _filters = const [
    'Semua',
    'Akan Datang',
    'Berlangsung',
  ];

  final List<String> _sourceFilters = const [
    'Semua',
    '🔒 Privat (Lokal)',
    '🌐 Publik (Server)',
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadUserSession();
    _loadTournaments();
  }

  Future<void> _loadUserSession() async {
    if (_currentUser == null) {
      final session = await DatabaseHelper.instance.getUserSession();
      if (session != null && mounted) {
        setState(() {
          _currentUser = session;
        });
      }
    } else {
      await DatabaseHelper.instance.saveUserSession(_currentUser!);
    }
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

      // 1. Ambil Turnamen Privat dari Database SQLite Lokal HP
      List<TurnamenModel> localData = [];
      try {
        if (_currentNavIndex == 1) {
          localData = await _localService.getRiwayatTurnamen(search: query);
        } else {
          localData = await _localService.getTurnamenAktif(
            search: query,
            statusFilter: _selectedFilter,
          );
        }
      } catch (e) {
        debugPrint('Error memuat turnamen lokal: $e');
      }

      // 2. Ambil Turnamen Publik dari Backend Server Express.js
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

      // 3. Gabungkan dan filter berdasarkan sumber (Privat / Publik)
      List<TurnamenModel> combined = [...localData, ...remoteData];

      if (_selectedSourceFilter == '🔒 Privat (Lokal)') {
        combined = combined.where((t) => t.isPrivate).toList();
      } else if (_selectedSourceFilter == '🌐 Publik (Server)') {
        combined = combined.where((t) => !t.isPrivate).toList();
      }

      // Urutkan tanggal terbaru
      combined.sort((a, b) => b.tanggalMulai.compareTo(a.tanggalMulai));

      if (mounted) {
        setState(() {
          _tournaments = combined;
          _isLoading = false;
          _backendOfflineNotice = (backendError != null);
          // Hanya tampilkan error blocking jika daftar kosong dan filter bukan privat saja
          if (combined.isEmpty && backendError != null && _selectedSourceFilter != '🔒 Privat (Lokal)') {
            _errorMessage = backendError;
          } else {
            _errorMessage = null;
          }
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Berlangsung':
        return AppColors.secondary;
      case 'Selesai':
        return AppColors.success;
      default:
        return const Color(0xFF6366F1);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Berlangsung':
        return Icons.play_circle_fill_rounded;
      case 'Selesai':
        return Icons.emoji_events_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

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
            Text('Pengaturan Server API', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          ],
        ),
        content: Column(
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
              '• Emulator Android: http://10.0.2.2:3000/api\n• Windows/Web: http://localhost:3000/api\n• HP Fisik: http://IP_LAPTOP:3000/api',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ApiConfig.resetToDefault();
              Navigator.pop(ctx);
              _loadTournaments();
            },
            child: const Text('Reset Default', style: TextStyle(color: AppColors.textSecondary)),
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
                _currentUser != null
                    ? AvatarHelper.getIcon(_currentUser!['avatar_index'] as int?)
                    : Icons.person_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _currentUser != null ? 'Profil Pengguna' : 'Belum Masuk Akun',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentUser != null) ...[
              Text(
                _currentUser!['nickname']?.toString() ?? 'Pemain',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentUser!['email']?.toString() ?? '',
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
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Anda belum masuk akun. Masuk akun agar data turnamen offline dapat dikaitkan dengan profil Anda.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          if (_currentUser != null) ...[
            TextButton(
              onPressed: () async {
                await DatabaseHelper.instance.clearUserSession();
                setState(() => _currentUser = null);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesi login telah dibersihkan.'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              },
              child: const Text('Keluar Akun', style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: Colors.white)),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ).then((_) => _loadUserSession());
              },
              child: const Text('Login Sekarang', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              _currentNavIndex == 0 ? 'RivNet Turnamen' : 'Riwayat Turnamen',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: _currentUser != null
                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              child: Icon(
                _currentUser != null
                    ? AvatarHelper.getIcon(_currentUser!['avatar_index'] as int?)
                    : Icons.person_outline_rounded,
                size: 16,
                color: _currentUser != null ? const Color(0xFF10B981) : AppColors.textSecondary,
              ),
            ),
            tooltip: _currentUser != null ? (_currentUser!['nickname']?.toString() ?? 'Profil') : 'Masuk',
            onPressed: _showUserProfileDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet_rounded, color: AppColors.textSecondary),
            tooltip: 'Konfigurasi Server API',
            onPressed: _showServerSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Muat Ulang',
            onPressed: _loadTournaments,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildSearchBar(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildFilterChips(),
            ),
            if (_backendOfflineNotice)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
              ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _tournaments.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              color: AppColors.primary,
                              backgroundColor: AppColors.bgCard,
                              onRefresh: _loadTournaments,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                                itemCount: _tournaments.length,
                                itemBuilder: (context, index) {
                                  return _buildTournamentCard(_tournaments[index]);
                                },
                              ),
                            ),
            ),
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
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BuatTurnamenScreen()),
                );
                if (result == true) {
                  _loadTournaments();
                }
              },
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

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _loadTournaments(),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: _currentNavIndex == 0 ? 'Cari turnamen aktif...' : 'Cari riwayat turnamen...',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _loadTournaments();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Filter Sumber: Semua / Privat (Lokal HP) / Publik (Server)
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _sourceFilters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final sFilter = _sourceFilters[index];
              final isSelected = sFilter == _selectedSourceFilter;
              final isPrivat = sFilter.contains('Privat');

              return ChoiceChip(
                label: Text(sFilter),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedSourceFilter = sFilter);
                  _loadTournaments();
                },
                backgroundColor: AppColors.bgCard,
                selectedColor: isPrivat ? const Color(0xFF059669) : AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              );
            },
          ),
        ),
        if (_currentNavIndex == 0) ...[
          const SizedBox(height: 8),
          // 2. Filter Status: Semua / Akan Datang / Berlangsung
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedFilter = filter);
                    _loadTournaments();
                  },
                  backgroundColor: AppColors.bgDarkSecondary,
                  selectedColor: AppColors.secondary.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppColors.secondary : Colors.transparent,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTournamentCard(TurnamenModel t) {
    final statusColor = _getStatusColor(t.status);
    final statusIcon = _getStatusIcon(t.status);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.isPrivate
              ? const Color(0xFF10B981).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailTurnamenScreen(
                  idTurnamen: t.idTurnamen,
                  isPrivate: t.isPrivate,
                ),
              ),
            );
            if (result == true || result == null) {
              _loadTournaments();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.isPrivate
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: t.isPrivate
                                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                    : AppColors.secondary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  t.isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                                  size: 10,
                                  color: t.isPrivate ? const Color(0xFF10B981) : AppColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  t.isPrivate ? 'Privat (Lokal HP)' : 'Publik',
                                  style: TextStyle(
                                    color: t.isPrivate ? const Color(0xFF10B981) : AppColors.secondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.namaTurnamen,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.tipeGame} · ${t.kuota} Tim · ${dateFormat.format(t.tanggalMulai)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (t.formatBracket.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${t.formatBracket} (${t.jumlahLeg == 2 ? "2 Leg" : "1 Leg"})',
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    t.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _currentNavIndex == 0 ? Icons.emoji_events_outlined : Icons.history_toggle_off_rounded,
              color: AppColors.textMuted,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              _currentNavIndex == 0 ? 'Belum Ada Turnamen Aktif' : 'Belum Ada Riwayat Turnamen',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _currentNavIndex == 0
                  ? 'Klik tombol "Buat Turnamen" di bawah untuk memulai turnamen baru.'
                  : 'Turnamen yang telah selesai akan otomatis muncul di sini.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Gagal Terhubung ke Backend',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan koneksi',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _showServerSettingsDialog,
                  icon: const Icon(Icons.settings_rounded, size: 16),
                  label: const Text('Ganti URL API'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadTournaments,
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                  label: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
