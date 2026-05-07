import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:leevinote/services/api_service.dart';

class AuthService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _api = ApiService();

  bool _isAuthenticated = false;
  String? _username;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;

  AuthService() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      _isAuthenticated = true;
      _username = await _storage.read(key: 'username');
      notifyListeners();
    }
  }

  Future<bool> signup(String username, String password, String? email) async {
    try {
      final response = await _api.post('/auth/signup', {
        'username': username,
        'password': password,
        'email': email,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await _api.post('/auth/login', {
        'username': username,
        'password': password,
      });
      final token = response['token'] ?? response.toString();
      await _storage.write(key: 'jwt_token', value: token);
      await _storage.write(key: 'username', value: username);
      _isAuthenticated = true;
      _username = username;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'username');
    _isAuthenticated = false;
    _username = null;
    notifyListeners();
  }
}
