import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// v1 nav: Dashboard + Service Requests only (see README scope decision —
/// Customers/Leads/Billing/etc. land in later milestones as bottom-nav
/// destinations, or move to a drawer once there are more than ~5).
class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  static const _tabs = [
    _Tab(label: 'Dashboard', icon: Icons.dashboard_rounded, path: '/dashboard'),
    _Tab(label: 'Requests', icon: Icons.support_agent_rounded, path: '/service-requests'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs.map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label)).toList(),
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
