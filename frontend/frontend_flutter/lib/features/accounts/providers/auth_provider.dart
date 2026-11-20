import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../data/account_model.dart';
import '../data/auth_repository.dart';

enum AuthStatus {
  initializing,
  authenticated,
  unauthenticated,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.initializing,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final Account? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    Account? user,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentUserProvider = Provider<Account?>((ref) {
  return ref.watch(authProvider).user;
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_bootstrap);
    return const AuthState(status: AuthStatus.initializing);
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(authRepositoryProvider);
    try {
      final account = await repo.restoreSession();
      if (account != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: account,
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } on ApiException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final account = await ref.read(authRepositoryProvider).login(
            username: username,
            password: password,
          );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: account,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String school = '',
    AccountRole role = AccountRole.teacher,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final account = await ref.read(authRepositoryProvider).register(
            username: username,
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            school: school,
            role: role,
          );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: account,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
    );
  }
}
