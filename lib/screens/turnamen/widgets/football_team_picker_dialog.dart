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

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isSelected
              ? [const Color(0xFF00FFA3).withValues(alpha: 0.25), const Color(0xFF0F172A)]
              : [const Color(0xFF1E293B), const Color(0xFF0A0F1D)],
        ),
        border: Border.all(
          color: isSelected ? const Color(0xFF00FFA3) : Colors.white24,
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
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    isTimnas ? Icons.flag_rounded : Icons.sports_soccer_rounded,
                    size: size * 0.45,
                    color: isSelected ? const Color(0xFF00FFA3) : Colors.white70,
                  );
                },
              );
            }
            return Icon(
              isTimnas ? Icons.flag_rounded : Icons.sports_soccer_rounded,
              size: size * 0.45,
              color: isSelected ? const Color(0xFF00FFA3) : Colors.white70,
            );
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _currentClubs => FootballTeamsData.getClubs(_selectedLeague, _selectedDivision);

  void _onLeagueChanged(String newLeague) {
    setState(() {
      _selectedLeague = newLeague;
      _selectedDivision = FootballTeamsData.getDivisions(newLeague).first;
      _currentClubIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _onDivisionChanged(String newDivision) {
    setState(() {
      _selectedDivision = newDivision;
      _currentClubIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _nextLeague() {
    final leagues = FootballTeamsData.leagues;
    int idx = leagues.indexOf(_selectedLeague);
    idx = (idx + 1) % leagues.length;
    _onLeagueChanged(leagues[idx]);
  }

  void _prevLeague() {
    final leagues = FootballTeamsData.leagues;
    int idx = leagues.indexOf(_selectedLeague);
    idx = (idx - 1 + leagues.length) % leagues.length;
    _onLeagueChanged(leagues[idx]);
  }

  void _nextDivision() {
    final divisions = FootballTeamsData.getDivisions(_selectedLeague);
    if (divisions.length <= 1) return;
    int idx = divisions.indexOf(_selectedDivision);
    idx = (idx + 1) % divisions.length;
    _onDivisionChanged(divisions[idx]);
  }

  void _prevDivision() {
    final divisions = FootballTeamsData.getDivisions(_selectedLeague);
    if (divisions.length <= 1) return;
    int idx = divisions.indexOf(_selectedDivision);
    idx = (idx - 1 + divisions.length) % divisions.length;
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
      final clubs = FootballTeamsData.getClubs(_selectedLeague, _selectedDivision);
      _currentClubIndex = clubs.indexOf(result['club']!);
      if (_currentClubIndex < 0) _currentClubIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentClubIndex);
      }
    });
  }

  void _randomInLeague() {
    final result = FootballTeamsData.getRandomInLeague(_selectedLeague);
    setState(() {
      _selectedDivision = result['division']!;
      final clubs = FootballTeamsData.getClubs(_selectedLeague, _selectedDivision);
      _currentClubIndex = clubs.indexOf(result['club']!);
      if (_currentClubIndex < 0) _currentClubIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentClubIndex);
      }
    });
  }

  void _randomInDivision() {
    final result = FootballTeamsData.getRandomInDivision(_selectedLeague, _selectedDivision);
    setState(() {
      final clubs = _currentClubs;
      _currentClubIndex = clubs.indexOf(result['club']!);
      if (_currentClubIndex < 0) _currentClubIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentClubIndex);
      }
    });
  }

  void _selectCurrentClub() {
    if (_currentClubs.isEmpty) return;
    final club = _currentClubs[_currentClubIndex];
    final String formattedClub = _selectedLeague == 'Tim Nasional'
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
      backgroundColor: const Color(0xFF0F172A),
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
                : allClubs.where((c) => c.toLowerCase().contains(query.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Klub - $_selectedDivision',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                            isSelected: false,
                          ),
                          title: Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white38),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _currentClubIndex = originalIdx >= 0 ? originalIdx : 0;
                              if (_pageController.hasClients) {
                                _pageController.jumpToPage(_currentClubIndex);
                              }
                            });
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String leagueFlag = FootballTeamsData.leagueFlags[_selectedLeague] ?? '⚽';
    final divisions = FootballTeamsData.getDivisions(_selectedLeague);
    final clubs = _currentClubs;
    final bool isTimnas = _selectedLeague == 'Tim Nasional';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1120),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
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
            // Header EA FC Style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF131D33),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FFA3).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF00FFA3).withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'FC 26',
                      style: TextStyle(color: Color(0xFF00FFA3), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Tim Peserta ${widget.participantIndex + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Geser Kiri / Kanan untuk Memilih Tim',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: Color(0xFF00FFA3), size: 22),
                    tooltip: 'Cari Cepat',
                    onPressed: _showQuickSearchModal,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  children: [
                    // 1. TOP CAROUSEL: LIGA / NEGARA
                    _buildHorizontalSelector(
                      label: 'LIGA / KATEGORI',
                      title: '$leagueFlag $_selectedLeague',
                      onPrev: _prevLeague,
                      onNext: _nextLeague,
                      onTapTitle: () {
                        _showSelectionSheet(
                          title: 'Pilih Liga',
                          items: FootballTeamsData.leagues,
                          selectedItem: _selectedLeague,
                          onSelected: _onLeagueChanged,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // 2. MIDDLE CAROUSEL: DIVISI
                    if (!isTimnas && divisions.length > 1)
                      _buildHorizontalSelector(
                        label: 'DIVISI / KASTA',
                        title: _selectedDivision,
                        isSecondary: true,
                        onPrev: _prevDivision,
                        onNext: _nextDivision,
                        onTapTitle: () {
                          _showSelectionSheet(
                            title: 'Pilih Divisi',
                            items: divisions,
                            selectedItem: _selectedDivision,
                            onSelected: _onDivisionChanged,
                          );
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131D33),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isTimnas ? '🌍 Tim Nasional Internasional' : _selectedDivision,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // 3. MAIN CAROUSEL: KLUB / TIM
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: clubs.length,
                            onPageChanged: (idx) => setState(() => _currentClubIndex = idx),
                            itemBuilder: (context, index) {
                              final clubName = clubs[index];
                              final isCurrent = index == _currentClubIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isCurrent
                                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                        : [const Color(0xFF131D33), const Color(0xFF0A0F1D)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isCurrent
                                        ? const Color(0xFF00FFA3).withValues(alpha: 0.6)
                                        : Colors.white.withValues(alpha: 0.08),
                                    width: isCurrent ? 2 : 1,
                                  ),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF00FFA3).withValues(alpha: 0.15),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Club Crest Widget (Offline first -> Network -> Fallback)
                                    TeamLogoWidget(
                                      teamName: clubName,
                                      leagueName: _selectedLeague,
                                      size: 96,
                                      isSelected: isCurrent,
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      child: Text(
                                        clubName,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                          shadows: isCurrent
                                              ? [
                                                  Shadow(
                                                    color: const Color(0xFF00FFA3).withValues(alpha: 0.4),
                                                    blurRadius: 8,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isTimnas ? 'Tim Nasional' : _selectedDivision,
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${index + 1} / ${clubs.length}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          Positioned(
                            left: 0,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.8),
                                side: const BorderSide(color: Colors.white12),
                              ),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                              onPressed: _prevClub,
                            ),
                          ),

                          Positioned(
                            right: 0,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.8),
                                side: const BorderSide(color: Colors.white12),
                              ),
                              icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                              onPressed: _nextClub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4. TIGA TOMBOL RANDOM
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D33),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRandomButton(
                              icon: Icons.shuffle_rounded,
                              label: 'Acak Total',
                              tooltip: 'Acak Liga, Divisi & Klub',
                              onPressed: _randomAll,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildRandomButton(
                              icon: Icons.alt_route_rounded,
                              label: isTimnas ? 'Acak Timnas' : 'Acak Divisi',
                              tooltip: isTimnas ? 'Acak Timnas' : 'Acak Divisi & Klub di $_selectedLeague',
                              onPressed: isTimnas ? _randomInDivision : _randomInLeague,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildRandomButton(
                              icon: Icons.casino_rounded,
                              label: 'Acak Klub',
                              tooltip: 'Acak Klub saja di $_selectedDivision',
                              onPressed: _randomInDivision,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 5. TOMBOL PILIH TIM
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFA3),
                          foregroundColor: const Color(0xFF0B1120),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 6,
                        ),
                        onPressed: _selectCurrentClub,
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: Text(
                          clubs.isNotEmpty
                              ? 'PILIH: ${clubs[_currentClubIndex]}'
                              : 'PILIH TIM INI',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

  Widget _buildHorizontalSelector({
    required String label,
    required String title,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required VoidCallback onTapTitle,
    bool isSecondary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isSecondary ? const Color(0xFF131D33) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSecondary ? Colors.white10 : const Color(0xFF00FFA3).withValues(alpha: 0.3),
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
                        color: isSecondary ? const Color(0xFF94A3B8) : const Color(0xFF00FFA3),
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

  Widget _buildRandomButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: const Color(0xFF0B1120),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF00FFA3)),
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

  void _showSelectionSheet({
    required String title,
    required List<String> items,
    required String selectedItem,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                      tileColor: isSel ? const Color(0xFF1E293B) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: flag != null ? Text(flag, style: const TextStyle(fontSize: 18)) : const Icon(Icons.shield_outlined, color: Colors.white54),
                      title: Text(
                        item,
                        style: TextStyle(
                          color: isSel ? const Color(0xFF00FFA3) : Colors.white,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSel ? const Icon(Icons.check, color: Color(0xFF00FFA3)) : null,
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
}
