import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/services/api_service.dart';

class AuthService extends ChangeNotifier {
  final _api = ApiService();

  bool _isAuthenticated = false;
  String? _username;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;

  AuthService() {
    _checkAuth();
  }

  Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    const storage = FlutterSecureStorage();
    return storage.read(key: key);
  }

  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      const storage = FlutterSecureStorage();
      await storage.write(key: key, value: value);
    }
  }

  Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      const storage = FlutterSecureStorage();
      await storage.delete(key: key);
    }
  }

  Future<void> _checkAuth() async {
    try {
      final token = await read('jwt_token');
      if (token != null) {
        _isAuthenticated = true;
        _username = await read('username');
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> signup(String username, String password, String? email) async {
    await _api.post('/auth/signup', {
      'username': username,
      'password': password,
      'email': email,
    });
  }

  Future<void> login(String username, String password) async {
    final response = await _api.post('/auth/login', {
      'username': username,
      'password': password,
    });
    final token = response['token'] ?? response.toString();
    await write('jwt_token', token);
    await write('username', username);
    _isAuthenticated = true;
    _username = username;
    notifyListeners();
  }

  Future<void> logout() async {
    await delete('jwt_token');
    await delete('username');
    _isAuthenticated = false;
    _username = null;
    notifyListeners();
  }
}
