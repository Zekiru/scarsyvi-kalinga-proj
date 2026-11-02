import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'drf_auth_token';
  static const _usernameKey = 'drf_username';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Returns null (= "not logged in") if secure storage can't be read, e.g.
  /// after an Android backup restore or keystore reset.
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      await _storage.deleteAll();
      return null;
    }
  }

  /// The username is stored so queued offline changes can be tagged with the
  /// account that made them (shared devices).
  Future<void> saveUsername(String username) async {
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<String?> getUsername() async {
    try {
      return await _storage.read(key: _usernameKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _usernameKey);
  }
}
