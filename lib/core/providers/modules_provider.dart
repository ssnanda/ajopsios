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
