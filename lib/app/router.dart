import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_state.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/communities/screens/communities_screens.dart';
import '../features/communities/screens/inspection_screen.dart';
import '../features/customers/screens/customers_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/ajphone/ajphone_screens.dart';
import '../features/email_log/email_log_screen.dart';
import '../features/files/screens/files_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/gmail_intake/screens/gmail_intake_screen.dart';
import '../features/live_chat/screens/chat_conversation_by_id_screen.dart';
import '../features/live_chat/screens/live_chat_screen.dart';
import '../features/visitors/screens/visitors_hub_screen.dart';
import '../features/leads/screens/leads_screen.dart';
import '../features/mail/screens/mail_screen.dart';
import '../features/more/screens/about_screen.dart';
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
        if (host.isEmpty) return '/live-chat';
        final path = state.uri.path; // e.g. "/42" for ajops://live-chat/42
        return '/$host$path';
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
            path: '/requests',
            builder: (context, state) => ServiceRequestsScreen(
              requestType: state.uri.queryParameters['type'],
              title: state.uri.queryParameters['title'],
            ),
          ),
          GoRoute(
            path: '/inspect',
            builder: (context, state) => const InspectionScreen(),
          ),
          GoRoute(
            path: '/visitors',
            builder: (context, state) => const VisitorsHubScreen(),
          ),
          GoRoute(
            path: '/live-chat',
            builder: (context, state) => const LiveChatScreen(),
            routes: [
              GoRoute(
                path: ':sessionId',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['sessionId'] ?? '') ?? 0;
                  return ChatConversationByIdScreen(sessionId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) => const MoreScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: '/communities',
            builder: (context, state) => const CommunitiesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => CommunityScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'units/:unitId',
                    builder: (context, state) => UnitScreen(unitId: int.tryParse(state.pathParameters['unitId'] ?? '') ?? 0),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/leads',
            builder: (context, state) => const LeadsScreen(),
          ),
          GoRoute(
            path: '/mail',
            builder: (context, state) => const MailScreen(),
          ),
          GoRoute(
            path: '/files',
            builder: (context, state) => const FilesScreen(),
          ),
          GoRoute(
            path: '/pipeline',
            builder: (context, state) => const GmailIntakeScreen(),
          ),
          // Old path, kept so existing links still open the Pipeline.
          GoRoute(
            path: '/gmail-intake',
            builder: (context, state) => const GmailIntakeScreen(),
          ),
          GoRoute(
            path: '/email-log',
            builder: (context, state) => const EmailLogScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/about',
            builder: (context, state) => const AboutScreen(),
          ),
          GoRoute(
            path: '/ajphone',
            builder: (context, state) => const AjphoneScreen(),
          ),
        ],
      ),
    ],
  );
});

class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
