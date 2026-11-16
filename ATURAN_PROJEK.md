# Aturan Coding & Arsitektur UI — RivNet

Dokumen ini mencatat aturan wajib untuk setiap pengembangan atau revisi halaman/widget di project **RivNet**.

---

## 1. Tata Letak dengan `Row` dan `Column` Berbasis Rasio
Semua pembagian ruang horizontal (`Row`) maupun vertikal (`Column`) menggunakan **rasio proporsional** terhadap ukuran layar (bukan ukuran pixel sembarangan).

### Contoh perhitungan rasio
Misalkan ada 3 kolom dengan rasio **`1 : 2 : 1`** (total bagian = `1 + 2 + 1 = 4`):
- Kolom 1 = `(1 / 4) * lebarLayar`
- Kolom 2 = `(2 / 4) * lebarLayar`
- Kolom 3 = `(1 / 4) * lebarLayar`

Begitu juga untuk pembagian baris pada `Column` dengan tinggi layar (`tinggiLayar`), misalnya rasio `1 : 3` (total = `4`):
- Baris 1 = `(1 / 4) * tinggiLayar`
- Baris 2 = `(3 / 4) * tinggiLayar`

*(Catatan: jika memakai `Expanded` / `Flexible` di dalam `Row`/`Column`, properti `flex` juga mengikuti rasio bagian tersebut; bila butuh ukuran eksplisit untuk kartu/kontainer/grid, hitung langsung dari `MediaQuery` dikali rasionya sambil memperhitungkan `padding` & `gap`).*

---

## 2. Responsif Menggunakan `MediaQuery`
Penyesuaian ukuran layar (ponsel kecil, ponsel standar, tablet, maupun saat keyboard muncul) wajib mengambil ukuran dari `MediaQuery`:

```dart
final ukuranLayar = MediaQuery.of(context).size;
final lebarLayar = ukuranLayar.width;
final tinggiLayar = ukuranLayar.height;
```

- Gunakan `lebarLayar` untuk menentukan lebar kolom, lebar kartu, atau breakpoint responsif (bukan `LayoutBuilder` atau angka hardcode yang kaku).
- Gunakan `tinggiLayar` untuk menentukan proporsi tinggi komponen vertikal (misalnya tinggi bottom sheet `tinggiLayar * 0.8`).
- Gunakan `MediaQuery.of(context).viewInsets.bottom` bila perlu menyesuaikan padding ketika keyboard muncul.

---

## 3. Navigasi Menggunakan `Named Route`
Semua perpindahan halaman antar-screen wajib menggunakan **Named Route** yang terdaftar di `lib/routes/app_routes.dart` dan `lib/main.dart`:

- Pindah halaman:
  ```dart
  Navigator.pushNamed(context, Routes.detailTurnament, arguments: idTurnamen);
  ```
- Kembali ke halaman sebelumnya:
  ```dart
  Navigator.pop(context);
  ```
- **Jangan** membuat `Navigator.push(context, MaterialPageRoute(...))` langsung di dalam screen/controller untuk perpindahan halaman utama; daftarkan semua route di `Routes` (`lib/routes/app_routes.dart`) dan `onGenerateRoute` (`lib/main.dart`).

---

## 4. Penggunaan `StatelessWidget` dan `StatefulWidget`
- **`StatelessWidget`**: wajib dipakai untuk widget/komponen yang hanya menerima data dari parent (atau merespons `AnimatedBuilder` / `FutureBuilder` tanpa state lokal internal) dan tidak butuh lifecycle (`initState` / `dispose`) maupun `setState`.
- **`StatefulWidget`**: hanya dipakai untuk halaman/komponen yang benar-benar mengelola **state lokal berubah** (`setState`), controller/input (`TextEditingController`, `Timer`), atau lifecycle (`initState`, `didChangeDependencies`, `dispose`).

---

## 5. Penamaan Fungsi, Parameter, dan Variabel yang Jelas
- **Dilarang** memakai nama fungsi, parameter, maupun variabel 1 huruf atau singkatan yang tidak mudah dibaca (misalnya `c`, `d`, `p`, `e`, `a`, `b`, `i`, `j`).
- Gunakan nama deskriptif yang langsung menjelaskan maksudnya (contoh: `indeks`, `peserta`, `laga`, `error`, `stackTrace`, `nomorBabak`, `timAtas`, `timBawah`).

---

## Catatan Penerapan Saat Ini di Project
- **Named Route**: sudah diterapkan di `lib/main.dart`, `lib/routes/app_routes.dart`, `lib/screen/main/home_screen.dart`, `lib/widgets/turnamen_card.dart`, dan `lib/controllers/detail_turnamen_controller.dart`.
- **`MediaQuery` + rasio**:
  - `lib/screen/main/home_screen.dart`: daftar turnamen responsif memakai `MediaQuery.of(context).size.width` (1 kolom di HP, 2 kolom `Row` rasio `1:1` pada layar `> 600`).
  - `lib/screen/turnamen/create_turnament.dart`: perhitungan lebar kartu format (`1:1`), leg (`1:1`), jumlah peserta (`1:1` / `1:1:1`), dan input peserta 2 kolom (`1:1` pada layar `> 600`) memakai `MediaQuery`.
  - `lib/screen/turnamen/detail_turnament.dart`: tabel klasemen memakai rasio kolom (`10 : 44 : 12 : 9 : 9 : 9 : 11 : 13`) dikali lebar dari `MediaQuery`, baris laga memakai `Row` rasio `2 : 1 : 2`, dan ukuran kolom/slot bracket dihitung dari `MediaQuery`.
  - `lib/controllers/detail_turnamen_controller.dart`: lebar konten dialog skor dihitung proporsional dari `MediaQuery`.
  - `lib/widgets/pilih_klub_sheet.dart`: tinggi bottom sheet `MediaQuery.of(context).size.height * 0.8` dan padding keyboard `viewInsets.bottom`.
- **`StatelessWidget` & `StatefulWidget` (100% sesuai):**
  - `StatefulWidget` (5 widget, semuanya punya state lokal / controller / lifecycle): `HomeScreen`, `CreateTurnamentScreen`, `DetailTurnamentScreen`, `_PilihKlubSheet`, dan `_DialogPeserta`.
  - `StatelessWidget` (19 widget, pure tampilan dari parent/`AnimatedBuilder`/`FutureBuilder`): `RivnetApp`, `DaftarTurnamen`, `_Label`, `_PilihanCard`, `_Header`, `_KlasemenTab`, `_BarisKlasemen`, `_BadgePeringkat`, `_PesertaTab`, `_PertandinganTab`, `_BarisHasil`, `_BracketTab`, `_KonektorBracket`, `_KartuBracketMatch`, `_BarisTimBracket`, `LogoKlub`, `_Pesan`, `StatusChip`, `TurnamenCard`.

