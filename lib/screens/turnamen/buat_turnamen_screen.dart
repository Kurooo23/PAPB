import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/api_service.dart';
import '../../data/services/local_tournament_service.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../widgets/common_widgets.dart';
import 'widgets/football_team_picker_dialog.dart';

/// Objek tipe game: nama, ikon, aturan, dan contoh nama peserta.
class _GameType {
  const _GameType(this.name, this.icon, this.rule, this.samples);

  final String name;
  final IconData icon;
  final String rule;
  final List<String> samples;
}

/// Objek format bagan: nama, deskripsi, dan ikon.
class _BracketFormat {
  const _BracketFormat(this.name, this.desc, this.icon);

  final String name;
  final String desc;
  final IconData icon;
}

const _football = 'Sepak Bola / Futsal';
const _basket = 'Bola Basket';
const _custom = 'Lainnya (Custom)';
const _singleElim = 'Single Elimination';
const _doubleElim = 'Double Elimination';

const _gameTypes = [
  _GameType(
    _football,
    Icons.sports_soccer_rounded,
    'Skor Gol. Sistem Liga: Menang 3 pts, Seri 1 pt, Kalah 0 pt.',
    ['Real Madrid', 'FC Barcelona', 'Manchester City', 'Arsenal', 'Liverpool', 'Bayern Munich', 'PSG', 'Juventus', 'AC Milan', 'Inter Milan', 'Chelsea', 'Dortmund', 'Atletico Madrid', 'Tottenham', 'Napoli', 'Ajax'],
  ),
  _GameType(
    _basket,
    Icons.sports_basketball_rounded,
    'Skor Poin Basket (cth: 88 - 82). Penentuan pemenang lewat Overtime jika imbang.',
    ['LA Lakers', 'Golden State Warriors', 'Boston Celtics', 'Chicago Bulls', 'Miami Heat', 'Milwaukee Bucks', 'Denver Nuggets', 'Phoenix Suns', 'Dallas Mavericks', 'Brooklyn Nets', 'Philadelphia 76ers', 'San Antonio Spurs'],
  ),
  _GameType(
    'Catur',
    Icons.extension_rounded,
    'Sistem Poin Catur: Menang 1 pt, Remis 0.5 pt, Kalah 0 pt. Sangat cocok dengan Swiss System & Elimination.',
    ['Magnus Carlsen', 'Hikaru Nakamura', 'Fabiano Caruana', 'Ding Liren', 'Alireza Firouzja', 'Ian Nepomniachtchi', 'Viswanathan Anand', 'Gukesh D', 'Praggnanandhaa', 'Wesley So'],
  ),
  _GameType(
    'E-Sports',
    Icons.sports_esports_rounded,
    'Mobile Legends, Valorant, PUBG, FF, Dota 2 (Best of 1, 3, 5 Match Series).',
    ['RRQ Hoshi', 'ONIC Esports', 'EVOS Legends', 'Bigetron Alpha', 'Alter Ego', 'Geek Fam ID', 'Rebellion Esports', 'Team Liquid ID', 'Fnatic ONIC', 'Paper Rex', 'Sentinels', 'Team Secret', 'PRX Gaming', 'DRX Vision', 'Gen.G Esports', 'T1 Academy'],
  ),
  _GameType(
    _custom,
    Icons.dashboard_customize_rounded,
    'Cabang olahraga / permainan khusus dengan aturan bebas.',
    ['Tim A', 'Tim B', 'Tim C', 'Tim D', 'Tim E', 'Tim F', 'Tim G', 'Tim H', 'Tim I', 'Tim J', 'Tim K', 'Tim L', 'Tim M', 'Tim N', 'Tim O', 'Tim P'],
  ),
];

const _formats = [
  _BracketFormat(_singleElim, 'Sistem gugur tunggal (1x kalah langsung gugur, min. 2 peserta)', Icons.account_tree_rounded),
  _BracketFormat(_doubleElim, 'Sistem gugur ganda (Winners & Losers Bracket, min. 4 peserta)', Icons.alt_route_rounded),
  _BracketFormat('Round Robin', 'Semua peserta bertemu satu sama lain (1 leg)', Icons.loop_rounded),
  _BracketFormat('Liga', 'Format kompetisi penuh (Home & Away / 2 leg)', Icons.format_list_numbered_rounded),
  _BracketFormat('Swiss System', 'Sistem Swiss berpasangan sesuai poin per ronde', Icons.shuffle_rounded),
];

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
  final _pesertaControllers = <TextEditingController>[];
  // Nama tim, cuma dipakai saat _splitPesertaTim (Online + Sepak Bola/Futsal).
  final _timControllers = <TextEditingController>[];

  bool _isPrivate = true; // Default: Turnamen Privat (Lokal di HP)
  _GameType _game = _gameTypes.first;
  _BracketFormat _format = _formats.first;
  String _lastLeague = 'Liga Inggris';
  String _lastDivision = 'Premier League';
  int _jumlahLeg = 1; // 1 = 1x Tanding, 2 = Home & Away
  int _bestOf = 1; // 1 / 3 / 5 / 7, untuk cabang selain sepak bola & basket
  int _kuota = 4;
  bool _isLoading = false;

  // Provider: user diambil dari AuthProvider
  Map<String, dynamic>? get _currentUser => context.read<AuthProvider>().user;

  bool get _isFootball => _game.name == _football;

  /// Sepak bola & basket pakai sistem leg (1x / Home & Away), cabang lain
  /// pakai Best of.
  bool get _usesLeg => _isFootball || _game.name == _basket;
  bool get _splitPesertaTim => !_isPrivate && _isFootball;
  bool get _isElimination => _format.name == _singleElim || _format.name == _doubleElim;
  List<int> get _eliminationOptions => _format.name == _doubleElim
      ? const [4, 8, 16, 32, 64]
      : const [2, 4, 8, 16, 32, 64];

  @override
  void initState() {
    super.initState();
    _setPesertaCount(_kuota);
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _customGameController.dispose();
    for (final c in [..._pesertaControllers, ..._timControllers]) {
      c.dispose();
    }
    super.dispose();
  }

  // ===================== LOGIKA FORM =====================

  void _setPesertaCount(int count) {
    while (_pesertaControllers.length < count) {
      _pesertaControllers.add(
        TextEditingController(text: 'Peserta ${_pesertaControllers.length + 1}'),
      );
      _timControllers.add(TextEditingController());
    }
    while (_pesertaControllers.length > count) {
      _pesertaControllers.removeLast().dispose();
      _timControllers.removeLast().dispose();
    }
  }

  void _onFormatChanged(_BracketFormat format) {
    setState(() {
      _format = format;
      // Format gugur: kuota harus salah satu pilihan (kelipatan 2).
      if (_isElimination && !_eliminationOptions.contains(_kuota)) _kuota = 4;
      _setPesertaCount(_kuota);
    });
  }

  void _onGameChanged(_GameType game) {
    setState(() {
      _game = game;
      // Pindah ke cabang tanpa leg: leg dikembalikan ke 1x
      if (!_usesLeg) _jumlahLeg = 1;
    });
  }

  void _changeKuota(int newKuota) {
    if (newKuota < 2) return;
    if (_format.name == _doubleElim && newKuota < 4) {
      context.showSnack(
        'Double Elimination membutuhkan minimal 4 peserta untuk Upper & Lower Bracket!',
        color: AppColors.warning,
      );
      return;
    }
    setState(() {
      _kuota = newKuota;
      _setPesertaCount(newKuota);
    });
  }

  void _fillSampleNames() {
    final targets = _splitPesertaTim ? _timControllers : _pesertaControllers;
    for (int i = 0; i < targets.length; i++) {
      if (i < _game.samples.length) {
        targets[i].text = _game.samples[i];
      } else if (!_splitPesertaTim) {
        targets[i].text = 'Peserta ${i + 1}';
      }
    }
    setState(() {});
  }

  Future<void> _openFootballTeamPicker(int index) async {
    // GetX: buka dialog dan tunggu hasilnya
    final result = await Get.dialog<FootballTeamPickerResult>(
      FootballTeamPickerDialog(
        initialLeague: _lastLeague,
        initialDivision: _lastDivision,
        participantIndex: index,
      ),
    );
    if (result == null) return;

    setState(() {
      final target = _splitPesertaTim ? _timControllers : _pesertaControllers;
      target[index].text = result.clubName;
      _lastLeague = result.leagueName;
      _lastDivision = result.divisionName;
    });
  }

  void _selectPublic() {
    if (_currentUser == null) {
      _showLoginRequired();
    } else {
      setState(() => _isPrivate = false);
    }
  }

  void _showLoginRequired() {
    showLoginRequiredDialog(
      message: 'Untuk membuat turnamen online (publik), Anda harus masuk ke akun '
          'terlebih dahulu agar data tersimpan di server dan dapat dilihat oleh pemain lain.',
      cancelLabel: 'Tetap Privat',
      onLogin: () async {
        // Push/Pop (basic)
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        if (!mounted) return;
        await context.read<AuthProvider>().loadSession();
        if (_currentUser != null && mounted) setState(() => _isPrivate = false);
      },
    );
  }

  Future<void> _saveTurnamen() async {
    if (!_formKey.currentState!.validate()) return;
    // Turnamen publik wajib login
    if (!_isPrivate && _currentUser == null) {
      _showLoginRequired();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final nama = _namaController.text.trim();
      final deskripsi = _deskripsiController.text.trim();
      final customGame = _customGameController.text.trim();
      final tipeGame = _game.name == _custom && customGame.isNotEmpty ? customGame : _game.name;
      final peserta = [
        for (int i = 0; i < _pesertaControllers.length; i++)
          _pesertaControllers[i].text.trim().isEmpty
              ? 'Peserta ${i + 1}'
              : _pesertaControllers[i].text.trim(),
      ];
      // Leg untuk sepak bola & basket, Best of untuk cabang lain
      final jumlahLeg = _usesLeg ? _jumlahLeg : 1;
      final bestOf = _usesLeg ? 1 : _bestOf;

      if (_isPrivate) {
        await LocalTournamentService.instance.createTurnamen(
          namaTurnamen: nama,
          deskripsi: deskripsi.isEmpty ? null : deskripsi,
          tipeGame: tipeGame,
          formatBracket: _format.name,
          jumlahLeg: jumlahLeg,
          bestOf: bestOf,
          tanggalMulai: DateTime.now(),
          kuota: _kuota,
          peserta: peserta,
          emailUser: _currentUser?['email']?.toString() ?? '',
        );
      } else {
        await ApiService.instance.createTurnamen(
          namaTurnamen: nama,
          deskripsi: deskripsi.isEmpty ? null : deskripsi,
          tipeGame: tipeGame,
          formatBracket: _format.name,
          jumlahLeg: jumlahLeg,
          bestOf: bestOf,
          tanggalMulai: DateTime.now(),
          kuota: _kuota,
          peserta: peserta,
          namaTim: _splitPesertaTim ? [for (final c in _timControllers) c.text.trim()] : null,
        );
      }

      if (!mounted) return;
      context.showSnack(
        _isPrivate
            ? 'Turnamen privat berhasil dibuat & disimpan ke database lokal HP!'
            : 'Turnamen publik berhasil dibuat di server backend!',
        color: AppColors.success,
      );
      // GetX: kembali + bawa hasil
      Get.back(result: true);
    } catch (e) {
      if (mounted) context.showSnack('Gagal membuat turnamen: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCustomKuotaDialog() {
    final controller = TextEditingController(text: '$_kuota');

    Get.dialog(
      AppDialog(
        title: 'Input Jumlah Kuota Peserta',
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
              controller: controller,
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
          const DialogTextButton('Batal'),
          DialogFilledButton(
            'Terapkan',
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 2) {
                context.showSnack('Jumlah peserta minimal 2 orang!', color: AppColors.error);
                return;
              }
              _changeKuota(value);
              Get.back();
            },
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
    // MediaQuery: padding 5% lebar layar, isi maks 900 dp. Layar >= 600 dp:
    // section berdampingan 1:1 dan daftar peserta 2 kolom.
    final layout = PageLayout.of(context, maxWidth: 900, paddingRatio: 0.05);
    final sectionGap = layout.isShort ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('Buat Turnamen Baru')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: layout.sidePadding, vertical: sectionGap),
            children: [
              // Bagian 1: Sifat | Informasi
              ResponsivePair(
                isWide: layout.isWide,
                gap: layout.gap,
                verticalGap: sectionGap,
                left: Section(
                  title: 'Sifat & Penyimpanan Turnamen',
                  child: _SifatSelector(
                    isPrivate: _isPrivate,
                    onPrivate: () => setState(() => _isPrivate = true),
                    onPublic: _selectPublic,
                  ),
                ),
                right: Section(
                  title: 'Informasi Turnamen',
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _namaController,
                        label: 'Nama Turnamen',
                        hint: 'cth: Turnamen Futsal ITK Cup 2026',
                        icon: Icons.emoji_events_rounded,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Nama turnamen wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
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
              SizedBox(height: sectionGap),

              // Bagian 2: Tipe Game | Format
              ResponsivePair(
                isWide: layout.isWide,
                gap: layout.gap,
                verticalGap: sectionGap,
                left: Section(
                  title: 'Tipe Game / Cabang Olahraga',
                  child: _GameTypeSelector(
                    selected: _game,
                    customController: _customGameController,
                    onSelected: _onGameChanged,
                  ),
                ),
                right: Section(
                  title: 'Format & Sistem Pertandingan',
                  child: _FormatSelector(selected: _format, onSelected: _onFormatChanged),
                ),
              ),
              SizedBox(height: sectionGap * 0.7),

              // Bagian 3: Leg / Best of | Kuota
              ResponsivePair(
                isWide: layout.isWide,
                gap: layout.gap,
                verticalGap: 14,
                left: _SeriesSelector(
                  usesLeg: _usesLeg,
                  isChess: _game.name == 'Catur',
                  jumlahLeg: _jumlahLeg,
                  bestOf: _bestOf,
                  onLegChanged: (leg) => setState(() => _jumlahLeg = leg),
                  onBestOfChanged: (bo) => setState(() => _bestOf = bo),
                ),
                right: _KuotaSelector(
                  kuota: _kuota,
                  format: _format.name,
                  options: _isElimination ? _eliminationOptions : const [2, 3, 4, 5, 6, 8, 10, 12, 16],
                  onChanged: _changeKuota,
                  onCustom: _showCustomKuotaDialog,
                ),
              ),
              SizedBox(height: sectionGap + 4),

              // Bagian 4: Daftar peserta
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Daftar Peserta (${_pesertaControllers.length})',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: layout.isNarrow ? 15 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: _fillSampleNames,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.secondary),
                      label: Text(
                        'Isi Contoh ${_game.name}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.secondary, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ResponsiveGrid(
                columns: layout.isWide ? 2 : 1,
                gap: layout.gap,
                children: [
                  for (int i = 0; i < _pesertaControllers.length; i++)
                    _PesertaField(
                      index: i,
                      pesertaController: _pesertaControllers[i],
                      timController: _timControllers[i],
                      splitMode: _splitPesertaTim,
                      showPickButton: _isFootball,
                      onPickTeam: () => _openFootballTeamPicker(i),
                    ),
                ],
              ),
              SizedBox(height: sectionGap + 8),

              LoadingButton(
                label: 'Simpan & Generate Pertandingan',
                isLoading: _isLoading,
                onPressed: _saveTurnamen,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== WIDGET STATELESS =====================

class _CardBox extends StatelessWidget {
  const _CardBox({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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

/// Teks keterangan kecil (miring, abu-abu) di bawah pilihan.
class _HintText extends StatelessWidget {
  const _HintText(this.text, {this.fontSize = 11});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: AppColors.textMuted, fontSize: fontSize, fontStyle: FontStyle.italic),
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

class _SifatSelector extends StatelessWidget {
  const _SifatSelector({
    required this.isPrivate,
    required this.onPrivate,
    required this.onPublic,
  });

  final bool isPrivate;
  final VoidCallback onPrivate;
  final VoidCallback onPublic;

  @override
  Widget build(BuildContext context) {
    final accent = isPrivate ? privateColor : AppColors.secondary;

    return _CardBox(
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
                iconColor: privateColor,
                label: 'Privat (Lokal HP)',
                selected: isPrivate,
                selectedColor: privateColorDark,
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
    );
  }
}

class _GameTypeSelector extends StatelessWidget {
  const _GameTypeSelector({
    required this.selected,
    required this.customController,
    required this.onSelected,
  });

  final _GameType selected;
  final TextEditingController customController;
  final ValueChanged<_GameType> onSelected;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final game in _gameTypes)
              _OptionChip(
                icon: game.icon,
                label: game.name,
                selected: selected == game,
                onSelected: () => onSelected(game),
              ),
          ],
        ),
        if (selected.name == _custom) ...[
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
        _InfoNote(icon: Icons.rule_rounded, color: AppColors.secondary, text: selected.rule),
      ],
    );
  }
}

class _FormatSelector extends StatelessWidget {
  const _FormatSelector({required this.selected, required this.onSelected});

  final _BracketFormat selected;
  final ValueChanged<_BracketFormat> onSelected;

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      children: [
        const _CardHeader(icon: Icons.hub_rounded, title: 'Format Bagan Turnamen'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final format in _formats)
              _OptionChip(
                icon: format.icon,
                iconColor: AppColors.textSecondary,
                label: format.name,
                selected: selected == format,
                onSelected: () => onSelected(format),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _HintText(selected.desc, fontSize: 12),
      ],
    );
  }
}

/// Sepak bola & basket: 1x Tanding / 2x Home & Away (leg).
/// Cabang lain: Best of 1 / 3 / 5 / 7 (dibagi rata 1:1:1:1).
class _SeriesSelector extends StatelessWidget {
  const _SeriesSelector({
    required this.usesLeg,
    required this.isChess,
    required this.jumlahLeg,
    required this.bestOf,
    required this.onLegChanged,
    required this.onBestOfChanged,
  });

  final bool usesLeg;
  final bool isChess;
  final int jumlahLeg;
  final int bestOf;
  final ValueChanged<int> onLegChanged;
  final ValueChanged<int> onBestOfChanged;

  String get _description {
    if (usesLeg) {
      return jumlahLeg == 1
          ? '• 1x Tanding: Setiap pertemuan hanya 1 laga (format standar turnamen cepat).'
          : '• 2x Tanding: Format Kandang & Tandang (Home & Away / 2 Leg) untuk setiap pertemuan.';
    }
    if (bestOf == 1) return '• Best of 1: Cukup 1 game, pemenang langsung ditentukan.';
    if (isChess) {
      return '• Best of $bestOf: ${bestOf - 1} game utama (menang 1 poin, remis ½ poin). '
          'Jika poin sama, game ke-$bestOf jadi penentu tanpa remis.';
    }
    final target = bestOf ~/ 2 + 1;
    return '• Best of $bestOf: Pemenang adalah yang pertama menang $target game. '
        'Skor diinput sebagai jumlah game yang dimenangkan (cth: $target-${target - 1}).';
  }

  @override
  Widget build(BuildContext context) {
    return _CardBox(
      children: [
        _CardHeader(
          icon: usesLeg ? Icons.repeat_rounded : Icons.military_tech_rounded,
          title: usesLeg ? 'Sistem Pertemuan (Jumlah Leg)' : 'Format Seri (Best of)',
        ),
        const SizedBox(height: 10),
        if (usesLeg)
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
          Row(
            children: [
              for (final bo in const [1, 3, 5, 7]) ...[
                if (bo > 1) const SizedBox(width: 8),
                Expanded(
                  child: SelectBox(
                    label: 'BO$bo',
                    selected: bestOf == bo,
                    onTap: () => onBestOfChanged(bo),
                    background: AppColors.bgDarkSecondary,
                    borderColor: AppColors.primary,
                    unselectedBorder: Colors.white.withValues(alpha: 0.06),
                    minHeight: 44,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 8),
        _HintText(_description),
      ],
    );
  }
}

class _KuotaSelector extends StatelessWidget {
  const _KuotaSelector({
    required this.kuota,
    required this.format,
    required this.options,
    required this.onChanged,
    required this.onCustom,
  });

  final int kuota;
  final String format;
  final List<int> options;
  final ValueChanged<int> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final isElimination = format == _singleElim || format == _doubleElim;

    return _CardBox(
      children: [
        Row(
          children: [
            const Expanded(
              child: _CardHeader(icon: Icons.people_alt_rounded, title: 'Jumlah Kuota Peserta'),
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
          switch (format) {
            _doubleElim => 'Double Elimination butuh min. 4 peserta (Winners & Losers Bracket):',
            _singleElim => 'Single Elimination wajib kelipatan eksponen 2 (min. 2):',
            _ => 'Bisa pilih preset atau tentukan custom minimal 2 orang:',
          },
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (!isElimination) ...[
          // Stepper (ukuran isi) : tombol custom (sisa lebar)
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
                      icon: const Icon(Icons.remove_rounded, color: AppColors.textPrimary, size: 20),
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
                      icon: const Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 20),
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
    );
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

  /// Online + sepak bola: field pemain dan field tim terpisah.
  final bool splitMode;
  final bool showPickButton;
  final VoidCallback onPickTeam;

  InputDecoration _decoration(Widget prefix, String hint) {
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
    const textStyle = TextStyle(color: AppColors.textPrimary, fontSize: 14);
    final number = index + 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          // Field nama (sisa lebar) : tombol pilih tim (ukuran isi)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: pesertaController,
                  style: textStyle,
                  decoration: _decoration(
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                        child: Text(
                          '$number',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    splitMode ? 'Nama Pemain $number' : 'Nama Tim / Pemain $number',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Nama peserta $number tidak boleh kosong'
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
                    style: textStyle,
                    decoration: _decoration(
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(Icons.shield_outlined, size: 18, color: AppColors.textMuted),
                      ),
                      'Nama Tim $number (opsional)',
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
    // MediaQuery: di layar sangat sempit cuma tampil ikon.
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bgCard,
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
            : const Text('Pilih Tim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
