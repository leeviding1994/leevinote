import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/models/user.dart';

class AuthService extends ChangeNotifier {
  final _api = ApiService();

  bool _isAuthenticated = false;
  String? _username;
  String? _nickname;
  String? _avatarBase64;
  String? _email;
  VoidCallback? _onLogin;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  String? get nickname => _nickname;
  String? get avatarBase64 => _avatarBase64;
  String? get email => _email;

  User? get currentUser {
    if (_username == null) return null;
    return User(
      username: _username!,
      nickname: _nickname,
      email: _email,
      avatarBase64: _avatarBase64,
    );
  }

  String get displayName {
    if (_nickname != null && _nickname!.isNotEmpty) return _nickname!;
    return _username ?? '未登录';
  }

  AuthService({VoidCallback? onLogin}) {
    _onLogin = onLogin;
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
        _nickname = await read('nickname');
        _email = await read('email');
        _avatarBase64 = await read('avatar_base64');
        notifyListeners();
        _onLogin?.call();
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
    _onLogin?.call();
  }

  Future<void> logout() async {
    await delete('jwt_token');
    await delete('username');
    await delete('nickname');
    await delete('email');
    await delete('avatar_base64');
    _isAuthenticated = false;
    _username = null;
    _nickname = null;
    _email = null;
    _avatarBase64 = null;
    notifyListeners();
  }

  Future<void> updateProfile({String? nickname, String? email, String? avatarBase64}) async {
    if (nickname != null) {
      await write('nickname', nickname);
      _nickname = nickname;
    }
    if (email != null) {
      await write('email', email);
      _email = email;
    }
    if (avatarBase64 != null) {
      await write('avatar_base64', avatarBase64);
      _avatarBase64 = avatarBase64;
    }
    notifyListeners();
  }
}
