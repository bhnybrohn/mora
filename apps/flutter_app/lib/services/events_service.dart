import 'package:dio/dio.dart';

import '../models/event.dart';
import 'api_client.dart';
import 'api_failure.dart';

/// Maps the host-side /events endpoints to typed Dart calls. Read methods
/// return parsed models; mutating methods return the freshly-persisted row
/// so callers don't have to re-fetch to render.
class EventsService {
  final ApiClient _api;
  EventsService(this._api);

  Future<List<Event>> listMine({bool includeArchived = false}) async {
    try {
      final res = await _api.get('/events', params: {
        if (includeArchived) 'include_archived': 'true',
      });
      final list = (res.data as List).cast<Map<String, dynamic>>();
      return list.map(Event.fromJson).toList();
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<Event> get(String id) async {
    try {
      final res = await _api.get('/events/$id');
      return Event.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<Event> create({
    required String name,
    String location = '',
    required EventType eventType,
    required EventPrivacy privacy,
    required DateTime startsAt,
    required DateTime endsAt,
    required DateTime revealAt,
    required EventTier tier,
  }) async {
    try {
      final res = await _api.post('/events', data: {
        'name': name,
        'location': location,
        'event_type': eventType.name,
        'privacy': privacy.name,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'reveal_at': revealAt.toUtc().toIso8601String(),
        'tier': tier.name,
      });
      return Event.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  /// Mint a guest token for the host so they can shoot their own event.
  /// Idempotent — the API returns the same Guest row on repeat calls.
  Future<HostCameraGrant> hostCamera(String eventId) async {
    try {
      final res = await _api.post('/events/$eventId/host-camera');
      final j = res.data as Map<String, dynamic>;
      return HostCameraGrant(
        guestId: j['guest_id'] as String,
        eventId: j['event_id'] as String,
        token: j['token'] as String,
        displayName: j['display_name'] as String,
        isHost: (j['is_host'] as bool?) ?? true,
      );
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  /// Patch an existing event. Only fields you pass are touched server-side.
  Future<Event> update(
    String id, {
    String? name,
    String? location,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? revealAt,
    EventTier? tier,
    EventPrivacy? privacy,
  }) async {
    try {
      final res = await _api.patch('/events/$id', data: {
        if (name != null) 'name': name,
        if (location != null) 'location': location,
        if (startsAt != null) 'starts_at': startsAt.toUtc().toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        if (revealAt != null) 'reveal_at': revealAt.toUtc().toIso8601String(),
        if (tier != null) 'tier': tier.name,
        if (privacy != null) 'privacy': privacy.name,
      });
      return Event.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<Event> reveal(String id) async {
    try {
      final res = await _api.post('/events/$id/reveal');
      final body = res.data as Map<String, dynamic>;
      // /reveal returns a slim {id,status,revealed_at}; re-fetch to get the
      // full event payload (counts, etc.) for the caller.
      if (body.containsKey('owner_user_id')) {
        return Event.fromJson(body);
      }
      return await get(id);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<void> archive(String id) async {
    try {
      await _api.delete('/events/$id');
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  /// Host-side album: every active photo regardless of reveal state.
  Future<List<AlbumPhoto>> album(String id) async {
    try {
      final res = await _api.get('/events/$id/album');
      final list = (res.data as List).cast<Map<String, dynamic>>();
      return list.map(AlbumPhoto.fromJson).toList();
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }
}

/// Result of POST /events/:id/host-camera — the host's own guest token.
class HostCameraGrant {
  final String guestId;
  final String eventId;
  final String token;
  final String displayName;
  final bool isHost;

  HostCameraGrant({
    required this.guestId,
    required this.eventId,
    required this.token,
    required this.displayName,
    required this.isHost,
  });
}

/// Lightweight view of a photo from the host album endpoint. Includes a
/// ready-to-render public URL so the UI doesn't have to compose one.
class AlbumPhoto {
  final String id;
  final String? guestId;
  final String? guestName;
  final int width;
  final int height;
  final DateTime takenAt;
  final String url;
  final String previewUrl;

  AlbumPhoto({
    required this.id,
    required this.guestId,
    required this.guestName,
    required this.width,
    required this.height,
    required this.takenAt,
    required this.url,
    required this.previewUrl,
  });

  factory AlbumPhoto.fromJson(Map<String, dynamic> j) => AlbumPhoto(
        id: j['id'] as String,
        guestId: j['guest_id'] as String?,
        guestName: j['guest_name'] as String?,
        width: j['width'] as int,
        height: j['height'] as int,
        takenAt: DateTime.parse(j['taken_at'] as String),
        url: j['url'] as String,
        previewUrl: j['preview_url'] as String,
      );
}
