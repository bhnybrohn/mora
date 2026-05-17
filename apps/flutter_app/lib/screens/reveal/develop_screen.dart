import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/mora_photo.dart';
import '../../widgets/ui_atoms.dart';

class DevelopScreen extends StatefulWidget {
  const DevelopScreen({super.key});

  @override
  State<DevelopScreen> createState() => _DevelopScreenState();
}

class _DevelopScreenState extends State<DevelopScreen> {
  String _stage = 'countdown'; // countdown -> revealing -> revealed
  int _count = 3;

  final _photoSeeds = const [11, 22, 5, 31, 17, 8, 44, 3, 26, 14, 9, 38];

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_stage == 'countdown') {
        if (_count > 1) {
          setState(() => _count--);
          _tick();
        } else {
          setState(() => _stage = 'revealing');
          Future.delayed(const Duration(milliseconds: 2600), () {
            if (mounted) setState(() => _stage = 'revealed');
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == 'revealed') {
      return _RevealedHero(
        onOpen: () => context.push('/album'),
        filmName: 'Tobi & Adaeze',
      );
    }

    return Scaffold(
      backgroundColor: MoraColors.bgBase,
      body: Stack(
        children: [
          // Warm halo behind the photos — intensifies during reveal
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _stage == 'revealing' ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 1600),
                curve: MoraEase.reveal,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.1),
                      radius: 0.5,
                      colors: [Color(0x38D9A85C), Color(0x00D9A85C)],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Header
                AnimatedOpacity(
                  opacity: _stage == 'countdown' ? 1.0 : 0,
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                    'YOUR FILM IS DEVELOPING',
                    style: MoraText.label(color: MoraColors.accent),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Tobi & Adaeze', style: MoraText.display(size: 26)),
                const SizedBox(height: 6),
                Text(
                  '28 frames from 12 guests',
                  style: MoraText.body(size: 13, color: MoraColors.textSecondary),
                ),

                const Spacer(),

                // Photo grid with staggered develop animation
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: SizedBox(
                    width: 340,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _photoSeeds.length,
                      itemBuilder: (context, i) {
                        final s = _photoSeeds[i];
                        final revealing = _stage != 'countdown';
                        final delay = i * 130;
                        return AnimatedOpacity(
                          opacity: revealing ? 1.0 : 0,
                          duration: Duration(milliseconds: 1400 + delay),
                          curve: MoraEase.reveal,
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 1600 + delay),
                            curve: MoraEase.reveal,
                            transform: revealing
                                ? Matrix4.identity()
                                : Matrix4.diagonal3Values(0.94, 0.94, 1.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  MoraPhoto(seed: s),
                                  AnimatedOpacity(
                                    opacity: revealing ? 0 : 1,
                                    duration: Duration(milliseconds: 1800 + delay),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                      child: Container(color: Colors.black.withValues(alpha: 0.3)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),

          // Countdown overlay — vignettes everything else
          if (_stage == 'countdown')
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, 0.1),
                      radius: 0.6,
                      colors: [Color(0x730F0A06), Color(0xE60F0A06)],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('DEVELOPING IN', style: MoraText.label(color: MoraColors.accent)),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                          child: Text(
                            '$_count',
                            key: ValueKey(_count),
                            style: MoraText.display(size: 124, hero: true, weight: FontWeight.w300),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RevealedHero extends StatelessWidget {
  final String filmName;
  final VoidCallback onOpen;
  const _RevealedHero({required this.onOpen, required this.filmName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MoraPhoto(seed: 22, focalX: 50, focalY: 38),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x1A0F0A06),
                    Color(0x660F0A06),
                    Color(0xF20F0A06),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                  child: Text('YOUR FILM IS READY',
                      style: MoraText.label(color: MoraColors.accent)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(filmName, style: MoraText.display(size: 40, hero: true)),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '28 frames · 12 guests · Saturday in Lagos',
                    style: MoraText.body(size: 14, color: MoraColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: PrimaryButton(label: 'Open film', onTap: onOpen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
