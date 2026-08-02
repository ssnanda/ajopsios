import 'dart:async';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local (on-device) notifications only — no APNs/remote push. This app is
/// sideloaded without a paid Apple Developer account, which a real Push
/// Notifications entitlement requires (a strict Apple platform restriction,
/// not something app code can work around). Local notifications need no such
/// entitlement, just a user permission grant, but only fire while the app
/// process is actually alive (foreground or briefly backgrounded) — never
/// while fully force-quit.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Broadcast rather than single-subscription since the app-level listener that navigates on tap
  // (see AjOpsApp) may not have subscribed yet the instant a tap comes in during startup.
  final _tapController = StreamController<String>.broadcast();

  /// Emits the route path to navigate to whenever the user taps a notification. Listened to once,
  /// at the app root (AjOpsApp), which calls router.go(path).
  Stream<String> get onNotificationTapped => _tapController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(iOS: darwinSettings),
      onDidReceiveNotificationResponse: (response) {
        _tapController.add(response.payload ?? '/live-chat');
      },
    );
  }

  /// Visible alert only — badge count is NOT set here. flutter_local_notifications has no
  /// dedicated "set badge only" API; its badgeNumber only rides along with an actual .show()
  /// call, and that call's presentAlert/Badge/Sound flags govern in-app FOREGROUND presentation
  /// only, not background delivery — so using it as the badge's source of truth risks a stray
  /// empty banner if a sync fires while backgrounded. setBadgeCount() (via flutter_app_badger,
  /// which touches nothing notification-related) is the single source of truth for the badge —
  /// see AppBadgeSyncNotifier, which polls /ops/summary and keeps it current independently of
  /// whether any alert happens to fire.
  Future<void> showNewMessage({
    required String title,
    required String body,
    String payload = '/live-chat',
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: false, presentSound: true),
      ),
      payload: payload,
    );
  }

  Future<void> setBadgeCount(int count) async {
    try {
      if (count <= 0) {
        await FlutterAppBadger.removeBadge();
      } else {
        await FlutterAppBadger.updateBadgeCount(count);
      }
    } catch (_) {
      // Badge sync is best-effort — never worth surfacing a failure for.
    }
  }
}
