import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import 'api_interceptors.dart';

/// Talks to the AJOps web server (ops.<site>), for things AJCore has no API for, like AJPhone (Zoom).
/// Signs in with the same AJCore login token the rest of the app uses.
class AjopsApi {
  AjopsApi._();
  static final AjopsApi instance = AjopsApi._();

  /// "https://ncllcagents.com/wp-json/ajcore/v1" -> "https://ops.ncllcagents.com"
  static String? deriveFromSite(String? siteApiUrl) {
    final host = Uri.tryParse(siteApiUrl ?? '')?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '';
    return host.isEmpty ? null : 'https://ops.$host';
  }

  Future<String?> baseUrl() async {
    final stored = (await SecureStorage.instance.getOpsUrl())?.trim() ?? '';
    if (stored.isNotEmpty) return stored.replaceAll(RegExp(r'/+$'), '');
    return deriveFromSite(await SecureStorage.instance.getSiteUrl());
  }

  Future<Dio> _dio() async {
    final base = await baseUrl();
    if (base == null) throw const ApiException(statusCode: 0, message: 'AJOps address is not set. Add it in Settings.');
    final token = await SecureStorage.instance.getToken();
    final dio = Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));
    // Same error shape as the AJCore client, so friendlyError() works on both.
    dio.interceptors.add(InterceptorsWrapper(onError: (err, handler) {
      final response = err.response;
      if (response != null) {
        final data = response.data;
        final message = data is Map ? '${data['message'] ?? data['error'] ?? 'An unexpected error occurred.'}' : 'An unexpected error occurred.';
        return handler.reject(DioException(
          requestOptions: err.requestOptions,
          response: response,
          type: err.type,
          error: ApiException(statusCode: response.statusCode ?? 0, message: message),
        ));
      }
      handler.next(err);
    }));
    return dio;
  }

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) async => (await _dio()).get(path, queryParameters: query);

  Future<Response<dynamic>> post(String path, Map<String, dynamic> data) async => (await _dio()).post(path, data: data);
}
