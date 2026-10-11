import '../time.dart';

/// Market size and behaviour for one year (US market). Values are weekly.
/// Keyframe years are interpolated linearly; after the last keyframe the
/// market grows slowly towards saturation.
///
/// Numbers are first-pass approximations for calibration (see
/// docs/simulation.md §4 and §14). They are expected to change.
class EraValues {
  const EraValues({
    required this.year,
    required this.streamsWeekly,
    required this.downloadsWeekly,
    required this.physicalSinglesWeekly,
    required this.radioWeekly,
    required this.casualPurchaseRate,
    required this.superfanFactor,
    required this.collectorFactor,
  });

  final double year;

  /// Total on-demand streams per week in the whole market.
  final double streamsWeekly;

  /// Digital track sales per week in the whole market.
  final double downloadsWeekly;

  /// Physical single sales per week in the whole market.
  final double physicalSinglesWeekly;

  /// Total radio audience impressions per week.
  final double radioWeekly;

  /// How willing casual listeners are to buy albums (1.0 = year 2000).
  final double casualPurchaseRate;

  /// How willing core fans are to buy albums (weak era effect).
  final double superfanFactor;

  /// Collector culture: how much extra variants (vinyl, signed, exclusive)
  /// sell to devoted fans. Low in the CD era, high in the vinyl revival.
  final double collectorFactor;

  EraValues lerp(EraValues b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return EraValues(
      year: l(year, b.year),
      streamsWeekly: l(streamsWeekly, b.streamsWeekly),
      downloadsWeekly: l(downloadsWeekly, b.downloadsWeekly),
      physicalSinglesWeekly: l(physicalSinglesWeekly, b.physicalSinglesWeekly),
      radioWeekly: l(radioWeekly, b.radioWeekly),
      casualPurchaseRate: l(casualPurchaseRate, b.casualPurchaseRate),
      superfanFactor: l(superfanFactor, b.superfanFactor),
      collectorFactor: l(collectorFactor, b.collectorFactor),
    );
  }
}

/// Chart rules in force for a given year.
class ChartRules {
  const ChartRules({
    required this.countsDownloads,
    required this.streamFactor,
    required this.albumUsesUnits,
  });

  final bool countsDownloads;

  /// 0 = streams ignored, 1 = full on-demand streaming weight.
  final double streamFactor;

  /// Album chart uses pure sales + TEA + SEA instead of pure sales only.
  final bool albumUsesUnits;
}

class EraTable {
  EraTable(this.keyframes)
      : assert(keyframes.isNotEmpty),
        _cache = {};

  final List<EraValues> keyframes;
  final Map<int, EraValues> _cache;

  /// Values for the year containing [week] (cached per game year).
  EraValues forWeek(int week) {
    final year = GameTime.yearOf(week);
    return _cache.putIfAbsent(year, () => _compute(year.toDouble()));
  }

  EraValues _compute(double year) {
    final first = keyframes.first;
    if (year <= first.year) return first;
    for (var i = 0; i < keyframes.length - 1; i++) {
      final a = keyframes[i], b = keyframes[i + 1];
      if (year <= b.year) return a.lerp(b, (year - a.year) / (b.year - a.year));
    }
    // Projection: +1.5%/year streaming growth, saturating at +40%.
    final last = keyframes.last;
    final yearsAfter = year - last.year;
    final growth = 1.0 + 0.4 * (1.0 - _pow(0.965, yearsAfter));
    return EraValues(
      year: year,
      streamsWeekly: last.streamsWeekly * growth,
      downloadsWeekly: last.downloadsWeekly * _pow(0.97, yearsAfter),
      physicalSinglesWeekly: last.physicalSinglesWeekly,
      radioWeekly: last.radioWeekly,
      casualPurchaseRate: last.casualPurchaseRate,
      superfanFactor: last.superfanFactor,
      collectorFactor: last.collectorFactor,
    );
  }

  static double _pow(double b, double e) {
    var r = 1.0;
    var n = e.floor();
    while (n-- > 0) {
      r *= b;
    }
    return r;
  }

  ChartRules rulesForWeek(int week) {
    final y = GameTime.yearOf(week);
    return ChartRules(
      countsDownloads: y >= 2005,
      streamFactor: y < 2007 ? 0.0 : (y < 2012 ? 0.25 : 1.0),
      albumUsesUnits: y >= 2015,
    );
  }

  /// First-pass US keyframes, 2000 → 2026.
  static EraTable usDefault() => EraTable(const [
        EraValues(
            year: 2000,
            streamsWeekly: 0,
            downloadsWeekly: 0,
            physicalSinglesWeekly: 1.0e6,
            radioWeekly: 6.0e9,
            casualPurchaseRate: 1.00,
            superfanFactor: 1.00,
            collectorFactor: 0.15),
        EraValues(
            year: 2003,
            streamsWeekly: 0,
            downloadsWeekly: 0.4e6,
            physicalSinglesWeekly: 0.3e6,
            radioWeekly: 6.0e9,
            casualPurchaseRate: 0.88,
            superfanFactor: 0.95,
            collectorFactor: 0.15),
        EraValues(
            year: 2005,
            streamsWeekly: 0.05e9,
            downloadsWeekly: 6.8e6,
            physicalSinglesWeekly: 0.1e6,
            radioWeekly: 6.0e9,
            casualPurchaseRate: 0.75,
            superfanFactor: 0.90,
            collectorFactor: 0.15),
        EraValues(
            year: 2008,
            streamsWeekly: 0.2e9,
            downloadsWeekly: 20e6,
            physicalSinglesWeekly: 0.02e6,
            radioWeekly: 6.0e9,
            casualPurchaseRate: 0.55,
            superfanFactor: 0.82,
            collectorFactor: 0.18),
        EraValues(
            year: 2012,
            streamsWeekly: 1.0e9,
            downloadsWeekly: 26e6,
            physicalSinglesWeekly: 0.01e6,
            radioWeekly: 6.0e9,
            casualPurchaseRate: 0.38,
            superfanFactor: 0.75,
            collectorFactor: 0.25),
        EraValues(
            year: 2014,
            streamsWeekly: 3.0e9,
            downloadsWeekly: 21e6,
            physicalSinglesWeekly: 0.01e6,
            radioWeekly: 5.8e9,
            casualPurchaseRate: 0.30,
            superfanFactor: 0.70,
            collectorFactor: 0.40),
        EraValues(
            year: 2016,
            streamsWeekly: 7.0e9,
            downloadsWeekly: 14e6,
            physicalSinglesWeekly: 0.01e6,
            radioWeekly: 5.6e9,
            casualPurchaseRate: 0.22,
            superfanFactor: 0.62,
            collectorFactor: 0.55),
        EraValues(
            year: 2018,
            streamsWeekly: 11e9,
            downloadsWeekly: 8e6,
            physicalSinglesWeekly: 0.01e6,
            radioWeekly: 5.4e9,
            casualPurchaseRate: 0.15,
            superfanFactor: 0.60,
            collectorFactor: 0.75),
        EraValues(
            year: 2020,
            streamsWeekly: 16e9,
            downloadsWeekly: 4e6,
            physicalSinglesWeekly: 0.01e6,
            radioWeekly: 5.0e9,
            casualPurchaseRate: 0.11,
            superfanFactor: 0.64,
            collectorFactor: 0.90),
        EraValues(
            year: 2022,
            streamsWeekly: 21e9,
            downloadsWeekly: 2.6e6,
            physicalSinglesWeekly: 0.01e6,
            radioWeekly: 5.0e9,
            casualPurchaseRate: 0.10,
            superfanFactor: 0.68,
            collectorFactor: 1.00),
        EraValues(
            year: 2024,
            streamsWeekly: 25e9,
            downloadsWeekly: 1.9e6,
            physicalSinglesWeekly: 0.01e6,
            radioWeekly: 5.0e9,
            casualPurchaseRate: 0.10,
            superfanFactor: 0.72,
            collectorFactor: 1.10),
        EraValues(
            year: 2026,
            streamsWeekly: 27e9,
            downloadsWeekly: 1.5e6,
            physicalSinglesWeekly: 0.01e6,
            radioWeekly: 5.0e9,
            casualPurchaseRate: 0.10,
            superfanFactor: 0.72,
            collectorFactor: 1.15),
      ]);
}
