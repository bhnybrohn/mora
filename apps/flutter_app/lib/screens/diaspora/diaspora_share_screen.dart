import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/theme.dart';
import '../../models/event.dart';
import '../../services/providers.dart';
import '../../widgets/ui_atoms.dart';

/// Host-side diaspora link sharing. Generates a watch-only URL the host
/// passes to family abroad. Persistence of grants/payments is a v2 — for
/// now the link is the same `/d/<id>` route any browser can hit.
class DiasporaShareScreen extends ConsumerStatefulWidget {
  final String eventId;
  const DiasporaShareScreen({super.key, required this.eventId});

  @override
  ConsumerState<DiasporaShareScreen> createState() => _DiasporaShareScreenState();
}

class _DiasporaShareScreenState extends ConsumerState<DiasporaShareScreen> {
  bool _copied = false;

  String _watchUrl() => 'https://mora.film/d/${widget.eventId}';

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(_eventByIdProvider(widget.eventId));

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
                  Text('DIASPORA', style: MoraText.label(size: 10)),
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
                        const TextSpan(text: 'A window for '),
                        TextSpan(text: 'far-away', style: MoraText.display(size: 30, italic: true)),
                        const TextSpan(text: ' family.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A watch-only link your family abroad can open to see the day unfold and leave a blessing.',
                    style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),

            Expanded(
              child: eventAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: MoraColors.accent, strokeWidth: 2)),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(e.toString(), style: MoraText.body(size: 13, color: MoraColors.negative)),
                ),
                data: (event) => _body(event),
              ),
            ),
            BottomAction(
              children: [
                PrimaryButton(
                  label: 'Send via WhatsApp',
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF0B2912)),
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: const Color(0xFF0B2912),
                  onTap: _shareToWhatsApp,
                ),
                SecondaryButton(
                  label: _copied ? 'Link copied' : 'Copy link',
                  icon: Icon(_copied ? Icons.check_rounded : Icons.link_rounded, size: 18),
                  onTap: _copyLink,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Event event) {
    final url = _watchUrl();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),
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
                      data: url,
                      version: QrVersions.auto,
                      size: 196,
                      backgroundColor: MoraColors.bgBase,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: MoraColors.textPrimary),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: MoraColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(event.name, style: MoraText.display(size: 22, italic: true), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  'mora.film/d/${event.id}',
                  style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x0FD9A85C),
              border: Border.all(color: const Color(0x33D9A85C)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WHAT THEY CAN DO', style: MoraText.label(color: MoraColors.accent)),
                const SizedBox(height: 8),
                _Bullet('Watch the live curated feed as the event happens.'),
                _Bullet('React with emoji and short blessings that land on your screen.'),
                _Bullet('Get the full album at reveal time, same as everyone in the room.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToWhatsApp() async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _watchUrl()));
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Link copied — paste into WhatsApp')),
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _watchUrl()));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('· ', style: MoraText.body(size: 13, color: MoraColors.accent)),
          Expanded(
            child: Text(text, style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

final _eventByIdProvider = FutureProvider.family.autoDispose<Event, String>((ref, id) {
  return ref.watch(eventsServiceProvider).get(id);
});
