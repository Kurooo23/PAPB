import 'package:flutter/material.dart';

import 'package:rivnet/controllers/turnamen_controller.dart';
import 'package:rivnet/models/turnamen.dart';
import 'package:rivnet/services/klub_service.dart';
import 'package:rivnet/themes/color.dart';
import 'package:rivnet/utils/pesan.dart';
import 'package:rivnet/widgets/logo_klub.dart';
import 'package:rivnet/widgets/pilih_klub_sheet.dart';

/// Layar buat & edit turnamen.
/// StatefulWidget + setState untuk state lokal.
/// Lebar kartu dihitung pakai MediaQuery + rasio.
class CreateTurnamentScreen extends StatefulWidget {
  const CreateTurnamentScreen({super.key});

  @override
  State<CreateTurnamentScreen> createState() => _CreateTurnamentScreenState();
}

class _CreateTurnamentScreenState extends State<CreateTurnamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllerNama = TextEditingController();

  int _jumlahLeg = 1;
  int _jumlahPeserta = 4;
  List<TextEditingController> _controllerPeserta = [];
  bool _loading = false;

  // ----- mode edit -----
  String? _idEdit;
  Turnamen? _turnamenEdit;
  bool get _modeEdit => _idEdit != null;

  static const pilihanLeg = [1, 2];
  static const pilihanJumlah = [4, 6, 8];
  static const _paddingForm = 16.0;
  static const _gap = 8.0;

  @override
  void initState() {
    super.initState();
    _isiPeserta(_namaDefault());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_idEdit != null) return;
    // Ambil argumen Named Route
    _idEdit = ModalRoute.of(context)?.settings.arguments as String?;
    if (_idEdit != null) {
      _turnamenEdit = TurnamenController.instance.cari(_idEdit!);
      final turnamen = _turnamenEdit;
      if (turnamen != null) {
        _controllerNama.text = turnamen.namaTurnamen; // pakai getter
        _jumlahLeg = turnamen.jumlahLeg;
        _jumlahPeserta = turnamen.peserta.length;
        _isiPeserta(_namaDefault());
      }
    }
  }

  @override
  void dispose() {
    _controllerNama.dispose();
    for (final controller in _controllerPeserta) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _namaDefault() => [
    for (var indeks = 1; indeks <= _jumlahPeserta; indeks++) 'Peserta $indeks',
  ];

  void _isiPeserta(List<String> nama) {
    for (final controller in _controllerPeserta) {
      controller.dispose();
    }
    _controllerPeserta = [
      for (final namaPeserta in nama) TextEditingController(text: namaPeserta),
    ];
  }

  // ----- setter via setState -----
  void _ubahLeg(int nilai) {
    if (nilai == _jumlahLeg) return;
    setState(() => _jumlahLeg = nilai);
  }

  void _ubahJumlah(int nilai) {
    if (nilai == _jumlahPeserta) return;
    setState(() {
      _jumlahPeserta = nilai;
      final saatIni = _controllerPeserta.length;
      if (nilai > saatIni) {
        for (var indeks = saatIni; indeks < nilai; indeks++) {
          _controllerPeserta.add(
            TextEditingController(text: 'Peserta ${indeks + 1}'),
          );
        }
      } else if (nilai < saatIni) {
        for (var indeks = nilai; indeks < saatIni; indeks++) {
          _controllerPeserta[indeks].dispose();
        }
        _controllerPeserta.removeRange(nilai, saatIni);
      }
    });
  }

  // ----- simpan -----
  Future<void> _simpan() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final namaPeserta =
        _controllerPeserta.map((controller) => controller.text.trim()).toList();
    if (namaPeserta.any((teks) => teks.isEmpty)) {
      tampilPesan('Peserta kosong', error: true);
      return;
    }
    final lower = namaPeserta.map((teks) => teks.toLowerCase()).toList();
    if (lower.toSet().length != lower.length) {
      tampilPesan('Nama peserta ganda', error: true);
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) setState(() => _loading = false);
    if (mounted) Navigator.pop(context);
    tampilPesan(_modeEdit ? 'Berhasil mengedit' : 'Berhasil membuat');
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery: ambil lebar layar untuk hitung rasio kartu
    final lebarLayar = MediaQuery.of(context).size.width;

    // rasio 1:1 (2 kartu leg) dengan tiap kartu = (lebar - 2*padding - 1*gap) / 2
    final lebarKartuLeg = (lebarLayar - _paddingForm * 2 - _gap) / 2;
    // rasio 1:1:1 (3 kartu jumlah) dengan tiap kartu = (lebar - 2*padding - 2*gap) / 3
    final lebarKartuJumlah = (lebarLayar - _paddingForm * 2 - _gap * 2) / 3;

    // Responsive: kalau lebar > 600, nama peserta tampil 2 kolom (rasio 1:1)
    final duaKolom = lebarLayar > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(_modeEdit ? 'Edit Turnamen' : 'Buat Turnamen'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(_paddingForm),
            children: [
              TextFormField(
                controller: _controllerNama,
                decoration: const InputDecoration(labelText: 'Nama Turnamen'),
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().length < 3)
                    ? 'Minimal 3 karakter'
                    : null,
              ),
              Container(height: 20),

              // ----- Leg (rasio 1:1) -----
              const _Label('Leg'),
              Container(height: 8),
              Row(
                children: [
                  for (
                    var indeks = 0;
                    indeks < pilihanLeg.length;
                    indeks++
                  ) ...[
                    _PilihanCard(
                      label: '${pilihanLeg[indeks]} Leg',
                      dipilih: _jumlahLeg == pilihanLeg[indeks],
                      lebar: lebarKartuLeg,
                      onTap: () => _ubahLeg(pilihanLeg[indeks]),
                    ),
                    if (indeks < pilihanLeg.length - 1) Container(width: _gap),
                  ],
                ],
              ),
              Container(height: 20),

              // ----- Jumlah Peserta (rasio 1:1:1) -----
              const _Label('Jumlah Peserta'),
              Container(height: 8),
              Row(
                children: [
                  for (
                    var indeks = 0;
                    indeks < pilihanJumlah.length;
                    indeks++
                  ) ...[
                    _PilihanCard(
                      label: '${pilihanJumlah[indeks]}',
                      dipilih: _jumlahPeserta == pilihanJumlah[indeks],
                      lebar: lebarKartuJumlah,
                      onTap: () => _ubahJumlah(pilihanJumlah[indeks]),
                    ),
                    if (indeks < pilihanJumlah.length - 1)
                      Container(width: _gap),
                  ],
                ],
              ),
              Container(height: 20),

              // ----- Nama Peserta -----
              const _Label('Nama Peserta'),
              Container(height: 8),
              ...(duaKolom ? _barisPeserta2Kolom() : _barisPeserta1Kolom()),
              Container(height: 28),

              FilledButton(
                onPressed: _loading ? null : _simpan,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _loading
                    ? Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_modeEdit ? 'Simpan Perubahan' : 'Buat Turnamen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----- pilih klub Eropa dari API -----
  Future<void> _pilihKlub(int indeks) async {
    final klub = await pilihKlubEropa(context);
    if (klub == null || !mounted) return;
    final sudahDipakai = _controllerPeserta.asMap().entries.any(
      (entry) =>
          entry.key != indeks &&
          entry.value.text.trim().toLowerCase() == klub.nama.toLowerCase(),
    );
    if (sudahDipakai) {
      tampilPesan('${klub.nama} sudah dipilih', error: true);
      return;
    }
    _controllerPeserta[indeks].text = klub.nama;
  }

  /// Field nama peserta: ikon kiri = logo klub (kalau ada),
  /// tombol kanan = pilih klub Eropa dari API.
  Widget _fieldPeserta(int indeks) {
    final controller = _controllerPeserta[indeks];
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Peserta ${indeks + 1}',
        prefixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, nilaiTeks, child) {
            final logo = KlubService.instance.logoDariCache(nilaiTeks.text);
            if (logo == null) return const Icon(Icons.groups_outlined);
            return Padding(
              padding: const EdgeInsets.all(10),
              child: LogoKlub(nilaiTeks.text, url: logo, ukuran: 26),
            );
          },
        ),
        suffixIcon: IconButton(
          tooltip: 'Pilih klub Eropa',
          icon: const Icon(Icons.shield_outlined),
          onPressed: () => _pilihKlub(indeks),
        ),
      ),
      textInputAction: indeks == _controllerPeserta.length - 1
          ? TextInputAction.done
          : TextInputAction.next,
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Nama wajib diisi' : null,
    );
  }

  List<Widget> _barisPeserta1Kolom() {
    return [
      for (var indeks = 0; indeks < _controllerPeserta.length; indeks++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _fieldPeserta(indeks),
        ),
    ];
  }

  // 2 kolom (rasio 1:1) — layar lebar
  List<Widget> _barisPeserta2Kolom() {
    final baris = <Widget>[];
    for (var indeks = 0; indeks < _controllerPeserta.length; indeks += 2) {
      baris.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Flexible(flex: 1, child: _fieldPeserta(indeks)),
              Container(width: _gap),
              if (indeks + 1 < _controllerPeserta.length)
                Flexible(flex: 1, child: _fieldPeserta(indeks + 1))
              else
                Flexible(flex: 1, child: Container()),
            ],
          ),
        ),
      );
    }
    return baris;
  }
}

// ---------------- StatelessWidget helpers ----------------

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
      ),
    );
  }
}

class _PilihanCard extends StatelessWidget {
  final String label;
  final bool dipilih;
  final double lebar;
  final VoidCallback onTap;

  const _PilihanCard({
    required this.label,
    required this.dipilih,
    required this.lebar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final warna = dipilih ? AppColors.primary : AppColors.card;
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: lebar),
      child: Material(
        color: warna,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: dipilih
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: dipilih ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
