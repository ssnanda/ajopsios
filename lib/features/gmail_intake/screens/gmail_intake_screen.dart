import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/gmail_intake_item_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/gmail_intake_provider.dart';
import 'gmail_intake_detail_screen.dart';

class GmailIntakeScreen extends ConsumerWidget {
  const GmailIntakeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gmailIntakeProvider);
    final notifier = ref.read(gmailIntakeProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gmail Intake'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Check inbox now',
            onPressed: () async {
              final err = await notifier.processNow();
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _StatusChip(label: 'Needs review', value: 'needs_review', current: state.status, onSelect: notifier.setStatus),
                _StatusChip(label: 'Pending file', value: 'matched_pending_file', current: state.status, onSelect: notifier.setStatus),
                _StatusChip(label: 'Filed', value: 'filed', current: state.status, onSelect: notifier.setStatus),
                _StatusChip(label: 'Resolved', value: 'resolved', current: state.status, onSelect: notifier.setStatus),
                _StatusChip(label: 'All', value: '', current: state.status, onSelect: notifier.setStatus),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: state.loading
                ? const AjLoadingIndicator()
                : state.error != null
                    ? ErrorState(message: state.error!, onRetry: notifier.load)
                    : state.items.isEmpty
                        ? const EmptyState(icon: Icons.move_to_inbox_outlined, title: 'Nothing here', subtitle: 'Nothing matches the current filter.')
                        : RefreshIndicator(
                            onRefresh: notifier.load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: state.items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final item = state.items[i];
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

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onSelect;
  const _StatusChip({required this.label, required this.value, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: value == current, onSelected: (_) => onSelect(value)),
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
                        _StatusBadge(status: item.status),
                        if (item.customerName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(item.customerName, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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
