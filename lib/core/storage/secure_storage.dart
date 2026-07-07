import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedAccount {
  final String username;
  final String displayName;

  const SavedAccount({required this.username, required this.displayName});

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> j) => SavedAccount(
        username: j['username'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
      );
}

/// Wraps flutter_secure_storage for credential management.
/// Stores JWT tokens per account; never stores raw passwords.
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ── Active session keys ───────────────────────────────────────────────────
  static const _keyUsername = 'aj_username';
  static const _keyToken = 'aj_token';
  static const _keyRememberMe = 'aj_remember_me';
  static const _keyBiometricEnabled = 'aj_biometric_enabled';
  static const _keySiteUuid = 'aj_site_uuid';

  // ── Multi-account keys ────────────────────────────────────────────────────
  static const _keyAccountsList = 'aj_accounts_list';

  String _accountTokenKey(String username) => 'aj_acct_token_$username';
  String _accountDisplayKey(String username) => 'aj_acct_display_$username';

  // ── Active session credentials ────────────────────────────────────────────

  Future<void> saveCredentials({
    required String username,
    required String token,
    String displayName = '',
  }) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyToken, value: token);
    // Also persist per-account so it survives logout
    await saveAccountEntry(username: username, token: token, displayName: displayName);
  }

  Future<String?> getUsername() => _storage.read(key: _keyUsername);
  Future<String?> getToken() => _storage.read(key: _keyToken);

  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyToken);
    // Note: per-account entries remain so user can switch back
  }

  // ── Per-account storage ───────────────────────────────────────────────────

  /// Adds or updates an account entry and its token.
  Future<void> saveAccountEntry({
    required String username,
    required String token,
    String displayName = '',
  }) async {
    await _storage.write(key: _accountTokenKey(username), value: token);
    if (displayName.isNotEmpty) {
      await _storage.write(key: _accountDisplayKey(username), value: displayName);
    }
    // Merge into accounts list
    final accounts = await getSavedAccounts();
    final updated = [
      SavedAccount(
        username: username,
        displayName: displayName.isNotEmpty ? displayName : username,
      ),
      ...accounts.where((a) => a.username != username),
    ];
    await _storage.write(
      key: _keyAccountsList,
      value: jsonEncode(updated.map((a) => a.toJson()).toList()),
    );
  }

  Future<List<SavedAccount>> getSavedAccounts() async {
    final raw = await _storage.read(key: _keyAccountsList);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedAccount.fromJson(e as Map<String, dynamic>))
          .where((a) => a.username.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> getAccountToken(String username) =>
      _storage.read(key: _accountTokenKey(username));

  Future<void> updateAccountDisplayName(String username, String displayName) =>
      _storage.write(key: _accountDisplayKey(username), value: displayName);

  Future<void> removeAccount(String username) async {
    await _storage.delete(key: _accountTokenKey(username));
    await _storage.delete(key: _accountDisplayKey(username));
    final accounts = await getSavedAccounts();
    final updated = accounts.where((a) => a.username != username).toList();
    await _storage.write(
      key: _keyAccountsList,
      value: jsonEncode(updated.map((a) => a.toJson()).toList()),
    );
  }

  // ── Preferences ───────────────────────────────────────────────────────────

  Future<void> setRememberMe(bool value) =>
      _storage.write(key: _keyRememberMe, value: value.toString());

  Future<bool> getRememberMe() async {
    final v = await _storage.read(key: _keyRememberMe);
    return v == 'true';
  }

  Future<void> setBiometricEnabled(bool value) =>
      _storage.write(key: _keyBiometricEnabled, value: value.toString());

  Future<bool> getBiometricEnabled() async {
    final v = await _storage.read(key: _keyBiometricEnabled);
    return v == 'true';
  }

  // ── Site ──────────────────────────────────────────────────────────────────

  Future<void> saveSiteUuid(String uuid) =>
      _storage.write(key: _keySiteUuid, value: uuid);

  Future<String?> getSiteUuid() => _storage.read(key: _keySiteUuid);

  // ── Wipe all ──────────────────────────────────────────────────────────────

  Future<void> clearAll() => _storage.deleteAll();
}
