import 'package:dio/dio.dart';
import '../config/constants.dart';

/// Thin Dio wrapper. Holds the shared base URL + auth header. Each call
/// accepts an optional [Options] so a caller (eg PhotosService) can override
/// headers per-request — handy when a guest-scoped JWT needs to be used in
/// place of the saved host JWT for a single call.
class ApiClient {
  late final Dio _dio;
  final String baseUrl;

  /// Hook the host wires up at startup: given a failed request, attempt a
  /// refresh and return whether retry succeeded. The interceptor calls this
  /// instead of pulling AuthService in directly so we don't create a cycle.
  Future<bool> Function(DioException error)? onUnauthorized;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? apiBaseUrl {
    _dio = Dio(BaseOptions(
      baseUrl: this.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (err, handler) async {
        // Only act on 401s, only once per request, and never for the auth
        // routes themselves — those failures are user-facing.
        final status = err.response?.statusCode;
        final path = err.requestOptions.path;
        final alreadyRetried = err.requestOptions.extra['retry_after_refresh'] == true;
        final isAuthRoute = path.startsWith('/auth/');

        if (status != 401 || alreadyRetried || isAuthRoute || onUnauthorized == null) {
          return handler.next(err);
        }

        final refreshed = await onUnauthorized!(err);
        if (!refreshed) return handler.next(err);

        // Retry the original request with the new access token applied to
        // the shared Dio options. Mark it so we never loop.
        final req = err.requestOptions;
        req.headers['Authorization'] = _dio.options.headers['Authorization'];
        req.extra['retry_after_refresh'] = true;
        try {
          final res = await _dio.fetch(req);
          return handler.resolve(res);
        } on DioException catch (e2) {
          return handler.next(e2);
        }
      },
    ));
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuth() {
    _dio.options.headers.remove('Authorization');
  }

  Future<Response> get(String path, {Map<String, dynamic>? params, Options? options}) =>
      _dio.get(path, queryParameters: params, options: options);

  Future<Response> post(String path, {dynamic data, Options? options}) =>
      _dio.post(path, data: data, options: options);

  Future<Response> patch(String path, {dynamic data, Options? options}) =>
      _dio.patch(path, data: data, options: options);

  Future<Response> delete(String path, {Options? options}) =>
      _dio.delete(path, options: options);
}
