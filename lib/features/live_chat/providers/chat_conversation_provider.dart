import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/chat_session_model.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/utils/error_utils.dart';

const _pollInterval = Duration(seconds: 5);

class ChatConversationState {
  final ChatSession session;
  final List<ChatMessage> messages;
  final bool loading;
  final String? error;
  final bool sending;
  final bool actionBusy; // claim/unclaim/close in flight

  const ChatConversationState({
    required this.session,
    this.messages = const [],
    this.loading = true,
    this.error,
    this.sending = false,
    this.actionBusy = false,
  });

  ChatConversationState copyWith({
    ChatSession? session,
    List<ChatMessage>? messages,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? sending,
    bool? actionBusy,
  }) {
    return ChatConversationState(
      session: session ?? this.session,
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      sending: sending ?? this.sending,
      actionBusy: actionBusy ?? this.actionBusy,
    );
  }
}

/// Takes the ChatSession the list screen already has in hand (from GET
/// /ops/chat/sessions) rather than re-fetching it — there's no GET single-
/// session endpoint, only the list and its messages sub-resource.
class ChatConversationNotifier extends StateNotifier<ChatConversationState> {
  ChatConversationNotifier(ChatSession initialSession)
      : super(ChatConversationState(session: initialSession)) {
    load();
    _timer = Timer.periodic(_pollInterval, (_) => load(silent: true));
  }

  final _api = OpsApi.instance;
  Timer? _timer;

  Future<void> load({bool silent = false}) async {
    if (!silent) state = state.copyWith(loading: true, clearError: true);
    try {
      final messages = await _api.getChatSessionMessages(state.session.id);
      state = state.copyWith(messages: messages, loading: false, clearError: true);
    } catch (e) {
      if (!silent) {
        state = state.copyWith(loading: false, error: friendlyError(e));
      }
    }
  }

  Future<String?> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    state = state.copyWith(sending: true);
    try {
      await _api.replyToChatSession(state.session.id, trimmed);
      state = state.copyWith(sending: false);
      await load(silent: true);
      return null;
    } catch (e) {
      state = state.copyWith(sending: false);
      return friendlyError(e);
    }
  }

  Future<String?> claim() => _runAction(() => _api.claimChatSession(state.session.id));
  Future<String?> unclaim() => _runAction(() => _api.unclaimChatSession(state.session.id));
  Future<String?> close() => _runAction(() => _api.closeChatSession(state.session.id));

  Future<String?> _runAction(Future<ChatSession> Function() action) async {
    state = state.copyWith(actionBusy: true);
    try {
      final session = await action();
      state = state.copyWith(session: session, actionBusy: false);
      return null;
    } catch (e) {
      state = state.copyWith(actionBusy: false);
      return friendlyError(e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final chatConversationProvider = StateNotifierProvider.autoDispose
    .family<ChatConversationNotifier, ChatConversationState, ChatSession>(
  (ref, session) => ChatConversationNotifier(session),
);
