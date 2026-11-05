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
    final urlGambar = (ukuran <= 64 && urlLogo.contains('thesportsdb.com'))
        ? '$urlLogo/small'
        : urlLogo;
    return _wadahKotak(
      Image.network(
        urlGambar,
        fit: BoxFit.contain,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (context, error, stackTrace) => _tampilkanInisial(),
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
