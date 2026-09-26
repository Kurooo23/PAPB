import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Login akun Google (google_sign_in 7.x) untuk layar login.
///
/// Hasilnya berupa ID token. Token itu dikirim ke backend lewat
/// AuthService.loginWithGoogle, lalu backend memverifikasinya ke Google
/// dan membalas dengan token aplikasi, sama seperti login email.
class GoogleSignInService {
  GoogleSignInService._();

  /// Client ID OAuth tipe "Web application" dari Google Cloud Console, bukan
  /// client ID Android. Backend memakai nilai yang sama untuk memverifikasi
  /// ID token. Client ID bukan rahasia, jadi aman disimpan di kode.
  static const webClientId = '346491359516-qc6squv6eqgjck20qfoj2a79pq2lmmed.apps.googleusercontent.com';

  static Future<void>? _initialization;

  /// initialize() wajib dipanggil tepat satu kali sebelum method lain.
  static Future<void> _ensureInitialized() async {
    try {
      await (_initialization ??= GoogleSignIn.instance.initialize(
        serverClientId: webClientId,
      ));
    } catch (_) {
      // Gagal: boleh dicoba lagi pada percobaan login berikutnya.
      _initialization = null;
      rethrow;
    }
  }

  /// Membuka pemilih akun Google, lalu mengembalikan ID token.
  /// Mengembalikan null kalau pengguna menutup pemilih akun.
  static Future<String?> requestIdToken() async {
    if (webClientId.startsWith('ISI_')) {
      throw Exception('Web client ID Google belum diisi di GoogleSignInService.');
    }
    await _ensureInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw Exception('Login dengan Google belum didukung di perangkat ini.');
    }

    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google tidak mengirim ID token. Cek web client ID.');
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('GoogleSignInException ${e.code}: ${e.description}');
      throw Exception(
        e.code == GoogleSignInExceptionCode.clientConfigurationError
            ? 'Login dengan Google belum dikonfigurasi dengan benar.'
            : 'Login dengan Google gagal. Coba lagi.',
      );
    }
  }

  /// Panggil saat pengguna logout dari aplikasi, supaya login Google
  /// berikutnya menampilkan pemilih akun lagi.
  static Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }
}