class PertandinganModel {
  final String idPertandingan;
  final String idTurnamen;
  final String? idPeserta1;
  final String? idPeserta2;
  final String babak;
  final int skorPeserta1;
  final int skorPeserta2;
  final String status;
  final int urutan;
  final String? nextPertandinganId;

  // Joined fields for UI convenience
  final String? namaPeserta1;
  final String? namaPeserta2;

  PertandinganModel({
    required this.idPertandingan,
    required this.idTurnamen,
    this.idPeserta1,
    this.idPeserta2,
    required this.babak,
    this.skorPeserta1 = 0,
    this.skorPeserta2 = 0,
    this.status = 'Belum Mulai',
    this.urutan = 0,
    this.nextPertandinganId,
    this.namaPeserta1,
    this.namaPeserta2,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_pertandingan': idPertandingan,
      'id_turnamen': idTurnamen,
      'id_peserta_1': idPeserta1,
      'id_peserta_2': idPeserta2,
      'babak': babak,
      'skor_peserta_1': skorPeserta1,
      'skor_peserta_2': skorPeserta2,
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
      status: map['status'] as String? ?? 'Belum Mulai',
      urutan: (map['urutan'] as num?)?.toInt() ?? 0,
      nextPertandinganId: map['next_pertandingan_id'] as String?,
      namaPeserta1: map['nama_peserta_1'] as String?,
      namaPeserta2: map['nama_peserta_2'] as String?,
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
    String? status,
    int? urutan,
    String? nextPertandinganId,
    String? namaPeserta1,
    String? namaPeserta2,
  }) {
    return PertandinganModel(
      idPertandingan: idPertandingan ?? this.idPertandingan,
      idTurnamen: idTurnamen ?? this.idTurnamen,
      idPeserta1: idPeserta1 ?? this.idPeserta1,
      idPeserta2: idPeserta2 ?? this.idPeserta2,
      babak: babak ?? this.babak,
      skorPeserta1: skorPeserta1 ?? this.skorPeserta1,
      skorPeserta2: skorPeserta2 ?? this.skorPeserta2,
      status: status ?? this.status,
      urutan: urutan ?? this.urutan,
      nextPertandinganId: nextPertandinganId ?? this.nextPertandinganId,
      namaPeserta1: namaPeserta1 ?? this.namaPeserta1,
      namaPeserta2: namaPeserta2 ?? this.namaPeserta2,
    );
  }
}
