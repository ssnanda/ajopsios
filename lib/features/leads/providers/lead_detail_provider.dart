import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/utils/error_utils.dart';

class LeadDetailState {
  final Lead lead;
  final bool busy;

  const LeadDetailState({required this.lead, this.busy = false});

  LeadDetailState copyWith({Lead? lead, bool? busy}) =>
      LeadDetailState(lead: lead ?? this.lead, busy: busy ?? this.busy);
}

/// Takes the Lead the list screen already has (from GET /ops/leads) rather
/// than re-fetching — GET /ops/leads/{id} returns the same shape plus
/// all_fields, only worth the extra round trip if that's actually shown.
class LeadDetailNotifier extends StateNotifier<LeadDetailState> {
  LeadDetailNotifier(Lead initial) : super(LeadDetailState(lead: initial));

  final _api = OpsApi.instance;

  Future<String?> addNote(String note) => _run(() async {
    await _api.addLeadNote(state.lead.id, note);
    final refreshed = await _api.getLead(state.lead.id);
    state = state.copyWith(lead: refreshed);
  });

  Future<String?> setStage(
    String leadStatus, {
    String? stripeCustomerId,
    String? followUpAt,
  }) => _run(() async {
    await _api.setLeadPipelineStatus(
      state.lead.id,
      leadStatus,
      stripeCustomerId: stripeCustomerId,
      followUpAt: followUpAt,
    );
    final refreshed = await _api.getLead(state.lead.id);
    if (refreshed.leadStatus != leadStatus) {
      throw StateError(
        'AJCore returned ${refreshed.leadStatus} after saving $leadStatus.',
      );
    }
    state = state.copyWith(lead: refreshed);
  });

  Future<String?> _run(Future<void> Function() action) async {
    state = state.copyWith(busy: true);
    try {
      await action();
      state = state.copyWith(busy: false);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return friendlyError(e);
    }
  }
}

final leadDetailProvider = StateNotifierProvider.autoDispose
    .family<LeadDetailNotifier, LeadDetailState, Lead>(
      (ref, lead) => LeadDetailNotifier(lead),
    );
