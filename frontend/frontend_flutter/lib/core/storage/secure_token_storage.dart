import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'hive_boxes.dart';

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});

class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _roleKey = 'auth_role';

  Future<void> saveSession({
    required String token,
    required int userId,
    required String role,
  }) async {
    // Always persist in Hive accounts box so Web/Desktop/Offline never loses the token
    await HiveBoxes.accounts.put(_tokenKey, token);
    await HiveBoxes.accounts.put(_userIdKey, userId.toString());
    await HiveBoxes.accounts.put(_roleKey, role);

    if (!kIsWeb) {
      try {
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _userIdKey, value: userId.toString());
        await _storage.write(key: _roleKey, value: role);
      } catch (_) {}
    }
  }

  Future<String?> getToken() async {
    final hiveToken = HiveBoxes.accounts.get(_tokenKey);
    if (hiveToken != null && hiveToken.isNotEmpty) {
      return hiveToken;
    }
    if (!kIsWeb) {
      try {
        return await _storage.read(key: _tokenKey);
      } catch (_) {}
    }
    return null;
  }

  Future<void> clearSession() async {
    await HiveBoxes.accounts.delete(_tokenKey);
    await HiveBoxes.accounts.delete(_userIdKey);
    await HiveBoxes.accounts.delete(_roleKey);

    if (!kIsWeb) {
      try {
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: _userIdKey);
        await _storage.delete(key: _roleKey);
      } catch (_) {}
    }
  }
}
