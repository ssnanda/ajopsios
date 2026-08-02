import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/chat_session_model.dart';
import '../../../core/utils/error_utils.dart';

/// AJCore has no chat push/WebSocket channel reachable to this app (that
/// exists only between AJCore and AJOps' own Node server) — polling is the
/// only realtime option available directly against the REST API.
const _pollInterval = Duration(seconds: 10);

class ChatListState {
  final List<ChatSession> sessions;
  final bool loading;
  final String? error;
  final String statusFilter; // 'open' | 'all'

  const ChatListState({
    this.sessions = const [],
    this.loading = true,
    this.error,
    this.statusFilter = 'open',
  });

  ChatListState copyWith({
    List<ChatSession>? sessions,
    bool? loading,
    String? error,
    bool clearError = false,
    String? statusFilter,
  }) {
    return ChatListState(
      sessions: sessions ?? this.sessions,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }

  int get openCount => sessions.where((s) => s.isOpen).length;
}

class ChatListNotifier extends StateNotifier<ChatListState> {
  ChatListNotifier() : super(const ChatListState()) {
    load();
    _timer = Timer.periodic(_pollInterval, (_) => load(silent: true));
  }

  final _api = OpsApi.instance;
  Timer? _timer;

  Future<void> load({bool silent = false}) async {
    if (!silent) state = state.copyWith(loading: true, clearError: true);
    try {
      final sessions = await _api.getChatSessions(
        status: state.statusFilter == 'all' ? null : state.statusFilter,
      );
      state = state.copyWith(sessions: sessions, loading: false, clearError: true);
    } catch (e) {
      // Silent polling failures don't clobber a list that's already showing —
      // only surface the error state on an explicit/initial load.
      if (!silent) {
        state = state.copyWith(loading: false, error: friendlyError(e));
      }
    }
  }

  void setStatusFilter(String value) {
    state = state.copyWith(statusFilter: value);
    load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final chatListProvider = StateNotifierProvider.autoDispose<ChatListNotifier, ChatListState>(
  (ref) => ChatListNotifier(),
);
