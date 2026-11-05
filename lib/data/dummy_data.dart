typedef DataDummyTurnamen = ({
  String nama,
  String game,
  String status,
  int leg,
  List<String> peserta,
  List<List<int>> hasil,
});

const List<String> dummyGame = ['Sepak Bola'];

const List<DataDummyTurnamen> dummyTurnamen = [
  (
    nama: 'UEFA Champions Mini Cup',
    game: 'Sepak Bola',
    status: 'Berlangsung',
    leg: 1,
    peserta: [
      'Real Madrid',
      'Barcelona',
      'Arsenal',
      'Bayern Munich',
    ],
    hasil: [
      [0, 1, 3, 2],
      [2, 3, 1, 1],
      [0, 2, 2, 0],
      [1, 3, 2, 3],
      [0, 3, 1, 2],
      [1, 2, 0, 1],
    ],
  ),
  (
    nama: 'Rivnet Cup Season 1',
    game: 'Sepak Bola',
    status: 'Berlangsung',
    leg: 1,
    peserta: [
      'Borneo Muda FC',
      'Persiba Junior',
      'Mahakam United',
      'Samarinda City',
    ],
    hasil: [
      [0, 1, 2, 1],
      [2, 3, 1, 3],
      [0, 2, 3, 0],
      [1, 3, 2, 2],
      [0, 3, 1, 0],
      [1, 2, 0, 1],
    ],
  ),
  (
    nama: 'Kalimantan Open Cup',
    game: 'Sepak Bola',
    status: 'Berlangsung',
    leg: 1,
    peserta: [
      'Pesut Etam FC',
      'Tenggarong SC',
      'Bontang Selection',
      'Penajam Rangers',
    ],
    hasil: [
      [0, 1, 2, 1],
      [2, 3, 0, 2],
      [0, 3, 3, 1],
      [1, 2, 1, 1],
      [0, 2, 2, 0],
      [1, 3, 1, 3],
    ],
  ),
  (
    nama: 'Liga Mahasiswa Balikpapan',
    game: 'Sepak Bola',
    status: 'Selesai',
    leg: 1,
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
  (
    nama: 'Piala Kemerdekaan 2025',
    game: 'Sepak Bola',
    status: 'Selesai',
    leg: 1,
    peserta: ['RT 05 FC', 'Karang Taruna Jaya', 'Bintang Timur'],
    hasil: [
      [0, 1, 4, 2],
      [1, 2, 1, 1],
      [0, 2, 3, 0],
    ],
  ),
];
