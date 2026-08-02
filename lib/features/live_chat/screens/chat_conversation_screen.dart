import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/chat_session_model.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/chat_conversation_provider.dart';
import 'live_chat_screen.dart' show relativeTime;

class ChatConversationScreen extends ConsumerStatefulWidget {
  final ChatSession session;
  const ChatConversationScreen({super.key, required this.session});

  @override
  ConsumerState<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen> {
  final _composerCtrl = TextEditingController();

  @override
  void dispose() {
    _composerCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(ChatConversationNotifier notifier) async {
    final text = _composerCtrl.text;
    if (text.trim().isEmpty) return;
    _composerCtrl.clear();
    final err = await notifier.send(text);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _runAction(Future<String?> Function() action) async {
    final err = await action();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatConversationProvider(widget.session));
    final notifier = ref.read(chatConversationProvider(widget.session).notifier);
    final session = state.session;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.displayName),
        actions: [
          if (state.actionBusy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'claim':
                    _runAction(notifier.claim);
                    break;
                  case 'unclaim':
                    _runAction(notifier.unclaim);
                    break;
                  case 'close':
                    _runAction(notifier.close);
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!session.isAssigned)
                  const PopupMenuItem(value: 'claim', child: Text('Claim'))
                else
                  const PopupMenuItem(value: 'unclaim', child: Text('Unclaim')),
                if (session.isOpen)
                  const PopupMenuItem(value: 'close', child: Text('Close chat')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: Text(
              [
                session.siteLabel,
                session.isOpen ? 'Open' : 'Closed',
                session.isAssigned ? 'Claimed by ${session.assignedStaffName}' : 'Unclaimed',
              ].where((s) => s.isNotEmpty).join(' · '),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: state.loading
                ? const AjLoadingIndicator()
                : state.error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(state.error!, textAlign: TextAlign.center),
                        ),
                      )
                    : state.messages.isEmpty
                        ? const Center(child: Text('No messages yet.'))
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: state.messages.length,
                            itemBuilder: (context, i) {
                              final m = state.messages[state.messages.length - 1 - i];
                              return _MessageBubble(message: m);
                            },
                          ),
          ),
          if (session.isOpen) _Composer(controller: _composerCtrl, sending: state.sending, onSend: () => _send(notifier)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStaff = message.isStaff;
    return Align(
      alignment: isStaff ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isStaff ? theme.colorScheme.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.body,
              style: TextStyle(color: isStaff ? theme.colorScheme.onPrimary : Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              relativeTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: (isStaff ? theme.colorScheme.onPrimary : Colors.black54).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Reply…',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              onPressed: sending ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}
