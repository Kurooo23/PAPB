import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rivnet/models/klub.dart';
import 'package:rivnet/services/klub_service.dart';
import 'package:rivnet/themes/color.dart';
import 'package:rivnet/widgets/logo_klub.dart';

/// Buka bottom sheet untuk memilih klub Eropa dari API.
/// Mengembalikan [Klub] yang dipilih, atau null kalau dibatalkan.
Future<Klub?> pilihKlubEropa(BuildContext context) {
  return showModalBottomSheet<Klub>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.backgroundAlt,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => const _PilihKlubSheet(),
  );
}

class _PilihKlubSheet extends StatefulWidget {
  const _PilihKlubSheet();

  @override
  State<_PilihKlubSheet> createState() => _PilihKlubSheetState();
}

class _PilihKlubSheetState extends State<_PilihKlubSheet> {
  final _serviceKlub = KlubService.instance;
  final _controllerCari = TextEditingController();
  Timer? _timerDebounce;

  LigaEropa _ligaTerpilih = LigaEropa.daftar.first;
  String _kataKunciPencarian = '';
  late Future<List<Klub>> _futureDaftarKlub;

  @override
  void initState() {
    super.initState();
    _futureDaftarKlub = _serviceKlub.klubPerLiga(_ligaTerpilih.kode);
  }

  @override
  void dispose() {
    _timerDebounce?.cancel();
    _controllerCari.dispose();
    super.dispose();
  }

  void _pilihLiga(LigaEropa liga) {
    _controllerCari.clear();
    setState(() {
      _ligaTerpilih = liga;
      _kataKunciPencarian = '';
      _futureDaftarKlub = _serviceKlub.klubPerLiga(liga.kode);
    });
  }

  void _ketikCari(String teksPencarian) {
    _timerDebounce?.cancel();
    // Tunggu user selesai mengetik supaya tidak spam request API
    _timerDebounce = Timer(const Duration(milliseconds: 500), () {
      final kataBersih = teksPencarian.trim();
      setState(() {
        _kataKunciPencarian = kataBersih;
        _futureDaftarKlub = kataBersih.length >= 3
            ? _serviceKlub.cariKlub(kataBersih)
            : _serviceKlub.klubPerLiga(_ligaTerpilih.kode);
      });
    });
  }

  void _muatUlangData() {
    setState(() {
      _futureDaftarKlub = _kataKunciPencarian.length >= 3
          ? _serviceKlub.cariKlub(_kataKunciPencarian)
          : _serviceKlub.klubPerLiga(_ligaTerpilih.kode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tinggiSheet = MediaQuery.of(context).size.height * 0.8;
    final modePencarian = _kataKunciPencarian.length >= 3;

    return SizedBox(
      height: tinggiSheet,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Pilih Klub Eropa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _controllerCari,
                onChanged: _ketikCari,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Cari klub (min. 3 huruf), mis. Liverpool',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: LigaEropa.daftar.length,
                separatorBuilder: (context, indeks) => const SizedBox(width: 8),
                itemBuilder: (context, indeks) {
                  final liga = LigaEropa.daftar[indeks];
                  return ChoiceChip(
                    label: Text(liga.label),
                    selected: !modePencarian && liga == _ligaTerpilih,
                    onSelected: (dipilih) => _pilihLiga(liga),
                  );
                },
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: FutureBuilder<List<Klub>>(
                future: _futureDaftarKlub,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _Pesan(
                      ikon: Icons.wifi_off,
                      teks: 'Gagal memuat data klub.\nPeriksa koneksi internet.',
                      onCobaLagi: _muatUlangData,
                    );
                  }
                  final daftarKlub = snapshot.data ?? [];
                  if (daftarKlub.isEmpty) {
                    return const _Pesan(
                      ikon: Icons.search_off,
                      teks: 'Klub tidak ditemukan.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: daftarKlub.length,
                    itemBuilder: (context, indeks) {
                      final klub = daftarKlub[indeks];
                      return ListTile(
                        leading: LogoKlub(
                          klub.nama,
                          url: klub.logoUrl,
                          ukuran: 40,
                        ),
                        title: Text(klub.nama),
                        subtitle: Text(
                          [klub.liga, klub.negara]
                              .where((teks) => teks.isNotEmpty)
                              .join(' • '),
                          style: const TextStyle(color: Colors.white54),
                        ),
                        onTap: () => Navigator.pop(context, klub),
                      );
                    },
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Data & logo klub Eropa (Musim Terbaru)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pesan extends StatelessWidget {
  final IconData ikon;
  final String teks;
  final VoidCallback? onCobaLagi;
  const _Pesan({required this.ikon, required this.teks, this.onCobaLagi});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 40, color: Colors.white38),
          const SizedBox(height: 8),
          Text(teks, textAlign: TextAlign.center),
          if (onCobaLagi != null)
            TextButton(onPressed: onCobaLagi, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
