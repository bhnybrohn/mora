import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_failure.dart';

/// What `/auth/me` returns — the current user's profile.
class Me {
  final String id;
  final String phone;
  final String? displayName;
  final String locale;

  Me({
    required this.id,
    required this.phone,
    this.displayName,
    required this.locale,
  });

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: j['id'] as String,
        phone: j['phone'] as String,
        displayName: j['display_name'] as String?,
        locale: (j['locale'] as String?) ?? 'en',
      );
}

class MeService {
  final ApiClient _api;
  MeService(this._api);

  Future<Me> get() async {
    try {
      final res = await _api.get('/auth/me');
      return Me.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }
}
