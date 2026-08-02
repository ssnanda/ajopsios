import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/chat_session_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/live_chat_provider.dart';
import 'chat_conversation_screen.dart';

class LiveChatScreen extends ConsumerWidget {
  const LiveChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatListProvider);
    final notifier = ref.read(chatListProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => notifier.load(),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterRow(
            value: state.statusFilter,
            openCount: state.openCount,
            onChanged: notifier.setStatusFilter,
          ),
          Expanded(
            child: state.loading
                ? const AjLoadingIndicator()
                : state.error != null
                    ? ErrorState(message: state.error!, onRetry: () => notifier.load())
                    : state.sessions.isEmpty
                        ? const EmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'No conversations',
                            subtitle: 'Nothing matches the current filter.',
                          )
                        : RefreshIndicator(
                            onRefresh: () => notifier.load(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: state.sessions.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final s = state.sessions[i];
                                return _SessionCard(
                                  session: s,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChatConversationScreen(session: s),
                                    ),
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

class _FilterRow extends StatelessWidget {
  final String value;
  final int openCount;
  final void Function(String) onChanged;

  const _FilterRow({required this.value, required this.openCount, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: 'open',
            label: Text(openCount > 0 ? 'Open ($openCount)' : 'Open'),
          ),
          const ButtonSegment(value: 'all', label: Text('All')),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  session.displayName.isNotEmpty ? session.displayName[0].toUpperCase() : '?',
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          relativeTime(session.lastMessageAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.siteLabel,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatusBadge(open: session.isOpen),
                        const SizedBox(width: 6),
                        if (session.isAssigned)
                          _Chip(label: session.assignedStaffName, icon: Icons.person_rounded)
                        else
                          _Chip(label: 'Unclaimed', icon: Icons.person_outline_rounded),
                      ],
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

class _StatusBadge extends StatelessWidget {
  final bool open;
  const _StatusBadge({required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(
        open ? 'Open' : 'Closed',
        style: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// AJCore returns MySQL-style "Y-m-d H:i:s" strings (server local time, no
/// timezone offset) — parsed loosely since exact TZ correctness isn't worth
/// the complexity for a relative "Xm ago" label.
String relativeTime(String mysqlDateTime) {
  if (mysqlDateTime.isEmpty) return '';
  final normalized = mysqlDateTime.contains('T') ? mysqlDateTime : mysqlDateTime.replaceFirst(' ', 'T');
  final dt = DateTime.tryParse(normalized);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${dt.month}/${dt.day}';
}
