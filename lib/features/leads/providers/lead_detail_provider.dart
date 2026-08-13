import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/utils/error_utils.dart';
import 'leads_provider.dart';

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
  LeadDetailNotifier(this._ref, Lead initial)
    : super(LeadDetailState(lead: initial));

  final Ref _ref;
  final _api = OpsApi.instance;

  Future<String?> addNote(String note) => _run(() async {
    await _api.addLeadNote(state.lead.id, note);
    final refreshed = await _api.getLead(state.lead.id);
    state = state.copyWith(lead: refreshed);
  });

  Future<String?> updateLead({
    String? name,
    String? email,
    String? phone,
    String? company,
    String? source,
    String? notes,
    String? siteUuid,
  }) => _run(() async {
    final updated = await _api.updateLead(
      state.lead.id,
      name: name,
      email: email,
      phone: phone,
      company: company,
      source: source,
      notes: notes,
      siteUuid: siteUuid,
    );
    state = state.copyWith(lead: updated);
  });

  Future<String?> setStage(
    String leadStatus, {
    String? stripeCustomerId,
    String? followUpAt,
    String? nonStripeCustomerName,
  }) => _run(() async {
    await _api.setLeadPipelineStatus(
      state.lead.id,
      leadStatus,
      stripeCustomerId: stripeCustomerId,
      followUpAt: followUpAt,
      nonStripeCustomerName: nonStripeCustomerName,
    );
    final refreshed = await _api.getLead(state.lead.id);
    if (refreshed.leadStatus != leadStatus) {
      throw StateError(
        'AJCore returned ${refreshed.leadStatus} after saving $leadStatus.',
      );
    }
    state = state.copyWith(lead: refreshed);
  });

  /// Unlike _run()'s other actions, there's no updated lead to patch the list cache with — the
  /// row is gone — so this calls leadsProvider's removeLead() directly and lets the caller (the
  /// detail screen) decide what to do on success, typically popping back to the list.
  Future<String?> deleteLead() async {
    state = state.copyWith(busy: true);
    try {
      await _api.deleteLead(state.lead.id);
      _ref.read(leadsProvider.notifier).removeLead(state.lead.id);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return friendlyError(e);
    }
  }

  Future<String?> _run(Future<void> Function() action) async {
    state = state.copyWith(busy: true);
    try {
      await action();
      state = state.copyWith(busy: false);
      // Keep the Leads list screen's cached copy in sync — it's a separate provider that
      // otherwise wouldn't hear about this change until the next manual pull-to-refresh.
      _ref.read(leadsProvider.notifier).patchLead(state.lead);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return friendlyError(e);
    }
  }
}

final leadDetailProvider = StateNotifierProvider.autoDispose
    .family<LeadDetailNotifier, LeadDetailState, Lead>(
      (ref, lead) => LeadDetailNotifier(ref, lead),
    );
