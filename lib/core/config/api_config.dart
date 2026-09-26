import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  /// IP laptop di Wi-Fi. Bisa berubah tiap ganti jaringan, cek pakai
  /// `ipconfig` (IPv4 Address di adaptor Wi-Fi).
  static const _laptopIp = '10.10.10.242';
  static const _port = 3000;

  static String? _activeBaseUrl;

  // Kandidat alamat backend. Semuanya dicek bersamaan.
  static final List<String> _candidateUrls = [
    'http://10.0.2.2:$_port/api', // Android Emulator
    'http://$_laptopIp:$_port/api', // HP fisik di Wi-Fi yang sama
    'http://localhost:$_port/api', // Windows / Web / HP dengan adb reverse
    'http://127.0.0.1:$_port/api', // Localhost loopback
  ];

  static String get baseUrl => _activeBaseUrl ?? _candidateUrls.first;

  static set baseUrl(String url) {
    _activeBaseUrl = url.trim();
  }

  static void resetToDefault() {
    _activeBaseUrl = null;
  }

  /// Mencari alamat backend yang merespons, lalu menyimpannya.
  ///
  /// Kalau tidak ada yang merespons, langsung melempar Exception dengan pesan
  /// yang jelas. Sebelumnya aplikasi diam-diam memakai 10.0.2.2 (khusus
  /// emulator), sehingga di HP asli request menunggu 15 detik lalu timeout.
  static Future<String> autoDetectBaseUrl() async {
    final active = _activeBaseUrl;
    if (active != null && await _isReachable(active)) return active;
    _activeBaseUrl = null;

    final found = await _firstReachable(_candidateUrls);
    if (found == null) {
      debugPrint(
        '>>> [Auto-Discovery] Backend tidak ditemukan. Dicoba: ${_candidateUrls.join(', ')}',
      );
      debugPrint(
        '>>> Cek: server jalan, IP laptop di ApiConfig (ipconfig), firewall, '
            'atau jalankan: adb reverse tcp:$_port tcp:$_port',
      );
      throw Exception(
        'Backend tidak ditemukan. Pastikan server jalan dan IP laptop di ApiConfig sudah benar.',
      );
    }

    _activeBaseUrl = found;
    debugPrint('>>> [Auto-Discovery] Terhubung ke backend di: $found');
    return found;
  }

  /// Semua kandidat dicek bersamaan, yang pertama merespons dipakai.
  static Future<String?> _firstReachable(List<String> urls) {
    if (urls.isEmpty) return Future.value(null);

    final completer = Completer<String?>();
    var remaining = urls.length;

    for (final url in urls) {
      _isReachable(url).then((ok) {
        remaining -= 1;
        if (completer.isCompleted) return;
        if (ok) {
          completer.complete(url);
        } else if (remaining == 0) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }

  /// Ping ke halaman utama backend (`GET /`). Endpoint itu tidak menyentuh
  /// database dan tidak butuh login, jadi cepat dan tidak ikut gagal kalau
  /// Supabase sedang lambat.
  static Future<bool> _isReachable(String apiUrl) async {
    final root = apiUrl.endsWith('/api')
        ? apiUrl.substring(0, apiUrl.length - 4)
        : apiUrl;

    try {
      final res = await http
          .get(Uri.parse('$root/'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}