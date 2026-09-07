import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  static String? _activeBaseUrl;

  // Daftar kandidat IP yang akan di-scan otomatis
  static final List<String> _candidateUrls = [
    'http://10.0.2.2:3000/api',     // Android Emulator
    'http://10.10.10.242:3000/api', // IP Wi-Fi Laptop
    'http://localhost:3000/api',    // Windows / Web / adb reverse
    'http://127.0.0.1:3000/api',    // Localhost loopback
  ];

  static String get baseUrl => _activeBaseUrl ?? _candidateUrls.first;

  static set baseUrl(String url) {
    _activeBaseUrl = url.trim();
  }

  static void resetToDefault() {
    _activeBaseUrl = null;
  }

  /// Otomatis mencari dan mengunci URL backend yang sedang aktif
  static Future<String> autoDetectBaseUrl() async {
    if (_activeBaseUrl != null) {
      // Verifikasi apakah yang aktif masih merespons
      try {
        final res = await http.get(Uri.parse('$_activeBaseUrl/turnamen'))
            .timeout(const Duration(milliseconds: 1200));
        if (res.statusCode >= 200 && res.statusCode < 500) {
          return _activeBaseUrl!;
        }
      } catch (_) {
        _activeBaseUrl = null;
      }
    }

    // Ping semua kandidat URL secara paralel
    for (final url in _candidateUrls) {
      try {
        final res = await http.get(Uri.parse('$url/turnamen'))
            .timeout(const Duration(milliseconds: 1500));
        if (res.statusCode >= 200 && res.statusCode < 500) {
          _activeBaseUrl = url;
          debugPrint('>>> [Auto-Discovery] Berhasil terhubung otomatis ke backend di: $url');
          return url;
        }
      } catch (_) {}
    }

    // Default fallback jika tidak ada yang respons
    if (kIsWeb || !Platform.isAndroid) {
      _activeBaseUrl = 'http://localhost:3000/api';
    } else {
      _activeBaseUrl = 'http://10.0.2.2:3000/api';
    }
    return _activeBaseUrl!;
  }
}
