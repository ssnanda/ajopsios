import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/ops_summary_model.dart';

final dashboardProvider = FutureProvider.autoDispose<OpsSummaryModel>((ref) {
  return OpsApi.instance.getSummary();
});
