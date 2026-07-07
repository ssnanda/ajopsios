import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorage _storage;

  AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    options.headers['X-AJCore-Client'] = 'mobile/1.0';
    handler.next(options);
  }
}

/// Translates Dio errors into readable [ApiException] objects.
/// Also clears stored credentials when the server returns 401
/// (token expired or revoked) so the login screen is shown on the next navigation.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;

    if (response != null) {
      if (response.statusCode == 401) {
        SecureStorage.instance.clearCredentials();
      }

      final data = response.data;
      String message = 'An unexpected error occurred.';

      if (data is Map) {
        message = (data['message'] as String?) ??
            (data['error'] as String?) ??
            message;
      }

      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: response,
          type: err.type,
          error: ApiException(
            statusCode: response.statusCode ?? 0,
            message: message,
          ),
        ),
      );
      return;
    }

    handler.next(err);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
