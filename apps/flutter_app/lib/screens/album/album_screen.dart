import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/events_service.dart';
import '../../services/providers.dart';
import '../../services/sponsors_service.dart' show Sponsor;
import '../../widgets/mora_photo.dart';
import '../../widgets/ui_atoms.dart';
import '../guest/camera_screen.dart' show CameraEntry;
import 'photo_viewer_screen.dart' show PhotoViewerArgs;

class AlbumScreen extends ConsumerWidget {
  final String eventId;
  const AlbumScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(_eventByIdProvider(eventId));
    final albumAsync = ref.watch(_albumProvider(eventId));

    return Scaffold(
      backgroundColor: MoraColors.bgBase,
      body: eventAsync.when(
        loading: () => const _Splash(),
        error: (e, _) => _Error(message: e.toString(), onRetry: () {
          ref.invalidate(_eventByIdProvider(eventId));
        }),
        data: (event) => albumAsync.when(
          loading: () => _Skeleton(event: event),
          error: (e, _) => _Error(message: e.toString(), onRetry: () {
            ref.invalidate(_albumProvider(eventId));
          }),
          data: (photos) => _AlbumView(event: event, photos: photos, ref: ref),
        ),
      ),
    );
  }
}

class _AlbumView extends StatefulWidget {
  final Event event;
  final List<AlbumPhoto> photos;
  final WidgetRef ref;
  const _AlbumView({required this.event, required this.photos, required this.ref});

  @override
  State<_AlbumView> createState() => _AlbumViewState();
}

class _AlbumViewState extends State<_AlbumView> {
  String _tab = 'all';

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final photos = widget.photos;
    final heroSeed = photos.isNotEmpty ? _seedForKey(photos.first.id) : _seedForKey(event.id);

    return Stack(
      children: [
        RefreshIndicator(
          color: MoraColors.accent,
          backgroundColor: MoraColors.bgElevated,
          onRefresh: () async {
            widget.ref.invalidate(_albumProvider(event.id));
            await widget.ref.read(_albumProvider(event.id).future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Hero — magazine masthead
              SliverAppBar(
                expandedHeight: 320,
                pinned: false,
                backgroundColor: MoraColors.bgBase,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      Positioned.fill(child: MoraPhoto(seed: heroSeed, focalX: 50, focalY: 45)),
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x8C0F0A06), Color(0x1A0F0A06), Color(0xF20F0A06)],
                              stops: [0.0, 0.35, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 56, left: 16, right: 16,
                        child: Row(
                          children: [
                            _CircleButton(
                              icon: Icons.chevron_left,
                              onTap: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/films');
                                }
                              },
                            ),
                            const Spacer(),
                            _CircleButton(
                              icon: Icons.ios_share,
                              onTap: () => context.push('/qr-share', extra: event.id),
                            ),
                            const SizedBox(width: 8),
                            _AlbumActionsMenu(eventId: event.id),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0, right: 0, bottom: 16,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'VOL. 01 · ${event.eventType.name.toUpperCase()}'
                                        '${event.location.trim().isEmpty ? '' : ' · ${event.location.trim().toUpperCase()}'}',
                                    style: MoraText.mono(
                                      size: 10,
                                      color: MoraColors.accent,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(height: 1, color: MoraColors.accent.withValues(alpha: 0.35)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _romanDate(event.startsAt),
                                    style: MoraText.mono(
                                      size: 10,
                                      color: MoraColors.accent,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                event.name,
                                style: MoraText.display(size: 42, italic: true, hero: true),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.people_outline_rounded, size: 14, color: MoraColors.textTertiary),
                                  const SizedBox(width: 6),
                                  Text('${event.guestCount} guests',
                                      style: MoraText.body(size: 13, color: MoraColors.textSecondary)),
                                  Text(' · ', style: MoraText.body(size: 13, color: MoraColors.textDisabled)),
                                  Text('${photos.length} frames',
                                      style: MoraText.body(size: 13, color: MoraColors.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tabs
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabsDelegate(
                  tab: _tab,
                  eventId: event.id,
                  onTabChanged: (t) => setState(() => _tab = t),
                ),
              ),

              if (photos.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyAlbum(eventId: event.id),
                )
              else if (_tab == 'all')
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    childAspectRatio: 1 / 1.18,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      // Drop one SponsoredFrame at index 6 if we have enough
                      // photos for it to feel like an insert rather than a
                      // banner under sparse content.
                      if (photos.length >= 7 && i == 6) return const SponsoredFrame();
                      final idx = (photos.length >= 7 && i > 6) ? i - 1 : i;
                      if (idx >= photos.length) return const SizedBox.shrink();
                      return _AlbumTile(
                        photo: photos[idx],
                        onTap: () => _openViewer(context, event.id, photos, idx),
                      );
                    },
                    childCount: photos.length + (photos.length >= 7 ? 1 : 0),
                  ),
                )
              else if (_tab == 'guest')
                SliverToBoxAdapter(child: _AlbumByGuest(photos: photos))
              else
                SliverToBoxAdapter(child: _AlbumByTime(photos: photos)),

              SliverToBoxAdapter(
                child: _RealMadePossibleBy(eventId: event.id),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),

        // Floating actions — always show "Take a photo" for the host (they
        // can also contribute to their own film), then either Develop now
        // (pre-reveal) or Download all (post-reveal) as the primary action.
        Positioned(
          bottom: 32, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SecondaryFAB(
                label: 'Take a photo',
                icon: Icons.camera_alt_outlined,
                onTap: () => _openHostCamera(context, widget.ref, event),
              ),
              const SizedBox(width: 10),
              if (event.status != EventStatus.revealed)
                _PrimaryFAB(
                  label: 'Develop',
                  icon: Icons.auto_awesome_rounded,
                  onTap: () => _revealNow(context, widget.ref, event.id),
                )
              else
                _PrimaryFAB(
                  label: 'Download',
                  icon: Icons.download_rounded,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download arrives on paid tiers')),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _revealNow(BuildContext context, WidgetRef ref, String eventId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(eventsServiceProvider).reveal(eventId);
      ref.invalidate(_eventByIdProvider(eventId));
      ref.invalidate(myFilmsProvider);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Film developed.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Reveal failed: $e')));
    }
  }

  void _openViewer(BuildContext context, String eventId, List<AlbumPhoto> photos, int index) {
    context.push(
      '/photo-viewer',
      extra: PhotoViewerArgs(photos: photos, initialIndex: index, eventId: eventId),
    );
  }

  Future<void> _openHostCamera(BuildContext context, WidgetRef ref, Event event) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final grant = await ref.read(eventsServiceProvider).hostCamera(event.id);
      // Refresh the album when we come back so the new photo shows up.
      router.push(
        '/camera',
        extra: CameraEntry(
          eventId: event.id,
          guestToken: grant.token,
          filmName: event.name,
          totalFrames: 96, // hosts aren't capped like guests — generous default
          isHost: true,
        ),
      );
      // Listen for the route to pop and refresh
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Will refresh on the next frame the album becomes visible.
        ref.invalidate(_albumProvider(event.id));
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text("Couldn't open camera: $e")));
    }
  }
}

// ─── Tiles & viewers ────────────────────────────────────────────────────────

class _AlbumTile extends StatelessWidget {
  final AlbumPhoto photo;
  final VoidCallback? onTap;
  const _AlbumTile({required this.photo, this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      photo.previewUrl,
      fit: BoxFit.cover,
      // Fall back to a warm placeholder while the preview loads (or if it 404s).
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return MoraPhoto(seed: _seedForKey(photo.id));
      },
      errorBuilder: (ctx, _, _) => MoraPhoto(seed: _seedForKey(photo.id)),
    );
    if (onTap == null) return image;
    return GestureDetector(onTap: onTap, child: image);
  }
}

class _AlbumByGuest extends StatelessWidget {
  final List<AlbumPhoto> photos;
  const _AlbumByGuest({required this.photos});

  @override
  Widget build(BuildContext context) {
    // Group photos by guest name (or "Host" for null) preserving first-seen order.
    final groups = <String, List<AlbumPhoto>>{};
    for (final p in photos) {
      final key = p.guestName ?? 'Host';
      groups.putIfAbsent(key, () => []).add(p);
    }

    return Column(
      children: groups.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: MoraText.display(size: 18)),
                  Text('${entry.value.length} frames',
                      style: MoraText.body(size: 12, color: MoraColors.textTertiary)),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1,
                children: entry.value.map((p) => _AlbumTile(photo: p)).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AlbumByTime extends StatelessWidget {
  final List<AlbumPhoto> photos;
  const _AlbumByTime({required this.photos});

  @override
  Widget build(BuildContext context) {
    // Bucket by the hour the photo was taken — gives the album a natural arc.
    final buckets = <int, List<AlbumPhoto>>{};
    for (final p in photos) {
      final h = p.takenAt.hour;
      buckets.putIfAbsent(h, () => []).add(p);
    }
    final sorted = buckets.keys.toList()..sort();

    return Column(
      children: sorted.map((hour) {
        final list = buckets[hour]!;
        final label = '${hour % 12 == 0 ? 12 : hour % 12}:00 ${hour < 12 ? 'AM' : 'PM'}';
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: MoraText.display(size: 18)),
                  Text('${list.length} frames',
                      style: MoraText.mono(size: 11, color: MoraColors.textTertiary)),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1,
                children: list.map((p) => _AlbumTile(photo: p)).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Empty / loading / error ────────────────────────────────────────────────

class _EmptyAlbum extends StatelessWidget {
  final String eventId;
  const _EmptyAlbum({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MoraColors.borderSubtle),
            ),
            child: const FrameMark(size: 28, color: MoraColors.accent),
          ),
          const SizedBox(height: 18),
          Text('Empty so far', style: MoraText.display(size: 22, italic: true)),
          const SizedBox(height: 6),
          Text(
            'Share the QR code with your guests. Frames will land here as the day unfolds.',
            textAlign: TextAlign.center,
            style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          SecondaryButton(
            label: 'Share QR',
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            onTap: () => context.push('/qr-share', extra: eventId),
          ),
        ],
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: MoraColors.accent, strokeWidth: 2),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final Event event;
  const _Skeleton({required this.event});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 60),
        Text(event.name, style: MoraText.display(size: 26, italic: true)),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: MoraColors.accent, strokeWidth: 2),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: MoraColors.textTertiary, size: 36),
          const SizedBox(height: 14),
          Text("Couldn't load this album.",
              style: MoraText.body(size: 14, color: MoraColors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.4),
          ),
          const SizedBox(height: 18),
          SecondaryButton(label: 'Try again', onTap: onRetry),
        ],
      ),
    );
  }
}

// ─── Chrome ─────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Icon(icon, size: 18, color: const Color(0xEBF5EFE6)),
      ),
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  final String tab;
  final String eventId;
  final ValueChanged<String> onTabChanged;
  _TabsDelegate({required this.tab, required this.eventId, required this.onTabChanged});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: MoraColors.bgBase,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          _TabChip(label: 'All', selected: tab == 'all', onTap: () => onTabChanged('all')),
          const SizedBox(width: 6),
          _TabChip(label: 'By guest', selected: tab == 'guest', onTap: () => onTabChanged('guest')),
          const SizedBox(width: 6),
          _TabChip(label: 'By time', selected: tab == 'time', onTap: () => onTabChanged('time')),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/films/$eventId/sponsors'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: MoraColors.borderSubtle),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Icon(Icons.diamond_outlined, size: 16, color: MoraColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 56;
  @override
  double get minExtent => 56;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: MoraEase.out,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MoraColors.bgOverlay : Colors.transparent,
          border: Border.all(color: selected ? MoraColors.borderEmphasis : MoraColors.borderSubtle),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: MoraText.body(
            size: 13,
            color: selected ? MoraColors.textPrimary : MoraColors.textSecondary,
            weight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SecondaryFAB extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SecondaryFAB({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: const Color(0xEBF5EFE6)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: MoraText.body(
                    size: 14,
                    color: const Color(0xEBF5EFE6),
                    weight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryFAB extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryFAB({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: MoraColors.accent.withValues(alpha: 0.32),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: MoraColors.accent,
          foregroundColor: MoraColors.onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: MoraColors.onAccent),
            const SizedBox(width: 8),
            Text(
              label,
              style: MoraText.body(size: 14, color: MoraColors.onAccent, weight: FontWeight.w600, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

int _seedForKey(String key) {
  var h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0xFFFF;
  }
  return h;
}

String _romanDate(DateTime d) {
  const romans = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'];
  final yy = (d.year % 100).toString().padLeft(2, '0');
  return '${d.day} · ${romans[d.month - 1]} · $yy';
}

// ─── Album overflow menu ───────────────────────────────────────────────────

class _AlbumActionsMenu extends StatelessWidget {
  final String eventId;
  const _AlbumActionsMenu({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      color: MoraColors.bgElevated,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: MoraColors.borderSubtle),
      ),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          border: Border.all(color: const Color(0x1AFFFFFF)),
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xEBF5EFE6)),
      ),
      onSelected: (v) {
        switch (v) {
          case 'guests':
            context.push('/films/$eventId/guests');
          case 'sponsors':
            context.push('/films/$eventId/sponsors');
          case 'diaspora':
            context.push('/films/$eventId/diaspora');
          case 'edit':
            context.push('/films/$eventId/edit');
        }
      },
      itemBuilder: (ctx) => [
        _menuItem('guests', Icons.people_outline_rounded, 'Guests'),
        _menuItem('sponsors', Icons.diamond_outlined, 'Sponsors'),
        _menuItem('diaspora', Icons.public_rounded, 'Diaspora link'),
        _menuItem('edit', Icons.edit_outlined, 'Edit film'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: MoraColors.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: MoraText.body(size: 14, height: 1.2)),
        ],
      ),
    );
  }
}

// ─── Real-sponsor renderer ────────────────────────────────────────────────

/// Album-foot "Made possible by" wired to the real sponsor list. Falls back
/// to a quiet "no sponsors yet" line that the host can tap to add some.
class _RealMadePossibleBy extends ConsumerWidget {
  final String eventId;
  const _RealMadePossibleBy({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sponsorsForEventProvider(eventId));
    return async.when(
      loading: () => const SizedBox(height: 40),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x06F5EFE6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MoraColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.diamond_outlined, size: 18, color: MoraColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Credit your vendors', style: MoraText.body(size: 14, weight: FontWeight.w500, height: 1.2)),
                        const SizedBox(height: 2),
                        Text(
                          'They appear here in the album foot. A small fee comes back when guests book through.',
                          style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.push('/films/$eventId/sponsors'),
                    child: Text('Add',
                        style: MoraText.body(size: 13, color: MoraColors.accent, weight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          );
        }

        final featured = list.firstWhere(
          (s) => s.isFeatured,
          orElse: () => list.first,
        );

        return Column(
          children: [
            // One featured sponsor becomes a magazine-style IssueInsert if
            // they have either a tagline or a link — gives the placement
            // editorial weight rather than just a bigger banner.
            if (featured.tagline != null || featured.link != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _IssueInsertForSponsor(sponsor: featured),
              ),

            // The full grid.
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: MoraColors.borderSubtle)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('MADE POSSIBLE BY', style: MoraText.label(color: MoraColors.accent)),
                      const SizedBox(width: 10),
                      Expanded(child: Container(height: 1, color: MoraColors.borderSubtle)),
                      const SizedBox(width: 8),
                      _SponsoredMarkInline(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3.5,
                    children: list.map((s) => _VendorCard(sponsor: s)).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Vendors the host tagged. Mora earns a small fee when guests book through these credits.',
                    textAlign: TextAlign.center,
                    style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VendorCard extends StatelessWidget {
  final Sponsor sponsor;
  const _VendorCard({required this.sponsor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MoraColors.bgElevated,
        border: Border.all(color: MoraColors.borderSubtle),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 40, height: 40,
              child: sponsor.logoUrl != null && sponsor.logoUrl!.isNotEmpty
                  ? Image.network(
                      sponsor.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, _, _) => _swatch(sponsor),
                    )
                  : _swatch(sponsor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sponsor.name,
                  overflow: TextOverflow.ellipsis,
                  style: MoraText.body(size: 12, color: MoraColors.textPrimary, weight: FontWeight.w500, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(sponsor.role.toUpperCase(), style: MoraText.label(size: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _swatch(Sponsor s) {
    if (s.palette.length < 3) return Container(color: MoraColors.bgOverlay);
    return AsoebiSwatch(palette: s.palette);
  }
}

/// Sponsor-driven IssueInsert. Reuses the design's masthead/insert chrome
/// but with real sponsor data instead of hardcoded Folake Adisa.
class _IssueInsertForSponsor extends StatelessWidget {
  final Sponsor sponsor;
  const _IssueInsertForSponsor({required this.sponsor});

  @override
  Widget build(BuildContext context) {
    final palette = sponsor.palette.length == 3
        ? sponsor.palette
        : const [Color(0xFF3A1418), Color(0xFFD4A857), Color(0xFF7A3025)];
    return Container(
      decoration: BoxDecoration(
        color: MoraColors.bgElevated,
        border: Border.all(color: MoraColors.borderSubtle),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                // If a logo exists, render that as the hero; otherwise fall
                // back to the asoebi swatch.
                Positioned.fill(
                  child: sponsor.logoUrl != null && sponsor.logoUrl!.isNotEmpty
                      ? Image.network(
                          sponsor.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, _) => AsoebiSwatch(palette: palette),
                        )
                      : AsoebiSwatch(palette: palette),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-0.4, 0), end: Alignment(0.6, 0),
                        colors: [Color(0x8C0F0A06), Color(0x0D0F0A06)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12, left: 14, right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INSERT · ${sponsor.role.toUpperCase()}',
                        style: MoraText.mono(
                          size: 9,
                          color: Colors.white.withValues(alpha: 0.55),
                          letterSpacing: 1.44,
                        ),
                      ),
                      _SponsoredMarkInline(),
                    ],
                  ),
                ),
                Positioned(
                  left: 14, right: 14, bottom: 14,
                  child: Text(
                    sponsor.tagline ?? sponsor.name,
                    style: MoraText.display(size: 20, italic: true),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sponsor.name, style: MoraText.body(size: 12, weight: FontWeight.w500, height: 1.2)),
                      if (sponsor.tagline != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sponsor.tagline!,
                          overflow: TextOverflow.ellipsis,
                          style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
                if (sponsor.link != null && sponsor.link!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(color: MoraColors.borderEmphasis),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Visit', style: MoraText.body(size: 12, weight: FontWeight.w500, height: 1.2)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_outward_rounded, size: 12, color: MoraColors.textPrimary),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Sponsored" pill used in two places.
class _SponsoredMarkInline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 4, height: 4, color: MoraColors.accent),
          const SizedBox(width: 6),
          Text(
            'SPONSORED',
            style: MoraText.label(size: 9, color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

// ─── Providers ──────────────────────────────────────────────────────────────

final _eventByIdProvider = FutureProvider.family.autoDispose<Event, String>((ref, id) {
  return ref.watch(eventsServiceProvider).get(id);
});

final _albumProvider = FutureProvider.family.autoDispose<List<AlbumPhoto>, String>((ref, id) {
  return ref.watch(eventsServiceProvider).album(id);
});
