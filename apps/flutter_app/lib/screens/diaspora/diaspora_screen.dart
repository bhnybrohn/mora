import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/mora_photo.dart';

class DiasporaScreen extends StatelessWidget {
  const DiasporaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _PortalHero()),
            SliverToBoxAdapter(child: _LiveCounter()),
            const SliverToBoxAdapter(child: _SectionHeader(title: 'Latest frames')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: MoraPhoto(seed: (index * 7 + 3) % 100),
                  ),
                  childCount: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MoraColors.accent.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: MoraColors.accent.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const MoraPhoto(seed: 42),
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: MoraColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.radio_button_checked, size: 8, color: MoraColors.accent),
                        const SizedBox(width: 6),
                        Text('LIVE', style: MoraText.label(color: MoraColors.accent, size: 10, weight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tobi & Adaeze', style: MoraText.display(size: 22, italic: true)),
                        const SizedBox(height: 4),
                        Text('Lagos, Nigeria', style: MoraText.body(size: 12, color: MoraColors.textTertiary)),
                      ],
                    ),
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

class _LiveCounter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          const _CountBlock(value: '87', label: 'GUESTS'),
          const SizedBox(width: 24),
          const _CountBlock(value: '234', label: 'FRAMES'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x0AF5EFE6),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: MoraColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_rounded, size: 14, color: MoraColors.accent),
                const SizedBox(width: 6),
                Text('Synced', style: MoraText.body(size: 11, color: MoraColors.accent, height: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBlock extends StatelessWidget {
  final String value;
  final String label;
  const _CountBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: MoraText.display(size: 26)),
        const SizedBox(height: 2),
        Text(label, style: MoraText.label()),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Text(title, style: MoraText.display(size: 18)),
    );
  }
}
