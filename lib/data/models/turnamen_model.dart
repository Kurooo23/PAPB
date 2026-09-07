class TurnamenModel {
  final String idTurnamen;
  final String namaTurnamen;
  final String? deskripsi;
  final String tipeGame;
  final String formatBracket;
  final int jumlahLeg; // 1 = Single Match, 2 = Home & Away
  final DateTime tanggalMulai;
  final int kuota;
  final String status;
  final bool isPrivate;

  TurnamenModel({
    required this.idTurnamen,
    required this.namaTurnamen,
    this.deskripsi,
    this.tipeGame = 'E-Sports',
    required this.formatBracket,
    this.jumlahLeg = 1,
    required this.tanggalMulai,
    required this.kuota,
    this.status = 'Akan Datang',
    this.isPrivate = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_turnamen': idTurnamen,
      'nama_turnamen': namaTurnamen,
      'deskripsi': deskripsi,
      'tipe_game': tipeGame,
      'format_bracket': formatBracket,
      'jumlah_leg': jumlahLeg,
      'tanggal_mulai': tanggalMulai.toIso8601String(),
      'kuota': kuota,
      'status': status,
      'is_private': isPrivate ? 1 : 0,
    };
  }

  factory TurnamenModel.fromMap(Map<String, dynamic> map) {
    return TurnamenModel(
      idTurnamen: map['id_turnamen'] as String,
      namaTurnamen: map['nama_turnamen'] as String,
      deskripsi: map['deskripsi'] as String?,
      tipeGame: (map['tipe_game'] as String?) ?? 'E-Sports',
      formatBracket: map['format_bracket'] as String,
      jumlahLeg: (map['jumlah_leg'] as int?) ?? 1,
      tanggalMulai: DateTime.parse(map['tanggal_mulai'] as String),
      kuota: map['kuota'] as int,
      status: map['status'] as String? ?? 'Akan Datang',
      isPrivate: map['is_private'] == 1 || map['is_private'] == true || map['isPrivate'] == true,
    );
  }

  TurnamenModel copyWith({
    String? idTurnamen,
    String? namaTurnamen,
    String? deskripsi,
    String? tipeGame,
    String? formatBracket,
    int? jumlahLeg,
    DateTime? tanggalMulai,
    int? kuota,
    String? status,
    bool? isPrivate,
  }) {
    return TurnamenModel(
      idTurnamen: idTurnamen ?? this.idTurnamen,
      namaTurnamen: namaTurnamen ?? this.namaTurnamen,
      deskripsi: deskripsi ?? this.deskripsi,
      tipeGame: tipeGame ?? this.tipeGame,
      formatBracket: formatBracket ?? this.formatBracket,
      jumlahLeg: jumlahLeg ?? this.jumlahLeg,
      tanggalMulai: tanggalMulai ?? this.tanggalMulai,
      kuota: kuota ?? this.kuota,
      status: status ?? this.status,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}
