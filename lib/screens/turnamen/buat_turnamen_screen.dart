import 'widgets/football_team_picker_dialog.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database_helper.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';

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

  Map<String, dynamic>? _currentUser;
  bool _isPrivate = true; // Default: Turnamen Privat (Lokal di HP)
  String _tipeGame = 'Sepak Bola / Futsal';
  String _lastSelectedLeague = 'Liga Inggris';
  String _lastSelectedDivision = 'Premier League';
  String _formatBracket = 'Single Elimination';
  int _jumlahLeg = 1; // 1 = 1x Tanding, 2 = 2x Tanding (Home & Away)
  int _kuota = 4;

  final List<TextEditingController> _pesertaControllers = [];
  bool _isLoading = false;

  final ApiService _apiService = ApiService.instance;
  final LocalTournamentService _localService = LocalTournamentService.instance;

  // Daftar Kategori / Tipe Game & Karakteristik Aturannya
  final List<Map<String, dynamic>> _gameTypeList = [
    {
      'name': 'Sepak Bola / Futsal',
      'icon': Icons.sports_soccer_rounded,
      'rule': 'Skor Gol. Sistem Liga: Menang 3 pts, Seri 1 pt, Kalah 0 pt.',
      'sample': ['Real Madrid', 'FC Barcelona', 'Manchester City', 'Arsenal', 'Liverpool', 'Bayern Munich', 'PSG', 'Juventus', 'AC Milan', 'Inter Milan', 'Chelsea', 'Dortmund', 'Atletico Madrid', 'Tottenham', 'Napoli', 'Ajax']
    },
    {
      'name': 'Bulu Tangkis',
      'icon': Icons.sports_tennis_rounded,
      'rule': 'Sistem Game / Rubber Set (cth: 2-0 atau 2-1). Tidak ada hasil seri.',
      'sample': ['Viktor Axelsen', 'Anthony Ginting', 'Jonatan Christie', 'Shi Yuqi', 'Kunlavut Vitidsarn', 'Lee Zii Jia', 'Loh Kean Yew', 'Kodai Naraoka', 'Chou Tien Chen', 'Kento Momota', 'Anders Antonsen', 'Prannoy H.S.']
    },
    {
      'name': 'Bola Basket',
      'icon': Icons.sports_basketball_rounded,
      'rule': 'Skor Poin Basket (cth: 88 - 82). Penentuan pemenang lewat Overtime jika imbang.',
      'sample': ['LA Lakers', 'Golden State Warriors', 'Boston Celtics', 'Chicago Bulls', 'Miami Heat', 'Milwaukee Bucks', 'Denver Nuggets', 'Phoenix Suns', 'Dallas Mavericks', 'Brooklyn Nets', 'Philadelphia 76ers', 'San Antonio Spurs']
    },
    {
      'name': 'Bola Voli',
      'icon': Icons.sports_volleyball_rounded,
      'rule': 'Sistem Set 25 Poin (Best of 3 / 5 Sets). Tidak ada hasil seri.',
      'sample': ['Jakarta LavAni', 'Jakarta Bhayangkara', 'Jakarta STIN BIN', 'Palembang BSB', 'Kudus Sukun Badak', 'Surabaya Samator', 'Jakarta Garuda', 'Bandung BJB']
    },
    {
      'name': 'Catur',
      'icon': Icons.extension_rounded,
      'rule': 'Sistem Poin Catur: Menang 1 pt, Remis 0.5 pt, Kalah 0 pt. Sangat cocok dengan Swiss System & Elimination.',
      'sample': ['Magnus Carlsen', 'Hikaru Nakamura', 'Fabiano Caruana', 'Ding Liren', 'Alireza Firouzja', 'Ian Nepomniachtchi', 'Viswanathan Anand', 'Gukesh D', 'Praggnanandhaa', 'Wesley So']
    },
    {
      'name': 'E-Sports',
      'icon': Icons.sports_esports_rounded,
      'rule': 'Mobile Legends, Valorant, PUBG, FF, Dota 2 (Best of 1, 3, 5 Match Series).',
      'sample': ['RRQ Hoshi', 'ONIC Esports', 'EVOS Legends', 'Bigetron Alpha', 'Alter Ego', 'Geek Fam ID', 'Rebellion Esports', 'Team Liquid ID', 'Fnatic ONIC', 'Paper Rex', 'Sentinels', 'Team Secret', 'PRX Gaming', 'DRX Vision', 'Gen.G Esports', 'T1 Academy']
    },
    {
      'name': 'Lainnya (Custom)',
      'icon': Icons.dashboard_customize_rounded,
      'rule': 'Cabang olahraga / permainan khusus dengan aturan bebas.',
      'sample': ['Tim A', 'Tim B', 'Tim C', 'Tim D', 'Tim E', 'Tim F', 'Tim G', 'Tim H', 'Tim I', 'Tim J', 'Tim K', 'Tim L', 'Tim M', 'Tim N', 'Tim O', 'Tim P']
    },
  ];

  // 5 Format Turnamen yang didukung
  final List<Map<String, dynamic>> _formatList = [
    {
      'name': 'Single Elimination',
      'label': 'Single Elimination',
      'desc': 'Sistem gugur tunggal (1x kalah langsung gugur, min. 2 peserta)',
      'icon': Icons.account_tree_rounded,
    },
    {
      'name': 'Double Elimination',
      'label': 'Double Elimination',
      'desc': 'Sistem gugur ganda (Winners & Losers Bracket, min. 4 peserta)',
      'icon': Icons.alt_route_rounded,
    },
    {
      'name': 'Round Robin',
      'label': 'Round Robin',
      'desc': 'Semua peserta bertemu satu sama lain (1 leg)',
      'icon': Icons.loop_rounded,
    },
    {
      'name': 'Liga',
      'label': 'Liga',
      'desc': 'Format kompetisi penuh (Home & Away / 2 leg)',
      'icon': Icons.format_list_numbered_rounded,
    },
    {
      'name': 'Swiss System',
      'label': 'Swiss System',
      'desc': 'Sistem Swiss berpasangan sesuai poin per ronde',
      'icon': Icons.shuffle_rounded,
    },
  ];

  List<int> get _currentEliminationOptions {
    if (_formatBracket == 'Double Elimination') {
      return [4, 8, 16, 32, 64];
    }
    return [2, 4, 8, 16, 32, 64];
  }

  final List<int> _nonEliminationPresets = [2, 3, 4, 5, 6, 8, 10, 12, 16];

  bool get _isElimination =>
      _formatBracket == 'Single Elimination' || _formatBracket == 'Double Elimination';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _updatePesertaFields(_kuota);
  }

  Future<void> _loadCurrentUser() async {
    final session = await DatabaseHelper.instance.getUserSession();
    if (session != null && mounted) {
      setState(() {
        _currentUser = session;
      });
    }
  }

  void _updatePesertaFields(int count) {
    while (_pesertaControllers.length < count) {
      final index = _pesertaControllers.length + 1;
      _pesertaControllers.add(TextEditingController(text: 'Peserta $index'));
    }
    while (_pesertaControllers.length > count) {
      final controller = _pesertaControllers.removeLast();
      controller.dispose();
    }
  }

  void _onFormatChanged(String newFormat) {
    setState(() {
      _formatBracket = newFormat;
      if (newFormat == 'Double Elimination') {
        if (_kuota < 4 || !_currentEliminationOptions.contains(_kuota)) {
          _kuota = 4;
        }
      } else if (newFormat == 'Single Elimination') {
        if (!_currentEliminationOptions.contains(_kuota)) {
          _kuota = 4;
        }
      } else {
        if (_kuota < 2) _kuota = 2;
      }
      _updatePesertaFields(_kuota);
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
        _pesertaControllers[index].text = result.clubName;
        _lastSelectedLeague = result.leagueName;
        _lastSelectedDivision = result.divisionName;
      });
    }
  }

  void _fillSampleNames() {
    final currentGameObj = _gameTypeList.firstWhere(
      (g) => g['name'] == _tipeGame,
      orElse: () => _gameTypeList[0],
    );
    final List<String> sampleTeams = List<String>.from(currentGameObj['sample'] ?? []);

    for (int i = 0; i < _pesertaControllers.length; i++) {
      if (i < sampleTeams.length) {
        _pesertaControllers[i].text = sampleTeams[i];
      } else {
        _pesertaControllers[i].text = 'Peserta ${i + 1}';
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _customGameController.dispose();
    for (final controller in _pesertaControllers) {
      controller.dispose();
    }
    super.dispose();
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
      final List<String> pesertaList = [];
      for (int i = 0; i < _pesertaControllers.length; i++) {
        final nama = _pesertaControllers[i].text.trim().isEmpty
            ? 'Peserta ${i + 1}'
            : _pesertaControllers[i].text.trim();
        pesertaList.add(nama);
      }

      final effectiveGameType = _tipeGame == 'Lainnya (Custom)' && _customGameController.text.trim().isNotEmpty
          ? _customGameController.text.trim()
          : _tipeGame;

      if (_isPrivate) {
        await _localService.createTurnamen(
          namaTurnamen: _namaController.text.trim(),
          deskripsi: _deskripsiController.text.trim().isEmpty
              ? null
              : _deskripsiController.text.trim(),
          tipeGame: effectiveGameType,
          formatBracket: _formatBracket,
          jumlahLeg: _jumlahLeg,
          tanggalMulai: DateTime.now(),
          kuota: _kuota,
          peserta: pesertaList,
        );
      } else {
        await _apiService.createTurnamen(
          namaTurnamen: _namaController.text.trim(),
          deskripsi: _deskripsiController.text.trim().isEmpty
              ? null
              : _deskripsiController.text.trim(),
          tipeGame: effectiveGameType,
          formatBracket: _formatBracket,
          jumlahLeg: _jumlahLeg,
          tanggalMulai: DateTime.now(), // Otomatis dicatat sebagai timestamp riwayat
          kuota: _kuota,
          peserta: pesertaList,
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
        Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Buat Turnamen Baru'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionTitle('Sifat & Penyimpanan Turnamen'),
              const SizedBox(height: 12),
              _buildSifatTurnamenSelector(),
              const SizedBox(height: 20),

              _buildSectionTitle('Informasi Turnamen'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _namaController,
                label: 'Nama Turnamen',
                hint: 'cth: Turnamen Futsal ITK Cup 2026',
                icon: Icons.emoji_events_rounded,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Nama turnamen wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _deskripsiController,
                label: 'Deskripsi (Opsional)',
                hint: 'Tuliskan catatan atau aturan turnamen...',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // === TIPE GAME / CABANG OLAHRAGA ===
              _buildSectionTitle('Tipe Game / Cabang Olahraga'),
              const SizedBox(height: 12),
              _buildGameTypeSelector(),
              const SizedBox(height: 20),

              // === FORMAT & KUOTA ===
              _buildSectionTitle('Format & Sistem Pertandingan'),
              const SizedBox(height: 12),
              _buildFormatSelector(),
              const SizedBox(height: 14),
              _buildLegSelector(),
              const SizedBox(height: 14),
              _buildKuotaSelector(),
              const SizedBox(height: 24),

              // === DAFTAR PESERTA ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Daftar Peserta (${_pesertaControllers.length})'),
                  TextButton.icon(
                    onPressed: _fillSampleNames,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.secondary),
                    label: Text(
                      'Isi Contoh $_tipeGame',
                      style: const TextStyle(color: AppColors.secondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_pesertaControllers.length, (index) {
                final isFootball = _tipeGame == 'Sepak Bola / Futsal';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pesertaControllers[index],
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.bgCard,
                            prefixIcon: Padding(
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
                            hintText: 'Nama Tim / Pemain ${index + 1}',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nama peserta ${index + 1} tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (isFootball) ...[
                        const SizedBox(width: 8),
                        SizedBox(
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
                            onPressed: () => _openFootballTeamPicker(index),
                            icon: const Icon(Icons.sports_soccer_rounded, size: 16),
                            label: const Text(
                              'Pilih Tim',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveTurnamen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Simpan & Generate Pertandingan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 22),
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  // === SELECTOR SIFAT TURNAMEN (PRIVAT LOKAL VS PUBLIK SERVER) ===
  Widget _buildSifatTurnamenSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                size: 18,
                color: _isPrivate ? const Color(0xFF10B981) : AppColors.secondary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Pilih Media Penyimpanan',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  avatar: Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: _isPrivate ? Colors.white : const Color(0xFF10B981),
                  ),
                  label: const Text('Privat (Lokal HP)'),
                  selected: _isPrivate,
                  onSelected: (_) => setState(() => _isPrivate = true),
                  selectedColor: const Color(0xFF059669),
                  backgroundColor: AppColors.bgDarkSecondary,
                  labelStyle: TextStyle(
                    color: _isPrivate ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: _isPrivate ? FontWeight.bold : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: _isPrivate ? const Color(0xFF059669) : Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  avatar: Icon(
                    Icons.public_rounded,
                    size: 16,
                    color: !_isPrivate ? Colors.white : AppColors.secondary,
                  ),
                  label: const Text('Publik (Online)'),
                  selected: !_isPrivate,
                  onSelected: (_) => setState(() => _isPrivate = false),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.bgDarkSecondary,
                  labelStyle: TextStyle(
                    color: !_isPrivate ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: !_isPrivate ? FontWeight.bold : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: !_isPrivate ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_isPrivate ? const Color(0xFF10B981) : AppColors.secondary).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (_isPrivate ? const Color(0xFF10B981) : AppColors.secondary).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _isPrivate ? Icons.storage_rounded : Icons.cloud_queue_rounded,
                  size: 16,
                  color: _isPrivate ? const Color(0xFF10B981) : AppColors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isPrivate
                        ? 'Tersimpan aman di Database SQLite lokal di HP ini (rivnet.db). Bekerja 100% offline tanpa perlu koneksi server backend.'
                        : 'Tersimpan di server backend Express.js / Cloud. Data dapat diakses secara online antardevice.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === SELECTOR TIPE GAME / CABANG OLAHRAGA ===
  Widget _buildGameTypeSelector() {
    final currentGameObj = _gameTypeList.firstWhere(
      (g) => g['name'] == _tipeGame,
      orElse: () => _gameTypeList[0],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _gameTypeList.map((item) {
              final String name = item['name'] as String;
              final IconData icon = item['icon'] as IconData;
              final bool isSelected = _tipeGame == name;
              return ChoiceChip(
                avatar: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.secondary,
                ),
                label: Text(name),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _tipeGame = name;
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.bgDarkSecondary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
          if (_tipeGame == 'Lainnya (Custom)') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customGameController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgDarkSecondary,
                hintText: 'Ketik nama cabang olahraga / game...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.rule_rounded, size: 16, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentGameObj['rule'] as String,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Format Bagan Turnamen',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _formatList.map((item) {
              final String name = item['name'] as String;
              final IconData icon = item['icon'] as IconData;
              final bool isSelected = _formatBracket == name;
              return ChoiceChip(
                avatar: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                label: Text(name),
                selected: isSelected,
                onSelected: (_) => _onFormatChanged(name),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.bgDarkSecondary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _formatList.firstWhere(
              (f) => f['name'] == _formatBracket,
              orElse: () => _formatList[0],
            )['desc'] as String,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildLegSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.repeat_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Sistem Pertemuan (Jumlah Leg)',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  avatar: Icon(
                    Icons.flash_on_rounded,
                    size: 16,
                    color: _jumlahLeg == 1 ? Colors.white : AppColors.secondary,
                  ),
                  label: const Text('1x Tanding (Single)'),
                  selected: _jumlahLeg == 1,
                  onSelected: (_) => setState(() => _jumlahLeg = 1),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.bgDarkSecondary,
                  labelStyle: TextStyle(
                    color: _jumlahLeg == 1 ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: _jumlahLeg == 1 ? FontWeight.bold : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: _jumlahLeg == 1 ? AppColors.primary : Colors.transparent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  avatar: Icon(
                    Icons.compare_arrows_rounded,
                    size: 16,
                    color: _jumlahLeg == 2 ? Colors.white : AppColors.secondary,
                  ),
                  label: const Text('2x (Home & Away)'),
                  selected: _jumlahLeg == 2,
                  onSelected: (_) => setState(() => _jumlahLeg = 2),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.bgDarkSecondary,
                  labelStyle: TextStyle(
                    color: _jumlahLeg == 2 ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: _jumlahLeg == 2 ? FontWeight.bold : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: _jumlahLeg == 2 ? AppColors.primary : Colors.transparent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _jumlahLeg == 1
                ? '• 1x Tanding: Setiap pertemuan hanya 1 laga (format standar turnamen cepat).'
                : '• 2x Tanding: Format Kandang & Tandang (Home & Away / 2 Leg) untuk setiap pertemuan.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildKuotaSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Jumlah Kuota Peserta',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_kuota Peserta',
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
          if (_isElimination) ...[
            Text(
              _formatBracket == 'Double Elimination'
                  ? 'Double Elimination butuh min. 4 peserta (Winners & Losers Bracket):'
                  : 'Single Elimination wajib kelipatan eksponen 2 (min. 2):',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _currentEliminationOptions.map((k) {
                  final isSelected = _kuota == k;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$k'),
                      selected: isSelected,
                      onSelected: (_) => _changeKuota(k),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.bgDarkSecondary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else ...[
            const Text(
              'Bisa pilih preset atau tentukan custom minimal 2 orang:',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgDarkSecondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, color: AppColors.textPrimary, size: 20),
                        onPressed: _kuota > 2 ? () => _changeKuota(_kuota - 1) : null,
                        tooltip: 'Kurangi 1',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$_kuota',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 20),
                        onPressed: () => _changeKuota(_kuota + 1),
                        tooltip: 'Tambah 1',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showCustomKuotaDialog,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.secondary),
                    label: const Text(
                      'Input Angka Lain',
                      style: TextStyle(color: AppColors.secondary, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _nonEliminationPresets.map((k) {
                  final isSelected = _kuota == k;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$k'),
                      selected: isSelected,
                      onSelected: (_) => _changeKuota(k),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.bgDarkSecondary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
