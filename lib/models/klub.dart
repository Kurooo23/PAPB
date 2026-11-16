/// Data klub sepak bola dari API Top 5 Liga Eropa.
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
    final logoBadge =
        (jsonKlub['logoUrl'] ?? jsonKlub['strBadge']) as String?;
    return Klub(
      id: '${jsonKlub['id'] ?? jsonKlub['idTeam'] ?? ''}',
      nama: (jsonKlub['name'] ?? jsonKlub['strTeam'] as String?) ?? '-',
      liga: (jsonKlub['league'] ?? jsonKlub['strLeague'] as String?) ?? '',
      negara: (jsonKlub['country'] ?? jsonKlub['strCountry'] as String?) ?? '',
      logoUrl: (logoBadge == null || logoBadge.isEmpty) ? null : logoBadge,
    );
  }
}

/// Top 5 Liga Eropa yang tersedia di picker.
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
  ];
}
