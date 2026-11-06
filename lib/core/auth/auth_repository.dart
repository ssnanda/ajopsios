import 'package:dio/dio.dart';
import 'package:local_auth/local_auth.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_interceptors.dart';
import '../models/api_status_model.dart';
import '../models/user_model.dart';
import '../storage/secure_storage.dart';
import '../storage/cache_storage.dart';
import '../config/site_url.dart';

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  final _auth = LocalAuthentication();

  // ── API status check ─────────────────────────────────────────────────────

  Future<ApiStatusModel> checkApiStatus() async {
    try {
      final resp = await ApiClient.instance.dio.get(ApiEndpoints.status);
      return ApiStatusModel.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final msg = (e.error is ApiException)
          ? (e.error as ApiException).message
          : 'Cannot reach the server. Check your connection.';
      return ApiStatusModel.unreachable(msg);
    } catch (_) {
      return ApiStatusModel.unreachable('An unexpected error occurred.');
    }
  }

  // ── Login / logout ───────────────────────────────────────────────────────

  Future<UserModel> login({
    required String siteUrl,
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    final previousSite = await SecureStorage.instance.getSiteUrl();
    try {
      try {
        await SecureStorage.instance.saveSiteUrl(normalizeSiteUrl(siteUrl));
      } on FormatException catch (e) {
        throw ApiException(statusCode: 0, message: e.message);
      }
      ApiClient.instance.reset();
      final resp = await ApiClient.instance.dio.post(
        ApiEndpoints.login,
        data: {'username': username, 'password': password},
      );

      final data = resp.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          message: 'Server did not return a session token.',
        );
      }

      final user = UserModel.fromJson(data);

      await SecureStorage.instance.saveCredentials(
        username: username,
        token: token,
        displayName: user.displayName,
      );
      await SecureStorage.instance.setRememberMe(rememberMe);
      ApiClient.instance.reset();

      return user;
    } catch (_) {
      await SecureStorage.instance.clearCredentials();
      if (previousSite == null) {
        await SecureStorage.instance.clearSiteUrl();
      } else {
        await SecureStorage.instance.saveSiteUrl(previousSite);
      }
      ApiClient.instance.reset();
      rethrow;
    }
  }

  Future<UserModel> fetchCurrentUser() async {
    final resp = await ApiClient.instance.dio.get(ApiEndpoints.me);
    return UserModel.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.dio.post(ApiEndpoints.logout);
    } catch (_) {
      // Best-effort logout call.
    }
    await SecureStorage.instance.clearCredentials();
    await CacheStorage.instance.clearAll();
    ApiClient.instance.reset();
  }

  // ── Multi-account helpers ─────────────────────────────────────────────────

  Future<List<SavedAccount>> getSavedAccounts() =>
      SecureStorage.instance.getSavedAccounts();

  Future<void> removeAccount(String id) =>
      SecureStorage.instance.removeAccount(id);

  /// Restores a saved site login (site + user) by swapping the active site and token.
  Future<UserModel?> switchToAccount(String id) async {
    final accounts = await SecureStorage.instance.getSavedAccounts();
    final account = accounts.where((a) => a.id == id).firstOrNull;
    final token = account == null ? null : await SecureStorage.instance.getAccountToken(id);
    if (account == null || token == null) return null;
    if (account.siteUrl.isNotEmpty) await SecureStorage.instance.saveSiteUrl(account.siteUrl);
    await SecureStorage.instance.saveCredentials(
      username: account.username,
      token: token,
    );
    ApiClient.instance.reset();
    try {
      final user = await fetchCurrentUser();
      await SecureStorage.instance.updateAccountDisplayName(
        id,
        user.displayName,
      );
      return user;
    } catch (_) {
      await SecureStorage.instance.clearCredentials();
      ApiClient.instance.reset();
      return null;
    }
  }

  // ── Biometrics ───────────────────────────────────────────────────────────

  Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Returns true only when biometric hardware is available, the user has
  /// opted in via Settings, AND there is a saved token to restore.
  Future<bool> isBiometricReady() async {
    final available = await isBiometricAvailable();
    if (!available) return false;
    final enabled = await SecureStorage.instance.getBiometricEnabled();
    if (!enabled) return false;
    final token = await SecureStorage.instance.getToken();
    return token != null;
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to access your portal',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ── Restore session ──────────────────────────────────────────────────────

  Future<UserModel?> tryRestoreSession() async {
    final token = await SecureStorage.instance.getToken();
    if (token == null) return null;

    try {
      ApiClient.instance.reset();
      return await fetchCurrentUser();
    } catch (_) {
      return null;
    }
  }
}
