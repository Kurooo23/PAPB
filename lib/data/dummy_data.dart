import 'package:rivnet/models/turnamen.dart';

const List<String> dummyGame = ['Sepak Bola'];

// hasil: [indexPesertaA, indexPesertaB, skorA, skorB]
Turnamen _buat({
  required String nama,
  required String game,
  required String lokasi,
  required String status,
  required List<String> peserta,
  List<List<int>> hasil = const [],
}) {
  final t = Turnamen(
    id: buatId('trn'),
    nama: nama,
    game: game,
    lokasi: lokasi,
    status: status,
  );
  for (final n in peserta) {
    t.peserta.add(Peserta(id: buatId('p'), nama: n));
  }
  for (final h in hasil) {
    t.pertandingan.add(
      Pertandingan(
        id: buatId('m'),
        idA: t.peserta[h[0]].id,
        idB: t.peserta[h[1]].id,
        skorA: h[2],
        skorB: h[3],
      ),
    );
  }
  return t;
}

List<Turnamen> buatDummyTurnamen() => [
  _buat(
    nama: 'Rivnet Cup Season 1',
    game: 'Sepak Bola',
    lokasi: 'Stadion Batakan, Balikpapan',
    status: 'Akan Datang',
    peserta: [
      'Borneo Muda FC',
      'Persiba Junior',
      'Mahakam United',
      'Samarinda City',
      'Kutai Warriors',
      'Balikpapan Raya FC',
    ],
  ),
  _buat(
    nama: 'Kalimantan Open Cup',
    game: 'Sepak Bola',
    lokasi: 'Lapangan Gelora, Samarinda',
    status: 'Berlangsung',
    peserta: [
      'Pesut Etam FC',
      'Tenggarong SC',
      'Bontang Selection',
      'Penajam Rangers',
    ],
    hasil: [
      [0, 1, 2, 1],
      [2, 3, 0, 0],
      [0, 3, 3, 1],
    ],
  ),
  _buat(
    nama: 'Liga Mahasiswa Balikpapan',
    game: 'Sepak Bola',
    lokasi: 'Lapangan Kampus Utama, Balikpapan',
    status: 'Selesai',
    peserta: ['FT Garuda', 'FE Elang', 'FK Rajawali', 'FH Bhayangkara'],
    hasil: [
      [0, 1, 3, 1],
      [2, 3, 2, 2],
      [0, 2, 1, 0],
      [1, 3, 0, 2],
      [0, 3, 2, 2],
      [1, 2, 1, 3],
    ],
  ),
  _buat(
    nama: 'Piala Kemerdekaan 2025',
    game: 'Sepak Bola',
    lokasi: 'Lapangan Merdeka, Balikpapan',
    status: 'Selesai',
    peserta: ['RT 05 FC', 'Karang Taruna Jaya', 'Bintang Timur'],
    hasil: [
      [0, 1, 4, 2],
      [1, 2, 1, 1],
      [0, 2, 3, 0],
    ],
  ),
];
