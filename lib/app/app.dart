import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
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

  @override
  void initState() {
    super.initState();
    // Tapping a Live Chat notification navigates here regardless of which screen is currently
    // showing — router.go() (not push) so it replaces the stack rather than piling on top of
    // whatever the user was doing when the notification arrived.
    _tapSubscription = NotificationService.instance.onNotificationTapped.listen((path) {
      ref.read(routerProvider).go(path);
    });
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
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
