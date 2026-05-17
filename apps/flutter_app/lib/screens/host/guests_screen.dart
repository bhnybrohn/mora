import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../services/guests_service.dart';
import '../../services/providers.dart';
import '../../widgets/ui_atoms.dart';

/// Host's guest roster for a single film. Tap a row for a sheet that lets
/// the host kick. Hosts themselves are pinned at the top with a HOST badge
/// and can't be kicked.
class GuestsScreen extends ConsumerWidget {
  final String eventId;
  const GuestsScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestsAsync = ref.watch(guestsForEventProvider(eventId));

    return Scaffold(
      backgroundColor: MoraColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
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
                  Text('GUESTS', style: MoraText.label(size: 10)),
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
                        const TextSpan(text: 'Who joined the '),
                        TextSpan(text: 'film', style: MoraText.display(size: 30, italic: true)),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a guest to see what they contributed or remove them from the film.',
                    style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
            Expanded(
              child: guestsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: MoraColors.accent, strokeWidth: 2),
                ),
                error: (e, _) => _Error(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(guestsForEventProvider(eventId)),
                ),
                data: (guests) => guests.isEmpty
                    ? _Empty(eventId: eventId)
                    : RefreshIndicator(
                        color: MoraColors.accent,
                        backgroundColor: MoraColors.bgElevated,
                        onRefresh: () async {
                          ref.invalidate(guestsForEventProvider(eventId));
                          await ref.read(guestsForEventProvider(eventId).future);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                          itemCount: guests.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) => _GuestRow(
                            guest: guests[i],
                            onTap: () => _showActions(context, ref, guests[i]),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref, GuestSummary guest) async {
    if (guest.isHost) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MoraColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: MoraColors.borderEmphasis,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(guest.displayName, style: MoraText.display(size: 22, italic: true), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              '${guest.photoCount} ${guest.photoCount == 1 ? "frame" : "frames"} · joined ${_relativeTime(guest.joinedAt)}',
              style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.of(sheetCtx).pop();
                  await _confirmKick(context, ref, guest);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0x33C77859)),
                  foregroundColor: MoraColors.negative,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(
                  'Remove from film',
                  style: MoraText.body(size: 15, color: MoraColors.negative, weight: FontWeight.w500, height: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(sheetCtx).pop(),
              child: Text('Cancel', style: MoraText.body(size: 14, color: MoraColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmKick(BuildContext context, WidgetRef ref, GuestSummary guest) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MoraColors.bgElevated,
        title: Text('Remove ${guest.displayName}?', style: MoraText.display(size: 20, italic: true)),
        content: Text(
          "Their existing frames stay until you delete them individually. They can't add new frames.",
          style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: MoraText.body(size: 14, color: MoraColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove',
                style: MoraText.body(size: 14, color: MoraColors.negative, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(guestsServiceProvider).kick(eventId: eventId, guestId: guest.id);
      ref.invalidate(guestsForEventProvider(eventId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't remove: $e")));
    }
  }
}

class _GuestRow extends StatelessWidget {
  final GuestSummary guest;
  final VoidCallback onTap;
  const _GuestRow({required this.guest, required this.onTap});

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
            children: [
              Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: guest.isHost
                      ? const RadialGradient(
                          center: Alignment(-0.3, -0.3),
                          radius: 0.9,
                          colors: [Color(0xFFE6B66B), Color(0xFFD9A85C), Color(0xFF6B5530)],
                        )
                      : null,
                  color: guest.isHost ? null : MoraColors.bgOverlay,
                  border: guest.isHost ? null : Border.all(color: MoraColors.borderSubtle),
                ),
                child: Text(
                  guest.displayName.isNotEmpty ? guest.displayName[0].toUpperCase() : '?',
                  style: MoraText.display(
                    size: 18,
                    color: guest.isHost ? MoraColors.onAccent : MoraColors.textPrimary,
                    weight: FontWeight.w500,
                  ),
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
                            guest.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: MoraText.display(size: 17, italic: true),
                          ),
                        ),
                        if (guest.isHost) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: MoraColors.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text('HOST',
                                style: MoraText.label(size: 9, color: MoraColors.accent, weight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${guest.photoCount} ${guest.photoCount == 1 ? "frame" : "frames"} · joined ${_relativeTime(guest.joinedAt)}',
                      style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.3),
                    ),
                  ],
                ),
              ),
              if (!guest.isHost)
                const Icon(Icons.more_horiz_rounded, size: 18, color: MoraColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String eventId;
  const _Empty({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 80),
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
              child: const Icon(Icons.people_outline_rounded, size: 28, color: MoraColors.accent),
            ),
            const SizedBox(height: 18),
            Text('No guests yet', style: MoraText.display(size: 22, italic: true)),
            const SizedBox(height: 6),
            Text(
              'Share the QR code to fill the film. Every scan becomes a row here.',
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
          Text("Couldn't load guests.", style: MoraText.body(size: 14, color: MoraColors.textSecondary)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.4)),
          const SizedBox(height: 18),
          SecondaryButton(label: 'Try again', onTap: onRetry),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}
