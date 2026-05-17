import 'package:dio/dio.dart';

/// Shared error type for every service in this folder. Wraps Dio's network
/// errors and FastAPI's `{detail: …}` responses into something the UI can
/// just stringify into a SnackBar or inline error.
///
/// Validation errors come back from FastAPI as `{detail: [{loc, msg, ...}]}`
/// — we surface the first `msg` so users don't see "[object Object]".
class ApiFailure implements Exception {
  final String message;
  final int? statusCode;
  ApiFailure(this.message, {this.statusCode});

  factory ApiFailure.fromDio(DioException e) {
    final res = e.response;
    if (res != null) {
      final detail = res.data is Map ? (res.data as Map)['detail'] : null;
      final msg = detail is String
          ? detail
          : detail is List && detail.isNotEmpty && detail.first is Map
              ? ((detail.first as Map)['msg']?.toString() ?? 'Request failed')
              : 'Request failed (${res.statusCode})';
      return ApiFailure(msg, statusCode: res.statusCode);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiFailure("Can't reach Mora — check your connection.");
    }
    return ApiFailure(e.message ?? 'Unknown error');
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}
