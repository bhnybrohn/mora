import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../camera/mora_camera.dart';
import '../../config/theme.dart';
import '../../services/api_failure.dart';
import '../../services/providers.dart';
import '../../widgets/mora_photo.dart';

/// Everything the camera needs to push photos: the event it shoots into, the
/// guest token to authenticate uploads, and the labels/limits to render.
class CameraEntry {
  final String eventId;
  final String guestToken;
  final String filmName;
  final int totalFrames;
  final bool isHost;

  const CameraEntry({
    required this.eventId,
    required this.guestToken,
    required this.filmName,
    this.totalFrames = 24,
    this.isHost = false,
  });
}

/// Status of one shot in the upload queue, surfaced on the recent-strip
/// thumbnail so the user knows when a frame is actually safe.
enum _UploadState { uploading, uploaded, failed }

class _Capture {
  final String localPath;
  /// Compressed full-resolution bytes (max 2500px long edge, ~80% JPEG).
  final Uint8List bytes;
  /// Tiny preview bytes (240px long edge, WebP). Used by the recent strip
  /// and by the album for fast initial paint on slow networks.
  final Uint8List previewBytes;
  final int width;
  final int height;
  final DateTime takenAt;
  _UploadState state = _UploadState.uploading;
  String? error;

  _Capture({
    required this.localPath,
    required this.bytes,
    required this.previewBytes,
    required this.width,
    required this.height,
    required this.takenAt,
  });
}

class CameraScreen extends ConsumerStatefulWidget {
  final CameraEntry entry;
  const CameraScreen({super.key, required this.entry});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  late final MoraCameraController _camera;
  bool _shutter = false;
  bool _busy = false;
  final List<_Capture> _captured = [];

  // Pinch-to-zoom scratch state — _zoomAtScaleStart is the camera's zoom
  // ratio when the gesture began; on each update we multiply by the
  // gesture's relative scale to get the new target ratio.
  double _zoomAtScaleStart = 1.0;

  int get _remaining => widget.entry.totalFrames - _committedCount;
  int get _committedCount =>
      _captured.where((c) => c.state == _UploadState.uploaded).length +
      _captured.where((c) => c.state == _UploadState.uploading).length;

  @override
  void initState() {
    super.initState();
    _camera = MoraCameraController()..addListener(_onCameraChanged);
    _camera.init();
  }

  @override
  void dispose() {
    _camera.removeListener(_onCameraChanged);
    _camera.dispose();
    super.dispose();
  }

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  // ─── Actions ────────────────────────────────────────────────────────────

  Future<void> _shoot() async {
    if (_busy || _remaining <= 0) return;
    if (!_camera.isReady) return;

    setState(() {
      _busy = true;
      _shutter = true;
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _shutter = false);
    });

    try {
      final path = await _camera.takePicture();

      // Two-tier compression on the device before we ever hit the network.
      // - Full-res: 2500px long edge, 82% JPEG. Roughly 400-800 KB even from
      //   a 24 MP camera vs ~5-8 MB raw.
      // - Preview: 240px long edge, WebP. Roughly 10-30 KB for the recent
      //   strip + album-grid initial paint.
      final full = await FlutterImageCompress.compressWithFile(
            path,
            minWidth: 2500,
            minHeight: 2500,
            quality: 82,
            format: CompressFormat.jpeg,
            keepExif: false,
          ) ?? await File(path).readAsBytes();
      final preview = await FlutterImageCompress.compressWithFile(
            path,
            minWidth: 240,
            minHeight: 240,
            quality: 75,
            format: CompressFormat.webp,
            keepExif: false,
          ) ?? full;

      final fullBytes = Uint8List.fromList(full);
      final previewBytes = Uint8List.fromList(preview);
      final dims = await _decodeDimensions(fullBytes);

      final capture = _Capture(
        localPath: path,
        bytes: fullBytes,
        previewBytes: previewBytes,
        width: dims.width,
        height: dims.height,
        takenAt: DateTime.now(),
      );
      if (!mounted) return;
      setState(() => _captured.insert(0, capture));

      unawaited(_upload(capture));
    } catch (e) {
      if (!mounted) return;
      _showError("Couldn't capture: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload(_Capture capture) async {
    try {
      await ref.read(photosServiceProvider).uploadOne(
            eventId: widget.entry.eventId,
            guestToken: widget.entry.guestToken,
            bytes: capture.bytes,
            previewBytes: capture.previewBytes,
            width: capture.width,
            height: capture.height,
            mime: 'image/jpeg',
            ext: 'jpg',
            takenAt: capture.takenAt,
          );
      if (!mounted) return;
      setState(() => capture.state = _UploadState.uploaded);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        capture.state = _UploadState.failed;
        capture.error = e.message;
      });
      // Surface what actually went wrong. The recent-strip thumb turns red
      // either way, but a SnackBar means the user sees the reason: "Film
      // already developed" beats a silent failure.
      _showError(e.message, statusCode: e.statusCode);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        capture.state = _UploadState.failed;
        capture.error = e.toString();
      });
      _showError(e.toString());
    }
  }

  /// Show a SnackBar for an upload/capture failure. Includes the HTTP status
  /// when we have it so the operator can correlate with the API log line.
  void _showError(String message, {int? statusCode}) {
    if (!mounted) return;
    final tag = statusCode != null ? ' ($statusCode)' : '';
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: MoraColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 110),
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: MoraColors.negative),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Upload failed$tag: $message',
                style: MoraText.body(size: 13, color: MoraColors.textPrimary, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<({int width, int height})> _decodeDimensions(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    return (width: img.width, height: img.height);
  }

  /// What goes inside the contained viewfinder box. Three states:
  ///   - ready → mounted MoraCameraView (with iOS-only front-mirror Transform)
  ///   - hard error → warm MoraPhoto placeholder
  ///   - still initializing → tiny spinner
  Widget _buildViewfinder({required bool isFront}) {
    // On Android we mount the AndroidView unconditionally — its
    // onPlatformViewCreated is what flips the controller to isReady, so
    // refusing to mount until ready creates a chicken-and-egg.
    final shouldMount = _camera.isAndroidNative || _camera.isReady;
    if (shouldMount) {
      // CameraX auto-mirrors the front-camera preview; the Flutter `camera`
      // package (iOS fallback) does not. Apply the flip Transform only on
      // the iOS path so we don't double-flip on Android.
      final mirrorInFlutter = isFront && !_camera.isAndroidNative;
      return Transform(
        alignment: Alignment.center,
        transform: mirrorInFlutter
            ? Matrix4.diagonal3Values(-1.0, 1.0, 1.0)
            : Matrix4.identity(),
        child: MoraCameraView(controller: _camera),
      );
    }
    if (_camera.error != null) {
      return const MoraPhoto(seed: 99, focalX: 48, focalY: 60);
    }
    return const Center(
      child: SizedBox(
        width: 32, height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2, color: Color(0x66F5EFE6),
        ),
      ),
    );
  }

  // ─── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final remainingDisplay = _remaining < 0 ? 0 : _remaining;
    final hasUploading = _captured.any((c) => c.state == _UploadState.uploading);
    final isFront = _camera.lens == MoraLens.front;

    // Pixel-style camera layout. The preview fills almost the entire screen
    // (full-width, extending under the status bar) with chrome overlaid on
    // top. A compact dark bar at the bottom holds the shutter row + zoom
    // pill + status hint — no more contained polaroid feel, just a big
    // viewfinder and a controls strip beneath it.
    return Scaffold(
      backgroundColor: MoraColors.bgBase,
      body: Column(
        children: [
          // ─── Camera area — takes everything except the bottom bar ────
          Expanded(
            child: Stack(
              children: [
                // Full-bleed preview. CameraX's FILL_CENTER scaleType crops
                // the 4:3 sensor to fill the available space without
                // distortion, the way Pixel's camera does it.
                // Pinch gesture is bound to this whole area so the user can
                // zoom anywhere over the preview.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) {
                      _zoomAtScaleStart = _camera.zoom;
                    },
                    onScaleUpdate: (details) {
                      if (!_camera.canZoom) return;
                      final target = (_zoomAtScaleStart * details.scale)
                          .clamp(_camera.minZoom, _camera.maxZoom);
                      _camera.setZoom(target);
                    },
                    child: _buildViewfinder(isFront: isFront),
                  ),
                ),

                // Shutter flash, scoped to the camera area only (matches
                // Pixel and protects the bottom-bar widgets from blinking).
                if (_shutter)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(color: Color(0x8CF5EFE6)),
                    ),
                  ),

                // Top scrim — keeps the overlaid chrome readable against
                // bright outdoor scenes.
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 140,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Colors.transparent],
                      ),
                    ),
                  ),
                ),

                // Top chrome — film name pill on the left, flash + close on
                // the right. SafeArea so the row clears the status bar.
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Row(
                        children: [
                          _TopPill(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (entry.isHost) ...[
                                  const Icon(Icons.bolt_rounded, size: 12, color: MoraColors.accent),
                                  const SizedBox(width: 4),
                                ] else
                                  const Icon(Icons.movie_creation_outlined, size: 14, color: Color(0xEBF5EFE6)),
                                const SizedBox(width: 4),
                                Text(
                                  entry.filmName,
                                  style: MoraText.body(
                                    size: 12,
                                    color: const Color(0xEBF5EFE6),
                                    weight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _camera.cycleFlash(),
                            child: _TopPill(
                              bg: _camera.flash == MoraFlashMode.off
                                  ? Colors.black.withValues(alpha: 0.4)
                                  : MoraColors.accent,
                              child: _FlashIcon(mode: _camera.flash),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _closeCamera(hasUploading),
                            child: _TopPill(
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Color(0xEBF5EFE6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Zoom row — Pixel-style preset buttons (0.5×, 1×, 2×, 5×)
                // filtered by what the active lens supports. The active
                // preset is accent-highlighted and shows the live ratio
                // when the user pinches off-preset.
                if (_camera.canZoom)
                  Positioned(
                    left: 0, right: 0, bottom: 16,
                    child: Center(child: _ZoomRow(controller: _camera)),
                  ),
              ],
            ),
          ),

          // ─── Bottom control bar — compact, hugs the camera ───────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 76,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: MoraText.mono(size: 28, color: MoraColors.textPrimary, weight: FontWeight.w500),
                                children: [
                                  TextSpan(
                                    text: remainingDisplay.toString().padLeft(2, '0'),
                                    style: MoraText.mono(
                                      size: 28,
                                      color: remainingDisplay <= 3 ? MoraColors.accent : MoraColors.textPrimary,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '/${entry.totalFrames}',
                                    style: MoraText.mono(size: 28, color: MoraColors.textTertiary, weight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('FRAMES LEFT', style: MoraText.label(size: 9, color: const Color(0x80F5EFE6))),
                          ],
                        ),
                      ),

                      const Spacer(),

                      GestureDetector(
                        onTap: _shoot,
                        child: SizedBox(
                          width: 78, height: 78,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(BorderSide(color: Color(0xD9F5EFE6), width: 2)),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                curve: MoraEase.out,
                                width: _shutter ? 58 : 66,
                                height: _shutter ? 58 : 66,
                                decoration: const BoxDecoration(
                                  color: MoraColors.textPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      SizedBox(
                        width: 76,
                        height: 56,
                        child: _RecentStrip(
                          captured: _captured,
                          onFlip: () => _camera.switchCamera(),
                        ),
                      ),
                    ],
                  ),

                  if (hasUploading || _captured.any((c) => c.state == _UploadState.failed)) ...[
                    const SizedBox(height: 12),
                    _StatusHint(captured: _captured),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _closeCamera(bool hasUploading) {
    if (hasUploading) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: MoraColors.bgElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (sheetCtx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: MoraColors.borderEmphasis,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Text('Some frames are still uploading.',
                  style: MoraText.display(size: 20, italic: true)),
              const SizedBox(height: 8),
              Text(
                "We'll keep them queued in the background. Safe to close.",
                textAlign: TextAlign.center,
                style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    _exit();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MoraColors.accent,
                    foregroundColor: MoraColors.onAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: 0,
                  ),
                  child: Text('Close anyway',
                      style: MoraText.body(size: 15, color: MoraColors.onAccent, weight: FontWeight.w600, height: 1.2)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      _exit();
    }
  }

  void _exit() {
    final eventId = widget.entry.eventId;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/album', extra: eventId);
    }
  }
}

class _TopPill extends StatelessWidget {
  final Widget child;
  final Color? bg;
  const _TopPill({required this.child, this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg ?? Colors.black.withValues(alpha: 0.4),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: child,
    );
  }
}

class _FlashIcon extends StatelessWidget {
  final MoraFlashMode mode;
  const _FlashIcon({required this.mode});

  @override
  Widget build(BuildContext context) {
    final tint = mode == MoraFlashMode.off
        ? const Color(0xEBF5EFE6)
        : MoraColors.onAccent;
    final icon = switch (mode) {
      MoraFlashMode.off => Icons.flash_off_rounded,
      MoraFlashMode.auto => Icons.flash_auto_rounded,
      MoraFlashMode.on => Icons.flash_on_rounded,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: tint),
        if (mode == MoraFlashMode.auto) ...[
          const SizedBox(width: 4),
          Text('AUTO', style: MoraText.label(size: 9, color: tint)),
        ],
      ],
    );
  }
}

class _RecentStrip extends StatelessWidget {
  final List<_Capture> captured;
  final VoidCallback onFlip;
  const _RecentStrip({required this.captured, required this.onFlip});

  @override
  Widget build(BuildContext context) {
    if (captured.isEmpty) {
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: onFlip,
          child: Container(
            width: 50, height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x40F5EFE6)),
            ),
            child: const Icon(Icons.cameraswitch_rounded, size: 20, color: Color(0xB3F5EFE6)),
          ),
        ),
      );
    }
    return Stack(
      children: captured.take(3).toList().asMap().entries.map((e) {
        final c = e.value;
        return Positioned(
          right: e.key * 3.0,
          top: e.key * 3.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x66000000), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 6)),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Use the tiny preview here — decoding the full-res 2500px
                  // JPEG for a 50×50 thumb is wasteful and stutters the UI.
                  Image.memory(c.previewBytes, fit: BoxFit.cover, gaplessPlayback: true),
                  if (c.state == _UploadState.uploading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(MoraColors.accent),
                        ),
                      ),
                    )
                  else if (c.state == _UploadState.failed)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: const Icon(Icons.refresh_rounded, color: MoraColors.negative, size: 20),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Pixel-style preset zoom row. Renders 0.5× / 1× / 2× / 5× buttons,
/// filtered by what the active lens supports. The active preset is
/// accent-highlighted; when the user is pinched off-preset the active
/// button shows the live ratio ("2.3×") so the snapshot value is visible
/// without an extra readout. Tap any preset to jump to that ratio.
class _ZoomRow extends StatelessWidget {
  final MoraCameraController controller;
  const _ZoomRow({required this.controller});

  /// Standard preset ratios. We filter to what the lens reports so 5× isn't
  /// offered on a phone with 3× max, and 0.5× only shows on ultrawides.
  static const _allPresets = <double>[0.5, 1.0, 2.0, 5.0, 10.0];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final minZ = controller.minZoom;
        final maxZ = controller.maxZoom;
        final cur = controller.zoom;

        final presets = _allPresets
            .where((p) => p >= minZ - 0.01 && p <= maxZ + 0.01)
            .toList();
        // If the lens has zoom but none of our presets fit (eg a strange
        // 1.1..1.3 range), still surface 1× and the max so the user has
        // something to tap.
        if (presets.isEmpty) {
          presets.addAll([1.0, maxZ]);
        }

        // Active preset = closest to the current zoom value. The threshold
        // is generous so the highlight feels stable as the user pinches.
        double bestDelta = double.infinity;
        double activePreset = presets.first;
        for (final p in presets) {
          final d = (p - cur).abs();
          if (d < bestDelta) {
            bestDelta = d;
            activePreset = p;
          }
        }

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            border: Border.all(color: const Color(0x1FFFFFFF)),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in presets)
                _ZoomPresetButton(
                  preset: p,
                  active: p == activePreset,
                  // When highlighting the active preset, show the actual
                  // current zoom instead of the preset label so a 2.3×
                  // pinch reads as "2.3×" not "2×".
                  liveValue: p == activePreset ? cur : null,
                  onTap: () => controller.setZoom(p),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ZoomPresetButton extends StatelessWidget {
  final double preset;
  final bool active;
  final double? liveValue;
  final VoidCallback onTap;

  const _ZoomPresetButton({
    required this.preset,
    required this.active,
    required this.liveValue,
    required this.onTap,
  });

  String _labelFor(double v) {
    // 0.5×, 1×, 2.3× — drop trailing ".0" so common values stay crisp.
    if (v >= 10) return '${v.round()}×';
    if (v == v.roundToDouble()) return '${v.toInt()}×';
    return '${v.toStringAsFixed(1)}×';
  }

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(liveValue ?? preset);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: MoraEase.out,
        constraints: const BoxConstraints(minWidth: 38),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? MoraColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: MoraText.mono(
            size: 12,
            color: active ? MoraColors.onAccent : const Color(0xCCF5EFE6),
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatusHint extends StatelessWidget {
  final List<_Capture> captured;
  const _StatusHint({required this.captured});

  @override
  Widget build(BuildContext context) {
    final uploading = captured.where((c) => c.state == _UploadState.uploading).length;
    final failed = captured.where((c) => c.state == _UploadState.failed).length;

    final segments = <String>[];
    if (uploading > 0) segments.add('$uploading uploading');
    if (failed > 0) segments.add('$failed failed');
    if (segments.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        segments.join(' · '),
        style: MoraText.body(size: 11, color: const Color(0xD9F5EFE6), height: 1.2),
      ),
    );
  }
}
