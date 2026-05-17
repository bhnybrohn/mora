import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL for the Mora API.
///
/// - On the Android emulator, `localhost` resolves inside the emulator VM, not
///   the host; we use `10.0.2.2` which is the special host-loopback alias.
/// - On the iOS simulator (and macOS desktop), `localhost` works directly.
/// - On a real device you'll want to override this via `--dart-define` —
///   e.g. `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000`.
const _envBaseUrl = String.fromEnvironment('API_BASE_URL');

String _defaultBaseUrl() {
  if (kIsWeb) return 'http://localhost:8000';
  try {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  } catch (_) {
    // Platform isn't available (web fallback above) — ignore.
  }
  return 'http://localhost:8000';
}

final String apiBaseUrl = _envBaseUrl.isNotEmpty ? _envBaseUrl : _defaultBaseUrl();

const double kScreenPadding = 20;
const double kSpace4 = 16;
const double kSpace5 = 24;
const double kSpace6 = 32;
const double kSpace7 = 48;
const double kSpace8 = 64;
