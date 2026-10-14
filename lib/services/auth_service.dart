import 'dart:async';
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
  }) {
    return _sendRequest(
      endpoint: 'register',
      body: {
        'email': email,
        'password': password,
        'nickname': nickname,
        'avatar_index': avatarIndex,
      },
      expectedStatus: 201,
      defaultErrorMessage: 'Gagal mendaftar.',
    );
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return _sendRequest(
      endpoint: 'login',
      body: {'email': email, 'password': password},
      expectedStatus: 200,
      defaultErrorMessage: 'Gagal login.',
    );
  }

  static Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
  }) {
    return _sendRequest(
      endpoint: 'google',
      body: {'id_token': idToken},
      expectedStatus: 200,
      defaultErrorMessage: 'Gagal login dengan Google.',
    );
  }

  static Future<Map<String, dynamic>> resendVerification({
    required String email,
  }) {
    return _sendRequest(
      endpoint: 'resend-verification',
      body: {'email': email},
      expectedStatus: 200,
      defaultErrorMessage: 'Gagal mengirim ulang email verifikasi.',
    );
  }

  static Future<Map<String, dynamic>> checkVerificationStatus({
    required String userId,
  }) {
    return _sendRequest(
      endpoint: 'verification-status/$userId',
      method: 'GET',
      expectedStatus: 200,
      defaultErrorMessage: 'Gagal memeriksa status verifikasi.',
    );
  }

  static Future<Map<String, dynamic>> _sendRequest({
    required String endpoint,
    Map<String, dynamic>? body,
    String method = 'POST',
    required int expectedStatus,
    required String defaultErrorMessage,
  }) async {
    try {
      final baseUrl = await ApiConfig.autoDetectBaseUrl();
      final requestBody = <String, dynamic>{...?body};

      if (endpoint == 'register' || endpoint == 'resend-verification') {
        requestBody['client'] = Uri.parse(baseUrl).host == '10.0.2.2'
            ? 'emulator'
            : 'device';
      }

      final authUrl = baseUrl.endsWith('/api')
          ? '$baseUrl/auth/$endpoint'
          : '$baseUrl/api/auth/$endpoint';

      final response =
          await (method == 'GET'
                  ? http.get(Uri.parse(authUrl), headers: _headers)
                  : http.post(
                      Uri.parse(authUrl),
                      headers: _headers,
                      body: jsonEncode(requestBody),
                    ))
              .timeout(const Duration(seconds: 15));

      Map<String, dynamic> data;

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw const FormatException();
        }

        data = decoded;
      } catch (_) {
        throw Exception('Format respons server tidak valid.');
      }

      debugPrint('[$endpoint] STATUS: ${response.statusCode}');
      debugPrint('[$endpoint] BODY: $data');

      if (response.statusCode == expectedStatus ||
          (endpoint == 'register' && response.statusCode == 200)) {
        return data;
      }

      throw Exception(data['message'] ?? defaultErrorMessage);
    } on SocketException {
      throw Exception(
        'Tidak dapat terhubung ke backend. Pastikan server berjalan dan HP berada pada Wi-Fi yang sama.',
      );
    } on http.ClientException {
      throw Exception(
        'Tidak dapat terhubung ke backend. Pastikan alamat server benar.',
      );
    } on HttpException {
      throw Exception('Terjadi masalah saat menghubungi backend.');
    } on TimeoutException {
      throw Exception('Server tidak merespons. Coba lagi beberapa saat lagi.');
    } on FormatException {
      throw Exception('Format respons server tidak valid.');
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('Terjadi kesalahan jaringan.');
    }
  }
}
