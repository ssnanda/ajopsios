import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/ops_api.dart';
import 'notification_service.dart';

const _badgeSyncInterval = Duration(seconds: 30);

/// Keeps the home-screen app icon badge in sync with pending service requests
/// + open Live Chat conversations while the app is alive — a single /ops/summary
/// poll covers both counts. Wired into ShellScreen (watched continuously, not
/// tied to any one tab) so it runs regardless of which screen is showing, same
/// lifetime pattern as chatListProvider's own polling there.
class AppBadgeSyncNotifier {
  AppBadgeSyncNotifier() {
    _sync();
    _timer = Timer.periodic(_badgeSyncInterval, (_) => _sync());
  }

  Timer? _timer;

  Future<void> _sync() async {
    try {
      final summary = await OpsApi.instance.getSummary();
      final count = summary.serviceRequestsNeedsAction + summary.chatUnread;
      await NotificationService.instance.setBadgeCount(count);
    } catch (_) {
      // Best-effort — skip this tick rather than surface a failure anywhere.
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

final appBadgeSyncProvider = Provider.autoDispose<AppBadgeSyncNotifier>((ref) {
  final notifier = AppBadgeSyncNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});
