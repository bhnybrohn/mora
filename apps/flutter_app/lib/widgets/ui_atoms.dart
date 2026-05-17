import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/theme.dart';

// ─── FrameMark (Mora logo - single film frame) ───
class FrameMark extends StatelessWidget {
  final double size;
  final Color? color;
  const FrameMark({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? MoraColors.textPrimary;
    return CustomPaint(
      painter: _FrameMarkPainter(c),
      size: Size(size, size),
    );
  }
}

class _FrameMarkPainter extends CustomPainter {
  final Color color;
  _FrameMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 24;

    // perforation tab
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6 * u, 4 * u, 12 * u, 2.4 * u),
        Radius.circular(1.1 * u),
      ),
      Paint()..color = color.withValues(alpha: 0.45)..style = PaintingStyle.fill,
    );
    // frame body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4.75 * u, 7.5 * u, 14.5 * u, 13 * u),
        Radius.circular(2.5 * u),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * u,
    );
    // exposure dot
    canvas.drawCircle(
      Offset(12 * u, 14 * u),
      2.1 * u,
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── MoraMark — the italic "mora" wordmark at a small size (logo lock-up) ───
class MoraMark extends StatelessWidget {
  final double size;
  final Color? color;
  const MoraMark({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      'mora',
      style: MoraText.display(
        size: size,
        color: color ?? MoraColors.textPrimary,
        italic: true,
        weight: FontWeight.w300,
      ),
    );
  }
}

// ─── StatusPill ───
class StatusPill extends StatelessWidget {
  final String text;
  final bool dot;
  final String tone;
  const StatusPill(this.text, {super.key, this.dot = false, this.tone = 'neutral'});

  @override
  Widget build(BuildContext context) {
    Color bg, fg, dotColor;
    switch (tone) {
      case 'positive':
        bg = const Color(0x1A7FA868);
        fg = const Color(0xFFA8C293);
        dotColor = MoraColors.positive;
      case 'accent':
        bg = const Color(0x1AD9A85C);
        fg = MoraColors.accentHover;
        dotColor = MoraColors.accent;
      default:
        bg = const Color(0x0FF5EFE6);
        fg = MoraColors.textSecondary;
        dotColor = MoraColors.textTertiary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: MoraText.body(size: 12, color: fg, weight: FontWeight.w500, height: 1.2),
          ),
        ],
      ),
    );
  }
}

// ─── PillToggleGroup ───
class PillToggleGroup extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  final List<MapEntry<String, String>> options;
  const PillToggleGroup({super.key, required this.value, required this.onChange, required this.options});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x0AF5EFE6),
        border: Border.all(color: MoraColors.borderSubtle),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: options.map((o) {
          final sel = value == o.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(o.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: MoraEase.out,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel ? MoraColors.textPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  o.value,
                  style: MoraText.body(
                    size: 13,
                    color: sel ? MoraColors.bgBase : MoraColors.textSecondary,
                    weight: sel ? FontWeight.w600 : FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── StepHeader ───
class StepHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final int? step;
  final int? of;
  final Widget? right;
  const StepHeader({super.key, this.onBack, this.step, this.of, this.right});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.chevron_left, size: 22, color: MoraColors.textSecondary),
              ),
            )
          else
            const SizedBox(width: 38),
          const Spacer(),
          if (step != null && of != null)
            Text(
              'Step $step of $of'.toUpperCase(),
              style: MoraText.label(),
            ),
          const Spacer(),
          right ?? const SizedBox(width: 38),
        ],
      ),
    );
  }
}

// ─── BottomAction ───
class BottomAction extends StatelessWidget {
  final Widget? hint;
  final List<Widget> children;
  const BottomAction({super.key, this.hint, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MoraColors.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
          if (hint != null) ...[
            const SizedBox(height: 8),
            DefaultTextStyle(
              style: MoraText.body(size: 12, color: MoraColors.textTertiary, height: 1.4),
              textAlign: TextAlign.center,
              child: hint!,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── FramesDial ───
class FramesDial extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChange;
  final List<int> options;

  const FramesDial({
    super.key,
    required this.value,
    required this.onChange,
    // Six positions around the ring (clock face) — covers the full
    // disposable-camera range plus higher counts for big owambe weekends.
    this.options = const [12, 24, 36, 48, 60, 72],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        children: [
          // Backdrop disc with warm radial highlight + center numeral
          CustomPaint(
            painter: _FramesDialPainter(),
            size: const Size(200, 200),
          ),
          // Center value (Fraunces) + label (Switzer)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$value', style: MoraText.display(size: 48, weight: FontWeight.w300)),
                const SizedBox(height: 2),
                Text('FRAMES', style: MoraText.label(size: 10)),
              ],
            ),
          ),
          // Option pips on the ring
          ...options.map((opt) {
            final i = options.indexOf(opt);
            final angle = (i / options.length) * 2 * math.pi - math.pi / 2;
            final r = 84.0;
            final px = 100 + math.cos(angle) * r - 18;
            final py = 100 + math.sin(angle) * r - 18;
            return Positioned(
              left: px,
              top: py,
              child: GestureDetector(
                onTap: () => onChange(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: MoraEase.out,
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: opt == value ? MoraColors.accent : Colors.transparent,
                    border: opt == value ? null : Border.all(color: MoraColors.borderSubtle),
                  ),
                  child: Text(
                    '$opt',
                    style: MoraText.body(
                      size: 13,
                      color: opt == value ? MoraColors.onAccent : MoraColors.textTertiary,
                      weight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FramesDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 1;

    canvas.drawCircle(
      c,
      outerR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.24),
          colors: [Color(0xFF2A1E13), Color(0xFF1A130C)],
          stops: [0, 0.7],
        ).createShader(Rect.fromCircle(center: c, radius: outerR)),
    );

    canvas.drawCircle(
      c,
      outerR,
      Paint()
        ..color = MoraColors.borderSubtle
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Primary button ───
class PrimaryButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final VoidCallback? onTap;
  final double? height;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? MoraColors.onAccent;
    return SizedBox(
      width: double.infinity,
      height: height ?? 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? MoraColors.accent,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 8)],
            Text(label, style: MoraText.body(size: 16, color: fg, weight: FontWeight.w600, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

// ─── Secondary button ───
class SecondaryButton extends StatelessWidget {
  final String label;
  final Widget? icon;
  final VoidCallback? onTap;

  const SecondaryButton({super.key, required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: MoraColors.textPrimary,
          side: const BorderSide(color: MoraColors.borderEmphasis),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 10)],
            Text(label, style: MoraText.body(size: 16, weight: FontWeight.w500, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

// ─── Sponsor placement: "Made possible by" vendor card ───
class VendorCard extends StatelessWidget {
  final String name;
  final String role;
  final List<Color> palette;
  final VoidCallback? onTap;

  const VendorCard({
    super.key,
    required this.name,
    required this.role,
    required this.palette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MoraColors.bgElevated,
          border: Border.all(color: MoraColors.borderSubtle),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 40,
                height: 40,
                child: AsoebiSwatch(palette: palette),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: MoraText.body(size: 12, color: MoraColors.textPrimary, weight: FontWeight.w500, height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(role.toUpperCase(), style: MoraText.label(size: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sponsor placement: "Made possible by" block ───
class MadePossibleBy extends StatelessWidget {
  final List<Map<String, dynamic>> vendors;
  const MadePossibleBy({super.key, this.vendors = _defaultVendors});

  static const _defaultVendors = [
    {'name': 'Folake Adisa Textiles', 'role': 'Aso oke', 'palette': [Color(0xFF3A1418), Color(0xFFD4A857), Color(0xFF7A3025)]},
    {'name': 'Hibiscus & Hay', 'role': 'Catering', 'palette': [Color(0xFF2A1F1A), Color(0xFFE89C5C), Color(0xFF4D2A20)]},
    {'name': 'Aramide Studio', 'role': 'Photography', 'palette': [Color(0xFF1A1714), Color(0xFFA88B5C), Color(0xFF3D3530)]},
    {'name': 'Hall One, Ikeja', 'role': 'Venue', 'palette': [Color(0xFF1F2A52), Color(0xFFD4A857), Color(0xFF3D3530)]},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: MoraColors.borderSubtle)),
      ),
      child: Column(
        children: [
          // Section masthead
          Row(
            children: [
              Text('MADE POSSIBLE BY', style: MoraText.label(color: MoraColors.accent)),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: MoraColors.borderSubtle)),
              const SizedBox(width: 8),
              const _SponsoredMark(),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.5,
            children: vendors.map((v) => VendorCard(
              name: v['name'] as String,
              role: v['role'] as String,
              palette: (v['palette'] as List).cast<Color>(),
            )).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'Vendors the host tagged. Mora earns a small fee when guests book through these credits.',
            textAlign: TextAlign.center,
            style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─── Asoebi color swatch backdrop ───
class AsoebiSwatch extends StatelessWidget {
  final List<Color> palette;
  const AsoebiSwatch({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    if (palette.length < 3) return const SizedBox();
    return CustomPaint(painter: _AsoebiSwatchPainter(palette[0], palette[1], palette[2]), size: Size.infinite);
  }
}

class _AsoebiSwatchPainter extends CustomPainter {
  final Color base, glow, lift;
  _AsoebiSwatchPainter(this.base, this.glow, this.lift);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(r, Paint()..color = base);

    // Lift blob top-left (matches `<ellipse cx="30" cy="40" rx="40" ry="32">`)
    final liftRect = Rect.fromCenter(
      center: Offset(size.width * 0.30, size.height * 0.40),
      width: size.width * 0.80,
      height: size.height * 0.64,
    );
    canvas.drawOval(
      liftRect,
      Paint()
        ..color = lift.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Glow blob bottom-right (matches `<ellipse cx="75" cy="70" rx="32" ry="40">`)
    final glowRect = Rect.fromCenter(
      center: Offset(size.width * 0.75, size.height * 0.70),
      width: size.width * 0.64,
      height: size.height * 0.80,
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..color = glow.withValues(alpha: 0.60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Radial gradient finish (matches the SVG <radialGradient>)
    canvas.drawRect(
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.1),
          radius: 0.85,
          colors: [
            glow.withValues(alpha: 0.85),
            base.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.65),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Sponsor "Sponsored" mark badge ───
class _SponsoredMark extends StatelessWidget {
  const _SponsoredMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4, height: 4,
            decoration: const BoxDecoration(color: MoraColors.accent, shape: BoxShape.rectangle),
          ),
          const SizedBox(width: 6),
          Text(
            'SPONSORED',
            style: MoraText.label(
              size: 9,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sponsor: SponsoredFrame (tile in photo grid) ───
class SponsoredFrame extends StatelessWidget {
  final String brand;
  final String tagline;
  final double aspectRatio;

  const SponsoredFrame({
    super.key,
    this.brand = 'Folake Adisa',
    this.tagline = 'Aso oke for the day.',
    this.aspectRatio = 1 / 1.18,
  });

  @override
  Widget build(BuildContext context) {
    const palette = [Color(0xFF3A1418), Color(0xFFD4A857), Color(0xFF7A3025)];
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        children: [
          const Positioned.fill(child: AsoebiSwatch(palette: palette)),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x1A0F0A06), Color(0xBF0F0A06)],
                ),
              ),
            ),
          ),
          const Positioned(top: 8, left: 8, child: _SponsoredMark()),
          Positioned(
            bottom: 10, left: 10, right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(brand, style: MoraText.display(size: 17, italic: true)),
                const SizedBox(height: 2),
                Text(
                  tagline,
                  style: MoraText.body(size: 10, color: MoraColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sponsor: IssueInsert (editorial card between sections) ───
class IssueInsert extends StatelessWidget {
  final String brand;
  final String headline;
  final String body;
  final String cta;

  const IssueInsert({
    super.key,
    this.brand = 'Folake Adisa Textiles',
    this.headline = 'Aso oke, woven slow.',
    this.body = 'Hand-loomed in Iseyin. Cut for owambe season.',
    this.cta = 'See the cloth',
  });

  @override
  Widget build(BuildContext context) {
    const palette = [Color(0xFF3A1418), Color(0xFFD4A857), Color(0xFF7A3025)];
    return Container(
      decoration: BoxDecoration(
        color: MoraColors.bgElevated,
        border: Border.all(color: MoraColors.borderSubtle),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                const Positioned.fill(child: AsoebiSwatch(palette: palette)),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-0.4, 0), end: Alignment(0.6, 0),
                        colors: [Color(0x8C0F0A06), Color(0x0D0F0A06)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12, left: 14, right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INSERT · NO. 03',
                        style: MoraText.mono(
                          size: 9,
                          color: Colors.white.withValues(alpha: 0.55),
                          letterSpacing: 1.44,
                        ),
                      ),
                      const _SponsoredMark(),
                    ],
                  ),
                ),
                Positioned(
                  left: 14, right: 14, bottom: 14,
                  child: Text(headline, style: MoraText.display(size: 20, italic: true)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand,
                        style: MoraText.body(size: 12, weight: FontWeight.w500, height: 1.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        overflow: TextOverflow.ellipsis,
                        style: MoraText.body(size: 11, color: MoraColors.textTertiary, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: MoraColors.borderEmphasis),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cta, style: MoraText.body(size: 12, weight: FontWeight.w500, height: 1.2)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 12, color: MoraColors.textPrimary),
                    ],
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
