import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/mora_photo.dart';
import '../../widgets/ui_atoms.dart';

class GuestSplashScreen extends StatelessWidget {
  const GuestSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-bleed warm photo
          const Positioned.fill(child: MoraPhoto(seed: 42, focalX: 50, focalY: 40)),

          // Scrim overlay — fades to bg-base at bottom for legibility
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x4D0F0A06),
                    Color(0x8C0F0A06),
                    MoraColors.bgBase,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top lockup: asterisk + wordmark
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      const FrameMark(size: 18, color: MoraColors.accent),
                      const SizedBox(width: 8),
                      const MoraMark(size: 22),
                    ],
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOU\'RE INVITED TO',
                          style: MoraText.label(color: MoraColors.accent)),
                      const SizedBox(height: 10),
                      Text('Tobi & Adaeze', style: MoraText.display(size: 44, hero: true)),
                      const SizedBox(height: 14),
                      Text.rich(
                        TextSpan(
                          style: MoraText.body(size: 15, color: MoraColors.textSecondary, height: 1.5),
                          children: [
                            const TextSpan(text: "You'll get "),
                            TextSpan(
                              text: '24 frames',
                              style: MoraText.body(
                                size: 15,
                                color: MoraColors.textPrimary,
                                weight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                            const TextSpan(
                              text: '. Take your camera and shoot the day. The film develops after the party.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      PrimaryButton(
                        label: 'Take your camera',
                        onTap: () => context.push('/camera'),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          "By tapping you'll allow Mora to use your camera.",
                          style: MoraText.body(size: 12, color: MoraColors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
