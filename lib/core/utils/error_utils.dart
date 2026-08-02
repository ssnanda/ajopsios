import 'package:dio/dio.dart';
import '../api/api_interceptors.dart';

/// Unwraps the server-provided message from a caught API error instead of
/// falling back to DioException's verbose toString() (the raw
/// "DioException ... Bad response ... ApiException(...)" chain).
String friendlyError(Object error) {
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return inner.message;
    return 'Cannot reach the server. Check your connection.';
  }
  if (error is ApiException) return error.message;
  return 'An unexpected error occurred.';
}
