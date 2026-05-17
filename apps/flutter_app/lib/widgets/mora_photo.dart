import 'package:flutter/material.dart';

class MoraPhoto extends StatelessWidget {
  final int seed;
  final double focalX;
  final double focalY;

  const MoraPhoto({
    super.key,
    this.seed = 0,
    this.focalX = 50,
    this.focalY = 55,
  });

  static const _palettes = [
    [Color(0xFF231209), Color(0xFFD9A85C), Color(0xFF7A3318)],
    [Color(0xFF1B0F0A), Color(0xFFE6B66B), Color(0xFF3D1A0E)],
    [Color(0xFF2A1A0D), Color(0xFFF1C57E), Color(0xFF5C2A14)],
    [Color(0xFF181009), Color(0xFFC77859), Color(0xFF2B130A)],
    [Color(0xFF13110D), Color(0xFFA47C40), Color(0xFF3A2515)],
    [Color(0xFF241006), Color(0xFFFAD18D), Color(0xFF7A3A1A)],
    [Color(0xFF1F1408), Color(0xFFD89F4A), Color(0xFF48200D)],
    [Color(0xFF150C07), Color(0xFFB58A4B), Color(0xFF341905)],
    [Color(0xFF2C1A0E), Color(0xFFEFB964), Color(0xFF6E2E14)],
    [Color(0xFF1A0D07), Color(0xFFE8A75A), Color(0xFF522010)],
  ];

  @override
  Widget build(BuildContext context) {
    final pal = _palettes[seed % _palettes.length];
    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: CustomPaint(
        painter: _MoraPhotoPainter(seed, pal, focalX / 100, focalY / 100),
        size: Size.infinite,
      ),
    );
  }
}

class _MoraPhotoPainter extends CustomPainter {
  final int seed;
  final List<Color> palette;
  final double fx;
  final double fy;

  _MoraPhotoPainter(this.seed, this.palette, this.fx, this.fy);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = _Rng(seed * 1973 + 31);
    final base = palette[0];
    final glow = palette[1];
    final lift = palette[2];

    // base fill
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = base);

    // blurred blobs
    final blobCount = 2 + (rng.next() % 3);
    for (int i = 0; i < blobCount; i++) {
      final cx = (10 + rng.next() % 80) / 100 * size.width;
      final cy = (20 + rng.next() % 70) / 100 * size.height;
      final r = (18 + rng.next() % 32) / 100 * size.width;
      final blobColor = i == 0 ? glow : (rng.next() % 2 == 0 ? lift : glow);
      final alpha = (0.35 + (rng.next() % 45) / 100.0);
      final blurPx = (8 + rng.next() % 14).toDouble();

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
      final blurPaint = Paint()
        ..color = blobColor.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurPx);
      canvas.drawCircle(Offset(cx, cy), r, blurPaint);
      canvas.restore();
    }

    // radial gradient overlay
    final gradient = RadialGradient(
      center: Alignment(fx * 2 - 1, fy * 2 - 1),
      radius: 0.75,
      colors: [
        glow.withValues(alpha: 0.35),
        base.withValues(alpha: 0),
        Colors.black.withValues(alpha: 0.45),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    final gradientPaint = Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);

    // vignette
    final vignette = RadialGradient(
      center: Alignment(0, 0),
      radius: 0.75,
      colors: [
        Colors.black.withValues(alpha: 0),
        Colors.black.withValues(alpha: 0.55),
      ],
      stops: const [0.55, 1.0],
    );
    final vignettePaint = Paint()..shader = vignette.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);

    // film grain overlay
    final grainPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.035)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.3);
    for (int i = 0; i < 60; i++) {
      final gx = (rng.next() % 100) / 100 * size.width;
      final gy = (rng.next() % 100) / 100 * size.height;
      canvas.drawCircle(Offset(gx, gy), 0.5, grainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Rng {
  int state;
  _Rng(this.state);

  int next() {
    state += 0x6D2B79F5;
    int t = state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= t + _imul(t ^ (t >>> 7), t | 61);
    return (t ^ (t >>> 14)) & 0x7FFFFFFF;
  }

  static int _imul(int a, int b) {
    final aLow = a & 0xFFFF;
    final aHigh = a >> 16;
    final bLow = b & 0xFFFF;
    final bHigh = b >> 16;
    final product = aLow * bLow + ((aLow * bHigh + aHigh * bLow) << 16);
    return product & 0x7FFFFFFF;
  }
}
