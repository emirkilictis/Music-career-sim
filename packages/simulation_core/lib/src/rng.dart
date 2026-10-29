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
  static const catalogDrift = 44;
  static const beef = 50;
  static const comments = 52;
  static const moments = 54;
  static const catalogTrend = 56;
}

/// Numbers are JavaScript doubles: the web build's fallback for browsers
/// without WebAssembly GC (docs K236). 64-bit words then go through
/// [Word64]; the VM and WebAssembly use native ints. Both give the same
/// numbers.
const bool jsNumbers = identical(0, 0.0);

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

final _wGolden = Word64(0x9E3779B9, 0x7F4A7C15);
final _wWeekK = Word64(0x632BE59B, 0xD9B4E019);
final _wEntityK = Word64(0x85EBCA77, 0xC2B2AE63);
final _wPurposeK = Word64(0xC2B2AE3D, 0x27D4EB4F);

/// SplitMix64 finalizer. Dart native ints are 64-bit and wrap on overflow.
int mix64(int z) {
  z = (z ^ (z >>> 30)) * _mixA;
  z = (z ^ (z >>> 27)) * _mixB;
  return z ^ (z >>> 31);
}

/// One uniform draw in [0, 1) for a key: cheaper than a [RandomStream]
/// when a single number is all that is needed (two mixes instead of five).
double keyedUnit(int seed, int week, int entity, int purpose) {
  if (jsNumbers) return Word64.keyedUnit(seed, week, entity, purpose);
  final k = mix64(seed * _golden ^
      week * _weekK ^
      entity * _entityK ^
      purpose * _purposeK);
  return (mix64(k + _golden) >>> 11) * (1.0 / 9007199254740992.0);
}

/// An unsigned 64-bit word as two 32-bit halves, for numbers that are
/// doubles (docs K236). Every step stays below 2^53, so the results match
/// native 64-bit ints bit for bit.
class Word64 {
  Word64(this.hi, this.lo);

  /// [v] as a 64-bit two's complement word (|v| < 2^53).
  Word64.of(int v)
      : lo = v & 0xFFFFFFFF,
        hi = ((v - (v & 0xFFFFFFFF)) ~/ 0x100000000) & 0xFFFFFFFF;

  int hi, lo;

  static const _2p32 = 0x100000000;

  // `& 0xFFFFFFFF` is mod 2^32 for any int below 2^53, natively and as a
  // JavaScript double, and much faster than `%` there.

  /// The low 32 bits of a * b, for a, b < 2^32.
  static int _mulLo(int a, int b) {
    final a0 = a & 0xFFFF, b0 = b & 0xFFFF;
    return (a0 * b0 + ((((a >>> 16) * b0 + a0 * (b >>> 16)) & 0xFFFF) << 16)) &
        0xFFFFFFFF;
  }

  /// this *= b (mod 2^64).
  void mul(Word64 b) => _mul(b.hi, b.lo);

  void _mul(int bh, int bl) {
    final l = lo;
    final a0 = l & 0xFFFF, a1 = l >>> 16, b0 = bl & 0xFFFF, b1 = bl >>> 16;
    final p00 = a0 * b0, p01 = a0 * b1, p10 = a1 * b0;
    final mid = (p00 >>> 16) + (p01 & 0xFFFF) + (p10 & 0xFFFF);
    final carry = (mid >>> 16) + (p01 >>> 16) + (p10 >>> 16) + a1 * b1;
    hi = (carry + _mulLo(hi, bl) + _mulLo(l, bh)) & 0xFFFFFFFF;
    lo = ((mid & 0xFFFF) * 0x10000 + (p00 & 0xFFFF));
  }

  /// this += b (mod 2^64).
  void add(Word64 b) {
    final l = lo + b.lo;
    final c = l >= _2p32 ? 1 : 0;
    lo = l & 0xFFFFFFFF;
    hi = (hi + b.hi + c) & 0xFFFFFFFF;
  }

  /// this ^= b.
  void xor(Word64 b) {
    hi ^= b.hi;
    lo ^= b.lo;
  }

  /// this ^= this >>> n (0 < n < 32).
  void xorShr(int n) {
    lo ^= (hi & ((1 << n) - 1)) * (1 << (32 - n)) + (lo >>> n);
    hi ^= hi >>> n;
  }

  /// this ^= this >> n, the sign kept (0 < n < 32).
  void xorSar(int n) {
    final up = 1 << (32 - n);
    final sign = hi >= 0x80000000 ? _2p32 - up : 0;
    lo ^= (hi & ((1 << n) - 1)) * up + (lo >>> n);
    hi ^= (hi >>> n) + sign;
  }

  /// [mix64] in place.
  void mix() {
    xorShr(30);
    _mul(0xBF58476D, 0x1CE4E5B9);
    xorShr(27);
    _mul(0x94D049BB, 0x133111EB);
    xorShr(31);
  }

  /// (this >>> 11) / 2^53: a uniform double in [0, 1).
  double unit() =>
      (hi * 0x200000 + (lo >>> 11)) * (1.0 / 9007199254740992.0);

  /// The word as a native int (the VM only: tests).
  int toInt() => (hi << 32) | lo;

  static Word64 _times(int v, Word64 k) => Word64.of(v)..mul(k);

  /// [keyedUnit] on halves.
  static double keyedUnit(int seed, int week, int entity, int purpose) {
    final k = _times(seed, _wGolden)
      ..xor(_times(week, _wWeekK))
      ..xor(_times(entity, _wEntityK))
      ..xor(_times(purpose, _wPurposeK))
      ..mix()
      ..add(_wGolden)
      ..mix();
    return k.unit();
  }

  /// [RandomStream.keyed]'s starting state on halves.
  static Word64 keyed(int seed, int week, int entity, int purpose) =>
      (Word64.of(seed)..add(_wGolden)..mix())
        ..xor(_times(week, _wWeekK))
        ..mix()
        ..xor(_times(entity, _wEntityK))
        ..mix()
        ..xor(_times(purpose, _wPurposeK))
        ..mix();
}

/// Counter-based random stream derived from a key. Cheap to create; create a
/// fresh one per (week, entity, purpose) instead of sharing a global generator.
class RandomStream {
  RandomStream._(this._state) : _word = null;
  RandomStream._word(Word64 w)
      : _state = 0,
        _word = w;

  factory RandomStream.keyed(int seed, int week, int entity, int purpose) {
    if (jsNumbers) return RandomStream.onHalves(seed, week, entity, purpose);
    var k = mix64(seed + _golden);
    k = mix64(k ^ (week * _weekK));
    k = mix64(k ^ (entity * _entityK));
    k = mix64(k ^ (purpose * _purposeK));
    return RandomStream._(k);
  }

  /// The JavaScript path, which tests also run on the VM (docs K236).
  factory RandomStream.onHalves(int seed, int week, int entity, int purpose) =>
      RandomStream._word(Word64.keyed(seed, week, entity, purpose));

  int _state;

  /// The state on halves (docs K236).
  final Word64? _word;
  static final _draw = Word64(0, 0);
  double? _spareNormal;

  /// Uniform double in [0, 1).
  double nextDouble() {
    final w = _word;
    if (w != null) {
      w.add(_wGolden);
      return (_draw
            ..hi = w.hi
            ..lo = w.lo
            ..mix())
          .unit();
    }
    _state += _golden;
    return (mix64(_state) >>> 11) * (1.0 / 9007199254740992.0);
  }

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
