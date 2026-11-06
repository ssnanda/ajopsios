import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/ops_api.dart';

/// Menu routes the connected site offers (e.g. "customers", "gmail-intake"). Null while loading, on
/// error, or on an older AJCore without the list: callers then show everything.
final modulesProvider = FutureProvider<List<String>?>((ref) async {
  try {
    return await OpsApi.instance.getModules();
  } catch (_) {
    return null;
  }
});

/// Number per menu route from AJCore /ops/counts ("violations", "work-orders"…). Empty if unavailable.
final countsProvider = FutureProvider<Map<String, int>>((ref) async {
  try {
    return await OpsApi.instance.getCounts();
  } catch (_) {
    return <String, int>{};
  }
});
