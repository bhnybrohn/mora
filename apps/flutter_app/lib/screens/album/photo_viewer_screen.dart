import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../services/api_failure.dart';
import '../../services/events_service.dart';
import '../../services/providers.dart';

/// Fullscreen single-photo viewer. Swipe left/right to page through the
/// album. The host can delete from the trailing action.
class PhotoViewerArgs {
  final List<AlbumPhoto> photos;
  final int initialIndex;
  final String eventId;
  const PhotoViewerArgs({required this.photos, required this.initialIndex, required this.eventId});
}

class PhotoViewerScreen extends ConsumerStatefulWidget {
  final PhotoViewerArgs args;
  const PhotoViewerScreen({super.key, required this.args});

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late PageController _controller;
  late List<AlbumPhoto> _photos;
  late int _index;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.args.photos);
    _index = widget.args.initialIndex.clamp(0, _photos.isEmpty ? 0 : _photos.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting || _photos.isEmpty) return;
    final current = _photos[_index];

    // Confirm in a bottom sheet so an accidental tap doesn't lose a frame.
    final confirm = await showModalBottomSheet<bool>(
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
            Text(
              'Remove this frame?',
              style: MoraText.display(size: 22, italic: true),
            ),
            const SizedBox(height: 8),
            Text(
              "It disappears from the album. The original on the guest's phone is unaffected.",
              textAlign: TextAlign.center,
              style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MoraColors.negative,
                  foregroundColor: const Color(0xFFFFF6F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 0,
                ),
                child: Text(
                  'Remove frame',
                  style: MoraText.body(size: 15, color: const Color(0xFFFFF6F2), weight: FontWeight.w600, height: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(sheetCtx).pop(false),
              child: Text('Cancel', style: MoraText.body(size: 14, color: MoraColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting = true);
    try {
      // The events service doesn't have a host-delete helper yet; call the
      // raw API path directly through the shared client.
      final api = ref.read(apiClientProvider);
      await api.delete('/events/${widget.args.eventId}/photos/${current.id}/by-host');

      if (!mounted) return;
      setState(() {
        _photos.removeAt(_index);
        if (_index >= _photos.length) _index = (_photos.length - 1).clamp(0, 0).toInt();
        _deleting = false;
      });

      // No photos left → bounce back to the album.
      if (_photos.isEmpty) {
        if (context.canPop()) context.pop();
        return;
      }

      // Re-seat the page controller on the new current index.
      _controller.jumpToPage(_index);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      final f = ApiFailure.fromDio(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't remove: ${f.message}")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't remove: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Pure black here is correct — fullscreen viewer is the one place the
      // design system explicitly allows it (DESIGN.md §5).
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (ctx, i) {
              final p = _photos[i];
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    p.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 32, height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0x66F5EFE6),
                        ),
                      );
                    },
                    errorBuilder: (ctx, _, _) => const Icon(
                      Icons.broken_image_outlined, size: 36, color: Color(0x66F5EFE6),
                    ),
                  ),
                ),
              );
            },
          ),

          // Top chrome — back, attribution, delete
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  _ChromeButton(
                    icon: Icons.close_rounded,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  if (_photos.isNotEmpty) ...[
                    Text(
                      '${_index + 1} / ${_photos.length}',
                      style: MoraText.mono(size: 12, color: const Color(0xCCF5EFE6)),
                    ),
                    const SizedBox(width: 12),
                  ],
                  _ChromeButton(
                    icon: _deleting ? Icons.hourglass_top_rounded : Icons.delete_outline_rounded,
                    onTap: _deleting ? () {} : _delete,
                  ),
                ],
              ),
            ),
          ),

          // Bottom attribution
          if (_photos.isNotEmpty)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _photos[_index].guestName ?? 'Unknown',
                              style: MoraText.display(size: 16, italic: true),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTaken(_photos[_index].takenAt),
                              style: MoraText.mono(size: 11, color: MoraColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ChromeButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Icon(icon, size: 18, color: const Color(0xEBF5EFE6)),
      ),
    );
  }
}

String _formatTaken(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day} · $h12:$mm $ampm';
}
