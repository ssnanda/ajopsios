import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/pipeline_item_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/pipeline_provider.dart';
import 'pipeline_detail_screen.dart';

/// Pipeline: emails from the Gmail and Zoho mailboxes, matched to customers. Mirrors the AJOps web screen:
/// mailbox tiles, Pending / Filed, search, Clear, Refresh and Reset log.
class PipelineScreen extends ConsumerStatefulWidget {
  const PipelineScreen({super.key});

  @override
  ConsumerState<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends ConsumerState<PipelineScreen> {
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
    final err = await ref.read(pipelineProvider.notifier).processNow();
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
    final err = await ref.read(pipelineProvider.notifier).resetLog();
    _snack(err ?? 'Pipeline log cleared.');
  }

  /// Gmail and Zoho: connection state, pending count, and a tap to filter the list to one mailbox.
  void _openMailboxes(PipelineState state, PipelineNotifier notifier) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Mailboxes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            _MailboxRow(label: 'All mailboxes', sourceKey: '', icon: Icons.all_inbox_rounded, color: Colors.indigo, state: state, onPick: (k) { Navigator.of(ctx).pop(); notifier.setSource(k); }),
            _MailboxRow(label: 'Gmail', sourceKey: 'gmail', icon: Icons.mail_outline_rounded, color: Colors.red, state: state, onPick: (k) { Navigator.of(ctx).pop(); notifier.setSource(k); }),
            _MailboxRow(label: 'Zoho', sourceKey: 'zoho', icon: Icons.move_to_inbox_rounded, color: Colors.blue, state: state, onPick: (k) { Navigator.of(ctx).pop(); notifier.setSource(k); }),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('Connect or change a mailbox in AJ Core (Client Portal > Pipeline).', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "Nov 12" for this year, "Nov 12 '25" otherwise; raw text if unparseable.
  static String _briefDate(String raw) {
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toLocal();
    if (d == null) return raw.length > 10 ? raw.substring(0, 10) : raw;
    final base = '${_months[d.month - 1]} ${d.day}';
    return d.year == DateTime.now().year ? base : "$base '${d.year % 100}";
  }

  /// Subject without Re:/Fwd: prefixes, for comparing and for display.
  static String _cleanSubject(String s) =>
      s.replaceFirst(RegExp(r'^\s*((re|fwd?)\s*:\s*)+', caseSensitive: false), '').trim();

  /// Customer if matched, else the extracted company, else the sender's display name.
  static String _who(PipelineItem i) {
    if (i.customerName.isNotEmpty) return i.customerName;
    if (i.companyNameExtracted.isNotEmpty) return i.companyNameExtracted;
    final m = RegExp(r'^\s*"?([^"<]+?)"?\s*<').firstMatch(i.sender);
    return m != null ? m.group(1)!.trim() : i.sender;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pipelineProvider);
    final notifier = ref.read(pipelineProvider.notifier);
    final items = state.items;
    final subjects = items.map((i) => _cleanSubject(i.subject).toLowerCase()).toSet();
    final sameSubject = items.length > 1 && subjects.length == 1;
    final reviewCount = state.all.where((i) => i.status == 'needs_review' && (state.source.isEmpty || i.source == state.source)).length;
    final anyDown = state.sources.values.any((c) => c['connected'] != true);

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
          // One row: status filters on the left, mailbox picker (settings-style icon) on the right.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatusChip(label: 'Pending', count: state.countOf(state.source, kPipelinePending), selected: state.status == 'pending' && !state.reviewOnly, onTap: () => notifier.setStatus('pending')),
                        _StatusChip(label: 'Needs review', count: reviewCount, selected: state.reviewOnly && state.status == 'pending', color: Colors.orange, onTap: notifier.toggleReviewOnly),
                        _StatusChip(label: 'Filed', count: state.countOf(state.source, kPipelineFiled), selected: state.status == 'filed', onTap: () => notifier.setStatus('filed')),
                      ],
                    ),
                  ),
                ),
                _MailboxMenu(state: state, anyDown: anyDown, onSelect: notifier.setSource),
              ],
            ),
          ),
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
          if (sameSubject)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Text('All: ${_cleanSubject(items.first.subject)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Row(
                children: [
                  SizedBox(width: 52, child: Text('DATE', style: _headStyle)),
                  Expanded(child: Text(sameSubject ? 'CUSTOMER' : 'CUSTOMER / SUBJECT', style: _headStyle)),
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
                              padding: const EdgeInsets.only(bottom: 12),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.shade200),
                              itemBuilder: (context, i) {
                                final item = items[i];
                                return _IntakeRow(
                                  item: item,
                                  date: _briefDate(item.receivedAt),
                                  who: _who(item),
                                  subject: sameSubject ? '' : _cleanSubject(item.subject),
                                  showSource: state.source.isEmpty,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => PipelineDetailScreen(item: item)),
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

  static final _headStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Colors.grey.shade500);
}

/// Mailbox filter tucked behind one icon: shows which mailbox is active, with connection state in the menu.
class _MailboxMenu extends StatelessWidget {
  final PipelineState state;
  final bool anyDown;
  final void Function(String) onSelect;
  const _MailboxMenu({required this.state, required this.anyDown, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<String> item(String label, String key, IconData icon, Color color) {
      final conn = key.isEmpty ? null : state.sources[key];
      final dot = conn == null ? null : (conn['connected'] != true ? Colors.red : (conn['enabled'] == false ? Colors.grey : Colors.green));
      return PopupMenuItem<String>(
        value: key,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontWeight: state.source == key ? FontWeight.w800 : FontWeight.w500))),
            Text('${state.countOf(key, kPipelinePending)}', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w700)),
            if (dot != null) ...[
              const SizedBox(width: 8),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            ],
          ],
        ),
      );
    }

    final filtered = state.source.isNotEmpty;
    return PopupMenuButton<String>(
      tooltip: 'Mailboxes',
      onSelected: onSelect,
      itemBuilder: (_) => [
        item('All mailboxes', '', Icons.all_inbox_rounded, Colors.indigo),
        item('Gmail', 'gmail', Icons.mail_outline_rounded, Colors.red),
        item('Zoho', 'zoho', Icons.move_to_inbox_rounded, Colors.blue),
      ],
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.tune_rounded, color: filtered ? Theme.of(context).colorScheme.primary : null),
            if (filtered || anyDown)
              Positioned(
                top: -2,
                right: -2,
                child: Container(width: 9, height: 9, decoration: BoxDecoration(color: anyDown ? Colors.red : Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.count, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label  $count'),
        selected: selected,
        selectedColor: color?.withValues(alpha: 0.2),
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// Table-style row: date | customer (+ brief subject). Status is only shown when it is not implied by the active filter.
class _IntakeRow extends StatelessWidget {
  final PipelineItem item;
  final String date;
  final String who;
  final String subject;
  final bool showSource;
  final VoidCallback onTap;
  const _IntakeRow({required this.item, required this.date, required this.who, required this.subject, required this.showSource, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final odd = item.status != 'needs_review' && item.status != 'filed' && item.status != 'resolved';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 52, child: Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showSource)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(color: item.source == 'zoho' ? Colors.blue : Colors.red, shape: BoxShape.circle),
                        ),
                      Flexible(child: Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                      if (odd) ...[
                        const SizedBox(width: 6),
                        Text(item.status.replaceAll('_', ' '), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ],
                  ),
                  if (subject.isNotEmpty)
                    Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
