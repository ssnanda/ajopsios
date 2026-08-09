import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/visitor_model.dart';
import '../../../core/utils/error_utils.dart';

class VisitorHistoryState {
  final List<Visitor> visitors;
  final bool loading;
  final String? error;

  const VisitorHistoryState({
    this.visitors = const [],
    this.loading = true,
    this.error,
  });

  VisitorHistoryState copyWith({
    List<Visitor>? visitors,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return VisitorHistoryState(
      visitors: visitors ?? this.visitors,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Full Visitor History — not "live" (no polling), just load-once + pull-to-refresh, same as the
/// leads list. Live Monitor (currently-online visitors) is the separate, polling provider.
class VisitorHistoryNotifier extends StateNotifier<VisitorHistoryState> {
  VisitorHistoryNotifier() : super(const VisitorHistoryState()) {
    load();
  }

  final _api = OpsApi.instance;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final visitors = await _api.getVisitors();
      // API already orders by latest visit start, but sort explicitly by lastSeen (mirrors AJOps
      // web's VisitorHistoryClient) so a visit that started earlier but ended later still lands
      // on top, and so this stays correct if the API's own ordering ever changes.
      final sorted = [...visitors]..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      state = state.copyWith(visitors: sorted, loading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  /// Link/unlink both just reload from AJCore rather than hand-rolling an optimistic patch — this
  /// screen already isn't "live" (load-once + pull-to-refresh), and a full reload is the only way
  /// to get the real linked_stripe_customer_id/linked_lead_id back rather than a placeholder.
  Future<String?> link(String visitorUuid, {String? stripeCustomerId, int? leadId}) async {
    try {
      await _api.linkVisitor(visitorUuid, stripeCustomerId: stripeCustomerId, leadId: leadId);
      await load();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  Future<String?> unlink(String visitorUuid) async {
    try {
      await _api.unlinkVisitor(visitorUuid);
      await load();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }
}

final visitorHistoryProvider =
    StateNotifierProvider.autoDispose<VisitorHistoryNotifier, VisitorHistoryState>(
  (ref) => VisitorHistoryNotifier(),
);
