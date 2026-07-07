import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/models/user_model.dart';
import '../../../core/storage/secure_storage.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.unknown()) {
    _restoreSession();
  }

  final _repo = AuthRepository.instance;

  Future<void> _restoreSession() async {
    final user = await _repo.tryRestoreSession();
    state = user != null
        ? AuthState.authenticated(user)
        : const AuthState.unauthenticated();
  }

  Future<void> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    state = const AuthState.unknown();
    try {
      final user = await _repo.login(
        username: username,
        password: password,
        rememberMe: rememberMe,
      );
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.unauthenticated(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState.unauthenticated();
  }

  Future<bool> tryBiometricLogin() async {
    final ok = await _repo.authenticateWithBiometrics();
    if (!ok) return false;
    final user = await _repo.tryRestoreSession();
    if (user != null) {
      state = AuthState.authenticated(user);
      return true;
    }
    return false;
  }

  /// Switch to a different saved account using its stored token.
  Future<bool> switchToAccount(String username) async {
    state = const AuthState.unknown();
    final user = await _repo.switchToAccount(username);
    if (user != null) {
      state = AuthState.authenticated(user);
      return true;
    }
    state = const AuthState.unauthenticated();
    return false;
  }

  Future<List<SavedAccount>> getSavedAccounts() =>
      _repo.getSavedAccounts();

  Future<void> removeSavedAccount(String username) =>
      _repo.removeAccount(username);

  UserModel? get currentUser => state.user;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
