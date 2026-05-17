import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/providers.dart';
import '../../widgets/ui_atoms.dart';

/// Phone OTP step 2 — six single-digit boxes that auto-advance as the user
/// types. Surfaces resend with a countdown and supports paste of a full code.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpVerifyScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  static const _len = 6;
  final List<TextEditingController> _controllers =
      List.generate(_len, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(_len, (_) => FocusNode());
  Timer? _resendTimer;
  int _resendIn = 30;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nodes[0].requestFocus());
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_resendIn > 0) {
          _resendIn--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int i, String value) {
    if (_error != null) setState(() => _error = null);
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var k = 0; k < _len; k++) {
        _controllers[k].text = k < digits.length ? digits[k] : '';
      }
      final next = digits.length >= _len ? _len - 1 : digits.length;
      _nodes[next].requestFocus();
    } else if (value.isNotEmpty && i < _len - 1) {
      _nodes[i + 1].requestFocus();
    } else if (value.isEmpty && i > 0) {
      _nodes[i - 1].requestFocus();
    }
    if (_code.length == _len) _verify();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).verifyOtp(widget.phone, _code);
      if (!mounted) return;
      context.go('/films');
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _verifying = false;
      });
      // Clear the code so the user can re-enter without backspace surgery.
      for (final c in _controllers) {
        c.clear();
      }
      _nodes[0].requestFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Try again.';
        _verifying = false;
      });
    }
  }

  Future<void> _resend() async {
    if (_resendIn > 0) return;
    try {
      await ref.read(authServiceProvider).requestOtp(widget.phone);
      _startResendTimer();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
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
                        const TextSpan(text: 'Enter the '),
                        TextSpan(text: 'code', style: MoraText.display(size: 30, italic: true)),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      style: MoraText.body(size: 14, color: MoraColors.textSecondary, height: 1.5),
                      children: [
                        const TextSpan(text: 'Sent to '),
                        TextSpan(
                          text: widget.phone,
                          style: MoraText.mono(size: 13, color: MoraColors.textPrimary, weight: FontWeight.w500),
                        ),
                        const TextSpan(text: '. It can take a minute.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_len, (i) {
                  final hasVal = _controllers[i].text.isNotEmpty;
                  return Container(
                    width: 48, height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x08F5EFE6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _error != null
                            ? MoraColors.negative
                            : hasVal
                                ? MoraColors.accent
                                : MoraColors.borderEmphasis,
                        width: _nodes[i].hasFocus ? 1.5 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _nodes[i],
                      autofocus: i == 0,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      cursorColor: MoraColors.accent,
                      cursorWidth: 1.4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: MoraText.mono(
                        size: 24,
                        color: MoraColors.textPrimary,
                        weight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => _onChanged(i, v),
                    ),
                  );
                }),
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text(_error!, style: MoraText.body(size: 13, color: MoraColors.negative)),
              ),

            const SizedBox(height: 20),

            Center(
              child: _resendIn > 0
                  ? Text(
                      'Resend code in ${_resendIn}s',
                      style: MoraText.body(size: 13, color: MoraColors.textTertiary),
                    )
                  : TextButton(
                      onPressed: _resend,
                      child: Text(
                        'Resend code',
                        style: MoraText.body(size: 13, color: MoraColors.accent, weight: FontWeight.w500),
                      ),
                    ),
            ),

            const Spacer(),

            BottomAction(
              children: [
                PrimaryButton(
                  label: _verifying ? 'Verifying…' : 'Verify',
                  onTap: _code.length == _len && !_verifying ? _verify : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
