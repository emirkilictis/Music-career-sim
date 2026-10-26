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
  static const resonance = 36;
  static const holiday = 37;
  static const leak = 38;
  static const snippet = 39;
  static const curators = 40;
  static const lineup = 41;
  static const rivalTools = 42;
  static const songMarket = 43;
}

/// A 64-bit constant from its two halves (docs K218): the web build's
/// JavaScript fallback cannot spell such literals; the VM and WebAssembly
/// compute them exactly.
int _u64(int hi, int lo) => (hi << 32) | lo;

final int _mixA = _u64(0xBF58476D, 0x1CE4E5B9);
final int _mixB = _u64(0x94D049BB, 0x133111EB);
final int _golden = _u64(0x9E3779B9, 0x7F4A7C15);
final int _weekK = _u64(0x632BE59B, 0xD9B4E019);
final int _entityK = _u64(0x85EBCA77, 0xC2B2AE63);
final int _purposeK = _u64(0xC2B2AE3D, 0x27D4EB4F);

/// SplitMix64 finalizer. Dart native ints are 64-bit and wrap on overflow.
int mix64(int z) {
  z = (z ^ (z >>> 30)) * _mixA;
  z = (z ^ (z >>> 27)) * _mixB;
  return z ^ (z >>> 31);
}

/// One uniform draw in [0, 1) for a key: cheaper than a [RandomStream]
/// when a single number is all that is needed (two mixes instead of five).
double keyedUnit(int seed, int week, int entity, int purpose) {
  final k = mix64(seed * _golden ^
      week * _weekK ^
      entity * _entityK ^
      purpose * _purposeK);
  return (mix64(k + _golden) >>> 11) * (1.0 / 9007199254740992.0);
}

/// Counter-based random stream derived from a key. Cheap to create; create a
/// fresh one per (week, entity, purpose) instead of sharing a global generator.
class RandomStream {
  RandomStream._(this._state);

  factory RandomStream.keyed(int seed, int week, int entity, int purpose) {
    var k = mix64(seed + _golden);
    k = mix64(k ^ (week * _weekK));
    k = mix64(k ^ (entity * _entityK));
    k = mix64(k ^ (purpose * _purposeK));
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
