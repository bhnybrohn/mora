/// MoraCamera — a thin Dart abstraction over the platform-specific camera
/// pipeline.
///
/// Why this exists: the Flutter `camera` package gives us middling quality,
/// a known front-camera mirroring quirk on Android, and patchy flash control.
/// On Android we drop down to CameraX through our own platform view (see
/// `android/.../camera/MoraCameraView.kt`). iOS still rides the `camera`
/// plugin until the AVFoundation port lands — both are hidden behind the same
/// [MoraCameraController] surface so the rest of the app doesn't care.
library;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Flash configuration. We mirror CameraX's modes since they're the richer
/// set; the iOS fallback maps `on`/`auto`/`off` onto its three modes.
enum MoraFlashMode { off, auto, on }

/// What the camera lens is currently looking at. We don't need more — Mora
/// is a disposable, not a pro shoot rig.
enum MoraLens { back, front }

/// Sticky configuration for the camera widget. The controller exposes
/// `init()` for the host to call once the widget mounts; methods are no-ops
/// (graceful fallbacks) when [isReady] is false.
class MoraCameraController extends ChangeNotifier {
  static const _channel = MethodChannel('mora/camera');

  MoraLens _lens;
  MoraFlashMode _flash = MoraFlashMode.off;
  int? _platformViewId; // set by the Android view when it's attached
  cam.CameraController? _ios; // iOS fallback only
  bool _ready = false;
  String? _error;

  // Zoom state — populated after the camera binds. min/max differ per lens
  // (front cameras typically don't zoom at all → both 1.0). Current is the
  // ratio currently applied; the pinch gesture writes through setZoom.
  double _zoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  MoraCameraController({MoraLens initialLens = MoraLens.back})
      : _lens = initialLens;

  // ─── State ──────────────────────────────────────────────────────────────

  MoraLens get lens => _lens;
  MoraFlashMode get flash => _flash;
  bool get isReady => _ready;
  String? get error => _error;

  /// Current zoom ratio applied to the camera (1.0 = no zoom). Drives the
  /// zoom pill in the camera UI.
  double get zoom => _zoom;
  /// Per-lens zoom limits, refreshed after each successful bind. Some front
  /// cameras report `min == max == 1.0` — the UI hides the zoom pill in
  /// that case so we don't show "1.0×" with no way to change it.
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  bool get canZoom => _maxZoom > _minZoom + 0.01;

  /// Whether we're using the Android native pipeline. iOS callers can branch
  /// on this if they want to render the fallback CameraPreview themselves.
  bool get isAndroidNative => !kIsWeb && Platform.isAndroid;

  // ─── Init / dispose ─────────────────────────────────────────────────────

  /// On Android this is implicit — the platform view init signals readiness
  /// via [_attachAndroid]. On iOS we still need to spin up a CameraController
  /// because the iOS native bridge isn't here yet.
  Future<void> init() async {
    if (isAndroidNative) return; // wait for platform view
    try {
      final cams = await cam.availableCameras();
      if (cams.isEmpty) {
        _error = 'No camera available';
        notifyListeners();
        return;
      }
      final c = cams.firstWhere(
        (d) => d.lensDirection == _ios0LensDir(_lens),
        orElse: () => cams.first,
      );
      _ios = cam.CameraController(
        c,
        cam.ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: cam.ImageFormatGroup.jpeg,
      );
      await _ios!.initialize();
      _ready = true;
      notifyListeners();
      // Same as the Android attach path — load zoom limits before the user
      // can pinch so the first gesture clamps correctly.
      unawaited(_refreshZoomState());
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_platformViewId != null) {
      // Tell the native side to release its CameraX use cases.
      _channel.invokeMethod('dispose', {'viewId': _platformViewId});
    }
    _ios?.dispose();
    super.dispose();
  }

  // ─── Android wiring (called by the widget) ──────────────────────────────

  void _attachAndroid(int viewId) {
    _platformViewId = viewId;
    _ready = true;
    notifyListeners();
    // Poll the zoom state with backoff. CameraX's ProcessCameraProvider
    // binds async after the platform view attaches, so the first
    // getZoomState often returns (min=1, max=1, current=1) — defaults
    // before the lens has been queried. We retry a few times until we
    // either see a real range or give up (front cameras genuinely report
    // 1..1 and that's fine — canZoom stays false and the UI hides the pill).
    unawaited(_loadInitialZoomState());
  }

  Future<void> _loadInitialZoomState() async {
    const backoffs = [
      Duration(milliseconds: 80),
      Duration(milliseconds: 240),
      Duration(milliseconds: 600),
      Duration(milliseconds: 1200),
    ];
    for (final wait in backoffs) {
      await Future<void>.delayed(wait);
      await _refreshZoomState();
      if (canZoom) return;
    }
  }

  // ─── Capture ────────────────────────────────────────────────────────────

  /// Take a still picture. Returns the on-disk path the platform wrote to.
  /// Throws on any underlying error so the caller can surface a SnackBar.
  Future<String> takePicture() async {
    if (isAndroidNative) {
      if (_platformViewId == null) throw StateError('Camera not attached yet');
      final path = await _channel.invokeMethod<String>(
        'takePicture',
        {'viewId': _platformViewId},
      );
      if (path == null) throw StateError('Native camera returned no path');
      return path;
    }
    final c = _ios;
    if (c == null || !c.value.isInitialized) {
      throw StateError('iOS camera not ready');
    }
    final shot = await c.takePicture();
    return shot.path;
  }

  // ─── Flash ──────────────────────────────────────────────────────────────

  Future<void> setFlashMode(MoraFlashMode mode) async {
    _flash = mode;
    notifyListeners();
    if (isAndroidNative) {
      // The platform view may not have mounted yet — store the mode locally
      // and bail; the native side adopts current state on first bind.
      if (_platformViewId == null) return;
      await _channel.invokeMethod('setFlashMode', {
        'viewId': _platformViewId,
        'mode': mode.name,
      });
    } else {
      await _ios?.setFlashMode(_ios0Flash(mode));
    }
  }

  /// Cycle off → auto → on → off. Wired to the top-bar flash pill.
  Future<void> cycleFlash() async {
    final next = switch (_flash) {
      MoraFlashMode.off => MoraFlashMode.auto,
      MoraFlashMode.auto => MoraFlashMode.on,
      MoraFlashMode.on => MoraFlashMode.off,
    };
    await setFlashMode(next);
  }

  // ─── Camera switch ──────────────────────────────────────────────────────

  Future<void> switchCamera() async {
    _lens = _lens == MoraLens.back ? MoraLens.front : MoraLens.back;
    // Reset zoom local state — the new lens will report its own limits.
    _zoom = 1.0;
    notifyListeners();
    if (isAndroidNative) {
      // If the AndroidView hasn't attached yet, just update local state.
      // The new lens will be applied when the platform view next binds.
      if (_platformViewId == null) return;
      await _channel.invokeMethod('switchCamera', {'viewId': _platformViewId});
      await _refreshZoomState();
    } else {
      // iOS fallback: tear down + re-init against the other camera.
      final old = _ios;
      _ios = null;
      _ready = false;
      notifyListeners();
      await old?.dispose();
      await init();
    }
  }

  // ─── Zoom ───────────────────────────────────────────────────────────────

  /// Apply a zoom ratio (1.0 = no zoom). The value is clamped server-side
  /// to [minZoom, maxZoom] for whichever lens is active; the actual applied
  /// ratio is read back and stored locally so the UI stays in sync even if
  /// the user pinched past the hardware limit.
  Future<void> setZoom(double ratio) async {
    if (isAndroidNative) {
      if (_platformViewId == null) return;
      final res = await _channel.invokeMethod<Map<Object?, Object?>>(
        'setZoom',
        {'viewId': _platformViewId, 'ratio': ratio},
      );
      if (res != null) _adoptZoomState(res);
    } else {
      final c = _ios;
      if (c == null) return;
      final clamped = ratio.clamp(_minZoom, _maxZoom);
      try {
        await c.setZoomLevel(clamped);
        _zoom = clamped;
        notifyListeners();
      } catch (_) {
        // setZoomLevel throws if the camera isn't ready or the level is out
        // of range — silent fallback so a fast pinch doesn't spam SnackBars.
      }
    }
  }

  /// Pull the platform's current zoom limits + current ratio. Called after
  /// every bind (initial mount + each camera switch) so the controller's
  /// view of [minZoom]/[maxZoom] stays accurate for the active lens.
  Future<void> _refreshZoomState() async {
    if (isAndroidNative) {
      if (_platformViewId == null) return;
      try {
        final res = await _channel.invokeMethod<Map<Object?, Object?>>(
          'getZoomState',
          {'viewId': _platformViewId},
        );
        if (res != null) _adoptZoomState(res);
      } catch (_) {
        // Not fatal — just leaves the previous values in place.
      }
    } else {
      final c = _ios;
      if (c == null) return;
      try {
        _minZoom = await c.getMinZoomLevel();
        _maxZoom = await c.getMaxZoomLevel();
        _zoom = _zoom.clamp(_minZoom, _maxZoom);
        notifyListeners();
      } catch (_) {
        // Older iOS / unsupported devices — leave defaults.
      }
    }
  }

  void _adoptZoomState(Map<Object?, Object?> res) {
    _minZoom = (res['min'] as num?)?.toDouble() ?? _minZoom;
    _maxZoom = (res['max'] as num?)?.toDouble() ?? _maxZoom;
    _zoom = (res['zoom'] as num?)?.toDouble() ?? _zoom;
    notifyListeners();
  }

  // ─── iOS fallback helpers ───────────────────────────────────────────────

  cam.CameraLensDirection _ios0LensDir(MoraLens lens) => lens == MoraLens.front
      ? cam.CameraLensDirection.front
      : cam.CameraLensDirection.back;

  cam.FlashMode _ios0Flash(MoraFlashMode mode) => switch (mode) {
        MoraFlashMode.off => cam.FlashMode.off,
        MoraFlashMode.auto => cam.FlashMode.auto,
        MoraFlashMode.on => cam.FlashMode.always,
      };

  /// Internal: iOS fallback CameraController for the preview widget.
  cam.CameraController? get iosController => _ios;
}

/// The actual on-screen preview. Drops into the camera screen as a fill
/// widget and routes preview to the platform-native pipeline on Android,
/// or the Flutter `camera` package preview on iOS.
class MoraCameraView extends StatelessWidget {
  final MoraCameraController controller;
  const MoraCameraView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.isAndroidNative) {
      return AndroidView(
        viewType: 'mora_camera_view',
        creationParams: {'lens': controller.lens.name},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) => controller._attachAndroid(id),
      );
    }
    final c = controller.iosController;
    if (c == null || !c.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return cam.CameraPreview(c);
  }
}
