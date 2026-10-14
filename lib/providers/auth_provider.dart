import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/database_helper.dart';

class AuthProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  Map<String, dynamic>? _user;

  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> loadSession() async {
    final token = await _storage.read(key: 'user_token');
    final session = await DatabaseHelper.instance.getUserSession();
    _user = (token != null && token.isNotEmpty) ? session : null;
    notifyListeners();
  }

  void setUser(Map<String, dynamic> user) {
    _user = user;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: 'user_token');
    await _storage.delete(key: 'refresh_token');
    await DatabaseHelper.instance.clearUserSession();
    _user = null;
    notifyListeners();
  }
}