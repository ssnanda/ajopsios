import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_interceptors.dart';

/// Central Dio instance factory.
/// Re-created when the base URL changes (i.e., on logout / site switch).
class ApiClient {
  ApiClient._();
  static ApiClient? _instance;
  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio? _dio;

  Dio get dio {
    _dio ??= _build();
    return _dio!;
  }

  /// Call after login/logout to reset the client (e.g. so a fresh auth
  /// header interceptor state is picked up).
  void reset() => _dio = null;

  Dio _build() {
    final storage = SecureStorage.instance;

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(storage),
      ErrorInterceptor(),
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (o) => _log(o.toString()),
      ),
    ]);

    return dio;
  }

  void _log(String msg) {
    // ignore: avoid_print
    assert(() {
      // ignore: avoid_print
      print('[ApiClient] $msg');
      return true;
    }());
  }
}
