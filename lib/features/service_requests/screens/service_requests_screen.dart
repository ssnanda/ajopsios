import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/ops_service_request_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/service_requests_provider.dart';
import '../widgets/history_sheet.dart';
import '../widgets/service_status_stepper.dart';

class ServiceRequestsScreen extends ConsumerStatefulWidget {
  const ServiceRequestsScreen({super.key});

  @override
  ConsumerState<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends ConsumerState<ServiceRequestsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openHistory(OpsServiceRequest r) {
    final notifier = ref.read(serviceRequestsProvider.notifier);
    final staff = ref.read(serviceRequestsProvider).staff;
    return showHistorySheet(
      context,
      request: r,
      staff: staff,
      onAssign: (userId) => notifier.updateAssignee(r.id, userId),
      onAddNote: (note) => notifier.addNote(r.id, note),
      onCancel: () => notifier.updateServiceStatus(r.id, 'cancelled'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceRequestsProvider);
    final notifier = ref.read(serviceRequestsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Service Requests')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search customer, service, email, note...',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          notifier.setSearch('');
                        },
                      ),
              ),
              onSubmitted: notifier.setSearch,
            ),
          ),
          _StatRow(stats: state.stats, view: state.view, onSelect: notifier.setView),
          if (state.selectedIds.isNotEmpty)
            _BulkBar(state: state, notifier: notifier),
          Expanded(
            child: state.loading
                ? const AjLoadingIndicator()
                : state.error != null
                    ? ErrorState(message: state.error!, onRetry: notifier.load)
                    : state.requests.isEmpty
                        ? const EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'No service requests',
                            subtitle: 'Nothing matches the current filters.',
                          )
                        : RefreshIndicator(
                            onRefresh: notifier.load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: state.requests.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final r = state.requests[i];
                                return _RequestCard(
                                  request: r,
                                  selected: state.selectedIds.contains(r.id),
                                  busy: state.busyIds.contains(r.id),
                                  onToggleSelected: () => notifier.toggleSelected(r.id),
                                  onStatusChange: (status) async {
                                    final err = await notifier.updateServiceStatus(r.id, status);
                                    if (err != null && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                    }
                                  },
                                  onTapHistory: () => _openHistory(r),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final OpsServiceRequestStats stats;
  final ServiceRequestsView view;
  final void Function(ServiceRequestsView) onSelect;

  const _StatRow({required this.stats, required this.view, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = [
      (ServiceRequestsView.all, 'Total', stats.total),
      (ServiceRequestsView.needsAction, 'Needs Action', stats.needsAction),
      (ServiceRequestsView.active, 'Active', stats.active),
      (ServiceRequestsView.completed, 'Completed', stats.completed),
    ];
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (v, label, count) = items[i];
          final selected = view == v;
          return GestureDetector(
            onTap: () => onSelect(v),
            child: Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BulkBar extends ConsumerWidget {
  final ServiceRequestsState state;
  final ServiceRequestsNotifier notifier;
  const _BulkBar({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('${state.selectedIds.length} selected', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          PopupMenuButton<String>(
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Assign to'), Icon(Icons.arrow_drop_down)]),
            ),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: '0', child: Text('Unassigned')),
              ...state.staff.map((s) => PopupMenuItem(value: '${s.id}', child: Text(s.displayName))),
            ],
            onSelected: (v) async {
              final err = await notifier.bulkApply(assignedUserId: int.parse(v));
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              }
            },
          ),
          TextButton(onPressed: notifier.clearSelection, child: const Text('Clear')),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final OpsServiceRequest request;
  final bool selected;
  final bool busy;
  final VoidCallback onToggleSelected;
  final void Function(String status) onStatusChange;
  final VoidCallback onTapHistory;

  const _RequestCard({
    required this.request,
    required this.selected,
    required this.busy,
    required this.onToggleSelected,
    required this.onStatusChange,
    required this.onTapHistory,
  });

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: selected, onChanged: (_) => onToggleSelected()),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.serviceName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        r.customerName.isNotEmpty ? r.customerName : r.stripeCustomerId,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: onTapHistory),
              ],
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 40),
              child: ServiceStatusStepper(request: r, busy: busy, onChange: onStatusChange),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  _PayStatusBadge(status: r.status),
                  const Spacer(),
                  Text(
                    r.amount > 0
                        ? (r.currency.toLowerCase() == 'usd' ? '\$${r.amount.toStringAsFixed(2)}' : '${r.currency.toUpperCase()} ${r.amount.toStringAsFixed(2)}')
                        : '—',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayStatusBadge extends StatelessWidget {
  final String status;
  const _PayStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isGood = ['paid', 'active', 'completed'].contains(status);
    final isBad = ['cancelled', 'failed'].contains(status);
    final color = isGood ? Colors.green : (isBad ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
