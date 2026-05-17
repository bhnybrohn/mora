import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_failure.dart';

/// One photo from a guest's reveal-aware listing.
class GuestPhoto {
  final String id;
  final String eventId;
  final String? guestId;
  final String? guestName;
  final int width;
  final int height;
  final DateTime takenAt;
  final String url;
  final String previewUrl;
  final bool isOwn;

  GuestPhoto({
    required this.id,
    required this.eventId,
    required this.guestId,
    required this.guestName,
    required this.width,
    required this.height,
    required this.takenAt,
    required this.url,
    required this.previewUrl,
    required this.isOwn,
  });

  factory GuestPhoto.fromJson(Map<String, dynamic> j) => GuestPhoto(
        id: j['id'] as String,
        eventId: j['event_id'] as String,
        guestId: j['guest_id'] as String?,
        guestName: j['guest_name'] as String?,
        width: j['width'] as int,
        height: j['height'] as int,
        takenAt: DateTime.parse(j['taken_at'] as String),
        url: j['url'] as String,
        previewUrl: j['preview_url'] as String,
        isOwn: j['is_own'] as bool,
      );
}

/// What `/photos/init` hands back for one of the two presigned uploads.
class _PresignedUpload {
  final String url;
  final String method;
  final Map<String, String> headers;
  final String key;
  _PresignedUpload({
    required this.url,
    required this.method,
    required this.headers,
    required this.key,
  });
  factory _PresignedUpload.fromJson(Map<String, dynamic> j) => _PresignedUpload(
        url: j['url'] as String,
        method: j['method'] as String,
        headers: (j['headers'] as Map).cast<String, String>(),
        key: j['key'] as String,
      );
}

/// Result of an end-to-end upload — what the camera screen needs to update
/// its local "recent shots" strip.
class UploadedPhoto {
  final String id;
  final DateTime takenAt;
  UploadedPhoto({required this.id, required this.takenAt});
}

class PhotosService {
  final ApiClient _api;
  PhotosService(this._api);

  /// Full happy path: init -> PUT full -> PUT preview -> commit.
  ///
  /// [bytes] is the full-resolution image (what the camera produced).
  /// [previewBytes] is a 240px-ish preview. If null, we reuse the full bytes —
  /// fine for v1, but the camera screen should compress and pass a real
  /// preview so the album loads fast.
  Future<UploadedPhoto> uploadOne({
    required String eventId,
    required String guestToken,
    required List<int> bytes,
    List<int>? previewBytes,
    required int width,
    required int height,
    String mime = 'image/webp',
    String ext = 'webp',
    DateTime? takenAt,
  }) async {
    try {
      // 1. init — get presigned URLs + photo_id
      final initRes = await _api.post(
        '/events/$eventId/photos/init',
        data: {'mime': mime, 'ext': ext},
        options: Options(headers: {'Authorization': 'Bearer $guestToken'}),
      );
      final data = initRes.data as Map<String, dynamic>;
      final photoId = data['photo_id'] as String;
      final full = _PresignedUpload.fromJson(data['full'] as Map<String, dynamic>);
      final preview = _PresignedUpload.fromJson(data['preview'] as Map<String, dynamic>);

      // 2. PUT both blobs in parallel
      await Future.wait([
        _putBlob(full, bytes),
        _putBlob(preview, previewBytes ?? bytes),
      ]);

      // 3. commit
      final commitRes = await _api.post(
        '/events/$eventId/photos/commit',
        data: {
          'photo_id': photoId,
          'mime': mime,
          'width': width,
          'height': height,
          if (takenAt != null) 'taken_at': takenAt.toUtc().toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Bearer $guestToken'}),
      );
      final body = commitRes.data as Map<String, dynamic>;
      return UploadedPhoto(
        id: body['id'] as String,
        takenAt: DateTime.parse(body['taken_at'] as String),
      );
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<void> _putBlob(_PresignedUpload p, List<int> bytes) async {
    // The presigned URLs point at the storage backend directly (R2 or our
    // dev /dev-uploads). They must NOT carry our API's Authorization header,
    // so use a bare Dio instance for the PUT.
    final raw = Dio(BaseOptions(
      followRedirects: false,
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
    ));
    await raw.requestUri(
      Uri.parse(p.url),
      data: Stream.value(bytes),
      options: Options(
        method: p.method,
        headers: {
          ...p.headers,
          HttpHeaders.contentLengthHeader: bytes.length,
        },
      ),
    );
  }

  /// Reveal-aware list for a guest. Pre-reveal returns own only;
  /// post-reveal returns the full album.
  Future<List<GuestPhoto>> listForGuest({
    required String eventId,
    required String guestToken,
  }) async {
    try {
      final res = await _api.get(
        '/events/$eventId/photos',
        options: Options(headers: {'Authorization': 'Bearer $guestToken'}),
      );
      final list = (res.data as List).cast<Map<String, dynamic>>();
      return list.map(GuestPhoto.fromJson).toList();
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }
}
