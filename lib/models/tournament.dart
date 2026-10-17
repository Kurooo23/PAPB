class Tournament {
  String? id;
  final String name;
  final String game;
  final DateTime date;
  final String? deskripsi;
  final String format;
  final int jumlahLeg;
  final int kuota;
  final List<String> peserta;
  String _status;
  bool _isFinished;

  Tournament({
    this.id,
    required this.name,
    required this.game,
    required this.date,
    this.deskripsi,
    this.format = 'Single Elimination',
    this.jumlahLeg = 1,
    this.kuota = 4,
    this.peserta = const [],
    String status = 'Akan Datang',
    bool isFinished = false,
  }) : _status = status,
       _isFinished = isFinished;

  String get status => _status;
  bool get isFinished => _isFinished;

  bool get isKnockout => format == 'Single Elimination';

  static const _validStatus = ['Akan Datang', 'Berlangsung', 'Selesai'];
  set status(String value) {
    if (_validStatus.contains(value)) _status = value;
  }

  // kalau turnamen ditandai selesai, statusnya ikut jadi 'Selesai'
  set isFinished(bool value) {
    _isFinished = value;
    if (value) _status = 'Selesai';
  }

  Map<String, Object?> toMap() => {
    'id_turnamen': id,
    'nama_turnamen': name,
    'deskripsi': deskripsi,
    'tipe_game': game,
    'format_bracket': format,
    'jumlah_leg': jumlahLeg,
    'tanggal_mulai': date.toIso8601String(),
    'kuota': kuota,
    'status': status,
    'is_finished': isFinished ? 1 : 0,
  };

  factory Tournament.fromMap(Map<String, Object?> map, List<String> peserta) {
    return Tournament(
      id: map['id_turnamen'] as String,
      name: map['nama_turnamen'] as String,
      game: map['tipe_game'] as String,
      date: DateTime.parse(map['tanggal_mulai'] as String),
      deskripsi: map['deskripsi'] as String?,
      format: map['format_bracket'] as String,
      jumlahLeg: map['jumlah_leg'] as int,
      kuota: map['kuota'] as int,
      peserta: peserta,
      status: map['status'] as String,
      isFinished: (map['is_finished'] as int) == 1,
    );
  }
}
