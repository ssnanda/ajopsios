import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/aj_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider),
        child: summary.when(
          loading: () => const AjLoadingIndicator(),
          error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Welcome back, ${user.displayName.isNotEmpty ? user.displayName : user.username}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  // Customers and Subscriptions tiles removed per explicit ask. Service
                  // Requests/Open Tasks/Leads/Chat only show when there's actually something
                  // needing attention — a "0" tile is just noise on a small screen.
                  if (data.serviceRequestsNeedsAction > 0)
                    AjStatCard(
                      label: 'Service Requests',
                      value: '${data.serviceRequestsNeedsAction}',
                      icon: Icons.support_agent_rounded,
                      onTap: () => context.go('/service-requests'),
                    ),
                  if (data.tasksOpen > 0)
                    AjStatCard(
                      label: 'Open Tasks',
                      value: '${data.tasksOpen}',
                      icon: Icons.task_alt_rounded,
                    ),
                  if (data.leadsUnread > 0)
                    AjStatCard(
                      label: 'Leads',
                      value: '${data.leadsUnread}',
                      icon: Icons.person_search_rounded,
                      onTap: () => context.go('/leads'),
                    ),
                  if (data.chatUnread > 0)
                    AjStatCard(
                      label: 'Live Chat',
                      value: '${data.chatUnread}',
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () => context.go('/live-chat'),
                    ),
                  AjStatCard(
                    label: 'AJPhone',
                    value: '',
                    icon: Icons.phone_in_talk_rounded,
                    onTap: () => context.go('/ajphone'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AjCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Links', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.support_agent_rounded),
                      title: const Text('Service Requests queue'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/service-requests'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
