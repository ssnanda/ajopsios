import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/utils/error_utils.dart';

enum LeadsView { active, won, lost, all }

extension on LeadsView {
  bool matches(Lead lead) => switch (this) {
        LeadsView.active => !lead.isWon && !lead.isLost,
        LeadsView.won => lead.isWon,
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
}

final leadsProvider = StateNotifierProvider.autoDispose<LeadsNotifier, LeadsState>((ref) => LeadsNotifier());
