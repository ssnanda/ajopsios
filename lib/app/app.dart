import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import 'router.dart';
import 'theme.dart';

class AjOpsApp extends ConsumerWidget {
  const AjOpsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
