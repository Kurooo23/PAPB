class PertandinganModel {
  final String idPertandingan;
  final String idTurnamen;
  final String? idPeserta1;
  final String? idPeserta2;
  final String babak;
  final int skorPeserta1;
  final int skorPeserta2;
  final int? skorPenaltiPeserta1;
  final int? skorPenaltiPeserta2;
  final String status;
  final int urutan;
  final String? nextPertandinganId;

  // Joined fields for UI convenience
  final String? namaPeserta1;
  final String? namaPeserta2;

  /// Nama tim yang dimainkan tiap peserta, terpisah dari identitas orangnya.
  /// Cuma terisi untuk turnamen Online + Sepak Bola/Futsal.
  final String? namaTim1;
  final String? namaTim2;

  PertandinganModel({
    required this.idPertandingan,
    required this.idTurnamen,
    this.idPeserta1,
    this.idPeserta2,
    required this.babak,
    this.skorPeserta1 = 0,
    this.skorPeserta2 = 0,
    this.skorPenaltiPeserta1,
    this.skorPenaltiPeserta2,
    this.status = 'Belum Mulai',
    this.urutan = 0,
    this.nextPertandinganId,
    this.namaPeserta1,
    this.namaPeserta2,
    this.namaTim1,
    this.namaTim2,
  });

  /// Label tampilan siap pakai: "Nama Pemain (Nama Tim)" kalau nama tim ada,
  /// atau nama peserta saja kalau tidak (turnamen non-sepak bola / privat).
  String? get displayNama1 => _displayNama(namaPeserta1, namaTim1);
  String? get displayNama2 => _displayNama(namaPeserta2, namaTim2);

  static String? _displayNama(String? nama, String? tim) {
    if (nama == null) return null;
    if (tim == null || tim.trim().isEmpty) return nama;
    return '$nama ($tim)';
  }

  Map<String, dynamic> toMap() {
    return {
      'id_pertandingan': idPertandingan,
      'id_turnamen': idTurnamen,
      'id_peserta_1': idPeserta1,
      'id_peserta_2': idPeserta2,
      'babak': babak,
      'skor_peserta_1': skorPeserta1,
      'skor_peserta_2': skorPeserta2,
      'skor_penalti_peserta_1': skorPenaltiPeserta1,
      'skor_penalti_peserta_2': skorPenaltiPeserta2,
      'status': status,
      'urutan': urutan,
      'next_pertandingan_id': nextPertandinganId,
    };
  }

  factory PertandinganModel.fromMap(Map<String, dynamic> map) {
    return PertandinganModel(
      idPertandingan: map['id_pertandingan'] as String,
      idTurnamen: map['id_turnamen'] as String,
      idPeserta1: map['id_peserta_1'] as String?,
      idPeserta2: map['id_peserta_2'] as String?,
      babak: map['babak'] as String,
      skorPeserta1: (map['skor_peserta_1'] as num?)?.toInt() ?? 0,
      skorPeserta2: (map['skor_peserta_2'] as num?)?.toInt() ?? 0,
      skorPenaltiPeserta1: (map['skor_penalti_peserta_1'] as num?)?.toInt(),
      skorPenaltiPeserta2: (map['skor_penalti_peserta_2'] as num?)?.toInt(),
      status: map['status'] as String? ?? 'Belum Mulai',
      urutan: (map['urutan'] as num?)?.toInt() ?? 0,
      nextPertandinganId: map['next_pertandingan_id'] as String?,
      namaPeserta1: map['nama_peserta_1'] as String?,
      namaPeserta2: map['nama_peserta_2'] as String?,
      namaTim1: map['nama_tim_1'] as String?,
      namaTim2: map['nama_tim_2'] as String?,
    );
  }

  PertandinganModel copyWith({
    String? idPertandingan,
    String? idTurnamen,
    String? idPeserta1,
    String? idPeserta2,
    String? babak,
    int? skorPeserta1,
    int? skorPeserta2,
    int? skorPenaltiPeserta1,
    int? skorPenaltiPeserta2,
    String? status,
    int? urutan,
    String? nextPertandinganId,
    String? namaPeserta1,
    String? namaPeserta2,
    String? namaTim1,
    String? namaTim2,
  }) {
    return PertandinganModel(
      idPertandingan: idPertandingan ?? this.idPertandingan,
      idTurnamen: idTurnamen ?? this.idTurnamen,
      idPeserta1: idPeserta1 ?? this.idPeserta1,
      idPeserta2: idPeserta2 ?? this.idPeserta2,
      babak: babak ?? this.babak,
      skorPeserta1: skorPeserta1 ?? this.skorPeserta1,
      skorPeserta2: skorPeserta2 ?? this.skorPeserta2,
      skorPenaltiPeserta1: skorPenaltiPeserta1 ?? this.skorPenaltiPeserta1,
      skorPenaltiPeserta2: skorPenaltiPeserta2 ?? this.skorPenaltiPeserta2,
      status: status ?? this.status,
      urutan: urutan ?? this.urutan,
      nextPertandinganId: nextPertandinganId ?? this.nextPertandinganId,
      namaPeserta1: namaPeserta1 ?? this.namaPeserta1,
      namaPeserta2: namaPeserta2 ?? this.namaPeserta2,
      namaTim1: namaTim1 ?? this.namaTim1,
      namaTim2: namaTim2 ?? this.namaTim2,
    );
  }
}
