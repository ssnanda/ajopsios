import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/models/ops_summary_model.dart';

final dashboardProvider = FutureProvider.autoDispose<OpsSummaryModel>((ref) async {
  final api = OpsApi.instance;
  final results = await Future.wait([api.getSummary(), api.getLeads()]);
  final summary = results[0] as OpsSummaryModel;
  final leads = results[1] as List<Lead>;
  // Recomputed client-side, same as the Leads screen's own "Active" view + default-on "Hide
  // Future Follow-up" filter (see leads_provider.dart) — a lead isn't something needing action
  // today just because AJCore's /ops/summary count doesn't yet account for a future date.
  final leadsActive = leads.where((l) => !l.isWon && !l.isLost && !l.isFutureFollowUp).length;
  return summary.copyWith(leadsActive: leadsActive);
});
