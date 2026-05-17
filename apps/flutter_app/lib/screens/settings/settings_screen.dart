import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../services/me_service.dart';
import '../../services/providers.dart';

/// Provider for the signed-in user. Refresh by invalidating, cheap to leave
/// in scope since /auth/me is a tiny call.
final _meProvider = FutureProvider.autoDispose<Me>((ref) {
  return ref.watch(meServiceProvider).get();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(_meProvider);

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
                        context.go('/films');
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.chevron_left, size: 22, color: MoraColors.textSecondary),
                    ),
                  ),
                  const Spacer(),
                  Text('SETTINGS', style: MoraText.label(size: 10)),
                  const Spacer(),
                  const SizedBox(width: 38),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  meAsync.when(
                    loading: () => const _ProfileCardSkeleton(),
                    error: (_, _) => const _ProfileCardOffline(),
                    data: (me) => _ProfileCard(me: me, onTap: () {}),
                  ),

                  const SizedBox(height: 28),

                  _SectionTitle('Account'),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    hint: 'Name, photo, contact',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.translate_rounded,
                    label: 'Language',
                    hint: 'English',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    hint: 'Push, SMS, reveal alerts',
                    onTap: () {},
                  ),

                  const SizedBox(height: 28),

                  _SectionTitle('Billing'),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.credit_card_rounded,
                    label: 'Payment methods',
                    hint: 'Paystack, Flutterwave, card',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.receipt_long_rounded,
                    label: 'Receipts',
                    hint: 'Past film purchases',
                    onTap: () {},
                  ),

                  const SizedBox(height: 28),

                  _SectionTitle('About'),
                  const SizedBox(height: 10),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    label: 'Privacy & data',
                    hint: 'How we handle your photos',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    label: 'Terms of service',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Help',
                    hint: 'mora.film/help',
                    onTap: () {},
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => _confirmSignOut(context, ref),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x33C77859)),
                        foregroundColor: MoraColors.negative,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: Text(
                        'Sign out',
                        style: MoraText.body(size: 15, color: MoraColors.negative, weight: FontWeight.w500, height: 1.2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Mora · v0.1 · Made with care in Tilburg.',
                      style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.4),
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

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MoraColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Padding(
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
              Text('Sign out of Mora?', style: MoraText.display(size: 22, italic: true)),
              const SizedBox(height: 8),
              Text(
                "We'll keep your films safe. You can sign back in any time.",
                textAlign: TextAlign.center,
                style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    await ref.read(authServiceProvider).logout();
                    // Drop any cached state tied to the old session.
                    ref.invalidate(myFilmsProvider);
                    ref.invalidate(_meProvider);
                    ref.invalidate(sessionRestoredProvider);
                    if (!context.mounted) return;
                    context.go('/welcome');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MoraColors.negative,
                    foregroundColor: const Color(0xFFFFF6F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Sign out',
                    style: MoraText.body(size: 15, color: const Color(0xFFFFF6F2), weight: FontWeight.w600, height: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: Text(
                  'Cancel',
                  style: MoraText.body(size: 14, color: MoraColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
      child: Text(text.toUpperCase(), style: MoraText.label()),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Me me;
  final VoidCallback onTap;
  const _ProfileCard({required this.me, required this.onTap});

  String get _name => me.displayName?.trim().isNotEmpty == true ? me.displayName!.trim() : 'Mora host';
  String get _initial => _name.isNotEmpty ? _name[0].toUpperCase() : 'M';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MoraColors.bgElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MoraColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.3),
                  radius: 0.9,
                  colors: [Color(0xFFE6B66B), Color(0xFFD9A85C), Color(0xFF6B5530)],
                ),
              ),
              child: Text(
                _initial,
                style: MoraText.display(size: 22, color: MoraColors.onAccent, weight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name, style: MoraText.display(size: 18)),
                  const SizedBox(height: 2),
                  Text(me.phone, style: MoraText.mono(size: 12, color: MoraColors.textTertiary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: MoraColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ProfileCardSkeleton extends StatelessWidget {
  const _ProfileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoraColors.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MoraColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0x14F5EFE6),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 120, height: 14, color: const Color(0x14F5EFE6)),
                const SizedBox(height: 8),
                Container(width: 90, height: 10, color: const Color(0x0FF5EFE6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCardOffline extends StatelessWidget {
  const _ProfileCardOffline();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoraColors.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MoraColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 22, color: MoraColors.textTertiary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Couldn't reach Mora — showing offline profile.",
              style: MoraText.body(size: 13, color: MoraColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.label, this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0x06F5EFE6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MoraColors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: MoraColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: MoraText.body(size: 14, weight: FontWeight.w500, height: 1.2)),
                      if (hint != null) ...[
                        const SizedBox(height: 2),
                        Text(hint!, style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.2)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: MoraColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
