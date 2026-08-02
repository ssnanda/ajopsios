import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/services/deep_link_service.dart';
import '../core/services/notification_service.dart';
import 'router.dart';
import 'theme.dart';

class AjOpsApp extends ConsumerStatefulWidget {
  const AjOpsApp({super.key});

  @override
  ConsumerState<AjOpsApp> createState() => _AjOpsAppState();
}

class _AjOpsAppState extends ConsumerState<AjOpsApp> {
  StreamSubscription<String>? _tapSubscription;
  StreamSubscription<String>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    // Both routes land here — tapping a Live Chat notification (in-app alert) and tapping the
    // ajops:// link from the AJPhone SMS text — router.go() (not push) so it replaces the stack
    // rather than piling on top of whatever the user was doing when it arrived.
    _tapSubscription = NotificationService.instance.onNotificationTapped.listen((path) {
      ref.read(routerProvider).go(path);
    });
    _linkSubscription = DeepLinkService.instance.onLink.listen((path) {
      ref.read(routerProvider).go(path);
    });
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AjTheme.light,
      darkTheme: AjTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
