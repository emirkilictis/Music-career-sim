import 'package:flutter/material.dart';

/// One set of app colors. The game has two (docs K41): a vivid navy
/// default and a light theme chosen in Settings.
class Palette {
  const Palette({
    required this.isLight,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.surfaceLow,
    required this.surfaceHighest,
    required this.accentSoft,
    required this.onAccent,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.lilac,
    required this.pink,
    required this.peach,
    required this.mint,
    required this.sky,
    required this.butter,
    required this.coral,
  });

  final bool isLight;
  final Color bg, surface, surfaceHigh, line, surfaceLow, surfaceHighest;
  final Color accentSoft, onAccent;
  final Color text, textMuted, textFaint;
  final Color lilac, pink, peach, mint, sky, butter, coral;

  /// Lighter blue base with saturated accents (the default).
  static const navy = Palette(
    isLight: false,
    bg: Color(0xFF1B2540),
    surface: Color(0xFF263253),
    surfaceHigh: Color(0xFF32406A),
    line: Color(0xFF3D4C78),
    surfaceLow: Color(0xFF16203A),
    surfaceHighest: Color(0xFF3C4B7A),
    accentSoft: Color(0xFF4B4A9C),
    onAccent: Color(0xFF1B1530),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFFBAC4DE),
    textFaint: Color(0xFF8592B3),
    lilac: Color(0xFFA48BFF),
    pink: Color(0xFFFF6BA8),
    peach: Color(0xFFFFA25C),
    mint: Color(0xFF3BE3A4),
    sky: Color(0xFF55BDFF),
    butter: Color(0xFFFFD54F),
    coral: Color(0xFFFF6470),
  );

  /// Light lilac-white base with strong accents.
  static const light = Palette(
    isLight: true,
    bg: Color(0xFFF4F1FB),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEDE8F7),
    line: Color(0xFFDCD5EA),
    surfaceLow: Color(0xFFFFFFFF),
    surfaceHighest: Color(0xFFE3DCF0),
    accentSoft: Color(0xFFE2D9FF),
    onAccent: Color(0xFFFFFFFF),
    text: Color(0xFF1A1530),
    textMuted: Color(0xFF5E5675),
    textFaint: Color(0xFF948CAA),
    lilac: Color(0xFF6D4AFF),
    pink: Color(0xFFE5407E),
    peach: Color(0xFFF2711C),
    mint: Color(0xFF0FA968),
    sky: Color(0xFF1C8FE6),
    butter: Color(0xFFD99A00),
    coral: Color(0xFFE5484D),
  );
}

/// The current app colors ([Palette.navy] unless Settings picked light).
/// Read at build time, so a theme change rebuilds the whole app.
abstract final class AppColors {
  /// Set by [AppSettings] at start and when the theme changes.
  static Palette palette = Palette.navy;
  static Palette get _p => palette;

  static bool get isLight => _p.isLight;
  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get surfaceHigh => _p.surfaceHigh;
  static Color get line => _p.line;
  static Color get surfaceLow => _p.surfaceLow;
  static Color get surfaceHighest => _p.surfaceHighest;
  static Color get accentSoft => _p.accentSoft;
  static Color get onAccent => _p.onAccent;
  static Color get text => _p.text;
  static Color get textMuted => _p.textMuted;
  static Color get textFaint => _p.textFaint;
  static Color get lilac => _p.lilac;
  static Color get pink => _p.pink;
  static Color get peach => _p.peach;
  static Color get mint => _p.mint;
  static Color get sky => _p.sky;
  static Color get butter => _p.butter;
  static Color get coral => _p.coral;

  static const gold = Color(0xFFF2C14E);

  /// Signature gradient (buttons, hero cards).
  static LinearGradient get sunset => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [lilac, pink, peach],
      );

  /// Soft version for large backgrounds.
  static LinearGradient haze(Color a, Color b) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          a.withValues(alpha: isLight ? 0.22 : 0.32),
          b.withValues(alpha: isLight ? 0.08 : 0.10)
        ],
      );
}

/// Streamify (the in-game streaming app): dark, Spotify-like.
abstract final class StreamifyColors {
  static const bg = Color(0xFF121212);
  static const surface = Color(0xFF1A1A1A);
  static const surfaceHigh = Color(0xFF282828);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFB3B3B3);
  static const accent = Color(0xFF2BD97C);
}

/// The chart magazine look: printed-paper white with black type.
abstract final class PaperColors {
  static const bg = Color(0xFFF7F4EF);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF141414);
  static const muted = Color(0xFF6E6A64);
  static const line = Color(0xFFE4DFD7);
  static const up = Color(0xFF1E9E5A);
  static const down = Color(0xFFD4442E);
  static const accent = Color(0xFF3B5BDB);
}

/// Fonts bundled in assets/fonts (SIL OFL).
/// Corner style (docs F1): soft (rounded, default) or sharp (squared, a
/// harder look). Widgets pass their soft radius through [r].
abstract final class AppShape {
  static bool sharp = false;

  /// [soft] in the soft style; at most 4 px in the sharp one.
  static double r(double soft) => sharp && soft > 4 ? 4 : soft;
}

abstract final class AppFonts {
  static const ui = 'Figtree';
  static const condensed = 'BarlowCondensed';
}
