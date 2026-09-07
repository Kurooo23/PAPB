import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../models/pertandingan_model.dart';
import '../models/peserta_model.dart';
import '../models/turnamen_model.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      return json['data'];
    } else {
      String message = 'Terjadi kesalahan pada server (${response.statusCode})';
      try {
        final json = jsonDecode(response.body);
        if (json['message'] != null) {
          message = json['message'];
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<http.Response> _sendWithAutoRetry(
      Future<http.Response> Function(String baseUrl) requestFn) async {
    final baseUrl = await ApiConfig.autoDetectBaseUrl();
    try {
      return await requestFn(baseUrl);
    } catch (e) {
      // Jika gagal, coba scan ulang sekali lagi
      final newBaseUrl = await ApiConfig.autoDetectBaseUrl();
      try {
        return await requestFn(newBaseUrl);
      } catch (_) {
        throw Exception(
            'Tidak dapat terhubung ke server backend Express.js. Pastikan server sudah dijalankan dengan npm start.');
      }
    }
  }

  // 1. GET Semua Turnamen
  Future<List<TurnamenModel>> getAllTurnamen({String? search, String? status}) async {
    final response = await _sendWithAutoRetry((baseUrl) {
      final uri = Uri.parse('$baseUrl/turnamen').replace(queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status != 'Semua') 'status': status,
      });
      return http.get(uri, headers: _headers);
    });

    final List data = _handleResponse(response) as List;
    return data.map((item) => TurnamenModel.fromMap(item as Map<String, dynamic>)).toList();
  }

  // 2. GET Turnamen Aktif
  Future<List<TurnamenModel>> getTurnamenAktif({String? search, String? statusFilter}) async {
    if ((search != null && search.isNotEmpty) || (statusFilter != null && statusFilter != 'Semua')) {
      return await getAllTurnamen(search: search, status: statusFilter);
    }
    final response = await _sendWithAutoRetry((baseUrl) {
      return http.get(Uri.parse('$baseUrl/turnamen/aktif'), headers: _headers);
    });
    final List data = _handleResponse(response) as List;
    return data.map((item) => TurnamenModel.fromMap(item as Map<String, dynamic>)).toList();
  }

  // 3. GET Riwayat Turnamen (Selesai)
  Future<List<TurnamenModel>> getRiwayatTurnamen({String? search}) async {
    if (search != null && search.isNotEmpty) {
      return await getAllTurnamen(search: search, status: 'Selesai');
    }
    final response = await _sendWithAutoRetry((baseUrl) {
      return http.get(Uri.parse('$baseUrl/turnamen/riwayat'), headers: _headers);
    });
    final List data = _handleResponse(response) as List;
    return data.map((item) => TurnamenModel.fromMap(item as Map<String, dynamic>)).toList();
  }

  // 4. GET Detail Turnamen (Include Peserta & Pertandingan)
  Future<Map<String, dynamic>> getTurnamenDetail(String idTurnamen) async {
    final response = await _sendWithAutoRetry((baseUrl) {
      return http.get(Uri.parse('$baseUrl/turnamen/$idTurnamen'), headers: _headers);
    });
    final Map<String, dynamic> data = _handleResponse(response) as Map<String, dynamic>;

    final turnamen = TurnamenModel.fromMap(data);
    final List pesertaRaw = (data['peserta'] as List?) ?? [];
    final List pertandinganRaw = (data['pertandingan'] as List?) ?? [];

    final pesertaList = pesertaRaw.map((p) => PesertaModel.fromMap(p as Map<String, dynamic>)).toList();
    final pertandinganList = pertandinganRaw.map((m) => PertandinganModel.fromMap(m as Map<String, dynamic>)).toList();

    return {
      'turnamen': turnamen,
      'peserta': pesertaList,
      'pertandingan': pertandinganList,
    };
  }

  // 5. POST Buat Turnamen Baru
  Future<TurnamenModel> createTurnamen({
    required String namaTurnamen,
    String? deskripsi,
    String tipeGame = 'E-Sports',
    required String formatBracket,
    int jumlahLeg = 1,
    required DateTime tanggalMulai,
    required int kuota,
    required List<String> peserta,
  }) async {
    final body = jsonEncode({
      'nama_turnamen': namaTurnamen,
      'deskripsi': deskripsi,
      'tipe_game': tipeGame,
      'format_bracket': formatBracket,
      'jumlah_leg': jumlahLeg,
      'tanggal_mulai': tanggalMulai.toIso8601String(),
      'kuota': kuota,
      'peserta': peserta,
    });

    final response = await _sendWithAutoRetry((baseUrl) {
      return http.post(
        Uri.parse('$baseUrl/turnamen'),
        headers: _headers,
        body: body,
      );
    });

    final data = _handleResponse(response) as Map<String, dynamic>;
    return TurnamenModel.fromMap(data);
  }

  // 6. PUT Edit Turnamen
  Future<TurnamenModel> updateTurnamen(TurnamenModel turnamen) async {
    final body = jsonEncode({
      'nama_turnamen': turnamen.namaTurnamen,
      'deskripsi': turnamen.deskripsi,
      'tipe_game': turnamen.tipeGame,
      'tanggal_mulai': turnamen.tanggalMulai.toIso8601String(),
      'status': turnamen.status,
    });

    final response = await _sendWithAutoRetry((baseUrl) {
      return http.put(
        Uri.parse('$baseUrl/turnamen/${turnamen.idTurnamen}'),
        headers: _headers,
        body: body,
      );
    });

    final data = _handleResponse(response) as Map<String, dynamic>;
    return TurnamenModel.fromMap(data);
  }

  // 7. DELETE Hapus Turnamen
  Future<void> deleteTurnamen(String idTurnamen) async {
    final response = await _sendWithAutoRetry((baseUrl) {
      return http.delete(
        Uri.parse('$baseUrl/turnamen/$idTurnamen'),
        headers: _headers,
      );
    });
    _handleResponse(response);
  }

  // 8. PUT Update Hasil Pertandingan (Skor & Status)
  Future<PertandinganModel> updateHasilPertandingan({
    required String idPertandingan,
    required int skor1,
    required int skor2,
    required String status,
  }) async {
    final body = jsonEncode({
      'skor_peserta_1': skor1,
      'skor_peserta_2': skor2,
      'status': status,
    });

    final response = await _sendWithAutoRetry((baseUrl) {
      return http.put(
        Uri.parse('$baseUrl/pertandingan/$idPertandingan/skor'),
        headers: _headers,
        body: body,
      );
    });

    final data = _handleResponse(response) as Map<String, dynamic>;
    return PertandinganModel.fromMap(data);
  }

  // 9. GET Peserta by Turnamen
  Future<List<PesertaModel>> getPesertaByTurnamen(String idTurnamen) async {
    final response = await _sendWithAutoRetry((baseUrl) {
      return http.get(
        Uri.parse('$baseUrl/peserta/turnamen/$idTurnamen'),
        headers: _headers,
      );
    });
    final List data = _handleResponse(response) as List;
    return data.map((item) => PesertaModel.fromMap(item as Map<String, dynamic>)).toList();
  }

  // 10. GET Pertandingan by Turnamen
  Future<List<PertandinganModel>> getPertandinganByTurnamen(String idTurnamen) async {
    final response = await _sendWithAutoRetry((baseUrl) {
      return http.get(
        Uri.parse('$baseUrl/pertandingan/turnamen/$idTurnamen'),
        headers: _headers,
      );
    });
    final List data = _handleResponse(response) as List;
    return data.map((item) => PertandinganModel.fromMap(item as Map<String, dynamic>)).toList();
  }
}
