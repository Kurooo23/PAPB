# Laporan Implementasi Konsep Flutter — Rivnet

## Daftar Konsep yang Dicek

| # | Konsep | Status |
|---|---|---|
| 1 | StatelessWidget | Sudah |
| 2 | StatefulWidget | Sudah |
| 3 | Column & Row | Sudah |
| 4 | MediaQuery | Sudah |
| 5 | Named Route | Tidak digunakan (navigasi pakai GetX) |
| 6 | Pop/Push (Navigator) | Diganti dengan GetX (Get.to / Get.back) |
| 7 | GetX | Sudah |
| 8 | setState | Sudah (StatefulBuilder di dialog + MainShell) |
| 9 | Setter | Sudah (di model) |
| 10 | Getter | Sudah (di model) |

---

## 1. lib/main.dart — Entry Point

**Class:** `MyApp extends StatelessWidget`

**Import:**
- `package:flutter/material.dart`
- `package:get/get.dart`
- `package:rivnet/controllers/turnamen_controller.dart`
- `package:rivnet/screen/main/main_shell.dart`
- `package:rivnet/themes/app_theme.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| StatelessWidget | 14 | `class MyApp extends StatelessWidget` |
| GetX (GetMaterialApp) | 19 | `return GetMaterialApp(...)` |
| GetX (Get.put) | 10 | `Get.put(TurnamenController())` |

---

## 2. lib/controllers/turnamen_controller.dart — Controller HomeScreen

**Class:** `TurnamenController extends GetxController`

**Import:**
- `package:get/get.dart`
- `package:rivnet/database/database_helper.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| GetX (GetxController) | 4 | `class TurnamenController extends GetxController` |
| GetX (.obs reaktif) | 5-6 | `var tournaments = <...>[].obs;` / `var filter = 'Semua'.obs;` |
| Getter (.value) | 16 | `filter.value` |
| Setter (.value =) | 22 | `filter.value = f;` |

---

## 3. lib/controllers/form_turnamen_controller.dart — Controller CreateTurnamentScreen

**Class:** `FormTurnamenController extends GetxController`

**Import:**
- `package:flutter/material.dart`
- `package:get/get.dart`
- `package:rivnet/database/database_helper.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| GetX (GetxController) | 5 | `class FormTurnamenController extends GetxController` |
| GetX (.obs reaktif) | 12-14 | `var format = ....obs;` / `var leg = ....obs;` / `var kuota = ....obs;` |
| Getter (.value) | 68 | `format.value` |
| Setter (.value =) | 43 | `kuota.value = kuotaBaru;` |
| GetX (Get.back) | 74 | `Get.back(result: true);` |
| GetX (Get.snackbar) | 55 | `Get.snackbar('Peringatan', ...)` |

---

## 4. lib/controllers/detail_turnamen_controller.dart — Controller DetailTurnamentScreen

**Class:** `DetailTurnamenController extends GetxController`

**Import:**
- `package:flutter/material.dart`
- `package:get/get.dart`
- `package:rivnet/database/database_helper.dart`
- `package:rivnet/models/input_skor.dart`
- `package:rivnet/models/match.dart`
- `package:rivnet/models/peserta.dart`
- `package:rivnet/models/tournament.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| GetX (GetxController) | 9 | `class DetailTurnamenController extends GetxController` |
| GetX (.obs reaktif) | 11-14 | `var peserta = ....obs;` / `var loading = true.obs;` dll |
| GetX (Get.arguments) | 19 | `Get.arguments as Map<String, Object?>` |
| Getter (.value) | 31-33 | `peserta.value` / `matches.value` / `loading.value` |
| Setter (.value =) | 31-33 | `peserta.value = [...]` / `loading.value = false` |
| GetX (Get.dialog) | 45 | `Get.dialog<bool>(AlertDialog(...))` |
| GetX (Get.back) | 53,57,67 | `Get.back(result: false/true)` |

---

## 5. lib/screen/main/main_shell.dart — Shell / Bottom Navigation

**Class:** `MainShell extends StatefulWidget`

**Import:**
- `package:flutter/material.dart`
- `package:rivnet/screen/main/home_screen.dart`
- `package:rivnet/screen/main/riwayat_screen.dart`
- `package:rivnet/themes/color.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| StatefulWidget | 7 | `class MainShell extends StatefulWidget` |
| Column | 25 | `child: Column(children: [...])` |
| Row | 48 | `child: Row(children: [...])` |
| MediaQuery | 21 | `final size = MediaQuery.of(context).size;` |
| setState | 78 | `onTap: () => setState(() => _index = i)` |

---

## 6. lib/screen/main/home_screen.dart — Daftar Turnamen (Route 1)

**Class:** `HomeScreen extends GetView<TurnamenController>`
(GetView adalah turunan StatelessWidget yang otomatis mencari controller via Get.find)

**Import:**
- `package:flutter/material.dart`
- `package:get/get.dart`
- `package:rivnet/controllers/turnamen_controller.dart`
- `package:rivnet/controllers/form_turnamen_controller.dart`
- `package:rivnet/controllers/detail_turnamen_controller.dart`
- `package:rivnet/screen/turnamen/create_turnament.dart`
- `package:rivnet/screen/turnamen/detail_turnament.dart`
- `package:rivnet/themes/color.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| StatelessWidget | 11 | `class HomeScreen extends GetView<TurnamenController>` |
| GetX (GetView) | 11 | `GetView<TurnamenController>` |
| GetX (Obx) | 25,32 | `Obx(() => Row(...))` / `Obx(() => controller.tournaments.isEmpty ...)` |
| Column | 21 | `Column(children: [...])` |
| Row | 25,76,124 | `Row(children: [...])` |
| MediaQuery | 16 | `final size = MediaQuery.of(context).size;` |
| GetX (Get.to + binding) | 48-52 | `Get.to(() => ..., arguments: t, binding: BindingsBuilder(...))` |
| GetX (Get.to + binding) | 69-72 | `Get.to(() => ..., binding: BindingsBuilder(...))` |
| GetX (Get.lazyPut) | 52,72 | `Get.lazyPut(() => DetailTurnamenController())` |

---

## 7. lib/screen/main/riwayat_screen.dart — Riwayat (Tab 2)

**Class:** `RiwayatScreen extends StatelessWidget`

**Import:**
- `package:flutter/material.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| StatelessWidget | 3 | `class RiwayatScreen extends StatelessWidget` |
| Column | 11 | `return Column(children: [...])` |
| Row | 22 | `child: Row(children: [...])` |
| MediaQuery | 8 | `final size = MediaQuery.of(context).size;` |

---

## 8. lib/screen/turnamen/create_turnament.dart — Form Buat Turnamen (Route 2)

**Class:** `CreateTurnamentScreen extends GetView<FormTurnamenController>`

**Import:**
- `package:flutter/material.dart`
- `package:get/get.dart`
- `package:rivnet/controllers/form_turnamen_controller.dart`
- `package:rivnet/themes/color.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| StatelessWidget | 7 | `class CreateTurnamentScreen extends GetView<FormTurnamenController>` |
| GetX (GetView) | 7 | `GetView<FormTurnamenController>` |
| GetX (Obx) | 65,82,99,116 | `Obx(() => Row(...))` / `Obx(() => Column(...))` |
| Column | 18,49,116 | `Column(children: [...])` |
| Row | 25,65,82,99 | `Row(children: [...])` |
| MediaQuery | 12 | `final size = MediaQuery.of(context).size;` |
| GetX (Get.back) | 29 | `onPressed: () => Get.back()` |

---

## 9. lib/screen/turnamen/detail_turnament.dart — Detail Turnamen (Route 3)

**Class:** `DetailTurnamentScreen extends GetView<DetailTurnamenController>`

**Import:**
- `package:flutter/material.dart`
- `package:get/get.dart`
- `package:rivnet/components/bracket.dart`
- `package:rivnet/components/daftar_laga.dart`
- `package:rivnet/components/daftar_peserta.dart`
- `package:rivnet/controllers/detail_turnamen_controller.dart`
- `package:rivnet/models/tournament.dart`
- `package:rivnet/themes/color.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| StatelessWidget | 11 | `class DetailTurnamentScreen extends GetView<DetailTurnamenController>` |
| GetX (GetView) | 11 | `GetView<DetailTurnamenController>` |
| GetX (Obx) | 62 | `Obx(() => controller.loading.value ? ... : ...)` |
| Column | 23,66,179,231 | `Column(children: [...])` |
| Row | 30,105,136,182,234,264 | `Row(children: [...])` |
| MediaQuery | 16 | `final size = MediaQuery.of(context).size;` |
| GetX (Get.back) | 34 | `onPressed: () => Get.back()` |
| Getter (dari model) | 18,165,238 | `controller.turnamen` / `t.status` / `t.isKnockout` |

---

## 10. lib/components/bracket.dart — Komponen Bagan/Klasemen

**Class:** `Bracket extends StatelessWidget`

**Import:**
- `package:flutter/material.dart`
- `package:rivnet/models/bracket_round.dart`
- `package:rivnet/models/bracket_tie.dart`
- `package:rivnet/models/klasemen.dart`
- `package:rivnet/models/klasemen_item.dart`
- `package:rivnet/models/match.dart`
- `package:rivnet/models/peserta.dart`
- `package:rivnet/models/tournament.dart`
- `package:rivnet/themes/color.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| StatelessWidget | 15 | `class Bracket extends StatelessWidget` |
| Column | 56,173,243 | `Column(children: [...])` |
| Row | 107,167,273 | `Row(children: [...])` |
| MediaQuery | 34 | `final size = MediaQuery.of(context).size;` |

---

## 11. lib/components/daftar_laga.dart — Komponen Daftar Laga

**Class:** `DaftarLagaCard extends StatelessWidget`

**Import:**
- `package:flutter/material.dart`
- `package:rivnet/models/match.dart`
- `package:rivnet/models/peserta.dart`
- `package:rivnet/themes/color.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| StatelessWidget | 6 | `class DaftarLagaCard extends StatelessWidget` |
| Column | 31,79 | `Column(children: [...])` |
| Row | 34,91 | `Row(children: [...])` |
| MediaQuery | 20 | `final size = MediaQuery.of(context).size;` |

---

## 12. lib/components/daftar_peserta.dart — Komponen Daftar Peserta

**Class:** `DaftarPesertaCard extends StatelessWidget`

**Import:**
- `package:flutter/material.dart`
- `package:rivnet/models/peserta.dart`
- `package:rivnet/themes/color.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| StatelessWidget | 5 | `class DaftarPesertaCard extends StatelessWidget` |
| Column | 29 | `Column(children: [...])` |
| Row | 40 | `Row(children: [...])` |

---

## 13. lib/models/input_skor.dart — Dialog Input Skor

**Class:** `InputSkor` (plain class, static method)

**Import:**
- `package:flutter/material.dart`
- `package:get/get.dart`
- `package:rivnet/database/database_helper.dart`
- `package:rivnet/models/match.dart`
- `package:rivnet/models/peserta.dart`
- `package:rivnet/themes/color.dart`

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| GetX (Get.dialog) | 33 | `return Get.dialog<bool>(StatefulBuilder(...))` |
| setState (StatefulBuilder) | 37,90,142 | `setState(() => butuhPenalti = ...)` |
| GetX (Get.back) | 210,233 | `Get.back(result: false)` / `Get.back(result: true)` |
| Column | 51,79 | `Column(children: [...])` |
| Row | 55,165 | `Row(children: [...])` |

---

## 14. lib/models/tournament.dart — Model Turnamen

**Class:** `Tournament`

**Import:** (tidak ada import eksternal — pure Dart)

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| Getter | 29 | `String get status => _status;` |
| Getter | 30 | `bool get isFinished => _isFinished;` |
| Getter | 32 | `bool get isKnockout => format == 'Single Elimination';` |
| Setter | 35-37 | `set status(String value) { if (_validStatus.contains(value)) _status = value; }` |
| Setter | 40-43 | `set isFinished(bool value) { _isFinished = value; if (value) _status = 'Selesai'; }` |

---

## 15. lib/models/match.dart — Model Pertandingan

**Class:** `Pertandingan`

**Import:** (tidak ada import eksternal — pure Dart)

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| Getter | 36 | `int get skor1 => _skor1;` |
| Getter | 37 | `int get skor2 => _skor2;` |
| Getter | 38 | `int? get penalti1 => _penalti1;` |
| Getter | 39 | `int? get penalti2 => _penalti2;` |
| Getter | 40 | `String get status => _status;` |
| Setter | 42-44 | `set skor1(int value) { if (value >= 0) _skor1 = value; }` |
| Setter | 46-48 | `set skor2(int value) { if (value >= 0) _skor2 = value; }` |
| Setter | 50-52 | `set penalti1(int? value) { ... }` |
| Setter | 54-56 | `set penalti2(int? value) { ... }` |
| Setter | 59-61 | `set status(String value) { ... }` |

---

## 16. lib/models/peserta.dart — Model Peserta

**Class:** `Peserta`

**Import:** (tidak ada import eksternal — pure Dart)

**Konsep yang diimplementasi:**

| Konsep | Baris | Kode |
|---|---|---|
| Getter | 18 | `String get namaTampil => isWo ? '$nama (WO)' : nama;` |

---

## Ringkasan Per Konsep

### StatelessWidget
`main.dart:14`, `home_screen.dart:11`, `riwayat_screen.dart:3`, `create_turnament.dart:7`, `detail_turnament.dart:11`, `bracket.dart:15`, `daftar_laga.dart:6`, `daftar_peserta.dart:5`

### StatefulWidget
`main_shell.dart:7`

### Column & Row
`main_shell.dart:25,48`, `home_screen.dart:21,25`, `riwayat_screen.dart:11,22`, `create_turnament.dart:18,25`, `detail_turnament.dart:23,30`, `bracket.dart:56,107`, `daftar_laga.dart:31,34`, `daftar_peserta.dart:29,40`, `input_skor.dart:51,55`

### MediaQuery
`main_shell.dart:21`, `home_screen.dart:16`, `riwayat_screen.dart:8`, `create_turnament.dart:12`, `detail_turnament.dart:16`, `bracket.dart:34`, `daftar_laga.dart:20`

### GetX
- **GetMaterialApp:** `main.dart:19`
- **Get.put:** `main.dart:10`
- **GetxController:** `turnamen_controller.dart:4`, `form_turnamen_controller.dart:5`, `detail_turnamen_controller.dart:9`
- **.obs:** `turnamen_controller.dart:5-6`, `form_turnamen_controller.dart:12-14`, `detail_turnamen_controller.dart:11-14`
- **Obx:** `home_screen.dart:25,32`, `create_turnament.dart:65,82,99,116`, `detail_turnament.dart:62`
- **GetView:** `home_screen.dart:11`, `create_turnament.dart:7`, `detail_turnament.dart:11`
- **Get.to:** `home_screen.dart:48,69`
- **Get.back:** `create_turnament.dart:29`, `detail_turnament.dart:34`, `detail_turnamen_controller.dart:53,57,67`, `form_turnamen_controller.dart:74`, `input_skor.dart:210,233`
- **Get.dialog:** `detail_turnamen_controller.dart:45`, `input_skor.dart:33`
- **Get.arguments:** `detail_turnamen_controller.dart:19`
- **Get.snackbar:** `form_turnamen_controller.dart:55`
- **Get.lazyPut:** `home_screen.dart:52,72`

### setState
`main_shell.dart:78` (bottom nav), `input_skor.dart:37,90,142` (StatefulBuilder dialog)

### Setter
`tournament.dart:35-43` (status, isFinished), `match.dart:42-61` (skor1, skor2, penalti1, penalti2, status)

### Getter
`tournament.dart:29-32` (status, isFinished, isKnockout), `match.dart:36-40` (skor1, skor2, penalti1, penalti2, status), `peserta.dart:18` (namaTampil)
