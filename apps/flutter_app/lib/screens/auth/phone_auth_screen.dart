import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/providers.dart';
import '../../widgets/ui_atoms.dart';

/// Phone OTP step 1 — collect the phone number. Defaults to a Nigerian
/// country code; user can pick a different one via the prefix chip.
class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  _CountryCode _country = _kCountries[0];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool get _valid {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 7 && digits.length <= 14;
  }

  String _e164() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return '${_country.dial}$digits';
  }

  Future<void> _sendCode() async {
    if (!_valid || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final phone = _e164();
    try {
      await ref.read(authServiceProvider).requestOtp(phone);
      if (!mounted) return;
      context.push('/auth/otp', extra: phone);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _pickCountry() async {
    final picked = await showModalBottomSheet<_CountryCode>(
      context: context,
      backgroundColor: MoraColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => _CountryPicker(selected: _country),
    );
    if (picked != null) setState(() => _country = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StepHeader(onBack: () => context.pop()),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: MoraText.display(size: 30),
                      children: [
                        const TextSpan(text: "What's your "),
                        TextSpan(text: 'number', style: MoraText.display(size: 30, italic: true)),
                        const TextSpan(text: '?'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We'll text you a 6-digit code. No spam, no calls.",
                    style: MoraText.body(size: 14, color: MoraColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Phone input — country prefix chip + tel field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x08F5EFE6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _error != null ? MoraColors.negative : MoraColors.borderEmphasis,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickCountry,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_country.flag, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Text(
                                _country.dial,
                                style: MoraText.mono(
                                  size: 16,
                                  color: MoraColors.textPrimary,
                                  weight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.expand_more_rounded, size: 16, color: MoraColors.textTertiary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1, height: 28,
                      color: MoraColors.borderSubtle,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autofocus: true,
                        cursorColor: MoraColors.accent,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
                          LengthLimitingTextInputFormatter(16),
                        ],
                        style: MoraText.mono(
                          size: 20,
                          color: MoraColors.textPrimary,
                          weight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: InputBorder.none,
                          hintText: '801 234 5678',
                          hintStyle: MoraText.mono(
                            size: 20,
                            color: MoraColors.textTertiary,
                            weight: FontWeight.w400,
                          ),
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                          setState(() {});
                        },
                        onSubmitted: (_) => _sendCode(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(_error!, style: MoraText.body(size: 13, color: MoraColors.negative)),
              ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'By continuing you agree to our terms and privacy policy. SMS rates may apply.',
                style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.5),
              ),
            ),

            const Spacer(),

            BottomAction(
              children: [
                PrimaryButton(
                  label: _sending ? 'Sending…' : 'Send code',
                  onTap: _valid && !_sending ? _sendCode : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryPicker extends StatelessWidget {
  final _CountryCode selected;
  const _CountryPicker({required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: MoraColors.borderEmphasis,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('CHOOSE COUNTRY', style: MoraText.label()),
            ),
            const SizedBox(height: 10),
            for (final c in _kCountries)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(c),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    child: Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(c.name,
                              style: MoraText.body(size: 15, color: MoraColors.textPrimary, height: 1.2)),
                        ),
                        Text(c.dial,
                            style: MoraText.mono(size: 14, color: MoraColors.textSecondary)),
                        if (c.dial == selected.dial)
                          const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Icon(Icons.check_rounded, size: 18, color: MoraColors.accent),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CountryCode {
  final String name;
  final String dial;
  final String flag;
  const _CountryCode(this.name, this.dial, this.flag);
}

const _kCountries = <_CountryCode>[
  _CountryCode('Nigeria', '+234', '🇳🇬'),
  _CountryCode('Ghana', '+233', '🇬🇭'),
  _CountryCode('Kenya', '+254', '🇰🇪'),
  _CountryCode('South Africa', '+27', '🇿🇦'),
  _CountryCode('United Kingdom', '+44', '🇬🇧'),
  _CountryCode('United States', '+1', '🇺🇸'),
];
