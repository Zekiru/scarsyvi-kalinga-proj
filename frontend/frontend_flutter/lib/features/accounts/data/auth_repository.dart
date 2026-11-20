import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/hive_boxes.dart';
import '../../../core/storage/secure_token_storage.dart';
import 'account_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
    accountsBox: HiveBoxes.accounts,
  );
});

class AuthRepository {
  AuthRepository({
    required this._apiClient,
    required this._tokenStorage,
    required this._accountsBox,
  });

  final ApiClient _apiClient;
  final SecureTokenStorage _tokenStorage;
  final Box<String> _accountsBox;

  static const String _currentUserKey = 'current_user';

  /// Authenticates against `/accounts/login/`, persists token + cached profile.
  Future<Account> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      includeAuth: false,
      body: {
        'username': username.trim(),
        'password': password,
      },
    );

    return _persistAuthResponse(response);
  }

  /// Registers a new account against `/accounts/register/`, persists token + cached profile.
  Future<Account> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String firstName,
    required String lastName,
    String school = '',
    AccountRole role = AccountRole.teacher,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      includeAuth: false,
      body: {
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirm': passwordConfirm,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'school': school.trim(),
        'role': role.apiValue,
      },
    );

    return _persistAuthResponse(response);
  }

  Future<Account> _persistAuthResponse(dynamic response) async {
    if (response is! Map<String, dynamic>) {
      throw ApiException(message: 'Unexpected authentication response format.');
    }

    final token = response['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException(message: 'Authentication token missing in response.');
    }

    final userMap = response['user'] is Map<String, dynamic>
        ? response['user'] as Map<String, dynamic>
        : response;

    final account = Account.fromJson(userMap);

    await _tokenStorage.saveSession(
      token: token,
      userId: account.id,
      role: account.role.apiValue,
    );
    await _accountsBox.put(_currentUserKey, account.toJsonString());

    return account;
  }

  /// Restores session on app startup:
  /// 1. Returns `null` if no token is stored.
  /// 2. Tries `/accounts/me/` online to refresh profile; if offline, falls back to cached Hive profile.
  /// 3. Clears session if server returns `401 Unauthorized`.
  Future<Account?> restoreSession() async {
    final token = await _tokenStorage.getToken();
    if (token == null || token.isEmpty) return null;

    final cached = getCachedUser();

    try {
      final response = await _apiClient.get(ApiEndpoints.me);
      if (response is Map<String, dynamic>) {
        final fresh = Account.fromJson(response);
        await _accountsBox.put(_currentUserKey, fresh.toJsonString());
        return fresh;
      }
      return cached;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await logout();
        return null;
      }
      if (e.isOffline && cached != null) {
        return cached;
      }
      if (cached != null) return cached;
      rethrow;
    }
  }

  Account? getCachedUser() {
    final raw = _accountsBox.get(_currentUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Account.fromJsonString(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clearSession();
    await HiveBoxes.clearUserData();
  }
}
