import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/visitor_model.dart';
import '../../../core/utils/error_utils.dart';

/// Same reasoning as chatListProvider's polling — AJCore has no push channel reachable to this
/// app, only AJOps' own Node server does (that's also where the true real-time WebSocket push
/// AJOps web uses for Live Monitor lives). This polls AJCore's durable open/close-row view of
/// "currently online" instead — a few seconds staler than web's instant push, consistent with how
/// every other "live" feature in this app already works.
const _pollInterval = Duration(seconds: 10);

class LiveMonitorState {
  final List<Visitor> visitors;
  final bool loading;
  final String? error;

  const LiveMonitorState({this.visitors = const [], this.loading = true, this.error});

  LiveMonitorState copyWith({
    List<Visitor>? visitors,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return LiveMonitorState(
      visitors: visitors ?? this.visitors,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LiveMonitorNotifier extends StateNotifier<LiveMonitorState> {
  LiveMonitorNotifier() : super(const LiveMonitorState()) {
    load();
    _timer = Timer.periodic(_pollInterval, (_) => load(silent: true));
  }

  final _api = OpsApi.instance;
  Timer? _timer;

  Future<void> load({bool silent = false}) async {
    if (!silent) state = state.copyWith(loading: true, clearError: true);
    try {
      final visitors = await _api.getVisitors(online: true);
      state = state.copyWith(visitors: visitors, loading: false, clearError: true);
    } catch (e) {
      if (!silent) {
        state = state.copyWith(loading: false, error: friendlyError(e));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final liveMonitorProvider =
    StateNotifierProvider.autoDispose<LiveMonitorNotifier, LiveMonitorState>(
  (ref) => LiveMonitorNotifier(),
);
