import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  static const _port = 3000;

  /// Port UDP tempat backend membalas broadcast pencarian alamat. Harus
  /// sama dengan DISCOVERY_PORT di backend/server.js.
  static const _discoveryPort = 41234;
  static const _discoveryRequest = 'RIVNET_DISCOVER';
  static const _discoveryReplyPrefix = 'RIVNET:';

  static String? _activeBaseUrl;

  // Kandidat alamat yang tidak perlu ditebak: selalu sama di tiap mesin.
  static final List<String> _staticCandidateUrls = [
    'http://10.0.2.2:$_port/api', // Android Emulator
    'http://localhost:$_port/api', // Windows / Web / HP dengan adb reverse
    'http://127.0.0.1:$_port/api', // Localhost loopback
  ];

  static String get baseUrl => _activeBaseUrl ?? _staticCandidateUrls.first;

  static set baseUrl(String url) {
    _activeBaseUrl = url.trim();
  }

  static void resetToDefault() {
    _activeBaseUrl = null;
  }

  /// Mencari alamat backend yang merespons, lalu menyimpannya.
  ///
  /// Dua cara dicoba bersamaan: kandidat statis (emulator/localhost/loopback)
  /// dan broadcast UDP ke jaringan lokal, supaya HP fisik menemukan IP
  /// laptop sendiri tanpa perlu ditulis manual di sini. Kalau tidak ada yang
  /// merespons, langsung melempar Exception dengan pesan yang jelas.
  /// Sebelumnya aplikasi diam-diam memakai 10.0.2.2 (khusus emulator),
  /// sehingga di HP asli request menunggu 15 detik lalu timeout.
  static Future<String> autoDetectBaseUrl() async {
    final active = _activeBaseUrl;
    if (active != null && await _isReachable(active)) return active;
    _activeBaseUrl = null;

    final found = await _firstNonNull([
      _firstReachable(_staticCandidateUrls),
      _discoverViaBroadcast(),
    ]);

    if (found == null) {
      debugPrint(
        '>>> [Auto-Discovery] Backend tidak ditemukan. Kandidat statis: '
        '${_staticCandidateUrls.join(', ')}. Broadcast UDP juga tidak dibalas.',
      );
      debugPrint(
        '>>> Cek: server jalan, HP dan laptop di Wi-Fi yang sama, firewall '
            'tidak memblokir port $_port/$_discoveryPort, atau jalankan: '
            'adb reverse tcp:$_port tcp:$_port',
      );
      throw Exception(
        'Backend tidak ditemukan. Pastikan server jalan dan HP berada pada Wi-Fi yang sama.',
      );
    }

    _activeBaseUrl = found;
    debugPrint('>>> [Auto-Discovery] Terhubung ke backend di: $found');
    return found;
  }

  /// Semua kandidat dicek bersamaan, yang pertama merespons dipakai.
  static Future<String?> _firstReachable(List<String> urls) {
    return _firstNonNull([
      for (final url in urls) _isReachable(url).then((ok) => ok ? url : null),
    ]);
  }

  /// Menunggu beberapa Future bersamaan dan mengambil hasil pertama yang
  /// tidak null. Kalau semuanya selesai dan tetap null, hasilnya null
  /// (tidak menunggu selamanya).
  static Future<String?> _firstNonNull(List<Future<String?>> futures) {
    if (futures.isEmpty) return Future.value(null);

    final completer = Completer<String?>();
    var remaining = futures.length;

    for (final future in futures) {
      future.then((value) {
        remaining -= 1;
        if (completer.isCompleted) return;
        if (value != null) {
          completer.complete(value);
        } else if (remaining == 0) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }

  /// Broadcast UDP "RIVNET_DISCOVER" ke jaringan lokal. Backend yang jalan
  /// di jaringan yang sama (lihat DISCOVERY_PORT di backend/server.js)
  /// membalas lewat unicast dengan alamatnya sendiri, jadi IP laptop tidak
  /// perlu diketahui atau ditulis manual di sini.
  static Future<String?> _discoverViaBroadcast({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.send(
        utf8.encode(_discoveryRequest),
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );

      final completer = Completer<String?>();
      final subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;

        final reply = utf8.decode(datagram.data);
        if (!reply.startsWith(_discoveryReplyPrefix)) return;

        if (!completer.isCompleted) {
          final port = reply.substring(_discoveryReplyPrefix.length).trim();
          completer.complete('http://${datagram.address.address}:$port/api');
        }
      });

      final result = await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
      await subscription.cancel();
      return result;
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
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