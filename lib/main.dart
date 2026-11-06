import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/config/site_url.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await DeepLinkService.instance.init();
  runApp(const SiteScope(child: AjOpsApp()));
}
