import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/live_chat_provider.dart';
import 'chat_conversation_screen.dart';

/// Resolves a bare session id (from a deep link or notification tap — see
/// router.dart's ajops:// redirect and DeepLinkService) to the full
/// ChatSession object ChatConversationScreen needs. There's no GET single-
/// session endpoint on AJCore, only the list and its messages sub-resource,
/// so this reuses the list provider's already-polling data instead of adding
/// a new API call.
class ChatConversationByIdScreen extends ConsumerWidget {
  final int sessionId;
  const ChatConversationByIdScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatListProvider);
    final notifier = ref.read(chatListProvider.notifier);

    // The list defaults to filtering status=open — a deep link might arrive
    // for a session that's since been closed, so make sure "all" gets tried
    // before giving up on it.
    final match = state.sessions.where((s) => s.id == sessionId).firstOrNull;

    if (match != null) {
      return ChatConversationScreen(session: match);
    }

    if (state.loading) {
      return const Scaffold(body: AjLoadingIndicator());
    }

    if (state.statusFilter != 'all') {
      // Not found under the default "open" filter — it may be closed. Switch
      // to "all" and let the rebuild above pick it up once loaded.
      WidgetsBinding.instance.addPostFrameCallback((_) => notifier.setStatusFilter('all'));
      return const Scaffold(body: AjLoadingIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Live Chat')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Conversation not found.', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Session #$sessionId may have been deleted.', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
