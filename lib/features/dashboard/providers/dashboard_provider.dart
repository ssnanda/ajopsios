import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/models/ops_summary_model.dart';
import '../../leads/providers/leads_provider.dart';

final dashboardProvider = FutureProvider.autoDispose<OpsSummaryModel>((ref) async {
  final api = OpsApi.instance;
  final results = await Future.wait([api.getSummary(), api.getLeads()]);
  final summary = results[0] as OpsSummaryModel;
  final leads = results[1] as List<Lead>;
  // Reuses the Leads screen's own Active-view matcher (leads_provider.dart) instead of
  // re-deriving the same condition here — the two drifted apart once already (this count kept
  // counting a merged/duplicate lead as active after the Leads screen was fixed to exclude it),
  // so a single source of truth is load-bearing, not just tidiness.
  final leadsActive = leads.where((l) => LeadsView.active.matches(l) && !l.isFutureFollowUp).length;
  return summary.copyWith(leadsActive: leadsActive);
});
