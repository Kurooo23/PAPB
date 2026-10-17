// Satu baris dari tabel `peserta`.
class Peserta {
  final String id;
  final String idTurnamen;
  final String nama;
  final int urutan;
  final bool isWo;

  const Peserta({
    required this.id,
    required this.idTurnamen,
    required this.nama,
    this.urutan = 0,
    this.isWo = false,
  });

  /// Nama untuk ditampilkan; peserta yang dihapus diberi tanda (WO).
  String get namaTampil => isWo ? '$nama (WO)' : nama;

  /// id_peserta -> nama tampil, dipakai untuk mencari nama lawan di laga.
  static Map<String, String> petaNama(List<Peserta> list) => {
    for (final p in list) p.id: p.namaTampil,
  };

  Map<String, Object?> toMap() => {
    'id_peserta': id,
    'id_turnamen': idTurnamen,
    'urutan': urutan,
    'nama_peserta': nama,
    'is_wo': isWo ? 1 : 0,
  };

  factory Peserta.fromMap(Map<String, Object?> map) => Peserta(
    id: map['id_peserta'] as String,
    idTurnamen: map['id_turnamen'] as String,
    nama: map['nama_peserta'] as String,
    urutan: map['urutan'] as int,
    isWo: (map['is_wo'] as int) == 1,
  );
}
