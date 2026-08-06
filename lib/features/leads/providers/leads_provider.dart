import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/utils/error_utils.dart';

// Naming matches AJOps web and AJCore's WP-admin queue labels exactly: Active / Lost / Customer /
// All — kept in sync deliberately so support conversations about "which queue" don't need
// translating between apps.
enum LeadsView { active, customer, lost, all }

extension LeadsViewMatcher on LeadsView {
  bool matches(Lead lead) => switch (this) {
        // A merged/duplicate lead keeps its old pipeline stage (e.g. "engaged") since merging
        // only sets status='duplicate' + merged_into_lead_id, not lead_status — so it must be
        // excluded here explicitly, same as AJOps web's "active" view does.
        LeadsView.active => !lead.isWon && !lead.isLost && !lead.isDuplicate,
        // Bundles merged duplicates in with actual customers, same as AJOps web's "customer" view.
        LeadsView.customer => lead.isWon || lead.isDuplicate,
        LeadsView.lost => lead.isLost,
        LeadsView.all => true,
      };
}

class LeadsState {
  final List<Lead> leads;
  final bool loading;
  final String? error;
  final LeadsView view;
  final String search;
  final bool hideFutureFollowUp;

  const LeadsState({
    this.leads = const [],
    this.loading = true,
    this.error,
    this.view = LeadsView.active,
    this.search = '',
    this.hideFutureFollowUp = true,
  });

  LeadsState copyWith({
    List<Lead>? leads,
    bool? loading,
    String? error,
    bool clearError = false,
    LeadsView? view,
    String? search,
    bool? hideFutureFollowUp,
  }) {
    return LeadsState(
      leads: leads ?? this.leads,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      view: view ?? this.view,
      search: search ?? this.search,
      hideFutureFollowUp: hideFutureFollowUp ?? this.hideFutureFollowUp,
    );
  }

  List<Lead> get filtered => leads
      .where(view.matches)
      .where((lead) => !hideFutureFollowUp || !lead.isFutureFollowUp)
      .toList();
}

class LeadsNotifier extends StateNotifier<LeadsState> {
  LeadsNotifier() : super(const LeadsState()) {
    load();
  }

  final _api = OpsApi.instance;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final leads = await _api.getLeads(search: state.search.isEmpty ? null : state.search);
      state = state.copyWith(leads: leads, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  void setView(LeadsView view) => state = state.copyWith(view: view);

  void setHideFutureFollowUp(bool value) => state = state.copyWith(hideFutureFollowUp: value);

  void setSearch(String value) {
    state = state.copyWith(search: value);
    load();
  }

  /// Replaces one row in the cached list in place — called after an edit/note/stage change on
  /// the detail screen so the list reflects it immediately, without waiting for a manual
  /// pull-to-refresh (this list and the per-lead detail provider are separate pieces of state
  /// that don't otherwise know about each other).
  void patchLead(Lead updated) {
    state = state.copyWith(
      leads: [for (final l in state.leads) l.id == updated.id ? updated : l],
    );
  }

  /// Called after creating a new lead — prepends it so it's visible immediately, matching
  /// AJOps web's AddLeadModal (onCreated prepends rather than re-fetching the whole list).
  void addLead(Lead lead) {
    state = state.copyWith(leads: [lead, ...state.leads]);
  }
}

final leadsProvider = StateNotifierProvider.autoDispose<LeadsNotifier, LeadsState>((ref) => LeadsNotifier());
