import 'package:flutter/material.dart';

import 'package:rivnet/services/klub_service.dart';
import 'package:rivnet/themes/color.dart';

/// Menampilkan logo klub berdasarkan nama tim.
/// Logo diambil dari API TheSportsDB (lewat [KlubService]).
/// Kalau tim tidak ditemukan / offline -> tampil inisial nama.
class LogoKlub extends StatelessWidget {
  final String nama;
  final double ukuran;

  /// URL logo langsung (opsional). Kalau diisi, tidak perlu cari ke API.
  final String? url;

  const LogoKlub(this.nama, {super.key, this.ukuran = 32, this.url});

  @override
  Widget build(BuildContext context) {
    final urlLangsung = url ?? KlubService.instance.logoDariCache(nama);
    if (urlLangsung != null) return _bangunGambar(urlLangsung);

    return FutureBuilder<String?>(
      future: KlubService.instance.logoUntuk(nama),
      builder: (context, snapshot) {
        final logo = snapshot.data;
        if (logo != null) return _bangunGambar(logo);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _wadahKotak(
            const Padding(
              padding: EdgeInsets.all(6),
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          );
        }
        return _tampilkanInisial();
      },
    );
  }

  Widget _wadahKotak(Widget widgetIsi) =>
      SizedBox(width: ukuran, height: ukuran, child: widgetIsi);

  Widget _bangunGambar(String urlLogo) {
    return _wadahKotak(
      Image.network(
        urlLogo,
        fit: BoxFit.contain,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        // Sebelum byte pertama datang, loadingProgress masih null sehingga
        // widget lama menampilkan kotak KOSONG. frameBuilder memperbaiki itu:
        // selama belum ada frame, tampilkan spinner.
        frameBuilder: (context, child, frame, sinkron) {
          if (sinkron || frame != null) return child;
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Error asli sebelumnya ditelan diam-diam. Sekarang dicetak.
          debugPrint('[LogoKlub] GAGAL "$nama" -> $urlLogo\n   $error');
          return _tampilkanInisial();
        },
      ),
    );
  }

  Widget _tampilkanInisial() {
    final daftarKata = nama
        .trim()
        .split(RegExp(r'\s+'))
        .where((kata) => kata.isNotEmpty);
    final inisial = daftarKata
        .take(2)
        .map((kata) => kata[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: ukuran / 2,
      backgroundColor: AppColors.primary.withValues(alpha: 0.25),
      child: Text(
        inisial.isEmpty ? '?' : inisial,
        style: TextStyle(
          fontSize: ukuran * 0.36,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }
}