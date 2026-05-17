import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/providers.dart';
import '../../widgets/ui_atoms.dart';

/// Renders the just-created film as a QR + share-code the host can show at
/// the door. Loads the event by id so it survives a back-and-forth (eg the
/// host taps Done, comes back from /films later).
class QRShareScreen extends ConsumerStatefulWidget {
  final String eventId;
  const QRShareScreen({super.key, required this.eventId});

  @override
  ConsumerState<QRShareScreen> createState() => _QRShareScreenState();
}

class _QRShareScreenState extends ConsumerState<QRShareScreen> {
  bool _copied = false;

  String _shareCode() {
    // Display the last 6 hex chars of the event id, uppercased — short enough
    // to read aloud, distinct enough to avoid collisions in practice.
    final id = widget.eventId;
    final tail = id.length >= 6 ? id.substring(id.length - 6) : id;
    return 'MORA-${tail.toUpperCase()}';
  }

  String _joinUrl() => 'https://mora.film/e/${widget.eventId}';

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(_eventByIdProvider(widget.eventId));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(
              onBack: () => context.pop(),
              right: GestureDetector(
                onTap: () => context.go('/films'),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Done', style: MoraText.body(size: 13, color: MoraColors.textSecondary)),
                ),
              ),
            ),
            Expanded(
              child: eventAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: MoraColors.accent, strokeWidth: 2),
                ),
                error: (e, _) => _ErrorView(message: e.toString()),
                data: (event) => _Body(
                  event: event,
                  shareCode: _shareCode(),
                  joinUrl: _joinUrl(),
                  copied: _copied,
                  onCopy: () async {
                    await Clipboard.setData(ClipboardData(text: _joinUrl()));
                    if (!mounted) return;
                    setState(() => _copied = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                ),
              ),
            ),
            BottomAction(
              hint: const Text('Hosts usually print this for the door, or pop it on the screen.'),
              children: [
                PrimaryButton(
                  label: 'Share to WhatsApp',
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Color(0xFF0B2912)),
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: const Color(0xFF0B2912),
                  onTap: () => _shareToWhatsApp(),
                ),
                SecondaryButton(
                  label: 'Other share options',
                  icon: const Icon(Icons.ios_share, size: 18),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: _joinUrl()));
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareToWhatsApp() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _joinUrl()));
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Link copied — paste into WhatsApp')),
    );
  }
}

class _Body extends StatelessWidget {
  final Event event;
  final String shareCode;
  final String joinUrl;
  final bool copied;
  final VoidCallback onCopy;

  const _Body({
    required this.event,
    required this.shareCode,
    required this.joinUrl,
    required this.copied,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final shortUrl = joinUrl.replaceFirst('https://', '');
    final hostFacingSlug = shortUrl.contains('/') ? shortUrl.substring(shortUrl.lastIndexOf('/') + 1) : shortUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Text('YOUR FILM IS LIVE', style: MoraText.label(color: MoraColors.accent)),
          const SizedBox(height: 8),
          Text(event.name, style: MoraText.display(size: 28), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          // Date · Location below the title — gives the QR card real context
          // instead of a generic "anyone with this code" line.
          Text(
            _eventSubhead(event),
            style: MoraText.body(size: 13, color: MoraColors.textTertiary),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: MoraColors.bgBase,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: MoraColors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MoraColors.bgOverlay,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MoraColors.borderSubtle),
                  ),
                  child: SizedBox(
                    width: 196,
                    height: 196,
                    child: QrImageView(
                      data: joinUrl,
                      version: QrVersions.auto,
                      size: 196,
                      backgroundColor: MoraColors.bgBase,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: MoraColors.textPrimary,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: MoraColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shareCode,
                      style: MoraText.mono(
                        size: 22,
                        color: MoraColors.textPrimary,
                        letterSpacing: 3.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onCopy,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x0AF5EFE6),
                          border: Border.all(color: MoraColors.borderSubtle),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              copied ? Icons.check : Icons.copy_rounded,
                              size: 14,
                              color: copied ? MoraColors.positive : MoraColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              copied ? 'Copied' : 'Copy',
                              style: MoraText.body(
                                size: 12,
                                color: copied ? MoraColors.positive : MoraColors.textSecondary,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'mora.film/e/',
                    style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.2),
                    children: [
                      TextSpan(
                        text: hostFacingSlug,
                        style: MoraText.body(size: 12, color: MoraColors.textSecondary, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusPill(
                '${event.guestCount} ${event.guestCount == 1 ? "guest" : "guests"} joined',
                dot: event.guestCount > 0,
                tone: event.guestCount > 0 ? 'positive' : 'neutral',
              ),
              const SizedBox(width: 8),
              if (event.tier == EventTier.free) const StatusPill('Free until 5'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: MoraColors.textTertiary, size: 36),
          const SizedBox(height: 14),
          Text(
            "Couldn't load this film.",
            style: MoraText.body(size: 14, color: MoraColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

final _eventByIdProvider = FutureProvider.family.autoDispose<Event, String>((ref, id) {
  return ref.watch(eventsServiceProvider).get(id);
});

String _eventSubhead(Event event) {
  // "Saturday, Jun 14 · Lagos" — falls back gracefully if either piece
  // is missing.
  final parts = <String>[_dateLabel(event.startsAt)];
  if (event.location.trim().isNotEmpty) parts.add(event.location.trim());
  return parts.join(' · ');
}

String _dateLabel(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}
