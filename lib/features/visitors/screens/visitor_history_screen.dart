import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/models/visitor_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/visitor_history_provider.dart';

class VisitorHistoryScreen extends ConsumerWidget {
  const VisitorHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visitorHistoryProvider);
    final notifier = ref.read(visitorHistoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor History'),
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
              icon: Icons.groups_outlined,
              title: 'No visitor history yet',
              subtitle: 'Past visits show up here once someone leaves the site.',
            )
          : RefreshIndicator(
              onRefresh: () => notifier.load(),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: state.visitors.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _VisitorCard(visitor: state.visitors[i]),
              ),
            ),
    );
  }
}

class _VisitorCard extends ConsumerStatefulWidget {
  final Visitor visitor;
  const _VisitorCard({required this.visitor});

  @override
  ConsumerState<_VisitorCard> createState() => _VisitorCardState();
}

class _VisitorCardState extends ConsumerState<_VisitorCard> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visitor;
    final notifier = ref.read(visitorHistoryProvider.notifier);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    v.ipAddress.isNotEmpty ? v.ipAddress : 'Unknown IP',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                  ),
                ),
                if (v.isOnline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Online',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
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
            const SizedBox(height: 6),
            Text(
              '${v.visits} visit${v.visits == 1 ? '' : 's'} · last seen ${_fmt(v.lastSeen)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (v.isLinked)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (v.linkedCustomerName.isNotEmpty ? Colors.green : Colors.blue)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        v.linkedCustomerName.isNotEmpty
                            ? 'Customer: ${v.linkedCustomerName}'
                            : 'Lead: ${v.linkedLeadName}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: v.linkedCustomerName.isNotEmpty ? Colors.green.shade800 : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                if (v.isLinked)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _run(() => notifier.unlink(v.visitorUuid)),
                    child: Text(_busy ? '…' : 'Unlink'),
                  )
                else
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final result = await pickVisitorLinkTarget(context);
                            if (result == null) return;
                            await _run(() => notifier.link(
                                  v.visitorUuid,
                                  stripeCustomerId: result.customer?.stripeCustomerId,
                                  leadId: result.lead?.id,
                                ));
                          },
                    child: Text(_busy ? '…' : 'Link'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(String mysqlDateTime) {
  if (mysqlDateTime.isEmpty) return '—';
  final normalized = mysqlDateTime.contains('T') ? mysqlDateTime : mysqlDateTime.replaceFirst(' ', 'T');
  final dt = DateTime.tryParse(normalized);
  if (dt == null) return mysqlDateTime;
  return '${dt.month}/${dt.day}/${dt.year}';
}

class LinkTargetResult {
  final Customer? customer;
  final Lead? lead;
  const LinkTargetResult.customer(Customer this.customer) : lead = null;
  const LinkTargetResult.lead(Lead this.lead) : customer = null;
}

Future<LinkTargetResult?> pickVisitorLinkTarget(BuildContext context) {
  return showModalBottomSheet<LinkTargetResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => const _LinkTargetSheet(),
  );
}

class _LinkTargetSheet extends StatefulWidget {
  const _LinkTargetSheet();

  @override
  State<_LinkTargetSheet> createState() => _LinkTargetSheetState();
}

class _LinkTargetSheetState extends State<_LinkTargetSheet> {
  bool _leadMode = false;
  final _searchCtrl = TextEditingController();
  List<Customer>? _customers;
  List<Lead>? _leads;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_leadMode) {
        _leads = await OpsApi.instance.getLeads();
      } else {
        _customers = await OpsApi.instance.getCustomers();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final customerMatches = (_customers ?? [])
        .where((c) => query.isEmpty || c.name.toLowerCase().contains(query) || c.email.toLowerCase().contains(query))
        .take(30)
        .toList();
    final leadMatches = (_leads ?? [])
        .where((l) => query.isEmpty || l.name.toLowerCase().contains(query) || l.email.toLowerCase().contains(query))
        .take(30)
        .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Customer')),
                ButtonSegment(value: true, label: Text('Lead')),
              ],
              selected: {_leadMode},
              onSelectionChanged: (s) {
                setState(() => _leadMode = s.first);
                _load();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(hintText: 'Search…', prefixIcon: Icon(Icons.search_rounded)),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _leadMode
                  ? (leadMatches.isEmpty
                        ? const Center(child: Text('No matching leads.'))
                        : ListView.builder(
                            itemCount: leadMatches.length,
                            itemBuilder: (context, i) {
                              final l = leadMatches[i];
                              return ListTile(
                                title: Text(l.name.isNotEmpty ? l.name : 'Lead #${l.id}'),
                                subtitle: Text([l.email, l.company].where((s) => s.isNotEmpty).join(' · ')),
                                onTap: () => Navigator.of(context).pop(LinkTargetResult.lead(l)),
                              );
                            },
                          ))
                  : (customerMatches.isEmpty
                        ? const Center(child: Text('No matching customers.'))
                        : ListView.builder(
                            itemCount: customerMatches.length,
                            itemBuilder: (context, i) {
                              final c = customerMatches[i];
                              return ListTile(
                                title: Text(c.name.isNotEmpty ? c.name : c.stripeCustomerId),
                                subtitle: Text(c.email),
                                onTap: () => Navigator.of(context).pop(LinkTargetResult.customer(c)),
                              );
                            },
                          )),
            ),
          ],
        ),
      ),
    );
  }
}
