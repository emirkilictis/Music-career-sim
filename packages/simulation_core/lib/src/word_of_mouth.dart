import 'dart:math' as math;

import 'model.dart';
import 'rng.dart';
import 'world.dart';

/// Some good songs catch on slowly by word of mouth (docs K108): more
/// people find them every week for months, the way a sleeper hit climbs
/// the chart long after release. A hidden trait drawn once per song (the
/// better the song, the likelier), so nothing has to be stored.
abstract final class WordOfMouth {
  /// Lift at which the player hears that a song is catching on.
  static const noticed = 0.25;

  /// How far [s] can travel by word of mouth (0: not a sleeper).
  static double potential(World w, Song s) {
    final r = RandomStream.keyed(w.seed, 0, s.id, RngPurpose.wordOfMouth);
    final q = s.quality / 100;
    if (!r.chance(0.03 + 0.07 * q * q)) return 0;
    return r.range(0.4, 1.4);
  }

  /// The exposure lift of [s] [age] weeks after release: slow to build,
  /// at its best around five months, then fading.
  static double lift(World w, Song s, int age) {
    if (age < 0) return 0;
    final p = potential(w, s);
    if (p == 0) return 0;
    return p * (1 - math.exp(-age / 12)) * math.exp(-age / 60);
  }

  /// Whether [s] crossed [noticed] this week.
  static bool catchingOn(World w, Song s, int age) =>
      lift(w, s, age) >= noticed && lift(w, s, age - 1) < noticed;
}
