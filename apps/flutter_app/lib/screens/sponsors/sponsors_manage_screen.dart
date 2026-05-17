import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../services/providers.dart';
import '../../services/sponsors_service.dart';
import '../../widgets/ui_atoms.dart';

/// Host-side sponsor list for a single film. Tap a row to edit, swipe-style
/// delete via a row trailing action. New ones come in via the bottom CTA.
class SponsorsManageScreen extends ConsumerWidget {
  final String eventId;
  const SponsorsManageScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sponsorsAsync = ref.watch(sponsorsForEventProvider(eventId));

    return Scaffold(
      backgroundColor: MoraColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Editorial header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.chevron_left, size: 22, color: MoraColors.textSecondary),
                    ),
                  ),
                  const Spacer(),
                  Text('SPONSORS', style: MoraText.label(size: 10)),
                  const Spacer(),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: MoraText.display(size: 30),
                      children: [
                        const TextSpan(text: 'Made '),
                        TextSpan(text: 'possible', style: MoraText.display(size: 30, italic: true)),
                        const TextSpan(text: ' by.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tag the vendors who helped make the day happen. They appear in the album foot — and unlock a small fee back to you when guests book through.',
                    style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),

            Expanded(
              child: sponsorsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: MoraColors.accent, strokeWidth: 2),
                ),
                error: (e, _) => _Error(message: e.toString(), onRetry: () {
                  ref.invalidate(sponsorsForEventProvider(eventId));
                }),
                data: (list) => list.isEmpty
                    ? _Empty(onAdd: () => _openAdd(context))
                    : RefreshIndicator(
                        color: MoraColors.accent,
                        backgroundColor: MoraColors.bgElevated,
                        onRefresh: () async {
                          ref.invalidate(sponsorsForEventProvider(eventId));
                          await ref.read(sponsorsForEventProvider(eventId).future);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) => _SponsorRow(
                            sponsor: list[i],
                            onTap: () => _openAdd(context, existing: list[i]),
                            onDelete: () => _confirmDelete(context, ref, list[i]),
                          ),
                        ),
                      ),
              ),
            ),

            BottomAction(
              children: [
                PrimaryButton(
                  label: 'Add a sponsor',
                  icon: const Icon(Icons.add_rounded, size: 18, color: MoraColors.onAccent),
                  onTap: () => _openAdd(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openAdd(BuildContext context, {Sponsor? existing}) {
    context.push('/films/$eventId/sponsors/new', extra: existing);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Sponsor sponsor) async {
    final messenger = ScaffoldMessenger.of(context);
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
            Text('Remove ${sponsor.name}?', style: MoraText.display(size: 20, italic: true)),
            const SizedBox(height: 8),
            Text(
              "They'll disappear from the album. You can add them back later.",
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
                  'Remove sponsor',
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
    try {
      await ref.read(sponsorsServiceProvider).delete(eventId: eventId, sponsorId: sponsor.id);
      ref.invalidate(sponsorsForEventProvider(eventId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't remove: $e")));
    }
  }
}

class _SponsorRow extends StatelessWidget {
  final Sponsor sponsor;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _SponsorRow({required this.sponsor, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MoraColors.bgElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MoraColors.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo if present, else asoebi swatch — same visual language as
              // the MadePossibleBy block in the album.
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48, height: 48,
                  child: _SponsorAvatar(sponsor: sponsor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            sponsor.name,
                            overflow: TextOverflow.ellipsis,
                            style: MoraText.display(size: 17, italic: true),
                          ),
                        ),
                        if (sponsor.isFeatured) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded, size: 14, color: MoraColors.accent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(sponsor.role.toUpperCase(), style: MoraText.label()),
                    if (sponsor.tagline != null && sponsor.tagline!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        sponsor.tagline!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MoraText.body(size: 12, color: MoraColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: MoraColors.textTertiary),
                tooltip: 'Remove',
                splashRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SponsorAvatar extends StatelessWidget {
  final Sponsor sponsor;
  const _SponsorAvatar({required this.sponsor});

  @override
  Widget build(BuildContext context) {
    if (sponsor.logoUrl != null && sponsor.logoUrl!.isNotEmpty) {
      return Image.network(
        sponsor.logoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (ctx, _, _) => _swatch(),
      );
    }
    return _swatch();
  }

  Widget _swatch() {
    if (sponsor.palette.length < 3) {
      return Container(color: MoraColors.bgOverlay);
    }
    return AsoebiSwatch(palette: sponsor.palette);
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 120),
      children: [
        Column(
          children: [
            Container(
              width: 64, height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: MoraColors.borderSubtle),
              ),
              child: const Icon(Icons.diamond_outlined, size: 28, color: MoraColors.accent),
            ),
            const SizedBox(height: 18),
            Text('No sponsors yet', style: MoraText.display(size: 22, italic: true)),
            const SizedBox(height: 6),
            Text(
              'Tag the people who made the day. Aso oke, catering, photography, venue — credit them all in the album.',
              textAlign: TextAlign.center,
              style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
            ),
          ],
        ),
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
          Text("Couldn't load sponsors.",
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
