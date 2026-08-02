import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_state.dart';
import '../core/widgets/coming_soon_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/live_chat/screens/live_chat_screen.dart';
import '../features/more/screens/more_screen.dart';
import '../features/service_requests/screens/service_requests_screen.dart';
import 'shell_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Stable notifier — fires when auth changes without recreating the GoRouter,
  // which avoids a black-screen flicker on logout (same pattern as ajcoreios).
  final notifier = _AuthChangeNotifier();
  ref.onDispose(notifier.dispose);
  ref.listen<AuthState>(authProvider, (prev, next) => notifier.notify());

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      // iOS reports an opened ajops:// deep link (see DeepLinkService/AppDelegate) to go_router's
      // own OS-level route listener as the RAW location string (e.g. "ajops://live-chat/") — go_router
      // treats that as a path to match against the route table, which of course never matches
      // ("No route for location: ajops://live-chat/"). Rewrite it to the actual in-app path first;
      // go_router re-runs redirect() on the result, so the auth check below still applies normally.
      if (state.uri.scheme == 'ajops') {
        final host = state.uri.host;
        return host.isNotEmpty ? '/$host' : '/live-chat';
      }

      final authState = ref.read(authProvider);
      final isAuth = authState.status == AuthStatus.authenticated;
      final isLoading = authState.status == AuthStatus.unknown;
      final onLogin = state.uri.path == '/login';

      if (isLoading) return null;
      if (!isAuth && !onLogin) return '/login';
      if (isAuth && onLogin) return '/dashboard';
      return null;
    },
    refreshListenable: notifier,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/service-requests',
            builder: (context, state) => const ServiceRequestsScreen(),
          ),
          GoRoute(
            path: '/live-chat',
            builder: (context, state) => const LiveChatScreen(),
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) => const MoreScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const ComingSoonScreen(title: 'Customers', icon: Icons.people_alt_rounded),
          ),
          GoRoute(
            path: '/leads',
            builder: (context, state) => const ComingSoonScreen(title: 'Leads', icon: Icons.person_search_rounded),
          ),
          GoRoute(
            path: '/upos-temps',
            builder: (context, state) => const ComingSoonScreen(title: 'UPOS Temps', icon: Icons.thermostat_rounded),
          ),
          GoRoute(
            path: '/mail',
            builder: (context, state) => const ComingSoonScreen(title: 'Mail', icon: Icons.mail_outline_rounded),
          ),
          GoRoute(
            path: '/files',
            builder: (context, state) => const ComingSoonScreen(title: 'Files', icon: Icons.folder_outlined),
          ),
          GoRoute(
            path: '/gmail-intake',
            builder: (context, state) => const ComingSoonScreen(title: 'Gmail Intake', icon: Icons.move_to_inbox_rounded),
          ),
          GoRoute(
            path: '/ajphone',
            builder: (context, state) => const ComingSoonScreen(title: 'AJPhone', icon: Icons.phone_in_talk_rounded),
          ),
        ],
      ),
    ],
  );
});

class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
