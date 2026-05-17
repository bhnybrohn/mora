import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/ui_atoms.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Editorial backdrop — warm asoebi-coded halos bleeding off edges
          Positioned(
            top: 120, right: -80,
            child: Container(
              width: 280, height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.4, -0.4),
                  radius: 0.7,
                  colors: [
                    Color(0x8CD9A85C),
                    Color(0x40C77859),
                    Color(0x000F0A06),
                  ],
                  stops: [0.0, 0.4, 0.7],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40, left: -40,
            child: Container(
              width: 200, height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(0.2, -0.2),
                  radius: 0.6,
                  colors: [Color(0x267FA868), Color(0x000F0A06)],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // MASTHEAD — dateline
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      const FrameMark(size: 20, color: MoraColors.accent),
                      const SizedBox(width: 10),
                      Text(
                        'VOL. 1 — ISS. 01',
                        style: MoraText.label(color: MoraColors.textSecondary, size: 10),
                      ),
                      const Spacer(),
                      Text(
                        'MAY · LAGOS',
                        style: MoraText.mono(
                          size: 10,
                          color: MoraColors.textTertiary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),

                // Hairline
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  height: 1,
                  color: MoraColors.borderEmphasis,
                ),

                // Main editorial block — pushed down toward CTAs
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Wordmark — italic Fraunces at hero scale
                        Transform.translate(
                          offset: const Offset(-6, 0),
                          child: Text(
                            'mora',
                            style: MoraText.wordmark(size: 132),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Accent rule + sub-label
                        Row(
                          children: [
                            Container(width: 24, height: 1, color: MoraColors.accent),
                            const SizedBox(width: 10),
                            Text(
                              'THE GATHERING\'S FILM',
                              style: MoraText.label(color: MoraColors.accent),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Deck — magazine subtitle
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            "One disposable. Everyone shoots. The film develops together when the day is done.",
                            style: MoraText.deck(
                              size: 22,
                              color: MoraColors.textSecondary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // CTAs — phone is the primary path. We show one
                        // platform-appropriate social button alongside it
                        // (Apple on iOS, Google on Android) as a stub for now;
                        // only phone is actually wired through.
                        PrimaryButton(
                          label: 'Continue with phone',
                          icon: const Icon(Icons.phone_rounded, size: 18, color: MoraColors.onAccent),
                          onTap: () => context.push('/auth/phone'),
                        ),
                        const SizedBox(height: 10),
                        _SocialContinueButton(onTap: () => context.go('/films')),

                        const SizedBox(height: 18),

                        // Joining a film link
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: MoraColors.borderSubtle)),
                          ),
                          child: GestureDetector(
                            onTap: () => context.push('/guest-splash'),
                            child: Text.rich(
                              TextSpan(
                                text: 'Joining a film? ',
                                style: MoraText.body(size: 13, color: MoraColors.textSecondary),
                                children: [
                                  TextSpan(
                                    text: 'Enter code →',
                                    style: MoraText.body(size: 13, color: MoraColors.accent, weight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
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
        ],
      ),
    );
  }
}

/// Platform-aware social sign-in button. Renders an "Apple" button on iOS
/// and a "Google" button on Android (and other platforms). Only one is shown
/// per the platform's conventions; both are stubs that drop into the films
/// dashboard for now.
class _SocialContinueButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SocialContinueButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return SecondaryButton(
      label: isIOS ? 'Continue with Apple' : 'Continue with Google',
      icon: isIOS
          ? const Icon(Icons.apple, size: 20)
          : const Icon(Icons.g_mobiledata_rounded, size: 24),
      onTap: onTap,
    );
  }
}
