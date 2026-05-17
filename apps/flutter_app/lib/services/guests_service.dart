import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_failure.dart';

/// A guest of an event, from the host's perspective.
class GuestSummary {
  final String id;
  final String displayName;
  final String? phone;
  final bool isHost;
  final int photoCount;
  final DateTime joinedAt;
  final DateTime? kickedAt;

  GuestSummary({
    required this.id,
    required this.displayName,
    this.phone,
    required this.isHost,
    required this.photoCount,
    required this.joinedAt,
    this.kickedAt,
  });

  factory GuestSummary.fromJson(Map<String, dynamic> j) => GuestSummary(
        id: j['id'] as String,
        displayName: j['display_name'] as String,
        phone: j['phone'] as String?,
        isHost: (j['is_host'] as bool?) ?? false,
        photoCount: (j['photo_count'] as int?) ?? 0,
        joinedAt: DateTime.parse(j['joined_at'] as String),
        kickedAt: j['kicked_at'] != null ? DateTime.parse(j['kicked_at'] as String) : null,
      );

  bool get isKicked => kickedAt != null;
}

class GuestsService {
  final ApiClient _api;
  GuestsService(this._api);

  Future<List<GuestSummary>> listForEvent(String eventId, {bool includeKicked = false}) async {
    try {
      final res = await _api.get(
        '/events/$eventId/guests',
        params: includeKicked ? {'include_kicked': 'true'} : null,
      );
      final list = (res.data as List).cast<Map<String, dynamic>>();
      return list.map(GuestSummary.fromJson).toList();
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  /// Soft-remove a guest. Existing photos stay until the host deletes them;
  /// new uploads from that guest are blocked.
  Future<void> kick({required String eventId, required String guestId}) async {
    try {
      await _api.delete('/events/$eventId/guests/$guestId');
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }
}
