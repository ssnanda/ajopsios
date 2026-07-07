import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple JSON cache for offline-first support.
/// Each key stores a JSON string + a timestamp for TTL checks.
class CacheStorage {
  CacheStorage._();
  static final CacheStorage instance = CacheStorage._();

  static const int _defaultTtlMinutes = 60;

  // ── Cache keys ───────────────────────────────────────────────────────────
  static const String keyOverview = 'cache_overview';
  static const String keyServices = 'cache_services';
  static const String keyInvoices = 'cache_invoices';
  static const String keyTransactions = 'cache_transactions';
  static const String keyFiles = 'cache_files';
  static const String keyTasks = 'cache_tasks';
  static const String keyServiceRequests = 'cache_service_requests';
  static const String keyProfile = 'cache_profile';

  // ── Read / write ─────────────────────────────────────────────────────────

  Future<void> write(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
    await prefs.setString(key, payload);
  }

  Future<T?> read<T>(
    String key, {
    int ttlMinutes = _defaultTtlMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;

    final payload = jsonDecode(raw) as Map<String, dynamic>;
    final ts = payload['ts'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - ts;

    if (age > ttlMinutes * 60 * 1000) {
      await prefs.remove(key);
      return null;
    }

    return payload['data'] as T?;
  }

  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKeys = prefs.getKeys().where((k) => k.startsWith('cache_'));
    for (final k in cacheKeys) {
      await prefs.remove(k);
    }
  }
}
