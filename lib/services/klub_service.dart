import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rivnet/models/klub.dart';

/// Service untuk data & logo klub sepak bola murni dari REST API TheSportsDB.
///
/// Semua request data klub dan logo langsung memanggil API TheSportsDB:
/// - Daftar tim per liga: search_all_teams.php?l={nama_liga}
/// - Pencarian klub: searchteams.php?t={nama_klub}
/// - Logo/Badge klub: diambil dari field strBadge / strTeamBadge respons API TheSportsDB
class KlubService {
  static final KlubService instance = KlubService._();
  KlubService._();

  static const _hostUrl = 'www.thesportsdb.com';
  // Test key publik TheSportsDB yang aktif adalah '123'
  // (Key lama '3' sudah di-disable permanen oleh TheSportsDB dan menghasilkan HTTP 403 Forbidden)
  static const _apiKey = '123';
  static const _durasiTimeout = Duration(seconds: 10);

  final _httpClient = http.Client();

  // Cache di memori (RAM) agar tidak spamming request ke server untuk data yang sama
  final Map<String, List<Klub>> _cacheLiga = {};
  final Map<String, List<Klub>> _cacheCari = {};
  final Map<String, String?> _cacheLogo = {};

  String _normalisasiKunci(String nama) => nama.trim().toLowerCase();

  /// Mengambil daftar semua klub dalam 1 liga langsung dari API TheSportsDB.
  Future<List<Klub>> klubPerLiga(String kodeLiga) async {
    if (_cacheLiga.containsKey(kodeLiga)) {
      return _cacheLiga[kodeLiga]!;
    }

    try {
      final daftarKlubDariApi = await _fetchKlubDariApi(
        'search_all_teams.php',
        {'l': kodeLiga},
      );
      for (final klub in daftarKlubDariApi) {
        if (klub.logoUrl != null) {
          _cacheLogo[_normalisasiKunci(klub.nama)] = klub.logoUrl;
        }
      }
      _cacheLiga[kodeLiga] = daftarKlubDariApi;
      return daftarKlubDariApi;
    } catch (_) {
      return [];
    }
  }

  /// Cari klub berdasarkan nama langsung melalui API TheSportsDB.
  Future<List<Klub>> cariKlub(String kataKunci) async {
    final kataKunciBersih = _normalisasiKunci(kataKunci);
    if (kataKunciBersih.length < 2) return [];

    if (_cacheCari.containsKey(kataKunciBersih)) {
      return _cacheCari[kataKunciBersih]!;
    }

    try {
      final daftarKlubDariApi = await _fetchKlubDariApi(
        'searchteams.php',
        {'t': kataKunci.trim()},
      );
      for (final klub in daftarKlubDariApi) {
        if (klub.logoUrl != null) {
          _cacheLogo[_normalisasiKunci(klub.nama)] = klub.logoUrl;
        }
      }
      _cacheCari[kataKunciBersih] = daftarKlubDariApi;
      return daftarKlubDariApi;
    } catch (_) {
      return [];
    }
  }

  /// Ambil URL logo klub langsung dari API TheSportsDB berdasarkan nama tim.
  Future<String?> logoUntuk(String namaKlub) async {
    final kunciNama = _normalisasiKunci(namaKlub);
    if (_cacheLogo.containsKey(kunciNama)) {
      return _cacheLogo[kunciNama];
    }

    try {
      final daftarHasil = await _fetchKlubDariApi(
        'searchteams.php',
        {'t': namaKlub.trim()},
      );
      if (daftarHasil.isEmpty) {
        _cacheLogo[kunciNama] = null;
        return null;
      }
      // Prioritaskan nama yang sama persis
      final klubCocok = daftarHasil.firstWhere(
        (klub) => _normalisasiKunci(klub.nama) == kunciNama,
        orElse: () => daftarHasil.first,
      );
      final urlLogo = klubCocok.logoUrl;
      _cacheLogo[kunciNama] = urlLogo;
      return urlLogo;
    } catch (_) {
      _cacheLogo[kunciNama] = null;
      return null;
    }
  }

  /// Logo yang sudah pernah dimuat dari API (tersimpan di memory cache).
  String? logoDariCache(String namaKlub) {
    return _cacheLogo[_normalisasiKunci(namaKlub)];
  }

  /// Hit endpoint REST API TheSportsDB
  Future<List<Klub>> _fetchKlubDariApi(
    String namaEndpoint,
    Map<String, String> parameterQuery,
  ) async {
    final uriEndpoint = Uri.https(
      _hostUrl,
      '/api/v1/json/$_apiKey/$namaEndpoint',
      parameterQuery,
    );
    final responseHttp = await _httpClient.get(uriEndpoint).timeout(_durasiTimeout);

    if (responseHttp.statusCode != 200) return [];

    final dynamic dataJson = jsonDecode(utf8.decode(responseHttp.bodyBytes));
    if (dataJson is! Map ||
        dataJson['teams'] == null ||
        dataJson['teams'] is! List) {
      return [];
    }

    final daftarTimMentah = dataJson['teams'] as List;

    return daftarTimMentah
        .where((elemen) => elemen is Map)
        .map((elemen) => Map<String, dynamic>.from(elemen as Map))
        .where(_apakahKlubSepakBolaAktif)
        .map(Klub.fromJson)
        .toList();
  }

  static bool _apakahKlubSepakBolaAktif(Map<String, dynamic> dataJsonKlub) {
    final cabangOlahraga = dataJsonKlub['strSport'];
    final namaLiga = (dataJsonKlub['strLeague'] as String?) ?? '';
    return cabangOlahraga == 'Soccer' && !namaLiga.startsWith('_');
  }

  /// Tutup client HTTP jika aplikasi dimatikan.
  /// CATATAN: Karena [KlubService] adalah Singleton, jangan panggil method ini
  /// dari State.dispose() widget, karena client akan tertutup permanen.
  void dispose() {
    _httpClient.close();
  }
}
