class PesertaModel {
  final String idPeserta;
  final String idTurnamen;
  final String namaPeserta;

  PesertaModel({
    required this.idPeserta,
    required this.idTurnamen,
    required this.namaPeserta,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_peserta': idPeserta,
      'id_turnamen': idTurnamen,
      'nama_peserta': namaPeserta,
    };
  }

  factory PesertaModel.fromMap(Map<String, dynamic> map) {
    return PesertaModel(
      idPeserta: map['id_peserta'] as String,
      idTurnamen: map['id_turnamen'] as String,
      namaPeserta: map['nama_peserta'] as String,
    );
  }

  PesertaModel copyWith({
    String? idPeserta,
    String? idTurnamen,
    String? namaPeserta,
  }) {
    return PesertaModel(
      idPeserta: idPeserta ?? this.idPeserta,
      idTurnamen: idTurnamen ?? this.idTurnamen,
      namaPeserta: namaPeserta ?? this.namaPeserta,
    );
  }
}
