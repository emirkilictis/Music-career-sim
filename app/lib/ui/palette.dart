import 'package:flutter/material.dart';

/// App colors: a soft plum-black base with pastel accents — friendly, but
/// calm enough for long sessions (low contrast surfaces, no pure white).
abstract final class AppColors {
  static const bg = Color(0xFF13111A);
  static const surface = Color(0xFF1C1926);
  static const surfaceHigh = Color(0xFF26222F);
  static const line = Color(0xFF332E3D);

  static const text = Color(0xFFF4F1F8);
  static const textMuted = Color(0xFFA9A2B6);
  static const textFaint = Color(0xFF6F6880);

  static const lilac = Color(0xFFB9A6FF);
  static const pink = Color(0xFFFFA8C5);
  static const peach = Color(0xFFFFC59E);
  static const mint = Color(0xFF9BE7C4);
  static const sky = Color(0xFF9CCBFF);
  static const butter = Color(0xFFFFE29A);
  static const coral = Color(0xFFFF8F8F);

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
        colors: [a.withValues(alpha: 0.32), b.withValues(alpha: 0.10)],
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
