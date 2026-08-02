import 'dart:async';
import 'package:app_links/app_links.dart';

/// Handles ajops:// custom-scheme deep links (tapped from the AJPhone SMS
/// alert — see chat/ingest route.ts). Not Universal Links: Associated
/// Domains also needs a paid Apple Developer account, same restriction that
/// rules out real push notifications for this sideloaded app.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  final _navController = StreamController<String>.broadcast();

  /// Emits the route path to navigate to. Listened to once, at the app root
  /// (AjOpsApp), the same way NotificationService's tap stream is.
  Stream<String> get onLink => _navController.stream;

  // No need to track/cancel this subscription — DeepLinkService is a
  // singleton that lives for the whole app process, same as NotificationService.
  Future<void> init() async {
    // Cold start: app was launched BY tapping the link, not already running.
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _handle(initial);

    _appLinks.uriLinkStream.listen(_handle);
  }

  void _handle(Uri uri) {
    // ajops://live-chat -> host="live-chat" -> "/live-chat". Falls back to
    // Live Chat for any unrecognized/empty host rather than doing nothing.
    final target = uri.host.isNotEmpty ? '/${uri.host}' : '/live-chat';
    _navController.add(target);
  }
}
