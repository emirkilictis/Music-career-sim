import 'dart:math' as math;

/// Purposes for keyed random streams. Every random draw in the simulation is
/// keyed by (seed, week, entity, purpose) so results never depend on the order
/// in which entities are processed.
abstract final class RngPurpose {
  static const songQuality = 1;
  static const songTraits = 2;
  static const weeklyNoise = 3;
  static const viral = 4;
  static const aiPlanning = 5;
  static const worldGen = 6;
  static const names = 7;
  static const albumNoise = 8;
  static const botPlayer = 9;
  static const newArtists = 10;
  static const playlist = 11;
  static const songGenres = 12;
  static const criticReview = 13;
  static const opportunity = 14;
  static const tour = 15;
  static const awards = 16;
  static const social = 17;
  static const bots = 18;
  static const pitch = 20;
  static const momentum = 30;
  static const albumLegs = 31;
  static const albumMomentum = 32;
  static const wordOfMouth = 33;
  static const criticPanel = 34;
  static const discover = 35;
}

/// SplitMix64 finalizer. Dart native ints are 64-bit and wrap on overflow.
int mix64(int z) {
  z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
  z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
  return z ^ (z >>> 31);
}

const int _golden = 0x9E3779B97F4A7C15;

/// One uniform draw in [0, 1) for a key: cheaper than a [RandomStream]
/// when a single number is all that is needed (two mixes instead of five).
double keyedUnit(int seed, int week, int entity, int purpose) {
  final k = mix64(seed * _golden ^
      week * 0x632BE59BD9B4E019 ^
      entity * 0x85EBCA77C2B2AE63 ^
      purpose * 0xC2B2AE3D27D4EB4F);
  return (mix64(k + _golden) >>> 11) * (1.0 / 9007199254740992.0);
}

/// Counter-based random stream derived from a key. Cheap to create; create a
/// fresh one per (week, entity, purpose) instead of sharing a global generator.
class RandomStream {
  RandomStream._(this._state);

  factory RandomStream.keyed(int seed, int week, int entity, int purpose) {
    var k = mix64(seed + _golden);
    k = mix64(k ^ (week * 0x632BE59BD9B4E019));
    k = mix64(k ^ (entity * 0x85EBCA77C2B2AE63));
    k = mix64(k ^ (purpose * 0xC2B2AE3D27D4EB4F));
    return RandomStream._(k);
  }

  int _state;
  double? _spareNormal;

  int nextInt64() {
    _state += _golden;
    return mix64(_state);
  }

  /// Uniform double in [0, 1).
  double nextDouble() => (nextInt64() >>> 11) * (1.0 / 9007199254740992.0);

  /// Uniform int in [0, max).
  int nextInt(int max) => (nextDouble() * max).floor();

  double range(double lo, double hi) => lo + (hi - lo) * nextDouble();

  bool chance(double p) => nextDouble() < p;

  /// Standard normal (Box–Muller).
  double nextNormal() {
    final spare = _spareNormal;
    if (spare != null) {
      _spareNormal = null;
      return spare;
    }
    var u1 = nextDouble();
    if (u1 < 1e-300) u1 = 1e-300;
    final u2 = nextDouble();
    final r = math.sqrt(-2.0 * math.log(u1));
    final theta = 2.0 * math.pi * u2;
    _spareNormal = r * math.sin(theta);
    return r * math.cos(theta);
  }

  /// Log-normal noise with median 1.0.
  double logNormal(double sigma) => math.exp(sigma * nextNormal());

  T pick<T>(List<T> items) => items[nextInt(items.length)];
}
