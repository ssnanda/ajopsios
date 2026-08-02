import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/ops_summary_model.dart';
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
              const Center(child: _SyncAllButton()),
              const SizedBox(height: 16),
              // Every menu destination gets a tile now — no more hide-if-zero. Ordering does the
              // work instead: tiles with a pending count sort to the top (highest count first),
              // then everything else keeps a fixed, sensible order. No "Recent" section label —
              // it's one continuous grid, the sort is the only signal.
              _DashboardTiles(data: data),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncAllButton extends ConsumerStatefulWidget {
  const _SyncAllButton();

  @override
  ConsumerState<_SyncAllButton> createState() => _SyncAllButtonState();
}

class _SyncAllButtonState extends ConsumerState<_SyncAllButton> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final runKey = await OpsApi.instance.triggerSync();
      Map<String, dynamic> status = {'done': false};
      // Same poll cadence/timeout as AJOps web's Full Sync Now button.
      for (var i = 0; i < 60 && !(status['done'] == true); i++) {
        await Future.delayed(const Duration(milliseconds: 1500));
        status = await OpsApi.instance.getSyncRunStatus(runKey);
      }
      if (!mounted) return;
      final synced = status['records_synced'];
      final errors = (status['errors'] as List<dynamic>?) ?? const [];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          status['done'] == true
              ? (errors.isEmpty ? 'Sync complete${synced != null ? ' — $synced records' : ''}.' : 'Sync finished with ${errors.length} error(s).')
              : 'Sync is still running in the background.',
        ),
      ));
      ref.invalidate(dashboardProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _running ? null : _run,
      icon: _running
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.sync_rounded, size: 18),
      label: Text(_running ? 'Syncing…' : 'Sync All'),
    );
  }
}

class _Tile {
  final String label;
  final IconData icon;
  final Color color;
  final String? route; // null = no dedicated screen exists for this yet (e.g. Open Tasks)
  final int pending; // 0 = no live count available for this destination
  final int order; // fallback ordering among tiles that all have pending == 0

  const _Tile({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
    required this.pending,
    required this.order,
  });
}

class _DashboardTiles extends StatelessWidget {
  final OpsSummaryModel data;
  const _DashboardTiles({required this.data});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile(label: 'Service Requests', icon: Icons.support_agent_rounded, color: Colors.orange, route: '/service-requests', pending: data.serviceRequestsNeedsAction, order: 0),
      // Active (still in the pipeline, not won/lost) — not a read/unread count, which isn't
      // something actually tracked here. Always shown regardless of the count, unlike the others.
      _Tile(label: 'Leads', icon: Icons.person_search_rounded, color: Colors.green, route: '/leads', pending: data.leadsActive, order: 2),
      _Tile(label: 'Live Chat', icon: Icons.chat_bubble_outline_rounded, color: Colors.teal, route: '/live-chat', pending: data.chatUnread, order: 3),
      // No live count available from /ops/summary for these — fixed fallback order below.
      _Tile(label: 'Customers', icon: Icons.people_alt_rounded, color: Colors.blue, route: '/customers', pending: 0, order: 4),
      _Tile(label: 'UPOS Temps', icon: Icons.thermostat_rounded, color: Colors.cyan, route: '/upos-temps', pending: 0, order: 5),
      _Tile(label: 'Mail', icon: Icons.mail_outline_rounded, color: Colors.amber.shade800, route: '/mail', pending: 0, order: 6),
      _Tile(label: 'Files', icon: Icons.folder_outlined, color: Colors.brown, route: '/files', pending: 0, order: 7),
      _Tile(label: 'Gmail Intake', icon: Icons.move_to_inbox_rounded, color: Colors.pink, route: '/gmail-intake', pending: 0, order: 8),
      _Tile(label: 'AJPhone', icon: Icons.phone_in_talk_rounded, color: Colors.indigo, route: '/ajphone', pending: 0, order: 9),
    ];

    // Compound sort, not relying on List.sort's stability: pending-bearing tiles first (highest
    // count first), then the rest in their fixed fallback order.
    tiles.sort((a, b) {
      if ((a.pending > 0) != (b.pending > 0)) return a.pending > 0 ? -1 : 1;
      if (a.pending != b.pending) return b.pending.compareTo(a.pending);
      return a.order.compareTo(b.order);
    });

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: tiles.map((t) {
        return AjStatCard(
          label: t.label,
          value: t.pending > 0 || t.label == 'Leads' ? '${t.pending}' : '',
          icon: t.icon,
          accentColor: t.color,
          onTap: t.route == null ? null : () => context.go(t.route!),
        );
      }).toList(),
    );
  }
}
