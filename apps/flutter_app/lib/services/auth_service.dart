import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'api_failure.dart';

const _kAccessKey = 'auth_access_token';
const _kRefreshKey = 'auth_refresh_token';
// Legacy single-token key from before refresh tokens existed. We read it on
// boot so users mid-flight don't get punted to /welcome, then migrate the
// value into the access slot and drop it.
const _kLegacyKey = 'auth_token';

/// Mirrors POST /auth/otp/verify.
class VerifyResult {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final bool isNewUser;
  final int expiresIn;

  VerifyResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.isNewUser,
    required this.expiresIn,
  });
}

class AuthFailure implements Exception {
  final String message;
  final int? statusCode;
  AuthFailure(this.message, {this.statusCode});

  @override
  String toString() => 'AuthFailure($statusCode): $message';
}

class AuthService {
  final _storage = const FlutterSecureStorage();
  final ApiClient _api;
  // Single in-flight refresh — concurrent 401s share it instead of hammering
  // /auth/refresh in parallel. Set by [refresh], cleared in finally.
  Future<bool>? _inflightRefresh;

  AuthService(this._api);

  // ─── Login ───────────────────────────────────────────────────────────────

  Future<void> requestOtp(String phone) async {
    try {
      await _api.post('/auth/otp/request', data: {'phone': phone});
    } on DioException catch (e) {
      throw _toFailure(e);
    }
  }

  Future<VerifyResult> verifyOtp(String phone, String code) async {
    try {
      final res = await _api.post('/auth/otp/verify', data: {'phone': phone, 'code': code});
      final data = res.data as Map<String, dynamic>;
      // The API also returns a legacy `token` alias for back-compat; ignore
      // it here — we only persist the explicit access/refresh pair.
      final access = data['access_token'] as String;
      final refresh = data['refresh_token'] as String;
      final userId = data['user_id'] as String;
      final isNew = (data['is_new_user'] as bool?) ?? false;
      final expiresIn = (data['expires_in'] as int?) ?? 3600;

      await _saveTokens(access: access, refresh: refresh);
      _api.setAuthToken(access);

      return VerifyResult(
        accessToken: access,
        refreshToken: refresh,
        userId: userId,
        isNewUser: isNew,
        expiresIn: expiresIn,
      );
    } on DioException catch (e) {
      throw _toFailure(e);
    }
  }

  // ─── Token plumbing ──────────────────────────────────────────────────────

  Future<String?> getAccessToken() => _storage.read(key: _kAccessKey);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshKey);

  Future<void> _saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _kAccessKey, value: access);
    await _storage.write(key: _kRefreshKey, value: refresh);
    // Drop the legacy entry once we have a fresh pair.
    await _storage.delete(key: _kLegacyKey);
  }

  /// Hydrate the shared [ApiClient] from secure storage on app start.
  /// Returns true if we found *anything* worth restoring (so the bootstrap
  /// can show /films instead of /welcome — the 401 interceptor will handle
  /// the case where the token turns out to be invalid).
  Future<bool> restoreSession() async {
    var access = await _storage.read(key: _kAccessKey);
    access ??= await _storage.read(key: _kLegacyKey);
    if (access == null) return false;
    _api.setAuthToken(access);
    return true;
  }

  Future<bool> hasSession() async {
    final a = await _storage.read(key: _kAccessKey);
    if (a != null) return true;
    return await _storage.read(key: _kLegacyKey) != null;
  }

  /// Wipe credentials and clear the shared client's auth header. Used by
  /// explicit sign-out AND by the 401 interceptor when refresh fails.
  Future<void> logout() async {
    await _storage.delete(key: _kAccessKey);
    await _storage.delete(key: _kRefreshKey);
    await _storage.delete(key: _kLegacyKey);
    _api.clearAuth();
  }

  // ─── Refresh ─────────────────────────────────────────────────────────────

  /// Exchange the saved refresh token for a fresh access (+ rotated refresh).
  /// Returns true on success. Concurrent callers share the same in-flight
  /// future so we never fire /auth/refresh twice in parallel.
  Future<bool> refresh() {
    return _inflightRefresh ??= _doRefresh()
        .whenComplete(() => _inflightRefresh = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      // Use a clean Dio for the refresh call so the interceptor on the main
      // client can't recurse into itself.
      final raw = Dio(BaseOptions(
        baseUrl: _api.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ));
      final res = await raw.post('/auth/refresh', data: {'refresh_token': refreshToken});
      final data = res.data as Map<String, dynamic>;
      final access = data['access_token'] as String;
      final newRefresh = data['refresh_token'] as String;
      await _saveTokens(access: access, refresh: newRefresh);
      _api.setAuthToken(access);
      return true;
    } on DioException catch (e) {
      // 401 from /auth/refresh is the hard sign-out signal — wipe tokens so
      // the next app open lands on /welcome.
      if (e.response?.statusCode == 401) {
        await logout();
      }
      return false;
    }
  }

  // ─── Error mapping ───────────────────────────────────────────────────────

  AuthFailure _toFailure(DioException e) {
    final f = ApiFailure.fromDio(e);
    return AuthFailure(f.message, statusCode: f.statusCode);
  }
}
