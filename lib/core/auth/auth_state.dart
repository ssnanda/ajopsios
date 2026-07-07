import '../models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  const AuthState.unknown()
      : status = AuthStatus.unknown,
        user = null,
        error = null;

  const AuthState.authenticated(UserModel u)
      : status = AuthStatus.authenticated,
        user = u,
        error = null;

  const AuthState.unauthenticated([String? e])
      : status = AuthStatus.unauthenticated,
        user = null,
        error = e;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.unknown;
}
