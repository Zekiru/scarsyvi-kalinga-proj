import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});

class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'kalinga_drf_auth_token';
  static const String _userIdKey = 'kalinga_auth_user_id';
  static const String _userRoleKey = 'kalinga_auth_user_role';

  Future<void> saveSession({
    required String token,
    required int userId,
    required String role,
  }) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _userIdKey, value: userId.toString()),
      _storage.write(key: _userRoleKey, value: role),
    ]);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<int?> getUserId() async {
    final raw = await _storage.read(key: _userIdKey);
    return raw != null ? int.tryParse(raw) : null;
  }

  Future<String?> getUserRole() => _storage.read(key: _userRoleKey);

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _userRoleKey),
    ]);
  }
}
