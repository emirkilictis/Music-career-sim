import 'package:flutter/material.dart';

/// Theme variant, chosen at build time while we compare looks
/// (`--dart-define=APP_THEME=plum|navy|light`).
const _theme = String.fromEnvironment('APP_THEME', defaultValue: 'plum');
const _navy = _theme == 'navy';
const _light = _theme == 'light';

/// App colors. Three looks are being compared (feedback: "too dark, too
/// sleepy"): plum (dark, pastel), navy (lighter blue base, vivid accents)
/// and light.
abstract final class AppColors {
  static const isLight = _light;

  static const bg = _light
      ? Color(0xFFF4F1FB)
      : _navy
          ? Color(0xFF1B2540)
          : Color(0xFF13111A);
  static const surface = _light
      ? Color(0xFFFFFFFF)
      : _navy
          ? Color(0xFF263253)
          : Color(0xFF1C1926);
  static const surfaceHigh = _light
      ? Color(0xFFEDE8F7)
      : _navy
          ? Color(0xFF32406A)
          : Color(0xFF26222F);
  static const line = _light
      ? Color(0xFFDCD5EA)
      : _navy
          ? Color(0xFF3D4C78)
          : Color(0xFF332E3D);

  /// Darker than [bg] (nav bar) and the strongest raised surface.
  static const surfaceLow = _light
      ? Color(0xFFFFFFFF)
      : _navy
          ? Color(0xFF16203A)
          : Color(0xFF17151F);
  static const surfaceHighest = _light
      ? Color(0xFFE3DCF0)
      : _navy
          ? Color(0xFF3C4B7A)
          : Color(0xFF2E2938);

  /// Selected chip / segment / nav indicator.
  static const accentSoft = _light
      ? Color(0xFFE2D9FF)
      : _navy
          ? Color(0xFF4B4A9C)
          : Color(0xFF3A3058);

  /// Text on accent-colored buttons.
  static const onAccent = _light ? Color(0xFFFFFFFF) : Color(0xFF1B1530);

  static const text = _light
      ? Color(0xFF1A1530)
      : _navy
          ? Color(0xFFFFFFFF)
          : Color(0xFFF4F1F8);
  static const textMuted = _light
      ? Color(0xFF5E5675)
      : _navy
          ? Color(0xFFBAC4DE)
          : Color(0xFFA9A2B6);
  static const textFaint = _light
      ? Color(0xFF948CAA)
      : _navy
          ? Color(0xFF8592B3)
          : Color(0xFF6F6880);

  static const lilac = _light
      ? Color(0xFF6D4AFF)
      : _navy
          ? Color(0xFFA48BFF)
          : Color(0xFFB9A6FF);
  static const pink = _light
      ? Color(0xFFE5407E)
      : _navy
          ? Color(0xFFFF6BA8)
          : Color(0xFFFFA8C5);
  static const peach = _light
      ? Color(0xFFF2711C)
      : _navy
          ? Color(0xFFFFA25C)
          : Color(0xFFFFC59E);
  static const mint = _light
      ? Color(0xFF0FA968)
      : _navy
          ? Color(0xFF3BE3A4)
          : Color(0xFF9BE7C4);
  static const sky = _light
      ? Color(0xFF1C8FE6)
      : _navy
          ? Color(0xFF55BDFF)
          : Color(0xFF9CCBFF);
  static const butter = _light
      ? Color(0xFFD99A00)
      : _navy
          ? Color(0xFFFFD54F)
          : Color(0xFFFFE29A);
  static const coral = _light
      ? Color(0xFFE5484D)
      : _navy
          ? Color(0xFFFF6470)
          : Color(0xFFFF8F8F);

  static const gold = Color(0xFFF2C14E);

  /// Signature gradient (buttons, hero cards).
  static const sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lilac, pink, peach],
  );

  /// Soft version for large backgrounds.
  static LinearGradient haze(Color a, Color b) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          a.withValues(alpha: _light ? 0.22 : 0.32),
          b.withValues(alpha: _light ? 0.08 : 0.10)
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
abstract final class AppFonts {
  static const ui = 'Figtree';
  static const condensed = 'BarlowCondensed';
}
