class TurnamenModel {
  final String idTurnamen;
  final String namaTurnamen;
  final String? deskripsi;
  final String tipeGame;
  final String formatBracket;
  final int jumlahLeg; // 1 = Single Match, 2 = Home & Away (sepak bola)
  final int bestOf; // 1 / 3 / 5 / 7 (cabang selain sepak bola)
  final DateTime tanggalMulai;
  final int kuota;
  final String status;
  final bool isPrivate;
  final bool isLocked;
  final String emailUser; // Email pemilik turnamen (untuk isolasi per akun)

  TurnamenModel({
    required this.idTurnamen,
    required this.namaTurnamen,
    this.deskripsi,
    this.tipeGame = 'E-Sports',
    required this.formatBracket,
    this.jumlahLeg = 1,
    this.bestOf = 1,
    required this.tanggalMulai,
    required this.kuota,
    this.status = 'Akan Datang',
    this.isPrivate = false,
    this.isLocked = false,
    this.emailUser = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id_turnamen': idTurnamen,
      'nama_turnamen': namaTurnamen,
      'deskripsi': deskripsi,
      'tipe_game': tipeGame,
      'format_bracket': formatBracket,
      'jumlah_leg': jumlahLeg,
      'best_of': bestOf,
      'tanggal_mulai': tanggalMulai.toIso8601String(),
      'kuota': kuota,
      'status': status,
      'is_private': isPrivate ? 1 : 0,
      'is_locked': isLocked ? 1 : 0,
      'email_user': emailUser,
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
      bestOf: (map['best_of'] as int?) ?? 1,
      tanggalMulai: DateTime.parse(map['tanggal_mulai'] as String),
      kuota: map['kuota'] as int,
      status: map['status'] as String? ?? 'Akan Datang',
      isPrivate: map['is_private'] == 1 || map['is_private'] == true || map['isPrivate'] == true,
      isLocked: map['is_locked'] == 1 || map['is_locked'] == true || map['isLocked'] == true,
      emailUser: (map['email_user'] as String?) ?? '',
    );
  }

  TurnamenModel copyWith({
    String? idTurnamen,
    String? namaTurnamen,
    String? deskripsi,
    String? tipeGame,
    String? formatBracket,
    int? jumlahLeg,
    int? bestOf,
    DateTime? tanggalMulai,
    int? kuota,
    String? status,
    bool? isPrivate,
    bool? isLocked,
    String? emailUser,
  }) {
    return TurnamenModel(
      idTurnamen: idTurnamen ?? this.idTurnamen,
      namaTurnamen: namaTurnamen ?? this.namaTurnamen,
      deskripsi: deskripsi ?? this.deskripsi,
      tipeGame: tipeGame ?? this.tipeGame,
      formatBracket: formatBracket ?? this.formatBracket,
      jumlahLeg: jumlahLeg ?? this.jumlahLeg,
      bestOf: bestOf ?? this.bestOf,
      tanggalMulai: tanggalMulai ?? this.tanggalMulai,
      kuota: kuota ?? this.kuota,
      status: status ?? this.status,
      isPrivate: isPrivate ?? this.isPrivate,
      isLocked: isLocked ?? this.isLocked,
      emailUser: emailUser ?? this.emailUser,
    );
  }
}