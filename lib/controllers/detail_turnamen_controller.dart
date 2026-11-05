import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rivnet/controllers/turnamen_controller.dart';
import 'package:rivnet/models/klasemen.dart';
import 'package:rivnet/models/turnamen.dart';
import 'package:rivnet/routes/app_routes.dart';
import 'package:rivnet/utils/pesan.dart';
import 'package:rivnet/widgets/pilih_klub_sheet.dart';

/// Controller untuk layar Detail Turnamen.
/// Dipakai oleh DetailTurnamentScreen (StatefulWidget).
/// Dibuat di initState layar
class DetailTurnamenController extends ChangeNotifier {
  Turnamen? data;
  List<KlasemenItem> klasemenTersimpan = [];
  bool _sudahHitungKlasemen = false;

  /// Ambil id turnamen dari argumen Named Route.
  void init(Object? args) {
    final idTurnamen = args as String?;
    data = idTurnamen == null
        ? null
        : TurnamenController.instance.cari(idTurnamen);
    // Hitung klasemen sekali saat layar pertama kali dibuka,
    // supaya tetap fix walau skor pertandingan diubah.
    if (data != null && !_sudahHitungKlasemen) {
      klasemenTersimpan = hitungKlasemen(data!);
      _sudahHitungKlasemen = true;
    }
  }

  Turnamen get turnamen => data!;

  // ---------------- Turnamen ----------------
  void ubahTurnamen(BuildContext context) {
    final turnamenSaatIni = data;
    if (turnamenSaatIni == null) return;
    Navigator.pushNamed(
      context,
      Routes.editTurnament,
      arguments: turnamenSaatIni.id,
    );
  }

  Future<void> akhiriTurnamen(BuildContext context) async {
    final turnamenSaatIni = data;
    if (turnamenSaatIni == null) return;

    final apakahDikonfirmasi = await konfirmasi(
      'Akhiri turnamen?',
      'Lanjutkan untuk mengakhiri turnamen?',
      tombol: 'Akhiri',
    );
    if (!apakahDikonfirmasi) return;

    tampilPesan('Berhasil mengakhiri turnamen');
  }

  Future<void> hapusTurnamen(BuildContext context) async {
    final turnamenSaatIni = data;
    if (turnamenSaatIni == null) return;
    final apakahDikonfirmasi = await konfirmasi(
      'Hapus turnamen?',
      '"${turnamenSaatIni.nama}" beserta peserta dan hasil pertandingannya akan dihapus.',
    );
    if (!apakahDikonfirmasi) return;
    // Fake delete: tampilkan pesan tapi jangan hapus data.
    tampilPesan('Berhasil menghapus');
  }

  // ---------------- Peserta ----------------
  Future<void> dialogPeserta(
    BuildContext context, {
    Peserta? pesertaYangDiubah,
  }) async {
    final turnamenSaatIni = data!;
    final formKey = GlobalKey<FormState>();
    final controllerNamaPeserta = TextEditingController(
      text: pesertaYangDiubah?.nama ?? '',
    );

    final apakahDisimpan = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          pesertaYangDiubah == null ? 'Tambah Peserta' : 'Edit Peserta',
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controllerNamaPeserta,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nama peserta / tim',
              suffixIcon: IconButton(
                tooltip: 'Pilih klub Eropa',
                icon: const Icon(Icons.shield_outlined),
                onPressed: () async {
                  final klubTerpilih = await pilihKlubEropa(context);
                  if (klubTerpilih != null) {
                    controllerNamaPeserta.text = klubTerpilih.nama;
                  }
                },
              ),
            ),
            validator: (nilaiInput) {
              final namaPesertaInput = (nilaiInput ?? '').trim();
              if (namaPesertaInput.isEmpty) return 'Nama wajib diisi';
              final apakahNamaSudahAda = turnamenSaatIni.peserta.any(
                (peserta) =>
                    peserta != pesertaYangDiubah &&
                    peserta.nama.toLowerCase() ==
                        namaPesertaInput.toLowerCase(),
              );
              return apakahNamaSudahAda ? 'Nama sudah terdaftar' : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    controllerNamaPeserta.dispose();

    if (apakahDisimpan != true) return;
    // Fake create/update: tampilkan pesan tapi jangan ubah data.
    if (pesertaYangDiubah == null) {
      tampilPesan('Berhasil menambah peserta');
    } else {
      tampilPesan('Berhasil mengedit peserta');
    }
  }

  Future<void> hapusPeserta(BuildContext context, Peserta peserta) async {
    final apakahDikonfirmasi = await konfirmasi(
      'Hapus peserta?',
      '"${peserta.nama}" dan semua pertandingannya akan dihapus.',
    );
    if (!apakahDikonfirmasi) return;
    // Fake delete: tampilkan pesan tapi jangan hapus data.
    tampilPesan('Berhasil menghapus peserta');
  }

  // ---------------- Pertandingan ----------------
  Future<void> buatPertandingan(BuildContext context) async {
    final turnamenSaatIni = data!;
    if (turnamenSaatIni.peserta.length < 2) {
      tampilPesan('Peserta kurang dari 2', error: true);
      return;
    }

    if (turnamenSaatIni.pertandingan.isNotEmpty) {
      final adaPertandinganSelesai = turnamenSaatIni.pertandingan.any(
        (pertandingan) => pertandingan.selesai,
      );
      final apakahDikonfirmasi = await konfirmasi(
        'Buat ulang pertandingan?',
        adaPertandinganSelesai
            ? 'Pertandingan lama beserta semua skor yang sudah diisi akan diganti.'
            : 'Pertandingan lama akan diganti.',
        tombol: 'Buat Ulang',
      );
      if (!apakahDikonfirmasi) return;
    }

    // Fake create: tampilkan pesan tapi jangan ubah data.
    tampilPesan('Berhasil membuat pertandingan');
  }

  Future<void> dialogSkor(
    BuildContext context,
    Pertandingan pertandingan,
  ) async {
    final turnamenSaatIni = data!;
    if (turnamenSaatIni.status == 'Selesai') return;
    final formKey = GlobalKey<FormState>();
    var skorTimA = pertandingan.skorA?.toString() ?? '';
    var skorTimB = pertandingan.skorB?.toString() ?? '';
    final namaTimA = turnamenSaatIni.namaPeserta(pertandingan.idA);
    final namaTimB = turnamenSaatIni.namaPeserta(pertandingan.idB);

    String? wajibAngka(String? nilaiInput) =>
        int.tryParse((nilaiInput ?? '').trim()) == null ? 'Isi angka' : null;

    Widget kolomSkor({
      required String namaTim,
      required String nilaiSkorAwal,
      required void Function(String) onSkorBerubah,
    }) {
      return Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              namaTim,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextFormField(
                initialValue: nilaiSkorAwal,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                onChanged: onSkorBerubah,
                validator: wajibAngka,
              ),
            ),
          ],
        ),
      );
    }

    final apakahDisimpan = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Masukkan Skor'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kolomSkor(
                  namaTim: namaTimA,
                  nilaiSkorAwal: skorTimA,
                  onSkorBerubah: (nilaiBaru) => skorTimA = nilaiBaru,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 44, 12, 0),
                  child: Text('-', style: TextStyle(fontSize: 22)),
                ),
                kolomSkor(
                  namaTim: namaTimB,
                  nilaiSkorAwal: skorTimB,
                  onSkorBerubah: (nilaiBaru) => skorTimB = nilaiBaru,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (apakahDisimpan != true) return;
    // Fake update: tampilkan pesan tapi jangan ubah skor asli.
    tampilPesan('Berhasil menyimpan skor');
  }
}
