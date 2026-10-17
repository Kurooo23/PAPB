class Pertandingan {
  final String id;
  final String idTurnamen;
  String? idPeserta1;
  String? idPeserta2;
  final String babak;
  final int leg;
  int _skor1;
  int _skor2;
  int? _penalti1;
  int? _penalti2;
  String _status;
  final int urutan;
  final String? nextId;

  Pertandingan({
    required this.id,
    required this.idTurnamen,
    this.idPeserta1,
    this.idPeserta2,
    required this.babak,
    this.leg = 1,
    int skor1 = 0,
    int skor2 = 0,
    int? penalti1,
    int? penalti2,
    String status = 'Belum Mulai',
    this.urutan = 0,
    this.nextId,
  }) : _skor1 = skor1,
       _skor2 = skor2,
       _penalti1 = penalti1,
       _penalti2 = penalti2,
       _status = status;

  int get skor1 => _skor1;
  int get skor2 => _skor2;
  int? get penalti1 => _penalti1;
  int? get penalti2 => _penalti2;
  String get status => _status;

  set skor1(int value) {
    if (value >= 0) _skor1 = value;
  }

  set skor2(int value) {
    if (value >= 0) _skor2 = value;
  }

  set penalti1(int? value) {
    if (value == null || value >= 0) _penalti1 = value;
  }

  set penalti2(int? value) {
    if (value == null || value >= 0) _penalti2 = value;
  }

  static const _validStatus = ['Belum Mulai', 'Selesai'];
  set status(String value) {
    if (_validStatus.contains(value)) _status = value;
  }

  Map<String, Object?> toMap() => {
    'id_pertandingan': id,
    'id_turnamen': idTurnamen,
    'id_peserta_1': idPeserta1,
    'id_peserta_2': idPeserta2,
    'babak': babak,
    'leg': leg,
    'skor_peserta_1': skor1,
    'skor_peserta_2': skor2,
    'skor_penalti_peserta_1': penalti1,
    'skor_penalti_peserta_2': penalti2,
    'status': status,
    'urutan': urutan,
    'next_pertandingan_id': nextId,
  };

  factory Pertandingan.fromMap(Map<String, Object?> map) => Pertandingan(
    id: map['id_pertandingan'] as String,
    idTurnamen: map['id_turnamen'] as String,
    idPeserta1: map['id_peserta_1'] as String?,
    idPeserta2: map['id_peserta_2'] as String?,
    babak: map['babak'] as String,
    leg: map['leg'] as int,
    skor1: map['skor_peserta_1'] as int,
    skor2: map['skor_peserta_2'] as int,
    penalti1: map['skor_penalti_peserta_1'] as int?,
    penalti2: map['skor_penalti_peserta_2'] as int?,
    status: map['status'] as String,
    urutan: map['urutan'] as int,
    nextId: map['next_pertandingan_id'] as String?,
  );
}
