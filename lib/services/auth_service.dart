import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

class AuthService {
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nickname,
    required int avatarIndex,
  }) async {
    return _sendRequest(
      endpoint: 'register',
      body: {
        'email': email,
        'password': password,
        'nickname': nickname,
        'avatar_index': avatarIndex,
      },
      expectedStatus: 201,
      defaultErrorMessage: 'Gagal mendaftar',
    );
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return _sendRequest(
      endpoint: 'login',
      body: {
        'email': email,
        'password': password,
      },
      expectedStatus: 200,
      defaultErrorMessage: 'Gagal login',
    );
  }

  static Future<Map<String, dynamic>> _sendRequest({
    required String endpoint,
    required Map<String, dynamic> body,
    required int expectedStatus,
    required String defaultErrorMessage,
  }) async {
    try {
      final baseUrl = await ApiConfig.autoDetectBaseUrl();
      final authUrl = baseUrl.endsWith('/api')
          ? '$baseUrl/auth/$endpoint'
          : '$baseUrl/api/auth/$endpoint';

      final response = await http.post(
        Uri.parse(authUrl),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('Format respon server tidak valid.');
      }

      debugPrint('[$endpoint] STATUS: ${response.statusCode}');
      debugPrint('[$endpoint] BODY: $data');

      if (response.statusCode == expectedStatus || response.statusCode == 200 || response.statusCode == 201) {
        return data;
      }

      throw Exception(data['message'] ?? defaultErrorMessage);
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server backend. Pastikan server sudah dijalankan.');
    } on http.ClientException {
      throw Exception('Tidak dapat terhubung ke server backend. Pastikan server sudah dijalankan.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Terjadi kesalahan jaringan.');
    }
  }
}
