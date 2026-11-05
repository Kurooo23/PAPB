/// Data klub sepak bola dari API TheSportsDB.
class Klub {
  final String id;
  final String nama;
  final String liga;
  final String negara;
  final String? logoUrl;

  const Klub({
    required this.id,
    required this.nama,
    required this.liga,
    required this.negara,
    this.logoUrl,
  });

  factory Klub.fromJson(Map<String, dynamic> jsonKlub) {
    // Field logo di API kadang bernama strBadge (baru) / strTeamBadge (lama)
    final logoBadge =
        (jsonKlub['strBadge'] ?? jsonKlub['strTeamBadge']) as String?;
    return Klub(
      id: '${jsonKlub['idTeam'] ?? ''}',
      nama: (jsonKlub['strTeam'] as String?) ?? '-',
      liga: (jsonKlub['strLeague'] as String?) ?? '',
      negara: (jsonKlub['strCountry'] as String?) ?? '',
      logoUrl: (logoBadge == null || logoBadge.isEmpty) ? null : logoBadge,
    );
  }

  /// URL logo versi kecil (lebih ringan untuk list).
  String? get logoKecil {
    if (logoUrl == null) return null;
    if (logoUrl!.contains('thesportsdb.com')) return '$logoUrl/small';
    return logoUrl;
  }
}

/// Liga-liga Eropa yang tersedia di picker.
/// [kode] = nama liga persis seperti di TheSportsDB.
class LigaEropa {
  final String kode;
  final String label;
  const LigaEropa(this.kode, this.label);

  static const daftar = [
    LigaEropa('English Premier League', 'Premier League'),
    LigaEropa('Spanish La Liga', 'La Liga'),
    LigaEropa('Italian Serie A', 'Serie A'),
    LigaEropa('German Bundesliga', 'Bundesliga'),
    LigaEropa('French Ligue 1', 'Ligue 1'),
    LigaEropa('Dutch Eredivisie', 'Eredivisie'),
    LigaEropa('Portuguese Primeira Liga', 'Liga Portugal'),
  ];
}
