import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/site_chip.dart';
import '../providers/live_monitor_provider.dart';
import 'live_monitor_screen.dart';
import 'visitor_history_screen.dart';

/// Its own tab: Live Monitor (who is on the site right now) is the main view, Visitor History sits one tap away.
class VisitorsHubScreen extends ConsumerWidget {
  const VisitorsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(liveMonitorProvider.select((s) => s.visitors.length));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const AjAppBarTitle('Visitors'),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.sensors_rounded, size: 20), text: online > 0 ? 'Live now ($online)' : 'Live now', iconMargin: const EdgeInsets.only(bottom: 2)),
              const Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'History', iconMargin: EdgeInsets.only(bottom: 2)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            LiveMonitorScreen(embedded: true),
            VisitorHistoryScreen(embedded: true),
          ],
        ),
      ),
    );
  }
}
