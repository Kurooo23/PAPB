/// Satu baris klasemen: statistik pertandingan seorang peserta.
class KlasemenItem {
  final String idPeserta;
  final String namaPeserta;

  /// Catur: [main], [menang], [seri], [kalah] dihitung per game (bukan per
  /// laga), dan [poin] dalam satuan ½ (menang 1 poin = 2, remis ½ poin = 1).
  final bool isChess;
  int main;
  int menang;
  int seri;
  int kalah;
  int gm; // Gol/Skor Masuk
  int gk; // Gol/Skor Kemasukan

  int get sg => gm - gk; // Selisih Skor
  int get poin => isChess ? (menang * 2) + seri : (menang * 3) + (seri * 1);

  KlasemenItem({
    required this.idPeserta,
    required this.namaPeserta,
    this.isChess = false,
    this.main = 0,
    this.menang = 0,
    this.seri = 0,
    this.kalah = 0,
    this.gm = 0,
    this.gk = 0,
  });
}
