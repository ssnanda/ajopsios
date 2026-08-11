import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/ops_api.dart';
import '../models/api_status_model.dart';

/// AJCore's /status, fetched once and cached for the provider's lifetime (deliberately not
/// .autoDispose — every screen that shows a timestamp watches this, and refetching it every time a
/// screen is entered would be wasteful for a value that only changes twice a year). Screens read
/// `.value?.utcOffsetSeconds` (falling back to 0/UTC while loading or if AJCore is unreachable) to
/// display times in AJCore's configured business timezone rather than the device's own — see
/// ApiStatusModel's doc comment for why.
final siteStatusProvider = FutureProvider<ApiStatusModel>((ref) {
  return OpsApi.instance.getStatus();
});
