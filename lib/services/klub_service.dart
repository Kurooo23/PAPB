import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rivnet/models/klub.dart';

/// Service untuk mengambil data & logo klub Top 5 Liga Eropa dari API Rivnet.
class KlubService {
  static final KlubService instance = KlubService._();
  KlubService._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://top5-league-api.rivnet-api.workers.dev/api',
  );
  static const String apiPassword = String.fromEnvironment(
    'API_PASSWORD',
    defaultValue:
        '4Kze27unjc5CbGpMXY2UhvfPmEYyJtNqqytZ8bHrSZQy8HqhKvHjnewqBctBF95265VwcXbCTGuTkyNUK9VS35uJJeVmMqEBZFxpDQVvjWtNT7DwV4VGWr9Zs3L6BfBJn5LBEtdndwKV7Qw3gaWBCwTDcdC6xTtD',
  );
  static const _durasiTimeout = Duration(seconds: 15);
  static const _jedaPerNamaSetelahGagal = Duration(minutes: 3);

  final _httpClient = http.Client();

  final Map<String, List<Klub>> _cacheLiga = {};
  final Map<String, List<Klub>> _cacheCari = {};
  final Map<String, String?> _cacheLogo = {};

  final Set<String> _logoTidakAda = {};
  final Map<String, DateTime> _logoGagalSampai = {};
  final Map<String, Future<String?>> _logoSedangDimuat = {};
  DateTime? _blokirSementaraSampai;

  String _normalisasiKunci(String nama) => nama.trim().toLowerCase();

  void _simpanLogo(List<Klub> daftar) {
    for (final klub in daftar) {
      final logo = klub.logoUrl;
      if (logo != null && logo.isNotEmpty) {
        _cacheLogo[_normalisasiKunci(klub.nama)] = logo;
      }
    }
  }

  /// Daftar klub dalam 1 liga dari endpoint `/api/teams?league=...`.
  Future<List<Klub>> klubPerLiga(String kodeLiga) async {
    if (_cacheLiga.containsKey(kodeLiga)) {
      return _cacheLiga[kodeLiga]!;
    }

    try {
      final daftarKlub = await _fetchKlubDariApi({'league': kodeLiga});
      if (daftarKlub.isNotEmpty) {
        _simpanLogo(daftarKlub);
        _cacheLiga[kodeLiga] = daftarKlub;
        debugPrint(
          '[KlubService] 📋 Data liga "$kodeLiga" (${daftarKlub.length} klub)',
        );
        return daftarKlub;
      }
    } catch (error) {
      debugPrint('[KlubService] ❌ Request liga error: $error');
    }

    return [];
  }

  /// Cari klub berdasarkan nama lewat endpoint `/api/teams?q=...`.
  Future<List<Klub>> cariKlub(String kataKunci) async {
    final kataKunciBersih = _normalisasiKunci(kataKunci);
    if (kataKunciBersih.length < 2) return [];

    if (_cacheCari.containsKey(kataKunciBersih)) {
      return _cacheCari[kataKunciBersih]!;
    }

    try {
      final daftarKlub = await _fetchKlubDariApi({'q': kataKunci.trim()});
      if (daftarKlub.isNotEmpty) {
        _simpanLogo(daftarKlub);
        _cacheCari[kataKunciBersih] = daftarKlub;
        return daftarKlub;
      }
    } catch (error) {
      debugPrint('[KlubService] ❌ Cari klub error: $error');
    }

    return [];
  }

  /// Ambil URL logo klub (dari cache memory, atau cari ke API).
  Future<String?> logoUntuk(String namaKlub) {
    final kunciNama = _normalisasiKunci(namaKlub);

    final dariCache = _cacheLogo[kunciNama];
    if (dariCache != null) return Future.value(dariCache);

    if (_logoTidakAda.contains(kunciNama)) return Future.value(null);

    final gagalSampai = _logoGagalSampai[kunciNama];
    if (gagalSampai != null && DateTime.now().isBefore(gagalSampai)) {
      return Future.value(null);
    }

    if (_blokirSementaraSampai != null &&
        DateTime.now().isBefore(_blokirSementaraSampai!)) {
      return Future.value(null);
    }

    return _logoSedangDimuat.putIfAbsent(kunciNama, () async {
      try {
        return await _ambilLogoDariApi(namaKlub, kunciNama);
      } finally {
        _logoSedangDimuat.remove(kunciNama);
      }
    });
  }

  Future<String?> _ambilLogoDariApi(String namaKlub, String kunciNama) async {
    try {
      final daftarHasil = await _fetchKlubDariApi({'q': namaKlub.trim()});
      if (daftarHasil.isEmpty) {
        _logoTidakAda.add(kunciNama);
        return null;
      }

      _simpanLogo(daftarHasil);

      final klubCocok = daftarHasil.firstWhere(
        (klub) => _normalisasiKunci(klub.nama) == kunciNama,
        orElse: () => daftarHasil.first,
      );
      final urlLogo = klubCocok.logoUrl;
      if (urlLogo != null && urlLogo.isNotEmpty) {
        _cacheLogo[kunciNama] = urlLogo;
      } else {
        _logoTidakAda.add(kunciNama);
      }
      return urlLogo;
    } catch (error) {
      debugPrint('[KlubService] ❌ Logo gagal untuk "$namaKlub": $error');
      _logoGagalSampai[kunciNama] = DateTime.now().add(
        _jedaPerNamaSetelahGagal,
      );
      return null;
    }
  }

  /// Logo yang sudah ada di memory cache.
  String? logoDariCache(String namaKlub) {
    return _cacheLogo[_normalisasiKunci(namaKlub)];
  }

  Future<List<Klub>> _fetchKlubDariApi(
    Map<String, String> parameterQuery,
  ) async {
    if (_blokirSementaraSampai != null &&
        DateTime.now().isBefore(_blokirSementaraSampai!)) {
      return [];
    }

    final uriEndpoint = Uri.parse(
      '$baseUrl/teams',
    ).replace(queryParameters: parameterQuery);
    debugPrint('[KlubService] 🌐 HIT API -> $uriEndpoint');

    final responseHttp = await _httpClient
        .get(
          uriEndpoint,
          headers: {
            'User-Agent': 'RivnetApp/1.0',
            'Accept': 'application/json',
            if (apiPassword.isNotEmpty) 'x-api-password': apiPassword,
          },
        )
        .timeout(_durasiTimeout);

    debugPrint('[KlubService] 📥 HTTP Status: ${responseHttp.statusCode}');

    if (responseHttp.statusCode == 401 || responseHttp.statusCode == 403) {
      _blokirSementaraSampai = DateTime.now().add(const Duration(seconds: 30));
      debugPrint(
        '[KlubService] 🔒 Akses ditolak (HTTP ${responseHttp.statusCode}). '
        'Periksa API_PASSWORD di klub_service.dart dan Cloudflare Worker.',
      );
      return [];
    }

    if (responseHttp.statusCode != 200) return [];

    final responTeks = utf8.decode(
      responseHttp.bodyBytes,
      allowMalformed: true,
    );
    if (responTeks.trimLeft().startsWith('<')) return [];

    final dynamic dataJson = jsonDecode(responTeks);
    if (dataJson is! Map || dataJson['teams'] is! List) {
      return [];
    }

    final hasilKlub = (dataJson['teams'] as List)
        .whereType<Map>()
        .map((elemen) => Klub.fromJson(Map<String, dynamic>.from(elemen)))
        .toList();

    debugPrint('[KlubService] ✅ Mendapatkan ${hasilKlub.length} klub');
    return hasilKlub;
  }
}
