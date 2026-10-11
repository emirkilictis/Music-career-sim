import '../time.dart';
import 'era_table.dart';

/// Simulation regions (docs/game-design.md §11.1). "Other" groups Latin
/// America, Asia, Oceania and Africa; it can be split later in config.
enum Region { northAmerica, europe, other }

const int regionCount = 3;

/// Where an artist is from. Drives their home region and the "home country"
/// bonus on country charts.
enum HomeCountry { us, canada, uk, europe, other }

extension HomeCountryRegion on HomeCountry {
  Region get region => switch (this) {
        HomeCountry.us || HomeCountry.canada => Region.northAmerica,
        HomeCountry.uk || HomeCountry.europe => Region.europe,
        HomeCountry.other => Region.other,
      };
}

/// Regional market multipliers relative to the US era table, by year.
class RegionalFactors {
  const RegionalFactors(this.year,
      {required this.streams,
      required this.downloads,
      required this.physical,
      required this.radio,
      required this.casual,
      required this.superfan,
      required this.collector});

  final double year;
  final double streams;
  final double downloads;
  final double physical;
  final double radio;
  final double casual;
  final double superfan;
  final double collector;

  RegionalFactors lerp(RegionalFactors b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return RegionalFactors(l(year, b.year),
        streams: l(streams, b.streams),
        downloads: l(downloads, b.downloads),
        physical: l(physical, b.physical),
        radio: l(radio, b.radio),
        casual: l(casual, b.casual),
        superfan: l(superfan, b.superfan),
        collector: l(collector, b.collector));
  }
}

class RegionConfig {
  const RegionConfig({
    required this.factors,
    required this.outsideAttention,
    required this.outsideDownloads,
    required this.globalReach,
  });

  /// Keyframes; interpolated, held constant after the last one.
  final List<RegionalFactors> factors;

  /// Share of the region's market taken by repertoire we do not simulate
  /// (local artists, long tail), as a multiple of simulated attention.
  final double outsideAttention;
  final double outsideDownloads;

  /// Where an internationally famous artist's audience ends up.
  final double globalReach;
}

/// First-pass values; calibrated in Phase 0 (docs/phase0-status.md).
const Map<Region, RegionConfig> regionConfigs = {
  // US + Canada ≈ US × 1.11.
  Region.northAmerica: RegionConfig(
    factors: [
      RegionalFactors(2000,
          streams: 1.11,
          downloads: 1.11,
          physical: 1.11,
          radio: 1.10,
          casual: 1.0,
          superfan: 1.0,
          collector: 1.0),
    ],
    outsideAttention: 0.35,
    outsideDownloads: 1.2,
    globalReach: 0.42,
  ),
  // Earlier streaming adoption, physical singles and CDs held on longer.
  Region.europe: RegionConfig(
    factors: [
      RegionalFactors(2000,
          streams: 0.5,
          downloads: 0.4,
          physical: 2.0,
          radio: 1.2,
          casual: 1.05,
          superfan: 1.0,
          collector: 0.9),
      RegionalFactors(2010,
          streams: 0.9,
          downloads: 0.45,
          physical: 1.5,
          radio: 1.2,
          casual: 1.2,
          superfan: 1.0,
          collector: 0.9),
      RegionalFactors(2016,
          streams: 0.9,
          downloads: 0.5,
          physical: 1.5,
          radio: 1.2,
          casual: 1.5,
          superfan: 1.0,
          collector: 0.9),
      RegionalFactors(2024,
          streams: 0.85,
          downloads: 0.5,
          physical: 1.5,
          radio: 1.2,
          casual: 1.6,
          superfan: 1.0,
          collector: 0.9),
    ],
    outsideAttention: 0.9,
    outsideDownloads: 1.5,
    globalReach: 0.33,
  ),
  // Huge streaming volumes late, strong collectors (Japan/Korea), lots of
  // local repertoire.
  Region.other: RegionConfig(
    factors: [
      RegionalFactors(2000,
          streams: 0.1,
          downloads: 0.1,
          physical: 1.0,
          radio: 2.0,
          casual: 0.8,
          superfan: 0.7,
          collector: 1.2),
      RegionalFactors(2010,
          streams: 0.3,
          downloads: 0.3,
          physical: 1.0,
          radio: 2.0,
          casual: 0.8,
          superfan: 0.7,
          collector: 1.2),
      RegionalFactors(2016,
          streams: 0.8,
          downloads: 0.3,
          physical: 1.0,
          radio: 2.0,
          casual: 0.8,
          superfan: 0.7,
          collector: 1.2),
      RegionalFactors(2020,
          streams: 1.3,
          downloads: 0.3,
          physical: 1.0,
          radio: 2.0,
          casual: 0.8,
          superfan: 0.7,
          collector: 1.2),
      RegionalFactors(2024,
          streams: 1.6,
          downloads: 0.3,
          physical: 1.0,
          radio: 2.0,
          casual: 0.8,
          superfan: 0.7,
          collector: 1.2),
    ],
    outsideAttention: 3.0,
    outsideDownloads: 3.0,
    globalReach: 0.25,
  ),
};

/// Genre strength per region [NA, Europe, Other] (renormalised per artist).
const List<List<double>> genreRegionAffinity = [
  [1.0, 1.0, 1.0], // Pop
  [1.3, 0.8, 0.8], // Hip-Hop
  [1.2, 0.9, 0.8], // R&B
  [1.0, 1.2, 0.8], // Rock
  [1.8, 0.4, 0.3], // Country
  [0.8, 1.4, 1.0], // Dance
  [0.9, 0.7, 2.2], // Latin
  [1.0, 1.2, 0.6], // Indie
];

/// Country charts are a share of their region's consumption, with a home
/// bonus (docs/game-design.md §11.1).
abstract final class CountryShares {
  static double usOfNorthAmerica(HomeCountry home) => switch (home) {
        HomeCountry.us => 0.92,
        HomeCountry.canada => 0.75,
        _ => 0.89,
      };

  static double ukOfEurope(HomeCountry home) => switch (home) {
        HomeCountry.uk => 0.35,
        HomeCountry.europe => 0.10,
        _ => 0.16,
      };
}

/// Regional era values: the US table scaled by regional factors.
class RegionalEra {
  RegionalEra(this.base);

  final EraTable base;
  final Map<int, List<EraValues>> _cache = {};

  /// Values for each region for the game year containing [week].
  List<EraValues> forWeek(int week) {
    final year = GameTime.yearOf(week);
    return _cache.putIfAbsent(year, () {
      final us = base.forWeek(week);
      return [
        for (final r in Region.values) _scale(us, _factors(r, year.toDouble())),
      ];
    });
  }

  static RegionalFactors _factors(Region r, double year) {
    final ks = regionConfigs[r]!.factors;
    if (year <= ks.first.year) return ks.first;
    for (var i = 0; i < ks.length - 1; i++) {
      if (year <= ks[i + 1].year) {
        return ks[i].lerp(
            ks[i + 1], (year - ks[i].year) / (ks[i + 1].year - ks[i].year));
      }
    }
    return ks.last;
  }

  static EraValues _scale(EraValues v, RegionalFactors f) => EraValues(
        year: v.year,
        streamsWeekly: v.streamsWeekly * f.streams,
        downloadsWeekly: v.downloadsWeekly * f.downloads,
        physicalSinglesWeekly: v.physicalSinglesWeekly * f.physical,
        radioWeekly: v.radioWeekly * f.radio,
        casualPurchaseRate: v.casualPurchaseRate * f.casual,
        superfanFactor: v.superfanFactor * f.superfan,
        collectorFactor: v.collectorFactor * f.collector,
      );
}
