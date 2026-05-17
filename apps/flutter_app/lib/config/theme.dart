import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mora color tokens. Warm darks, warm lights, single amber accent.
/// Never pure black. See DESIGN.md §3.
class MoraColors {
  static const bgBase = Color(0xFF0F0A06);
  static const bgElevated = Color(0xFF1A130C);
  static const bgOverlay = Color(0xFF261C13);
  static const textPrimary = Color(0xFFF5EFE6);
  static const textSecondary = Color(0xFFB8A99A);
  static const textTertiary = Color(0xFF7A6E60);
  static const textDisabled = Color(0xFF4A4138);
  static const accent = Color(0xFFD9A85C);
  static const accentHover = Color(0xFFE6B66B);
  static const accentMuted = Color(0xFF6B5530);
  static const positive = Color(0xFF7FA868);
  static const warning = Color(0xFFD89F4A);
  static const negative = Color(0xFFC77859);
  static const borderSubtle = Color(0x14F5EFE6);
  static const borderEmphasis = Color(0x29F5EFE6);

  // For dark scrim overlays on warm photos
  static const onAccent = Color(0xFF1A0E04);
}

/// Reusable cubic curves from DESIGN.md §6.
class MoraEase {
  static const out = Cubic(0.22, 1, 0.36, 1);
  static const inOut = Cubic(0.65, 0, 0.35, 1);
  static const reveal = Cubic(0.16, 1, 0.3, 1);
}

/// Mora text styles. Display = Fraunces (variable: opsz, SOFT, wght). Body =
/// DM Sans (closest Google Fonts match for Switzer per DESIGN.md §2). Mono =
/// JetBrains Mono.
class MoraText {
  // Variable-font axes used by display styles. Fraunces is loaded as a
  // variable font through google_fonts, so these axes resolve at runtime.
  static const _fraunces144 = [
    FontVariation('opsz', 144),
    FontVariation('SOFT', 100),
    FontVariation('wght', 320),
  ];
  static const _fraunces96 = [
    FontVariation('opsz', 96),
    FontVariation('SOFT', 100),
    FontVariation('wght', 350),
  ];
  static const _fraunces60 = [
    FontVariation('opsz', 60),
    FontVariation('SOFT', 100),
    FontVariation('wght', 350),
  ];

  /// Editorial display. Use for screen titles and hero text.
  /// [hero] enables the largest optical size (opsz 144) for true display use.
  static TextStyle display({
    double size = 28,
    double height = 1.1,
    Color color = MoraColors.textPrimary,
    bool italic = false,
    FontWeight weight = FontWeight.w400,
    bool hero = false,
  }) {
    return GoogleFonts.fraunces(
      textStyle: TextStyle(
        fontSize: size,
        height: height,
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: weight,
        letterSpacing: size * -0.02,
        fontVariations: hero ? _fraunces144 : _fraunces96,
      ),
    );
  }

  /// Sub-deck and mid-size editorial. Slightly looser optical size.
  static TextStyle deck({
    double size = 22,
    double height = 1.2,
    Color color = MoraColors.textSecondary,
    bool italic = false,
  }) {
    return GoogleFonts.fraunces(
      textStyle: TextStyle(
        fontSize: size,
        height: height,
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: FontWeight.w400,
        letterSpacing: size * -0.012,
        fontVariations: _fraunces60,
      ),
    );
  }

  /// Body text (DM Sans as Switzer substitute).
  static TextStyle body({
    double size = 15,
    double height = 1.5,
    Color color = MoraColors.textPrimary,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      height: height,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing ?? -0.01,
    );
  }

  /// Uppercase, tracked label. 11px by default.
  static TextStyle label({
    Color color = MoraColors.textTertiary,
    double size = 11,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      height: 1.2,
      color: color,
      fontWeight: weight,
      letterSpacing: size * 0.12,
    );
  }

  /// Mono — JetBrains Mono. Used sparingly for codes, dates, frame counts.
  static TextStyle mono({
    double size = 13,
    Color color = MoraColors.textSecondary,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.jetBrainsMono(
      textStyle: TextStyle(
        fontSize: size,
        height: 1.2,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  /// The big wordmark "mora" — italic Fraunces at hero scale.
  static TextStyle wordmark({
    double size = 132,
    Color color = MoraColors.textPrimary,
  }) {
    return GoogleFonts.fraunces(
      textStyle: TextStyle(
        fontSize: size,
        height: 0.86,
        color: color,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w300,
        letterSpacing: size * -0.045,
        fontVariations: _fraunces144,
      ),
    );
  }
}

ThemeData moraTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: MoraColors.bgBase,
    colorScheme: const ColorScheme.dark(
      primary: MoraColors.accent,
      surface: MoraColors.bgBase,
      onPrimary: MoraColors.onAccent,
      onSurface: MoraColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: MoraColors.textPrimary,
      elevation: 0,
    ),
  );

  return base.copyWith(
    // Default body font for any widget we don't explicitly restyle.
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
      bodyColor: MoraColors.textPrimary,
      displayColor: MoraColors.textPrimary,
    ),
  );
}
