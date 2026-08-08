import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/visitor_model.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/live_monitor_provider.dart';
import 'visitor_history_screen.dart' show pickVisitorLinkTarget;

/// View + link only — deliberately no "Start Chat"/"Start Text"/"Show Banner" push actions here.
/// Those require reaching AJOps' own live WebSocket server, which (unlike AJCore) this app has no
/// configured URL for at all — see the AJPhone/Live Monitor architecture discussion. Polls AJCore's
/// durable open/close-row view of "currently online" every 10s instead of a live push.
class LiveMonitorScreen extends ConsumerWidget {
  const LiveMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveMonitorProvider);
    final notifier = ref.read(liveMonitorProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Monitor${state.visitors.isNotEmpty ? ' (${state.visitors.length})' : ''}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => notifier.load()),
        ],
      ),
      body: state.loading
          ? const AjLoadingIndicator()
          : state.error != null
          ? ErrorState(message: state.error!, onRetry: () => notifier.load())
          : state.visitors.isEmpty
          ? const EmptyState(
              icon: Icons.sensors_rounded,
              title: 'No visitors online right now',
              subtitle: 'Refreshes automatically every 10 seconds.',
            )
          : RefreshIndicator(
              onRefresh: () => notifier.load(),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: state.visitors.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _OnlineVisitorCard(
                  visitor: state.visitors[i],
                  onLinked: () => notifier.load(silent: true),
                ),
              ),
            ),
    );
  }
}

class _OnlineVisitorCard extends StatefulWidget {
  final Visitor visitor;
  final VoidCallback onLinked;
  const _OnlineVisitorCard({required this.visitor, required this.onLinked});

  @override
  State<_OnlineVisitorCard> createState() => _OnlineVisitorCardState();
}

class _OnlineVisitorCardState extends State<_OnlineVisitorCard> {
  bool _busy = false;

  Future<void> _link() async {
    final result = await pickVisitorLinkTarget(context);
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await OpsApi.instance.linkVisitor(
        widget.visitor.visitorUuid,
        stripeCustomerId: result.customer?.stripeCustomerId,
        leadId: result.lead?.id,
      );
      widget.onLinked();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visitor;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.ipAddress.isNotEmpty ? v.ipAddress : 'Unknown IP',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [v.location, [v.browser, v.os].where((s) => s.isNotEmpty).join(' · ')]
                        .where((s) => s.isNotEmpty)
                        .join(' — '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (v.lastPage.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      v.lastPage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                  if (v.isLinked) ...[
                    const SizedBox(height: 6),
                    Text(
                      v.linkedCustomerName.isNotEmpty ? 'Customer: ${v.linkedCustomerName}' : 'Lead: ${v.linkedLeadName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: v.linkedCustomerName.isNotEmpty ? Colors.green.shade800 : Colors.blue.shade800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!v.isLinked)
              TextButton(
                onPressed: _busy ? null : _link,
                child: Text(_busy ? '…' : 'Link'),
              ),
          ],
        ),
      ),
    );
  }
}
