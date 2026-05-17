import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'api_failure.dart';

/// A vendor credit shown on a film. Palette is the asoebi 3-color triad
/// [base, glow, lift] — the AsoebiSwatch widget consumes it as-is.
class Sponsor {
  final String id;
  final String eventId;
  final String name;
  final String role;
  final List<Color> palette;
  final String? link;
  final String? tagline;
  final String? logoKey;
  final String? logoUrl;
  final bool isFeatured;
  final int sortOrder;

  Sponsor({
    required this.id,
    required this.eventId,
    required this.name,
    required this.role,
    required this.palette,
    this.link,
    this.tagline,
    this.logoKey,
    this.logoUrl,
    required this.isFeatured,
    required this.sortOrder,
  });

  factory Sponsor.fromJson(Map<String, dynamic> j) => Sponsor(
        id: j['id'] as String,
        eventId: j['event_id'] as String,
        name: j['name'] as String,
        role: j['role'] as String,
        palette: ((j['palette'] as List?) ?? const [])
            .map((s) => _parseHex(s as String))
            .toList(),
        link: j['link'] as String?,
        tagline: j['tagline'] as String?,
        logoKey: j['logo_key'] as String?,
        logoUrl: j['logo_url'] as String?,
        isFeatured: (j['is_featured'] as bool?) ?? false,
        sortOrder: (j['sort_order'] as int?) ?? 0,
      );
}

Color _parseHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  final v = int.parse(clean, radix: 16);
  // Add full alpha when only 6 digits were provided.
  return Color(clean.length == 6 ? (0xFF000000 | v) : v);
}

String hexOf(Color c) {
  // Flutter ≥ 3.27 exposes `.toARGB32()` since `.value` is deprecated. We
  // strip the alpha byte for the API which expects "#RRGGBB".
  final argb = c.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Presigned upload payload from POST /events/:id/sponsors/logo-init.
class SponsorLogoUpload {
  final String url;
  final String method;
  final Map<String, String> headers;
  final String key;
  final int expiresIn;

  SponsorLogoUpload({
    required this.url,
    required this.method,
    required this.headers,
    required this.key,
    required this.expiresIn,
  });

  factory SponsorLogoUpload.fromJson(Map<String, dynamic> j) => SponsorLogoUpload(
        url: j['url'] as String,
        method: j['method'] as String,
        headers: (j['headers'] as Map).cast<String, String>(),
        key: j['key'] as String,
        expiresIn: (j['expires_in'] as int?) ?? 900,
      );
}

class SponsorsService {
  final ApiClient _api;
  SponsorsService(this._api);

  Future<List<Sponsor>> listForEvent(String eventId) async {
    try {
      final res = await _api.get('/events/$eventId/sponsors');
      final list = (res.data as List).cast<Map<String, dynamic>>();
      return list.map(Sponsor.fromJson).toList();
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<Sponsor> create({
    required String eventId,
    required String name,
    required String role,
    List<Color>? palette,
    String? link,
    String? tagline,
    String? logoKey,
    bool isFeatured = false,
    int sortOrder = 0,
  }) async {
    try {
      final res = await _api.post('/events/$eventId/sponsors', data: {
        'name': name,
        'role': role,
        if (palette != null) 'palette': palette.map(hexOf).toList(),
        if (link != null && link.isNotEmpty) 'link': link,
        if (tagline != null && tagline.isNotEmpty) 'tagline': tagline,
        if (logoKey != null) 'logo_key': logoKey,
        'is_featured': isFeatured,
        'sort_order': sortOrder,
      });
      return Sponsor.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<Sponsor> update({
    required String eventId,
    required String sponsorId,
    String? name,
    String? role,
    List<Color>? palette,
    String? link,
    String? tagline,
    String? logoKey,
    bool? isFeatured,
    int? sortOrder,
  }) async {
    try {
      final res = await _api.patch('/events/$eventId/sponsors/$sponsorId', data: {
        if (name != null) 'name': name,
        if (role != null) 'role': role,
        if (palette != null) 'palette': palette.map(hexOf).toList(),
        if (link != null) 'link': link,
        if (tagline != null) 'tagline': tagline,
        if (logoKey != null) 'logo_key': logoKey,
        if (isFeatured != null) 'is_featured': isFeatured,
        if (sortOrder != null) 'sort_order': sortOrder,
      });
      return Sponsor.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  Future<void> delete({required String eventId, required String sponsorId}) async {
    try {
      await _api.delete('/events/$eventId/sponsors/$sponsorId');
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }

  /// Two-step logo upload: init → PUT bytes to the returned URL. The
  /// resulting `key` is what you stash on the sponsor via create/update.
  Future<String> uploadLogo({
    required String eventId,
    required List<int> bytes,
    String contentType = 'image/png',
  }) async {
    try {
      final initRes = await _api.post('/events/$eventId/sponsors/logo-init');
      final init = SponsorLogoUpload.fromJson(initRes.data as Map<String, dynamic>);

      // Bare Dio for the PUT — presigned URLs point at storage, not the API.
      final raw = Dio(BaseOptions(
        followRedirects: false,
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));
      await raw.requestUri(
        Uri.parse(init.url),
        data: Stream.value(bytes),
        options: Options(
          method: init.method,
          headers: {...init.headers, 'Content-Length': bytes.length},
        ),
      );
      return init.key;
    } on DioException catch (e) {
      throw ApiFailure.fromDio(e);
    }
  }
}
