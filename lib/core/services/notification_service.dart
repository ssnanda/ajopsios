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

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(iOS: darwinSettings));
  }

  /// Always carries the CURRENT total open-chat count as the app icon badge
  /// number, alongside a visible alert for the new activity that triggered
  /// it — kept as one combined call (rather than a separate silent badge-only
  /// path) since DarwinNotificationDetails' presentAlert/Badge/Sound flags
  /// only govern in-app foreground presentation, not background delivery, so
  /// a "silent" badge-sync call could still surface as an empty banner while
  /// backgrounded.
  Future<void> showNewMessage({required String title, required String body, required int badgeCount}) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          badgeNumber: badgeCount,
        ),
      ),
    );
  }
}
