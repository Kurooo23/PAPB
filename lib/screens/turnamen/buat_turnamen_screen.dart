import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import 'widgets/football_team_picker_dialog.dart';

/// Ukuran layout form dihitung dari MediaQuery.
/// - Padding samping = 5% lebar layar, isi dibatasi 900 dp di layar lebar.
/// - isWide (lebar >= 600): section dipasang berdampingan 1:1 (Row + Expanded),
///   daftar peserta 2 kolom. Di HP semuanya ditumpuk (Column).
class _FormLayout {
  const _FormLayout._({
    required this.sidePadding,
    required this.isWide,
    required this.gap,
    required this.sectionGap,
    required this.titleFontSize,
  });

  factory _FormLayout.of(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    const maxContentWidth = 900.0;

    final contentWidth =
    screen.width > maxContentWidth ? maxContentWidth : screen.width;
    final extraSpace =
    screen.width > maxContentWidth ? (screen.width - maxContentWidth) / 2 : 0.0;
    final isCompact = screen.height < 640;

    return _FormLayout._(
      sidePadding: extraSpace + contentWidth * 0.05,
      isWide: contentWidth >= 600,
      gap: contentWidth * 0.03,
      sectionGap: isCompact ? 14 : 20,
      titleFontSize: screen.width < 360 ? 15 : 16,
    );
  }

  final double sidePadding;
  final bool isWide;
  final double gap;
  final double sectionGap;
  final double titleFontSize;
}

class BuatTurnamenScreen extends StatefulWidget {
  const BuatTurnamenScreen({super.key});

  @override
  State<BuatTurnamenScreen> createState() => _BuatTurnamenScreenState();
}

class _BuatTurnamenScreenState extends State<BuatTurnamenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _customGameController = TextEditingController();

  // Provider: user diambil dari AuthProvider
  Map<String, dynamic>? get _currentUser => context.read<AuthProvider>().user;

  bool _isPrivate = true; // Default: Turnamen Privat (Lokal di HP)
  String _tipeGame = 'Sepak Bola / Futsal';
  String _lastSelectedLeague = 'Liga Inggris';
  String _lastSelectedDivision = 'Premier League';
  String _formatBracket = 'Single Elimination';
  int _jumlahLeg = 1; // 1 = 1x Tanding, 2 = Home & Away
  int _kuota = 4;
  int _bestOf = 1; // 1 / 3 / 5 / 7, untuk cabang selain sepak bola

  /// Sepak bola pakai sistem leg (1x / Home & Away), cabang lain pakai Best of.
  bool get _usesLeg => _tipeGame == 'Sepak Bola / Futsal';

  final List<TextEditingController> _pesertaControllers = [];
  // Nama tim, cuma dipakai saat _shouldSplitPesertaTim true
  // (Online + Sepak Bola/Futsal).
  final List<TextEditingController> _timControllers = [];
  bool _isLoading = false;

  bool get _shouldSplitPesertaTim => !_isPrivate && _tipeGame == 'Sepak Bola / Futsal';

  final ApiService _apiService = ApiService.instance;
  final LocalTournamentService _localService = LocalTournamentService.instance;

  static const List<Map<String, dynamic>> _gameTypeList = [
    {
      'name': 'Sepak Bola / Futsal',
      'icon': Icons.sports_soccer_rounded,
      'rule': 'Skor Gol. Sistem Liga: Menang 3 pts, Seri 1 pt, Kalah 0 pt.',
      'sample': ['Real Madrid', 'FC Barcelona', 'Manchester City', 'Arsenal', 'Liverpool', 'Bayern Munich', 'PSG', 'Juventus', 'AC Milan', 'Inter Milan', 'Chelsea', 'Dortmund', 'Atletico Madrid', 'Tottenham', 'Napoli', 'Ajax'],
    },
    {
      'name': 'Bola Basket',
      'icon': Icons.sports_basketball_rounded,
      'rule': 'Skor Poin Basket (cth: 88 - 82). Penentuan pemenang lewat Overtime jika imbang.',
      'sample': ['LA Lakers', 'Golden State Warriors', 'Boston Celtics', 'Chicago Bulls', 'Miami Heat', 'Milwaukee Bucks', 'Denver Nuggets', 'Phoenix Suns', 'Dallas Mavericks', 'Brooklyn Nets', 'Philadelphia 76ers', 'San Antonio Spurs'],
    },
    {
      'name': 'Catur',
      'icon': Icons.extension_rounded,
      'rule': 'Sistem Poin Catur: Menang 1 pt, Remis 0.5 pt, Kalah 0 pt. Sangat cocok dengan Swiss System & Elimination.',
      'sample': ['Magnus Carlsen', 'Hikaru Nakamura', 'Fabiano Caruana', 'Ding Liren', 'Alireza Firouzja', 'Ian Nepomniachtchi', 'Viswanathan Anand', 'Gukesh D', 'Praggnanandhaa', 'Wesley So'],
    },
    {
      'name': 'E-Sports',
      'icon': Icons.sports_esports_rounded,
      'rule': 'Mobile Legends, Valorant, PUBG, FF, Dota 2 (Best of 1, 3, 5 Match Series).',
      'sample': ['RRQ Hoshi', 'ONIC Esports', 'EVOS Legends', 'Bigetron Alpha', 'Alter Ego', 'Geek Fam ID', 'Rebellion Esports', 'Team Liquid ID', 'Fnatic ONIC', 'Paper Rex', 'Sentinels', 'Team Secret', 'PRX Gaming', 'DRX Vision', 'Gen.G Esports', 'T1 Academy'],
    },
    {
      'name': 'Lainnya (Custom)',
      'icon': Icons.dashboard_customize_rounded,
      'rule': 'Cabang olahraga / permainan khusus dengan aturan bebas.',
      'sample': ['Tim A', 'Tim B', 'Tim C', 'Tim D', 'Tim E', 'Tim F', 'Tim G', 'Tim H', 'Tim I', 'Tim J', 'Tim K', 'Tim L', 'Tim M', 'Tim N', 'Tim O', 'Tim P'],
    },
  ];

  static const List<Map<String, dynamic>> _formatList = [
    {
      'name': 'Single Elimination',
      'desc': 'Sistem gugur tunggal (1x kalah langsung gugur, min. 2 peserta)',
      'icon': Icons.account_tree_rounded,
    },
    {
      'name': 'Double Elimination',
      'desc': 'Sistem gugur ganda (Winners & Losers Bracket, min. 4 peserta)',
      'icon': Icons.alt_route_rounded,
    },
    {
      'name': 'Round Robin',
      'desc': 'Semua peserta bertemu satu sama lain (1 leg)',
      'icon': Icons.loop_rounded,
    },
    {
      'name': 'Liga',
      'desc': 'Format kompetisi penuh (Home & Away / 2 leg)',
      'icon': Icons.format_list_numbered_rounded,
    },
    {
      'name': 'Swiss System',
      'desc': 'Sistem Swiss berpasangan sesuai poin per ronde',
      'icon': Icons.shuffle_rounded,
    },
  ];

  static const List<int> _nonEliminationPresets = [2, 3, 4, 5, 6, 8, 10, 12, 16];

  List<int> get _currentEliminationOptions => _formatBracket == 'Double Elimination'
      ? const [4, 8, 16, 32, 64]
      : const [2, 4, 8, 16, 32, 64];

  bool get _isElimination =>
      _formatBracket == 'Single Elimination' || _formatBracket == 'Double Elimination';

  Map<String, dynamic> get _currentGame => _gameTypeList.firstWhere(
        (g) => g['name'] == _tipeGame,
    orElse: () => _gameTypeList[0],
  );

  String get _currentFormatDesc => _formatList.firstWhere(
        (f) => f['name'] == _formatBracket,
    orElse: () => _formatList[0],
  )['desc'] as String;

  @override
  void initState() {
    super.initState();
    _updatePesertaFields(_kuota);
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _customGameController.dispose();
    for (final c in _pesertaControllers) {
      c.dispose();
    }
    for (final c in _timControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ===================== LOGIKA FORM =====================

  void _updatePesertaFields(int count) {
    while (_pesertaControllers.length < count) {
      final index = _pesertaControllers.length + 1;
      _pesertaControllers.add(TextEditingController(text: 'Peserta $index'));
      _timControllers.add(TextEditingController());
    }
    while (_pesertaControllers.length > count) {
      _pesertaControllers.removeLast().dispose();
      _timControllers.removeLast().dispose();
    }
  }

  void _onFormatChanged(String newFormat) {
    setState(() {
      _formatBracket = newFormat;
      if (newFormat == 'Double Elimination') {
        if (_kuota < 4 || !_currentEliminationOptions.contains(_kuota)) _kuota = 4;
      } else if (newFormat == 'Single Elimination') {
        if (!_currentEliminationOptions.contains(_kuota)) _kuota = 4;
      } else {
        if (_kuota < 2) _kuota = 2;
      }
      _updatePesertaFields(_kuota);
    });
  }

  void _onGameTypeChanged(String name) {
    setState(() {
      _tipeGame = name;
      // Pindah dari sepak bola: leg dikembalikan ke 1x
      if (name != 'Sepak Bola / Futsal') _jumlahLeg = 1;
    });
  }

  void _changeKuota(int newKuota) {
    if (newKuota < 2) return;
    if (_formatBracket == 'Double Elimination' && newKuota < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Double Elimination membutuhkan minimal 4 peserta untuk Upper & Lower Bracket!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() {
      _kuota = newKuota;
      _updatePesertaFields(newKuota);
    });
  }

  void _onPublicSelected() {
    if (_currentUser == null) {
      _showLoginRequiredDialog();
    } else {
      setState(() => _isPrivate = false);
    }
  }

  void _fillSampleNames() {
    final sampleTeams = List<String>.from(_currentGame['sample'] ?? []);
    final targets = _shouldSplitPesertaTim ? _timControllers : _pesertaControllers;

    for (int i = 0; i < targets.length; i++) {
      if (i < sampleTeams.length) {
        targets[i].text = sampleTeams[i];
      } else if (!_shouldSplitPesertaTim) {
        targets[i].text = 'Peserta ${i + 1}';
      }
    }
    setState(() {});
  }

  Future<void> _openFootballTeamPicker(int index) async {
    final result = await showDialog<FootballTeamPickerResult>(
      context: context,
      builder: (ctx) => FootballTeamPickerDialog(
        initialLeague: _lastSelectedLeague,
        initialDivision: _lastSelectedDivision,
        participantIndex: index,
      ),
    );

    if (result != null) {
      setState(() {
        if (_shouldSplitPesertaTim) {
          _timControllers[index].text = result.clubName;
        } else {
          _pesertaControllers[index].text = result.clubName;
        }
        _lastSelectedLeague = result.leagueName;
        _lastSelectedDivision = result.divisionName;
      });
    }
  }

  Future<void> _saveTurnamen() async {
    if (!_formKey.currentState!.validate()) return;

    if (_formatBracket == 'Double Elimination' && _kuota < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Double Elimination membutuhkan minimal 4 peserta!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pesertaList = <String>[
        for (int i = 0; i < _pesertaControllers.length; i++)
          _pesertaControllers[i].text.trim().isEmpty
              ? 'Peserta ${i + 1}'
              : _pesertaControllers[i].text.trim(),
      ];

      final timList = _shouldSplitPesertaTim
          ? _timControllers.map((c) => c.text.trim()).toList()
          : null;

      final effectiveGameType =
      _tipeGame == 'Lainnya (Custom)' && _customGameController.text.trim().isNotEmpty
          ? _customGameController.text.trim()
          : _tipeGame;

      final deskripsi = _deskripsiController.text.trim().isEmpty
          ? null
          : _deskripsiController.text.trim();

      // Leg cuma untuk sepak bola, Best of untuk cabang lain
      final effectiveLeg = _usesLeg ? _jumlahLeg : 1;
      final effectiveBestOf = _usesLeg ? 1 : _bestOf;

      if (_isPrivate) {
        await _localService.createTurnamen(
          namaTurnamen: _namaController.text.trim(),
          deskripsi: deskripsi,
          tipeGame: effectiveGameType,
          formatBracket: _formatBracket,
          jumlahLeg: effectiveLeg,
          bestOf: effectiveBestOf,
          tanggalMulai: DateTime.now(),
          kuota: _kuota,
          peserta: pesertaList,
          emailUser: _currentUser?['email']?.toString() ?? '',
        );
      } else {
        // Turnamen publik wajib login
        if (_currentUser == null) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showLoginRequiredDialog();
          }
          return;
        }
        await _apiService.createTurnamen(
          namaTurnamen: _namaController.text.trim(),
          deskripsi: deskripsi,
          tipeGame: effectiveGameType,
          formatBracket: _formatBracket,
          jumlahLeg: effectiveLeg,
          bestOf: effectiveBestOf,
          tanggalMulai: DateTime.now(),
          kuota: _kuota,
          peserta: pesertaList,
          namaTim: timList,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isPrivate
                ? 'Turnamen privat berhasil dibuat & disimpan ke database lokal HP!'
                : 'Turnamen publik berhasil dibuat di server backend!'),
            backgroundColor: AppColors.success,
          ),
        );
        // GetX: kembali + bawa hasil
        Get.back(result: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat turnamen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===================== DIALOG =====================

  void _showCustomKuotaDialog() {
    final customController = TextEditingController(text: _kuota.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDarkSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Input Jumlah Kuota Peserta',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan jumlah peserta (minimal 2 orang):',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: customController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgCard,
                hintText: 'cth: 7',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixText: 'Peserta',
                suffixStyle: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final val = int.tryParse(customController.text.trim());
              if (val != null && val >= 2) {
                _changeKuota(val);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Jumlah peserta minimal 2 orang!'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Terapkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLoginRequiredDialog() {
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
          'Untuk membuat turnamen online (publik), Anda harus masuk ke akun terlebih dahulu agar data tersimpan di server dan dapat dilihat oleh pemain lain.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tetap Privat', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              // Push/Pop (basic)
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
              if (!mounted) return;
              await context.read<AuthProvider>().loadSession();
              if (_currentUser != null && mounted) {
                setState(() => _isPrivate = false);
              }
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
    // Provider: rebuild saat status login berubah
    context.watch<AuthProvider>();
    final layout = _FormLayout.of(context);
    final isFootball = _tipeGame == 'Sepak Bola / Futsal';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Buat Turnamen Baru')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: layout.sidePadding,
              vertical: layout.sectionGap,
            ),
            children: [
              // Bagian 1: Sifat | Informasi (sebaris di layar lebar)
              _ResponsivePair(
                isWide: layout.isWide,
                gap: layout.gap,
                verticalGap: layout.sectionGap,
                left: _Section(
                  title: 'Sifat & Penyimpanan Turnamen',
                  titleFontSize: layout.titleFontSize,
                  child: _SifatSelector(
                    isPrivate: _isPrivate,
                    onPrivate: () => setState(() => _isPrivate = true),
                    onPublic: _onPublicSelected,
                  ),
                ),
                right: _Section(
                  title: 'Informasi Turnamen',
                  titleFontSize: layout.titleFontSize,
                  child: Column(
                    children: [
                      _AppTextField(
                        controller: _namaController,
                        label: 'Nama Turnamen',
                        hint: 'cth: Turnamen Futsal ITK Cup 2026',
                        icon: Icons.emoji_events_rounded,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Nama turnamen wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _AppTextField(
                        controller: _deskripsiController,
                        label: 'Deskripsi (Opsional)',
                        hint: 'Tuliskan catatan atau aturan turnamen...',
                        icon: Icons.notes_rounded,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: layout.sectionGap),

              // Bagian 2: Tipe Game | Format
              _ResponsivePair(
                isWide: layout.isWide,
                gap: layout.gap,
                verticalGap: layout.sectionGap,
                left: _Section(
                  title: 'Tipe Game / Cabang Olahraga',
                  titleFontSize: layout.titleFontSize,
                  child: _GameTypeSelector(
                    games: _gameTypeList,
                    selected: _tipeGame,
                    rule: _currentGame['rule'] as String,
                    customController: _customGameController,
                    onSelected: _onGameTypeChanged,
                  ),
                ),
                right: _Section(
                  title: 'Format & Sistem Pertandingan',
                  titleFontSize: layout.titleFontSize,
                  child: _FormatSelector(
                    formats: _formatList,
                    selected: _formatBracket,
                    description: _currentFormatDesc,
                    onSelected: _onFormatChanged,
                  ),
                ),
              ),
              SizedBox(height: layout.sectionGap * 0.7),

              // Bagian 3: Leg / Best of | Kuota
              _ResponsivePair(
                isWide: layout.isWide,
                gap: layout.gap,
                verticalGap: 14,
                left: _SeriesSelector(
                  usesLeg: _usesLeg,
                  jumlahLeg: _jumlahLeg,
                  bestOf: _bestOf,
                  onLegChanged: (leg) => setState(() => _jumlahLeg = leg),
                  onBestOfChanged: (bo) => setState(() => _bestOf = bo),
                ),
                right: _KuotaSelector(
                  kuota: _kuota,
                  isElimination: _isElimination,
                  isDoubleElimination: _formatBracket == 'Double Elimination',
                  eliminationOptions: _currentEliminationOptions,
                  presets: _nonEliminationPresets,
                  onChanged: _changeKuota,
                  onCustom: _showCustomKuotaDialog,
                ),
              ),
              SizedBox(height: layout.sectionGap + 4),

              // Bagian 4: Daftar peserta
              _PesertaHeader(
                count: _pesertaControllers.length,
                tipeGame: _tipeGame,
                fontSize: layout.titleFontSize,
                onFillSample: _fillSampleNames,
              ),
              const SizedBox(height: 8),
              _PesertaGrid(
                columns: layout.isWide ? 2 : 1,
                gap: layout.gap,
                children: [
                  for (int i = 0; i < _pesertaControllers.length; i++)
                    _PesertaField(
                      index: i,
                      pesertaController: _pesertaControllers[i],
                      timController: _timControllers[i],
                      splitMode: _shouldSplitPesertaTim,
                      showPickButton: isFootball,
                      onPickTeam: () => _openFootballTeamPicker(i),
                    ),
                ],
              ),
              SizedBox(height: layout.sectionGap + 8),

              _SubmitButton(isLoading: _isLoading, onPressed: _saveTurnamen),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== WIDGET STATELESS =====================

/// Dua widget: berdampingan 1:1 (Row + Expanded) di layar lebar,
/// ditumpuk (Column) di HP.
class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.isWide,
    required this.gap,
    required this.verticalGap,
    required this.left,
    required this.right,
  });

  final bool isWide;
  final double gap;
  final double verticalGap;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          SizedBox(width: gap),
          Expanded(child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [left, SizedBox(height: verticalGap), right],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.titleFontSize,
    required this.child,
  });

  final String title;
  final double titleFontSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _CardBox extends StatelessWidget {
  const _CardBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title, this.iconColor = AppColors.primary});

  final IconData icon;
  final String title;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// ChoiceChip dengan gaya seragam untuk seluruh form.
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.selectedColor = AppColors.primary,
    this.iconColor = AppColors.secondary,
    this.fontSize = 12,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;
  final Color selectedColor;
  final Color iconColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: selected ? Colors.white : iconColor),
      label: Text(label, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: selectedColor,
      backgroundColor: AppColors.bgDarkSecondary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textSecondary,
        fontSize: fontSize,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? selectedColor : Colors.transparent),
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 22),
        filled: true,
        fillColor: AppColors.bgCard,
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _SifatSelector extends StatelessWidget {
  const _SifatSelector({
    required this.isPrivate,
    required this.onPrivate,
    required this.onPublic,
  });

  final bool isPrivate;
  final VoidCallback onPrivate;
  final VoidCallback onPublic;

  static const _privateColor = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final accent = isPrivate ? _privateColor : AppColors.secondary;

    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: isPrivate ? Icons.lock_rounded : Icons.public_rounded,
            title: 'Pilih Media Penyimpanan',
            iconColor: accent,
          ),
          const SizedBox(height: 12),
          // Dua pilihan dibagi rata 1:1
          Row(
            children: [
              Expanded(
                child: _OptionChip(
                  icon: Icons.lock_rounded,
                  iconColor: _privateColor,
                  label: 'Privat (Lokal HP)',
                  selected: isPrivate,
                  selectedColor: const Color(0xFF059669),
                  onSelected: onPrivate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OptionChip(
                  icon: Icons.public_rounded,
                  label: 'Publik (Online)',
                  selected: !isPrivate,
                  onSelected: onPublic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoNote(
            icon: isPrivate ? Icons.storage_rounded : Icons.cloud_queue_rounded,
            color: accent,
            text: isPrivate
                ? 'Tersimpan di Database lokal di HP anda. 100% offline tanpa perlu koneksi.'
                : 'Tersimpan di server Cloud. Data dapat diakses secara online.',
          ),
        ],
      ),
    );
  }
}

class _GameTypeSelector extends StatelessWidget {
  const _GameTypeSelector({
    required this.games,
    required this.selected,
    required this.rule,
    required this.customController,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> games;
  final String selected;
  final String rule;
  final TextEditingController customController;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final game in games)
                _OptionChip(
                  icon: game['icon'] as IconData,
                  label: game['name'] as String,
                  selected: selected == game['name'],
                  onSelected: () => onSelected(game['name'] as String),
                ),
            ],
          ),
          if (selected == 'Lainnya (Custom)') ...[
            const SizedBox(height: 12),
            TextField(
              controller: customController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgDarkSecondary,
                hintText: 'Ketik nama cabang olahraga / game...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _InfoNote(icon: Icons.rule_rounded, color: AppColors.secondary, text: rule),
        ],
      ),
    );
  }
}

class _FormatSelector extends StatelessWidget {
  const _FormatSelector({
    required this.formats,
    required this.selected,
    required this.description,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> formats;
  final String selected;
  final String description;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(icon: Icons.hub_rounded, title: 'Format Bagan Turnamen'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final format in formats)
                _OptionChip(
                  icon: format['icon'] as IconData,
                  iconColor: AppColors.textSecondary,
                  label: format['name'] as String,
                  selected: selected == format['name'],
                  onSelected: () => onSelected(format['name'] as String),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sepak bola: 1x Tanding / 2x Home & Away (leg).
/// Cabang lain: Best of 1 / 3 / 5 / 7 (dibagi rata 1:1:1:1).
class _SeriesSelector extends StatelessWidget {
  const _SeriesSelector({
    required this.usesLeg,
    required this.jumlahLeg,
    required this.bestOf,
    required this.onLegChanged,
    required this.onBestOfChanged,
  });

  final bool usesLeg;
  final int jumlahLeg;
  final int bestOf;
  final ValueChanged<int> onLegChanged;
  final ValueChanged<int> onBestOfChanged;

  static const _bestOfOptions = [1, 3, 5, 7];

  String get _description {
    if (usesLeg) {
      return jumlahLeg == 1
          ? '• 1x Tanding: Setiap pertemuan hanya 1 laga (format standar turnamen cepat).'
          : '• 2x Tanding: Format Kandang & Tandang (Home & Away / 2 Leg) untuk setiap pertemuan.';
    }
    if (bestOf == 1) {
      return '• Best of 1: Cukup 1 game, pemenang langsung ditentukan.';
    }
    final target = (bestOf ~/ 2) + 1;
    return '• Best of $bestOf: Pemenang adalah yang pertama menang $target game. '
        'Skor diinput sebagai jumlah game yang dimenangkan (cth: $target-${target - 1}).';
  }

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: usesLeg ? Icons.repeat_rounded : Icons.military_tech_rounded,
            title: usesLeg ? 'Sistem Pertemuan (Jumlah Leg)' : 'Format Seri (Best of)',
          ),
          const SizedBox(height: 10),
          if (usesLeg)
          // Dua pilihan dibagi rata 1:1
            Row(
              children: [
                Expanded(
                  child: _OptionChip(
                    icon: Icons.flash_on_rounded,
                    label: '1x Tanding (Single)',
                    selected: jumlahLeg == 1,
                    onSelected: () => onLegChanged(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OptionChip(
                    icon: Icons.compare_arrows_rounded,
                    label: '2x (Home & Away)',
                    selected: jumlahLeg == 2,
                    onSelected: () => onLegChanged(2),
                  ),
                ),
              ],
            )
          else
          // Empat pilihan dibagi rata 1:1:1:1
            Row(
              children: [
                for (int i = 0; i < _bestOfOptions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _BestOfOption(
                      value: _bestOfOptions[i],
                      selected: bestOf == _bestOfOptions[i],
                      onTap: () => onBestOfChanged(_bestOfOptions[i]),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 8),
          Text(
            _description,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _BestOfOption extends StatelessWidget {
  const _BestOfOption({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.bgDarkSecondary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Text(
            'BO$value',
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _KuotaSelector extends StatelessWidget {
  const _KuotaSelector({
    required this.kuota,
    required this.isElimination,
    required this.isDoubleElimination,
    required this.eliminationOptions,
    required this.presets,
    required this.onChanged,
    required this.onCustom,
  });

  final int kuota;
  final bool isElimination;
  final bool isDoubleElimination;
  final List<int> eliminationOptions;
  final List<int> presets;
  final ValueChanged<int> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final options = isElimination ? eliminationOptions : presets;

    return _CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _CardHeader(
                  icon: Icons.people_alt_rounded,
                  title: 'Jumlah Kuota Peserta',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$kuota Peserta',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isElimination
                ? (isDoubleElimination
                ? 'Double Elimination butuh min. 4 peserta (Winners & Losers Bracket):'
                : 'Single Elimination wajib kelipatan eksponen 2 (min. 2):')
                : 'Bisa pilih preset atau tentukan custom minimal 2 orang:',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (!isElimination) ...[
            // Stepper : tombol custom = ukuran isi : sisa lebar
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgDarkSecondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded,
                            color: AppColors.textPrimary, size: 20),
                        onPressed: kuota > 2 ? () => onChanged(kuota - 1) : null,
                        tooltip: 'Kurangi 1',
                      ),
                      Text(
                        '$kuota',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded,
                            color: AppColors.textPrimary, size: 20),
                        onPressed: () => onChanged(kuota + 1),
                        tooltip: 'Tambah 1',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCustom,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.secondary),
                    label: const Text(
                      'Input Angka Lain',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.secondary, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // Wrap: chip angka turun ke baris berikut kalau tidak muat
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in options)
                _OptionChip(
                  label: '$k',
                  selected: kuota == k,
                  fontSize: 13,
                  onSelected: () => onChanged(k),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PesertaHeader extends StatelessWidget {
  const _PesertaHeader({
    required this.count,
    required this.tipeGame,
    required this.fontSize,
    required this.onFillSample,
  });

  final int count;
  final String tipeGame;
  final double fontSize;
  final VoidCallback onFillSample;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Daftar Peserta ($count)',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Flexible(
          child: TextButton.icon(
            onPressed: onFillSample,
            icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.secondary),
            label: Text(
              'Isi Contoh $tipeGame',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.secondary, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

/// Daftar peserta: 1 kolom di HP, 2 kolom (1:1) di layar lebar.
class _PesertaGrid extends StatelessWidget {
  const _PesertaGrid({
    required this.columns,
    required this.gap,
    required this.children,
  });

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int start = 0; start < children.length; start += columns) {
      rows.add(
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
      );
    }
    return Column(children: rows);
  }
}

class _PesertaField extends StatelessWidget {
  const _PesertaField({
    required this.index,
    required this.pesertaController,
    required this.timController,
    required this.splitMode,
    required this.showPickButton,
    required this.onPickTeam,
  });

  final int index;
  final TextEditingController pesertaController;
  final TextEditingController timController;
  final bool splitMode;
  final bool showPickButton;
  final VoidCallback onPickTeam;

  InputDecoration _decoration({required Widget prefix, required String hint}) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.bgCard,
      prefixIcon: prefix,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      errorMaxLines: 2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field nama : tombol pilih tim = sisa lebar : ukuran isi
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: pesertaController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: _decoration(
                    prefix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    hint: splitMode
                        ? 'Nama Pemain ${index + 1}'
                        : 'Nama Tim / Pemain ${index + 1}',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Nama peserta ${index + 1} tidak boleh kosong'
                      : null,
                ),
              ),
              if (showPickButton && !splitMode) ...[
                const SizedBox(width: 8),
                _PilihTimButton(onPressed: onPickTeam),
              ],
            ],
          ),
          if (splitMode) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: timController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: _decoration(
                      prefix: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(Icons.shield_outlined, size: 18, color: AppColors.textMuted),
                      ),
                      hint: 'Nama Tim ${index + 1} (opsional)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PilihTimButton(onPressed: onPickTeam),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PilihTimButton extends StatelessWidget {
  const _PilihTimButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Di layar sangat sempit cuma tampil ikon supaya field nama tetap lega.
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: AppColors.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.4)),
          ),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.sports_soccer_rounded, size: 16),
        label: isNarrow
            ? const SizedBox.shrink()
            : const Text(
          'Pilih Tim',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: isLoading
          ? const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      )
          : const Text(
        'Simpan & Generate Pertandingan',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}