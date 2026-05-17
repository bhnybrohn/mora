import 'package:dio/dio.dart';

/// One search hit from a geocoder. The display label is what we render; the
/// short label is what we save on the event ("Ikoyi, Lagos") — full
/// addresses make the album masthead crowded.
class LocationHit {
  final String displayName;
  final String shortLabel;
  final double? lat;
  final double? lon;
  final String? country;

  LocationHit({
    required this.displayName,
    required this.shortLabel,
    this.lat,
    this.lon,
    this.country,
  });
}

/// Thin geocoder wrapper. Defaults to Nominatim (OpenStreetMap) which is
/// free, no API key required, and has decent coverage. The only ask from
/// their usage policy is a custom User-Agent — set below.
///
/// To swap to Google Places later, replace [_dio] with a Places-backed
/// client and translate the response into [LocationHit] instances; nothing
/// else in the app needs to change.
class LocationsService {
  final Dio _dio;
  CancelToken? _inflight;

  LocationsService()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://nominatim.openstreetmap.org',
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            // Nominatim asks every client to identify itself.
            'User-Agent': 'Mora/0.1 (contact: hello@mora.film)',
            'Accept': 'application/json',
          },
        ));

  /// Cancels any in-flight request when called repeatedly — keeps results
  /// snappy as the user types. Returns `[]` on a blank query or any error so
  /// the UI can just render whatever comes back.
  Future<List<LocationHit>> search(String query, {int limit = 8}) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    _inflight?.cancel();
    final token = CancelToken();
    _inflight = token;

    try {
      final res = await _dio.get(
        '/search',
        queryParameters: {
          'q': q,
          'format': 'jsonv2',
          'addressdetails': '1',
          'limit': limit,
        },
        cancelToken: token,
      );
      final list = (res.data as List).cast<Map<String, dynamic>>();
      return list.map(_toHit).toList();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return const [];
      return const [];
    } catch (_) {
      return const [];
    }
  }

  LocationHit _toHit(Map<String, dynamic> j) {
    final display = (j['display_name'] as String?) ?? '';
    final addr = (j['address'] as Map?)?.cast<String, dynamic>() ?? const {};

    // Build a tighter label: prefer "city, country" over the full
    // comma-separated display path. Fall back to the first two segments
    // of `display_name` if the address parts are missing.
    final cityish = addr['city'] ??
        addr['town'] ??
        addr['village'] ??
        addr['suburb'] ??
        addr['municipality'] ??
        addr['county'] ??
        addr['state'];
    final country = addr['country'];

    String shortLabel;
    if (cityish != null && country != null) {
      shortLabel = '$cityish, $country';
    } else if (cityish != null) {
      shortLabel = cityish as String;
    } else {
      final parts = display.split(',').map((s) => s.trim()).take(2).toList();
      shortLabel = parts.join(', ');
    }

    return LocationHit(
      displayName: display,
      shortLabel: shortLabel,
      lat: double.tryParse((j['lat'] as String?) ?? ''),
      lon: double.tryParse((j['lon'] as String?) ?? ''),
      country: country as String?,
    );
  }
}
