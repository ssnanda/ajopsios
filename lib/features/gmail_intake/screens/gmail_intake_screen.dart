import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/gmail_intake_item_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/gmail_intake_provider.dart';
import 'gmail_intake_detail_screen.dart';

/// Pipeline: emails from the Gmail and Zoho mailboxes, matched to customers. Mirrors the AJOps web screen:
/// mailbox tiles, Pending / Filed, search, Clear, Refresh and Reset log.
class GmailIntakeScreen extends ConsumerStatefulWidget {
  const GmailIntakeScreen({super.key});

  @override
  ConsumerState<GmailIntakeScreen> createState() => _GmailIntakeScreenState();
}

class _GmailIntakeScreenState extends ConsumerState<GmailIntakeScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    final err = await ref.read(gmailIntakeProvider.notifier).processNow();
    if (err != null) _snack(err);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset log?'),
        content: const Text('Clears pending Pipeline entries. Filed items are kept and the real mailboxes are not touched.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset log')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await ref.read(gmailIntakeProvider.notifier).resetLog();
    _snack(err ?? 'Pipeline log cleared.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gmailIntakeProvider);
    final notifier = ref.read(gmailIntakeProvider.notifier);
    final items = state.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline'),
        actions: [
          IconButton(icon: const Icon(Icons.sync_rounded), tooltip: 'Refresh (check mailboxes now)', onPressed: _refresh),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') _reset();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'reset', child: Text('Reset log'))],
          ),
        ],
      ),
      body: Column(
        children: [
          // Row 1: mailbox tiles (tap = filter; dot = connection state).
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              children: [
                _MailboxTile(label: 'All', sourceKey: '', color: Colors.indigo, icon: Icons.all_inbox_rounded, state: state, onTap: notifier.setSource),
                _MailboxTile(label: 'Gmail', sourceKey: 'gmail', color: Colors.red, icon: Icons.mail_outline_rounded, state: state, onTap: notifier.setSource),
                _MailboxTile(label: 'Zoho', sourceKey: 'zoho', color: Colors.blue, icon: Icons.move_to_inbox_rounded, state: state, onTap: notifier.setSource),
              ],
            ),
          ),
          // Row 2: search (filters as you type).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: notifier.setSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search subject, sender, company, customer',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: state.search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          notifier.setSearch('');
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          // Row 3: status + Clear.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _StatusChip(label: 'Pending', count: state.countOf(state.source, kPipelinePending), value: 'pending', current: state.status, onSelect: notifier.setStatus),
                _StatusChip(label: 'Filed', count: state.countOf(state.source, kPipelineFiled), value: 'filed', current: state.status, onSelect: notifier.setStatus),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Clear'),
                    onPressed: () {
                      _searchCtrl.clear();
                      notifier.clearFilters();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.loading && state.all.isEmpty
                ? const AjLoadingIndicator()
                : state.error != null
                    ? ErrorState(message: state.error!, onRetry: notifier.load)
                    : items.isEmpty
                        ? const EmptyState(icon: Icons.move_to_inbox_outlined, title: 'Nothing here', subtitle: 'Nothing matches the current filter.')
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final item = items[i];
                                return _IntakeCard(
                                  item: item,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => GmailIntakeDetailScreen(item: item)),
                                  ),
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

class _MailboxTile extends StatelessWidget {
  final String label;
  final String sourceKey; // '' = all
  final Color color;
  final IconData icon;
  final GmailIntakeState state;
  final void Function(String) onTap;
  const _MailboxTile({required this.label, required this.sourceKey, required this.color, required this.icon, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = state.source == sourceKey;
    final pending = state.countOf(sourceKey, kPipelinePending);
    final conn = sourceKey.isEmpty ? null : state.sources[sourceKey];
    final dot = conn == null
        ? null
        : (conn['connected'] != true ? Colors.red : (conn['enabled'] == false ? Colors.grey : Colors.green));
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 150,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200, width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onTap(sourceKey),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, size: 18, color: color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Colors.grey.shade600)),
                            Text('$pending', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.1, color: pending > 0 ? Colors.orange.shade800 : null)),
                            Text('pending', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (dot != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final String value;
  final String current;
  final void Function(String) onSelect;
  const _StatusChip({required this.label, required this.count, required this.value, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text('$label  $count'), selected: value == current, onSelected: (_) => onSelect(value)),
    );
  }
}

class _SourcePill extends StatelessWidget {
  final String source;
  const _SourcePill({required this.source});

  @override
  Widget build(BuildContext context) {
    final zoho = source == 'zoho';
    final color = zoho ? Colors.blue : Colors.red;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(zoho ? 'ZOHO' : 'GMAIL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: color.shade700)),
    );
  }
}

class _IntakeCard extends StatelessWidget {
  final GmailIntakeItem item;
  final VoidCallback onTap;
  const _IntakeCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.subject.isEmpty ? '(no subject)' : item.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(item.sender, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _SourcePill(source: item.source),
                        _StatusBadge(status: item.status),
                        if (item.customerName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(child: Text(item.customerName, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'filed' || 'resolved' => Colors.green,
      'needs_review' => Colors.orange,
      'skipped_no_attachment' => Colors.grey,
      _ => Colors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
