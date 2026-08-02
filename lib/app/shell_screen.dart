import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/app_badge_sync_provider.dart';
import '../core/widgets/app_version_label.dart';
import '../features/live_chat/providers/live_chat_provider.dart';

/// Bottom nav holds the 4 most-used destinations; everything past that
/// (Customers, Leads, UPOS Temps, Mail, Files, Gmail Intake, AJPhone) lives
/// behind "More" rather than crowding a phone-width NavigationBar.
class ShellScreen extends ConsumerWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  static const _tabs = [
    _Tab(label: 'Dashboard', icon: Icons.dashboard_rounded, path: '/dashboard'),
    _Tab(label: 'Requests', icon: Icons.support_agent_rounded, path: '/service-requests'),
    _Tab(label: 'Chat', icon: Icons.chat_bubble_outline_rounded, path: '/live-chat'),
    _Tab(label: 'More', icon: Icons.more_horiz_rounded, path: '/more'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].path)) return i;
    }
    // Anything reached via "More" (Customers, Leads, ...) still highlights
    // the More tab rather than falling back to Dashboard.
    return _tabs.length - 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ShellScreen wraps every authenticated tab (it's the ShellRoute's persistent shell), so
    // watching these here — not just from within the Live Chat screen — keeps both the tab badge
    // and the app icon badge polling continuously across the whole app, not just while on Chat.
    final openChatCount = ref.watch(chatListProvider.select((s) => s.openCount));
    ref.watch(appBadgeSyncProvider);

    return Scaffold(
      body: Stack(
        children: [
          child,
          const Positioned(
            right: 10,
            bottom: 6,
            child: IgnorePointer(child: AppVersionLabel()),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs.map((t) {
          final icon = Icon(t.icon);
          return NavigationDestination(
            icon: t.path == '/live-chat' && openChatCount > 0 ? Badge(label: Text('$openChatCount'), child: icon) : icon,
            label: t.label,
          );
        }).toList(),
      ),
    );
  }
}

class _Tab {
  final String label;
  final IconData icon;
  final String path;
  const _Tab({required this.label, required this.icon, required this.path});
}
