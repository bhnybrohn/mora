import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

class MoraIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const MoraIcon(this.name, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? MoraColors.textPrimary;
    return SizedBox(width: size, height: size, child: _build(c));
  }

  Widget _build(Color c) {
    switch (name) {
      case 'frame-mark':
        return CustomPaint(painter: _FrameMarkPainter(c), size: Size(size, size));
      case 'asterisk':
        return CustomPaint(painter: _AsteriskPainter(c), size: Size(size, size));
      case 'chevron-left':
        return Icon(Icons.chevron_left, size: size, color: c);
      case 'chevron-right':
        return Icon(Icons.chevron_right, size: size, color: c);
      case 'close':
        return Icon(Icons.close, size: size, color: c);
      case 'check':
        return Icon(Icons.check, size: size, color: c);
      case 'share':
        return Icon(Icons.ios_share, size: size, color: c);
      case 'whatsapp':
        return _WhatsAppIcon(c, size);
      case 'copy':
        return Icon(Icons.copy_rounded, size: size, color: c);
      case 'flash':
        return Icon(Icons.flash_on_rounded, size: size, color: c);
      case 'flip-camera':
        return Icon(Icons.flip_camera_android_rounded, size: size, color: c);
      case 'people':
        return Icon(Icons.people_outline_rounded, size: size, color: c);
      case 'clock':
        return Icon(Icons.access_time_rounded, size: size, color: c);
      case 'download':
        return Icon(Icons.download_rounded, size: size, color: c);
      case 'film':
        return Icon(Icons.movie_creation_outlined, size: size, color: c);
      case 'apple':
        return Icon(Icons.apple, size: size, color: c);
      case 'google':
        return _GoogleIcon(c, size);
      case 'phone':
        return Icon(Icons.phone_rounded, size: size, color: c);
      default:
        return SizedBox.shrink();
    }
  }
}

class _FrameMarkPainter extends CustomPainter {
  final Color color;
  _FrameMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final s = size.width;
    final halfUnit = s / 24;

    // perforation tab
    final tab = RRect.fromRectAndRadius(
      Rect.fromLTWH(6 * halfUnit, 4 * halfUnit, 12 * halfUnit, 2.4 * halfUnit),
      Radius.circular(1.1 * halfUnit),
    );
    canvas.drawRRect(tab, paint..color = color.withValues(alpha: 0.45));

    // frame
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(4.75 * halfUnit, 7.5 * halfUnit, 14.5 * halfUnit, 13 * halfUnit),
      Radius.circular(2.5 * halfUnit),
    );
    canvas.drawRRect(frame, paint..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5 * halfUnit);

    // exposure dot
    canvas.drawCircle(Offset(12 * halfUnit, 14 * halfUnit), 2.1 * halfUnit, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AsteriskPainter extends CustomPainter {
  final Color color;
  _AsteriskPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = size.width / 24;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.37;
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), paint);
    canvas.drawLine(Offset(cx - r * 0.95, cy - r * 0.4), Offset(cx + r * 0.95, cy + r * 0.4), paint);
    canvas.drawLine(Offset(cx + r * 0.95, cy - r * 0.4), Offset(cx - r * 0.95, cy + r * 0.4), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoogleIcon extends StatelessWidget {
  final Color color;
  final double size;
  _GoogleIcon(this.color, this.size);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GooglePainter(),
        size: Size(size, size),
      ),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final h = s / 2;
    final r = s * 0.36;

    // G letter approximation with colored arcs
    final blue = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.stroke..strokeWidth = s * 0.12..strokeCap = StrokeCap.round;
    final green = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.stroke..strokeWidth = s * 0.12..strokeCap = StrokeCap.round;
    final yellow = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.stroke..strokeWidth = s * 0.12..strokeCap = StrokeCap.round;
    final red = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.stroke..strokeWidth = s * 0.12..strokeCap = StrokeCap.round;

    // Blue circle (left side)
    canvas.drawArc(Rect.fromCircle(center: Offset(h, h), radius: r), -1.2, 2.8, false, blue);
    // Green down-right stroke
    canvas.drawArc(Rect.fromCircle(center: Offset(h, h), radius: r), 0.2, 1.0, false, green);
    // Yellow
    canvas.drawArc(Rect.fromCircle(center: Offset(h, h), radius: r), 1.2, 1.0, false, yellow);
    // Red
    canvas.drawArc(Rect.fromCircle(center: Offset(h, h), radius: r), -1.2, 0.6, false, red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WhatsAppIcon extends StatelessWidget {
  final Color color;
  final double size;
  _WhatsAppIcon(this.color, this.size);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WhatsAppPainter(color),
        size: Size(size, size),
      ),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  final Color color;
  _WhatsAppPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = size.width / 16..strokeCap = StrokeCap.round;
    final h = size.width / 2;
    final r = size.width * 0.4;

    // chat bubble
    canvas.drawArc(Rect.fromCircle(center: Offset(h, h), radius: r), 0.3, 5.2, false, paint);
    // phone icon inside
    final t = size.width * 0.2;
    canvas.drawLine(Offset(h - t * 0.4, h - t * 0.2), Offset(h + t * 0.4, h + t * 0.2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
