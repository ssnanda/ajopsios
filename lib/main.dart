import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/config/site_url.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/inspection_queue.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // None of these are required to show the login screen. A throw here used to abort main()
  // before runApp, leaving the native splash up forever (Android: stripped notification icon).
  await _safeInit('notifications', NotificationService.instance.init);
  await _safeInit('deep links', DeepLinkService.instance.init);
  await _safeInit('inspection queue', InspectionQueue.instance.init);
  runApp(const SiteScope(child: AjOpsApp()));
}

Future<void> _safeInit(String name, Future<void> Function() init) async {
  try {
    await init().timeout(const Duration(seconds: 5));
  } catch (e, st) {
    debugPrint('Startup: $name init failed: $e\n$st');
  }
}
