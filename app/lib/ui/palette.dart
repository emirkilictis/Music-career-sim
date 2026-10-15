import 'package:flutter/material.dart';

/// One set of app colors. The game has two (docs K41, K88): ink (the
/// default) and paper, chosen in Settings. [lilac] is the main accent
/// (the name stays from the first palette).
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

  /// Ink (the default; docs K88): near-black paper, warm white type, one
  /// signal-orange accent and flat, strong category colors. No tints of
  /// blue or lilac: it should read like a music paper, not an app kit.
  static const ink = Palette(
    isLight: false,
    bg: Color(0xFF0E0E0E),
    surface: Color(0xFF171717),
    surfaceHigh: Color(0xFF222222),
    line: Color(0xFF2E2E2E),
    surfaceLow: Color(0xFF0A0A0A),
    surfaceHighest: Color(0xFF2A2A2A),
    accentSoft: Color(0xFF3A1C0E),
    onAccent: Color(0xFF0E0E0E),
    text: Color(0xFFF3F1EC),
    textMuted: Color(0xFFA9A59D),
    textFaint: Color(0xFF6F6B64),
    lilac: Color(0xFFFF5A1F),
    pink: Color(0xFFFF3D6E),
    peach: Color(0xFFFFB020),
    mint: Color(0xFF2BD47D),
    sky: Color(0xFF3FA9FF),
    butter: Color(0xFFFFD233),
    coral: Color(0xFFFF4B3E),
  );

  /// Paper: off-white newsprint, black type, the same signal accent.
  static const light = Palette(
    isLight: true,
    bg: Color(0xFFF2EFE8),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE9E5DC),
    line: Color(0xFFD9D4C9),
    surfaceLow: Color(0xFFFFFFFF),
    surfaceHighest: Color(0xFFE1DCD1),
    accentSoft: Color(0xFFFFE1D4),
    onAccent: Color(0xFFFFFFFF),
    text: Color(0xFF111111),
    textMuted: Color(0xFF57534C),
    textFaint: Color(0xFF8C877E),
    lilac: Color(0xFFE8480C),
    pink: Color(0xFFD92B5A),
    peach: Color(0xFFDB8A00),
    mint: Color(0xFF0E9F5B),
    sky: Color(0xFF1677D2),
    butter: Color(0xFFC79300),
    coral: Color(0xFFD8352A),
  );
}

/// The current app colors ([Palette.ink] unless Settings picked light).
/// Read at build time, so a theme change rebuilds the whole app.
abstract final class AppColors {
  /// Set by [AppSettings] at start and when the theme changes.
  static Palette palette = Palette.ink;
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

  /// The main action fill: flat, one color (docs K88 dropped the
  /// lilac-pink-peach gradient).
  static LinearGradient get sunset => LinearGradient(colors: [lilac, lilac]);

  /// A flat tint of [a] for large backgrounds ([b] is no longer blended
  /// in; kept so callers stay the same).
  static LinearGradient haze(Color a, Color b) {
    final c = a.withValues(alpha: isLight ? 0.14 : 0.18);
    return LinearGradient(colors: [c, c]);
  }
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
  /// The tighter style is the default since docs K88: firm corners, not
  /// razor-sharp and not bubbly.
  static bool sharp = true;

  /// [soft] in the soft style; at most 6 px in the default one.
  static double r(double soft) => sharp && soft > 6 ? 6 : soft;
}

abstract final class AppFonts {
  static const ui = 'Figtree';
  static const condensed = 'BarlowCondensed';
}
