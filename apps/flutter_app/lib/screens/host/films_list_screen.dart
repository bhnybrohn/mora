import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/providers.dart';
import '../../widgets/mora_photo.dart';
import '../../widgets/ui_atoms.dart';

/// Films dashboard — the host's home after auth. Shows the active film hero
/// + a list of past films. Backed by GET /events. Empty state for first
/// load (no films yet) drops the user straight into create-flow.
class FilmsListScreen extends ConsumerStatefulWidget {
  const FilmsListScreen({super.key});

  @override
  ConsumerState<FilmsListScreen> createState() => _FilmsListScreenState();
}

class _FilmsListScreenState extends ConsumerState<FilmsListScreen> {
  @override
  Widget build(BuildContext context) {
    final filmsAsync = ref.watch(myFilmsProvider);
    return Scaffold(
      backgroundColor: MoraColors.bgBase,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: MoraColors.accent,
              backgroundColor: MoraColors.bgElevated,
              onRefresh: () async {
                ref.invalidate(myFilmsProvider);
                await ref.read(myFilmsProvider.future);
              },
              child: filmsAsync.when(
                loading: () => _loading(context),
                error: (e, _) => _error(context, e),
                data: (films) => films.isEmpty ? _empty(context) : _list(context, films),
              ),
            ),

            // Floating "New film" FAB — pinned bottom-center
            Positioned(
              bottom: 32, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: MoraColors.accent.withValues(alpha: 0.32),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => context.push('/film-type'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MoraColors.accent,
                        foregroundColor: MoraColors.onAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 18, color: MoraColors.onAccent),
                          const SizedBox(width: 6),
                          Text(
                            'New film',
                            style: MoraText.body(
                              size: 14,
                              color: MoraColors.onAccent,
                              weight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── States ───

  Widget _loading(BuildContext context) {
    // Keep the chrome consistent so the layout doesn't jump when data arrives.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _Header(),
        const SizedBox(height: 80),
        const Center(child: CircularProgressIndicator(color: MoraColors.accent, strokeWidth: 2)),
      ],
    );
  }

  Widget _error(BuildContext context, Object err) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _Header(),
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, color: MoraColors.textTertiary, size: 36),
              const SizedBox(height: 14),
              Text(
                "Couldn't load your films.",
                textAlign: TextAlign.center,
                style: MoraText.body(size: 14, color: MoraColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.4),
              ),
              const SizedBox(height: 18),
              SecondaryButton(
                label: 'Try again',
                onTap: () => ref.invalidate(myFilmsProvider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _Header(),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
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
              Text('No films yet', style: MoraText.display(size: 24, italic: true)),
              const SizedBox(height: 6),
              Text(
                "Create your first one to start a roll. We'll generate a QR for guests to scan.",
                textAlign: TextAlign.center,
                style: MoraText.body(size: 14, color: MoraColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Create your first film',
                icon: const Icon(Icons.add_rounded, size: 18, color: MoraColors.onAccent),
                onTap: () => context.push('/film-type'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }

  Widget _list(BuildContext context, List<Event> films) {
    // Split active vs past so the dashboard has the editorial rhythm of
    // "what's happening now" then "what's already in the can".
    final active = films
        .where((f) => f.status == EventStatus.active || f.status == EventStatus.revealed)
        .toList();
    final firstActive = active.isNotEmpty ? active.first : null;
    final past = films.where((f) => f != firstActive).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: _Header()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        if (firstActive != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _SectionRule(
                label: firstActive.status == EventStatus.revealed ? 'LATEST' : 'ACTIVE NOW',
                color: MoraColors.accent,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ActiveFilmCard(film: firstActive),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
        if (past.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: const _SectionRule(label: 'PAST FILMS'),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _PastFilmRow(film: past[i]),
              ),
              childCount: past.length,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _SectionRule extends StatelessWidget {
  final String label;
  final Color? color;
  const _SectionRule({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: MoraText.label(color: color ?? MoraColors.textTertiary)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: MoraColors.borderSubtle)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FrameMark(size: 18, color: MoraColors.accent),
              const SizedBox(width: 8),
              const MoraMark(size: 20),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/settings'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: MoraColors.borderSubtle),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Icon(Icons.settings_outlined, size: 16, color: MoraColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Your films', style: MoraText.display(size: 36, hero: true)),
          const SizedBox(height: 6),
          Text(
            'A roll of every gathering you’ve hosted.',
            style: MoraText.body(size: 14, color: MoraColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActiveFilmCard extends StatelessWidget {
  final Event film;
  const _ActiveFilmCard({required this.film});

  @override
  Widget build(BuildContext context) {
    final seed = _seedFor(film.id);
    final fmt = _formatDate(film.startsAt);
    final isRevealed = film.status == EventStatus.revealed;
    return GestureDetector(
      onTap: () => context.push('/album', extra: film.id),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MoraColors.borderSubtle),
        ),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 5 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MoraPhoto(seed: seed, focalX: 50, focalY: 45),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0x000F0A06), Color(0xE60F0A06)],
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14, left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: (isRevealed ? MoraColors.positive : MoraColors.accent)
                              .withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: isRevealed ? MoraColors.positive : MoraColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isRevealed ? 'REVEALED' : 'LIVE',
                            style: MoraText.label(
                              color: isRevealed ? MoraColors.positive : MoraColors.accent,
                              size: 10,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(film.name, style: MoraText.display(size: 28, italic: true)),
                    const SizedBox(height: 6),
                    Text(
                      '${film.eventType.name.toUpperCase()} · $fmt',
                      style: MoraText.label(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _CounterPill(value: '${film.guestCount}', label: 'guests'),
                        const SizedBox(width: 8),
                        _CounterPill(value: '${film.photoCount}', label: 'frames'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  final String value;
  final String label;
  const _CounterPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x4D000000),
        border: Border.all(color: const Color(0x14F5EFE6)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value, style: MoraText.mono(size: 13, color: MoraColors.textPrimary, weight: FontWeight.w500)),
          const SizedBox(width: 4),
          Text(label, style: MoraText.body(size: 11, color: MoraColors.textSecondary, height: 1.2)),
        ],
      ),
    );
  }
}

class _PastFilmRow extends StatelessWidget {
  final Event film;
  const _PastFilmRow({required this.film});

  @override
  Widget build(BuildContext context) {
    final seed = _seedFor(film.id);
    return GestureDetector(
      onTap: () => context.push('/album', extra: film.id),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MoraColors.bgElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MoraColors.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56, height: 56,
                child: MoraPhoto(seed: seed),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(film.name, style: MoraText.display(size: 17, italic: true)),
                  const SizedBox(height: 3),
                  Text(
                    '${film.eventType.name} · ${_formatDate(film.startsAt)}',
                    style: MoraText.body(size: 11, color: MoraColors.textTertiary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${film.guestCount} guests · ${film.photoCount} frames',
                    style: MoraText.body(size: 12, color: MoraColors.textSecondary, height: 1.2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusBadge(status: film.status),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final EventStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (status) {
      case EventStatus.active:
        label = 'Live';
        color = MoraColors.accent;
      case EventStatus.revealed:
        label = 'Revealed';
        color = MoraColors.positive;
      case EventStatus.archived:
        label = 'Archived';
        color = MoraColors.textTertiary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label.toUpperCase(),
        style: MoraText.label(color: color, size: 9),
      ),
    );
  }
}

// ─── Small helpers ───

int _seedFor(String id) {
  // Deterministic seed so a given film always picks the same warm palette
  // for its hero photo placeholder. Hash a slice of the id for variety.
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0xFFFF;
  }
  return h;
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}
