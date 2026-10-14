import 'package:flutter/material.dart';
import '../../../data/data_sources/football_teams_data.dart';

class FootballTeamPickerResult {
  final String clubName;
  final String leagueName;
  final String divisionName;

  FootballTeamPickerResult({
    required this.clubName,
    required this.leagueName,
    required this.divisionName,
  });
}

/// Palet dialog (gaya EA FC).
class _PickerPalette {
  static const bg = Color(0xFF0B1120);
  static const header = Color(0xFF131D33);
  static const card = Color(0xFF1E293B);
  static const cardDark = Color(0xFF0F172A);
  static const cardDeep = Color(0xFF0A0F1D);
  static const sheet = Color(0xFF0F172A);
  static const accent = Color(0xFF00FFA3);
  static const muted = Color(0xFF94A3B8);
}

/// Ukuran dialog dihitung dari MediaQuery, jadi menyesuaikan layar.
/// Lebar dialog = 92% lebar layar (maks 440), tinggi = 85% tinggi layar
/// (maks 680). Logo, font, dan tombol ikut diskalakan dari ukuran dialog.
class _PickerSize {
  const _PickerSize._({
    required this.screenWidth,
    required this.screenHeight,
    required this.dialogWidth,
    required this.dialogHeight,
    required this.logoSize,
    required this.clubFontSize,
    required this.buttonHeight,
    required this.padding,
    required this.gap,
    required this.isCompact,
  });

  factory _PickerSize.of(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final bars = MediaQuery.viewPaddingOf(context);
    final usableHeight = screen.height - bars.vertical;

    final dialogWidth = (screen.width * 0.92).clamp(280.0, 440.0);
    final dialogHeight = (usableHeight * 0.85).clamp(420.0, 680.0);
    final isCompact = dialogHeight < 560;

    return _PickerSize._(
      screenWidth: screen.width,
      screenHeight: usableHeight,
      dialogWidth: dialogWidth,
      dialogHeight: dialogHeight,
      // Logo = 22% lebar dialog, dibatasi 64–110 dp.
      logoSize: (dialogWidth * 0.22).clamp(64.0, 110.0),
      // Font nama klub = 4,2% lebar dialog, dibatasi 14–20.
      clubFontSize: (dialogWidth * 0.042).clamp(14.0, 20.0),
      // Tombol pilih = 7% tinggi dialog, dibatasi 42–52 dp.
      buttonHeight: (dialogHeight * 0.07).clamp(42.0, 52.0),
      padding: dialogWidth * 0.032,
      gap: isCompact ? 8 : 12,
      isCompact: isCompact,
    );
  }

  final double screenWidth;
  final double screenHeight;
  final double dialogWidth;
  final double dialogHeight;
  final double logoSize;
  final double clubFontSize;
  final double buttonHeight;
  final double padding;
  final double gap;
  final bool isCompact;
}

class TeamLogoWidget extends StatelessWidget {
  final String teamName;
  final String leagueName;
  final double size;
  final bool isSelected;

  const TeamLogoWidget({
    super.key,
    required this.teamName,
    required this.leagueName,
    this.size = 80,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTimnas = leagueName == 'Tim Nasional';
    final localAsset = FootballTeamsData.getLocalAssetPath(teamName, leagueName);
    final networkUrl = FootballTeamsData.getTeamLogoUrl(teamName, leagueName);

    final fallbackIcon = Icon(
      isTimnas ? Icons.flag_rounded : Icons.sports_soccer_rounded,
      size: size * 0.45,
      color: isSelected ? _PickerPalette.accent : Colors.white70,
    );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isSelected
              ? [_PickerPalette.accent.withValues(alpha: 0.25), _PickerPalette.cardDark]
              : [_PickerPalette.card, _PickerPalette.cardDeep],
        ),
        border: Border.all(
          color: isSelected ? _PickerPalette.accent : Colors.white24,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          localAsset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            if (networkUrl != null) {
              return Image.network(
                networkUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => fallbackIcon,
              );
            }
            return fallbackIcon;
          },
        ),
      ),
    );
  }
}

class FootballTeamPickerDialog extends StatefulWidget {
  final String initialLeague;
  final String initialDivision;
  final int participantIndex;

  const FootballTeamPickerDialog({
    super.key,
    this.initialLeague = 'Liga Inggris',
    this.initialDivision = 'Premier League',
    required this.participantIndex,
  });

  @override
  State<FootballTeamPickerDialog> createState() => _FootballTeamPickerDialogState();
}

class _FootballTeamPickerDialogState extends State<FootballTeamPickerDialog> {
  late String _selectedLeague;
  late String _selectedDivision;
  late PageController _pageController;
  int _currentClubIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedLeague = FootballTeamsData.leagues.contains(widget.initialLeague)
        ? widget.initialLeague
        : FootballTeamsData.leagues.first;

    final availableDivisions = FootballTeamsData.getDivisions(_selectedLeague);
    _selectedDivision = availableDivisions.contains(widget.initialDivision)
        ? widget.initialDivision
        : availableDivisions.first;

    _pageController = PageController(initialPage: 0, viewportFraction: 0.88);
    // Sinkronkan _currentClubIndex terus-menerus dari posisi scroll asli,
    // bukan cuma saat swipe selesai, supaya label tombol & highlight kartu
    // selalu sama dengan tim yang terlihat di layar.
    _pageController.addListener(_syncCurrentClubIndexWithScroll);
  }

  void _syncCurrentClubIndexWithScroll() {
    if (_currentClubs.isEmpty) return;
    if (!_pageController.hasClients || _pageController.page == null) return;
    final rounded = _pageController.page!.round().clamp(0, _currentClubs.length - 1);
    if (rounded != _currentClubIndex) {
      setState(() => _currentClubIndex = rounded);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_syncCurrentClubIndexWithScroll);
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _currentClubs =>
      FootballTeamsData.getClubs(_selectedLeague, _selectedDivision);

  void _jumpTo(int index) {
    _currentClubIndex = index < 0 ? 0 : index;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentClubIndex);
    }
  }

  void _onLeagueChanged(String newLeague) {
    setState(() {
      _selectedLeague = newLeague;
      _selectedDivision = FootballTeamsData.getDivisions(newLeague).first;
      _jumpTo(0);
    });
  }

  void _onDivisionChanged(String newDivision) {
    setState(() {
      _selectedDivision = newDivision;
      _jumpTo(0);
    });
  }

  void _nextLeague() {
    final leagues = FootballTeamsData.leagues;
    final idx = (leagues.indexOf(_selectedLeague) + 1) % leagues.length;
    _onLeagueChanged(leagues[idx]);
  }

  void _prevLeague() {
    final leagues = FootballTeamsData.leagues;
    final idx = (leagues.indexOf(_selectedLeague) - 1 + leagues.length) % leagues.length;
    _onLeagueChanged(leagues[idx]);
  }

  void _nextDivision() {
    final divisions = FootballTeamsData.getDivisions(_selectedLeague);
    if (divisions.length <= 1) return;
    final idx = (divisions.indexOf(_selectedDivision) + 1) % divisions.length;
    _onDivisionChanged(divisions[idx]);
  }

  void _prevDivision() {
    final divisions = FootballTeamsData.getDivisions(_selectedLeague);
    if (divisions.length <= 1) return;
    final idx = (divisions.indexOf(_selectedDivision) - 1 + divisions.length) % divisions.length;
    _onDivisionChanged(divisions[idx]);
  }

  void _nextClub() {
    if (_currentClubIndex < _currentClubs.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevClub() {
    if (_currentClubIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.animateToPage(
        _currentClubs.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _randomAll() {
    final result = FootballTeamsData.getRandomAll();
    setState(() {
      _selectedLeague = result['league']!;
      _selectedDivision = result['division']!;
      _jumpTo(_currentClubs.indexOf(result['club']!));
    });
  }

  void _randomInLeague() {
    final result = FootballTeamsData.getRandomInLeague(_selectedLeague);
    setState(() {
      _selectedDivision = result['division']!;
      _jumpTo(_currentClubs.indexOf(result['club']!));
    });
  }

  void _randomInDivision() {
    final result = FootballTeamsData.getRandomInDivision(_selectedLeague, _selectedDivision);
    setState(() => _jumpTo(_currentClubs.indexOf(result['club']!)));
  }

  void _selectCurrentClub() {
    if (_currentClubs.isEmpty) return;
    // Ambil posisi asli dari PageController supaya tim yang kepilih
    // dijamin sama dengan yang terlihat di layar.
    final index = _pageController.hasClients && _pageController.page != null
        ? _pageController.page!.round().clamp(0, _currentClubs.length - 1)
        : _currentClubIndex;
    final club = _currentClubs[index];
    final formattedClub = _selectedLeague == 'Tim Nasional'
        ? (club.startsWith('Timnas') ? club : 'Timnas $club')
        : club;

    Navigator.pop(
      context,
      FootballTeamPickerResult(
        clubName: formattedClub,
        leagueName: _selectedLeague,
        divisionName: _selectedDivision,
      ),
    );
  }

  void _showQuickSearchModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _PickerPalette.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allClubs = _currentClubs;
            final filtered = query.isEmpty
                ? allClubs
                : allClubs
                    .where((c) => c.toLowerCase().contains(query.toLowerCase()))
                    .toList();
            final screenHeight = MediaQuery.sizeOf(context).height;
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;

            return Padding(
              // Naik mengikuti keyboard supaya list tidak tertutup.
              padding: EdgeInsets.only(bottom: keyboard),
              child: SizedBox(
                height: screenHeight * 0.7,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Daftar Klub - $_selectedDivision',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        onChanged: (val) => setModalState(() => query = val),
                        decoration: InputDecoration(
                          hintText: 'Ketik nama klub...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54),
                          filled: true,
                          fillColor: _PickerPalette.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final item = filtered[idx];
                            final originalIdx = allClubs.indexOf(item);
                            return ListTile(
                              dense: true,
                              leading: TeamLogoWidget(
                                teamName: item,
                                leagueName: _selectedLeague,
                                size: 32,
                              ),
                              title: Text(
                                item,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: Colors.white38,
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() => _jumpTo(originalIdx));
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSelectionSheet({
    required String title,
    required List<String> items,
    required String selectedItem,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _PickerPalette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    final isSel = item == selectedItem;
                    final flag = FootballTeamsData.leagueFlags[item];
                    return ListTile(
                      dense: true,
                      tileColor: isSel ? _PickerPalette.card : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: flag != null
                          ? Text(flag, style: const TextStyle(fontSize: 18))
                          : const Icon(Icons.shield_outlined, color: Colors.white54),
                      title: Text(
                        item,
                        style: TextStyle(
                          color: isSel ? _PickerPalette.accent : Colors.white,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSel
                          ? const Icon(Icons.check, color: _PickerPalette.accent)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelected(item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _PickerSize.of(context);
    final leagueFlag = FootballTeamsData.leagueFlags[_selectedLeague] ?? '⚽';
    final divisions = FootballTeamsData.getDivisions(_selectedLeague);
    final clubs = _currentClubs;
    final isTimnas = _selectedLeague == 'Tim Nasional';

    return Dialog(
      backgroundColor: Colors.transparent,
      // Jarak dialog ke tepi layar = 4% lebar dan 2,5% tinggi layar.
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.screenWidth * 0.04,
        vertical: size.screenHeight * 0.025,
      ),
      child: Container(
        width: size.dialogWidth,
        height: size.dialogHeight,
        decoration: BoxDecoration(
          color: _PickerPalette.bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _PickerPalette.card, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Baris 1: header
            _PickerHeader(
              participantIndex: widget.participantIndex,
              padding: size.padding,
              onSearch: _showQuickSearchModal,
              onClose: () => Navigator.pop(context),
            ),
            // Baris 2: isi (selector, carousel, tombol)
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(size.padding),
                child: Column(
                  children: [
                    _HorizontalSelector(
                      label: 'LIGA / KATEGORI',
                      title: '$leagueFlag $_selectedLeague',
                      onPrev: _prevLeague,
                      onNext: _nextLeague,
                      onTapTitle: () => _showSelectionSheet(
                        title: 'Pilih Liga',
                        items: FootballTeamsData.leagues,
                        selectedItem: _selectedLeague,
                        onSelected: _onLeagueChanged,
                      ),
                    ),
                    SizedBox(height: size.gap * 0.8),
                    if (!isTimnas && divisions.length > 1)
                      _HorizontalSelector(
                        label: 'DIVISI / KASTA',
                        title: _selectedDivision,
                        isSecondary: true,
                        onPrev: _prevDivision,
                        onNext: _nextDivision,
                        onTapTitle: () => _showSelectionSheet(
                          title: 'Pilih Divisi',
                          items: divisions,
                          selectedItem: _selectedDivision,
                          onSelected: _onDivisionChanged,
                        ),
                      )
                    else
                      _DivisionBadge(
                        text: isTimnas ? '🌍 Tim Nasional Internasional' : _selectedDivision,
                      ),
                    SizedBox(height: size.gap),

                    // Carousel klub mengambil sisa tinggi (Expanded).
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: clubs.length,
                            itemBuilder: (context, index) => _ClubCard(
                              clubName: clubs[index],
                              leagueName: _selectedLeague,
                              subtitle: isTimnas ? 'Tim Nasional' : _selectedDivision,
                              position: '${index + 1} / ${clubs.length}',
                              isCurrent: index == _currentClubIndex,
                              logoSize: size.logoSize,
                              fontSize: size.clubFontSize,
                              isCompact: size.isCompact,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            child: _ArrowButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onPressed: _prevClub,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            child: _ArrowButton(
                              icon: Icons.arrow_forward_ios_rounded,
                              onPressed: _nextClub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: size.gap),

                    // Tiga tombol acak dalam satu Row, lebar dibagi rata 1:1:1.
                    _RandomButtonBar(
                      isTimnas: isTimnas,
                      selectedLeague: _selectedLeague,
                      selectedDivision: _selectedDivision,
                      onRandomAll: _randomAll,
                      onRandomLeague: isTimnas ? _randomInDivision : _randomInLeague,
                      onRandomDivision: _randomInDivision,
                    ),
                    SizedBox(height: size.gap),

                    _SelectButton(
                      height: size.buttonHeight,
                      label: clubs.isNotEmpty
                          ? 'PILIH: ${clubs[_currentClubIndex]}'
                          : 'PILIH TIM INI',
                      onPressed: _selectCurrentClub,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== WIDGET STATELESS =====================

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({
    required this.participantIndex,
    required this.padding,
    required this.onSearch,
    required this.onClose,
  });

  final int participantIndex;
  final double padding;
  final VoidCallback onSearch;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.8),
      decoration: const BoxDecoration(
        color: _PickerPalette.header,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _PickerPalette.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _PickerPalette.accent.withValues(alpha: 0.4)),
            ),
            child: const Text(
              'FC 26',
              style: TextStyle(
                color: _PickerPalette.accent,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih Tim Peserta ${participantIndex + 1}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Geser Kiri / Kanan untuk Memilih Tim',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: _PickerPalette.accent, size: 22),
            tooltip: 'Cari Cepat',
            onPressed: onSearch,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
            tooltip: 'Tutup',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _HorizontalSelector extends StatelessWidget {
  const _HorizontalSelector({
    required this.label,
    required this.title,
    required this.onPrev,
    required this.onNext,
    required this.onTapTitle,
    this.isSecondary = false,
  });

  final String label;
  final String title;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapTitle;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isSecondary ? _PickerPalette.header : _PickerPalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSecondary
              ? Colors.white10
              : _PickerPalette.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
            onPressed: onPrev,
          ),
          Expanded(
            child: InkWell(
              onTap: onTapTitle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isSecondary ? _PickerPalette.muted : _PickerPalette.accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _DivisionBadge extends StatelessWidget {
  const _DivisionBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: _PickerPalette.header,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _PickerPalette.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  const _ClubCard({
    required this.clubName,
    required this.leagueName,
    required this.subtitle,
    required this.position,
    required this.isCurrent,
    required this.logoSize,
    required this.fontSize,
    required this.isCompact,
  });

  final String clubName;
  final String leagueName;
  final String subtitle;
  final String position;
  final bool isCurrent;
  final double logoSize;
  final double fontSize;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrent
              ? [_PickerPalette.card, _PickerPalette.cardDark]
              : [_PickerPalette.header, _PickerPalette.cardDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? _PickerPalette.accent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: _PickerPalette.accent.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      // LayoutBuilder: logo mengecil kalau tinggi kartu tidak cukup,
      // jadi tidak overflow di HP pendek.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logo = logoSize.clamp(48.0, constraints.maxHeight * 0.45);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TeamLogoWidget(
                teamName: clubName,
                leagueName: leagueName,
                size: logo,
                isSelected: isCurrent,
              ),
              SizedBox(height: isCompact ? 8 : 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  clubName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    shadows: isCurrent
                        ? [
                            Shadow(
                              color: _PickerPalette.accent.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _PickerPalette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: isCompact ? 6 : 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  position,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: IconButton.styleFrom(
        backgroundColor: _PickerPalette.card.withValues(alpha: 0.8),
        side: const BorderSide(color: Colors.white12),
      ),
      icon: Icon(icon, color: Colors.white, size: 18),
      onPressed: onPressed,
    );
  }
}

class _RandomButtonBar extends StatelessWidget {
  const _RandomButtonBar({
    required this.isTimnas,
    required this.selectedLeague,
    required this.selectedDivision,
    required this.onRandomAll,
    required this.onRandomLeague,
    required this.onRandomDivision,
  });

  final bool isTimnas;
  final String selectedLeague;
  final String selectedDivision;
  final VoidCallback onRandomAll;
  final VoidCallback onRandomLeague;
  final VoidCallback onRandomDivision;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _PickerPalette.header,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RandomButton(
              icon: Icons.shuffle_rounded,
              label: 'Acak Total',
              tooltip: 'Acak Liga, Divisi & Klub',
              onPressed: onRandomAll,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _RandomButton(
              icon: Icons.alt_route_rounded,
              label: isTimnas ? 'Acak Timnas' : 'Acak Divisi',
              tooltip: isTimnas ? 'Acak Timnas' : 'Acak Divisi & Klub di $selectedLeague',
              onPressed: onRandomLeague,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _RandomButton(
              icon: Icons.casino_rounded,
              label: 'Acak Klub',
              tooltip: 'Acak Klub saja di $selectedDivision',
              onPressed: onRandomDivision,
            ),
          ),
        ],
      ),
    );
  }
}

class _RandomButton extends StatelessWidget {
  const _RandomButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: _PickerPalette.bg,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: _PickerPalette.accent),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectButton extends StatelessWidget {
  const _SelectButton({
    required this.height,
    required this.label,
    required this.onPressed,
  });

  final double height;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _PickerPalette.accent,
          foregroundColor: _PickerPalette.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.check_circle_rounded, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}