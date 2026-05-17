import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/mora_photo.dart';
import '../../widgets/ui_atoms.dart';

class SponsorsScreen extends StatelessWidget {
  const SponsorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoraColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/album');
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.chevron_left, size: 22, color: MoraColors.textSecondary),
                    ),
                  ),
                  const Spacer(),
                  Text('PLACEMENTS', style: MoraText.label(size: 9)),
                  const Spacer(),
                  const SizedBox(width: 38),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              style: MoraText.display(size: 26),
                              children: [
                                const TextSpan(text: 'How '),
                                TextSpan(
                                  text: 'advertising',
                                  style: MoraText.display(size: 26, italic: true),
                                ),
                                const TextSpan(text: '\nlives in Mora'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Three magazine-insert patterns. No banners, no popups. Each respects the film.',
                            style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
                          ),
                        ],
                      ),
                    ),

                    _SponsorSection(
                      num: '01',
                      title: 'Sponsored frame',
                      hint: 'A tile in the photo grid.',
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                        childAspectRatio: 1 / 1.18,
                        children: const [
                          _AlbumTile(seed: 22),
                          SponsoredFrame(),
                          _AlbumTile(seed: 31),
                          _AlbumTile(seed: 5),
                        ],
                      ),
                    ),

                    _SponsorSection(
                      num: '02',
                      title: 'Issue insert',
                      hint: 'Between sections in By-time view.',
                      child: const IssueInsert(),
                    ),

                    _SponsorSection(
                      num: '03',
                      title: 'Made possible by',
                      hint: 'Vendor credits at the album foot.',
                      pad: false,
                      child: const MadePossibleBy(),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: Container(
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
                            Text('PRINCIPLE', style: MoraText.label(color: MoraColors.accent)),
                            const SizedBox(height: 6),
                            Text(
                              'Ads on Mora must be of the event, not at the viewer. We favor vendors that worked the day, magazine-coded layouts, and zero urgency-language. No "limited time," no badges, no flashing.',
                              style: MoraText.body(size: 12, color: MoraColors.textSecondary, height: 1.55),
                            ),
                          ],
                        ),
                      ),
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

class _AlbumTile extends StatelessWidget {
  final int seed;
  const _AlbumTile({required this.seed});

  @override
  Widget build(BuildContext context) => MoraPhoto(seed: seed);
}

class _SponsorSection extends StatelessWidget {
  final String num;
  final String title;
  final String hint;
  final Widget child;
  final bool pad;

  const _SponsorSection({
    required this.num,
    required this.title,
    required this.hint,
    required this.child,
    this.pad = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: pad ? const EdgeInsets.fromLTRB(20, 0, 20, 28) : const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: pad ? EdgeInsets.zero : const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(num,
                    style: MoraText.mono(size: 10, color: MoraColors.accent, letterSpacing: 1.32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: MoraText.display(size: 18)),
                      const SizedBox(height: 2),
                      Text(hint, style: MoraText.body(size: 11, color: MoraColors.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
