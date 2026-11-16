import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rivnet/controllers/turnamen_controller.dart';
import 'package:rivnet/models/klasemen.dart';
import 'package:rivnet/models/turnamen.dart';
import 'package:rivnet/routes/app_routes.dart';
import 'package:rivnet/utils/pesan.dart';
import 'package:rivnet/widgets/pilih_klub_sheet.dart';

/// Controller untuk layar Detail Turnamen.
class DetailTurnamenController extends ChangeNotifier {
  Turnamen? data;
  List<KlasemenItem> klasemenTersimpan = [];
  bool _sudahHitungKlasemen = false;

  void init(Object? args) {
    final idTurnamen = args as String?;
    data = idTurnamen == null
        ? null
        : TurnamenController.instance.cari(idTurnamen);
    if (data != null && !_sudahHitungKlasemen) {
      klasemenTersimpan = hitungKlasemen(data!);
      _sudahHitungKlasemen = true;
    }
  }

  Turnamen get turnamen => data!;

  // ---------------- Turnamen ----------------
  void ubahTurnamen(BuildContext context) {
    final turnamenSaatIni = data;
    if (turnamenSaatIni == null || turnamenSaatIni.terkunci) return;
    Navigator.pushNamed(
      context,
      Routes.editTurnament,
      arguments: turnamenSaatIni.id,
    );
  }

  Future<void> akhiriTurnamen(BuildContext context) async {
    final turnamenSaatIni = data;
    if (turnamenSaatIni == null || !turnamenSaatIni.semuaPertandinganSelesai) {
      return;
    }

    final apakahDikonfirmasi = await konfirmasi(
      'Akhiri turnamen?',
      'Lanjutkan untuk mengakhiri turnamen?',
      tombol: 'Akhiri',
    );
    if (!apakahDikonfirmasi) return;

    await TurnamenController.instance.akhiriTurnamen(turnamenSaatIni);
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

    await TurnamenController.instance.hapusTurnamen(turnamenSaatIni.id);
    if (context.mounted) {
      Navigator.pop(context);
    }
    tampilPesan('Berhasil menghapus');
  }

  // ---------------- Peserta ----------------
  Future<void> dialogPeserta(
    BuildContext context, {
    Peserta? pesertaYangDiubah,
    Peserta? ubah,
  }) async {
    final targetPeserta = pesertaYangDiubah ?? ubah;
    final turnamenSaatIni = data!;
    if (turnamenSaatIni.terkunci) return;
    if (targetPeserta == null && !turnamenSaatIni.bisaKelolaJumlahPeserta) {
      tampilPesan(
        'Tambah peserta dikunci karena sudah ada skor pertandingan.',
        error: true,
      );
      return;
    }

    final namaBaru = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _DialogPeserta(
        turnamen: turnamenSaatIni,
        targetPeserta: targetPeserta,
      ),
    );

    if (namaBaru == null) return;
    if (targetPeserta == null) {
      await TurnamenController.instance.tambahPeserta(
        turnamenSaatIni,
        namaBaru,
      );
      tampilPesan('Berhasil menambah peserta');
    } else {
      await TurnamenController.instance.ubahPeserta(
        turnamenSaatIni,
        targetPeserta,
        namaBaru,
      );
      tampilPesan('Berhasil mengedit peserta');
    }
  }

  Future<void> hapusPeserta(BuildContext context, Peserta peserta) async {
    final turnamenSaatIni = data!;
    if (!turnamenSaatIni.bisaKelolaJumlahPeserta) {
      if (!turnamenSaatIni.terkunci) {
        tampilPesan(
          'Hapus peserta dikunci karena sudah ada skor pertandingan.',
          error: true,
        );
      }
      return;
    }
    final apakahDikonfirmasi = await konfirmasi(
      'Hapus peserta?',
      '"${peserta.nama}" dan semua pertandingannya akan dihapus.',
    );
    if (!apakahDikonfirmasi) return;

    await TurnamenController.instance.hapusPeserta(turnamenSaatIni, peserta);
    tampilPesan('Berhasil menghapus peserta');
  }

  // ---------------- Pertandingan ----------------
  Future<void> buatPertandingan(BuildContext context) async {
    final turnamenSaatIni = data!;
    if (turnamenSaatIni.status == 'Selesai') return;
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

    await TurnamenController.instance.buatUlangPertandingan(turnamenSaatIni);
    tampilPesan('Berhasil membuat pertandingan');
  }

  Future<void> dialogSkor(
    BuildContext context,
    Pertandingan pertandingan,
  ) async {
    final turnamenSaatIni = data!;
    if (turnamenSaatIni.status == 'Selesai') return;
    if (!pertandingan.siapDimainkan) {
      tampilPesan(
        pertandingan.adaBye
            ? 'Peserta langsung lolos (BYE)'
            : 'Menunggu pemenang babak sebelumnya',
        error: true,
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    var skorTimA = pertandingan.skorA?.toString() ?? '';
    var skorTimB = pertandingan.skorB?.toString() ?? '';
    String? pesanSeri;
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final lebarKonten = (MediaQuery.of(dialogContext).size.width * 0.65)
              .clamp(220.0, 290.0);

          return AlertDialog(
            title: const Text('Masukkan Skor'),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            content: SizedBox(
              width: lebarKonten,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          kolomSkor(
                            namaTim: namaTimA,
                            nilaiSkorAwal: skorTimA,
                            onSkorBerubah: (nilaiBaru) {
                              skorTimA = nilaiBaru;
                              if (pesanSeri != null) {
                                setDialogState(() => pesanSeri = null);
                              }
                            },
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(12, 44, 12, 0),
                            child: Text('-', style: TextStyle(fontSize: 22)),
                          ),
                          kolomSkor(
                            namaTim: namaTimB,
                            nilaiSkorAwal: skorTimB,
                            onSkorBerubah: (nilaiBaru) {
                              skorTimB = nilaiBaru;
                              if (pesanSeri != null) {
                                setDialogState(() => pesanSeri = null);
                              }
                            },
                          ),
                        ],
                      ),
                      if (pesanSeri != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            pesanSeri!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
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
                  if (!formKey.currentState!.validate()) return;
                  final angkaA = int.parse(skorTimA.trim());
                  final angkaB = int.parse(skorTimB.trim());
                  if (turnamenSaatIni.apakahSingleElimination &&
                      angkaA == angkaB) {
                    setDialogState(() {
                      pesanSeri =
                          'Sistem gugur tidak boleh seri. Jika lanjut adu penalti, tambahkan skor penalti ke skor akhir.';
                    });
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );

    if (apakahDisimpan != true) return;
    await TurnamenController.instance.simpanSkor(
      turnamenSaatIni,
      pertandingan,
      int.parse(skorTimA.trim()),
      int.parse(skorTimB.trim()),
    );
    tampilPesan('Berhasil menyimpan skor');
  }
}

class _DialogPeserta extends StatefulWidget {
  final Turnamen turnamen;
  final Peserta? targetPeserta;

  const _DialogPeserta({
    required this.turnamen,
    required this.targetPeserta,
  });

  @override
  State<_DialogPeserta> createState() => _DialogPesertaState();
}

class _DialogPesertaState extends State<_DialogPeserta> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controllerNamaPeserta;

  @override
  void initState() {
    super.initState();
    _controllerNamaPeserta = TextEditingController(
      text: widget.targetPeserta?.nama ?? '',
    );
  }

  @override
  void dispose() {
    _controllerNamaPeserta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetPeserta = widget.targetPeserta;
    return AlertDialog(
      title: Text(targetPeserta == null ? 'Tambah Peserta' : 'Edit Peserta'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controllerNamaPeserta,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nama peserta / tim',
            suffixIcon: IconButton(
              tooltip: 'Pilih klub Eropa',
              icon: const Icon(Icons.shield_outlined),
              onPressed: () async {
                final klubTerpilih = await pilihKlubEropa(context);
                if (klubTerpilih != null) {
                  _controllerNamaPeserta.text = klubTerpilih.nama;
                }
              },
            ),
          ),
          validator: (nilaiInput) {
            final namaPesertaInput = (nilaiInput ?? '').trim();
            if (namaPesertaInput.isEmpty) return 'Nama wajib diisi';
            final apakahNamaSudahAda = widget.turnamen.peserta.any(
              (peserta) =>
                  peserta != targetPeserta &&
                  peserta.nama.toLowerCase() == namaPesertaInput.toLowerCase(),
            );
            return apakahNamaSudahAda ? 'Nama sudah terdaftar' : null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controllerNamaPeserta.text.trim());
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
