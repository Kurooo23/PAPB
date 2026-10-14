class PesertaModel {
  final String idPeserta;
  final String idTurnamen;
  final String namaPeserta;

  /// Nama tim/klub yang dimainkan peserta ini, terpisah dari identitas
  /// orangnya (namaPeserta). Cuma dipakai turnamen Online + Sepak Bola/Futsal;
  /// null untuk turnamen lain atau mode Privat.
  final String? namaTim;

  PesertaModel({
    required this.idPeserta,
    required this.idTurnamen,
    required this.namaPeserta,
    this.namaTim,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_peserta': idPeserta,
      'id_turnamen': idTurnamen,
      'nama_peserta': namaPeserta,
      // Kolom nama_tim belum ada di skema SQLite lokal (cuma dipakai turnamen
      // Online + Sepak Bola/Futsal), jadi disertakan hanya kalau terisi agar
      // insert ke database lokal tidak gagal karena kolom tak dikenal.
      if (namaTim != null) 'nama_tim': namaTim,
    };
  }

  factory PesertaModel.fromMap(Map<String, dynamic> map) {
    return PesertaModel(
      idPeserta: map['id_peserta'] as String,
      idTurnamen: map['id_turnamen'] as String,
      namaPeserta: map['nama_peserta'] as String,
      namaTim: map['nama_tim'] as String?,
    );
  }

  PesertaModel copyWith({
    String? idPeserta,
    String? idTurnamen,
    String? namaPeserta,
    String? namaTim,
  }) {
    return PesertaModel(
      idPeserta: idPeserta ?? this.idPeserta,
      idTurnamen: idTurnamen ?? this.idTurnamen,
      namaPeserta: namaPeserta ?? this.namaPeserta,
      namaTim: namaTim ?? this.namaTim,
    );
  }
}
