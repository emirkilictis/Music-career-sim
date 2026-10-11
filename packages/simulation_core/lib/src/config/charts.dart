import '../time.dart';
import 'era_table.dart';

enum ChartKind { songs, albums }

/// Which consumption a chart measures.
enum ChartMarket {
  us,
  uk,
  global,
  platformGlobal,
  platformNorthAmerica,
  platformEurope
}

/// A chart definition. Names are fictional (no real chart or platform
/// trademarks); UI text comes from localisation keys.
class ChartDef {
  const ChartDef({
    required this.id,
    required this.key,
    required this.kind,
    required this.market,
    required this.size,
    this.recurrent = false,
    this.startYear = 0,
  });

  /// Stable id (stored in saves). Never renumber.
  final int id;
  final String key;
  final ChartKind kind;
  final ChartMarket market;
  final int size;

  /// Old songs low on the chart drop off (US/UK style rule).
  final bool recurrent;

  /// The chart exists from this year (e.g. streaming platform charts).
  final int startYear;

  bool get isPlatform =>
      market == ChartMarket.platformGlobal ||
      market == ChartMarket.platformNorthAmerica ||
      market == ChartMarket.platformEurope;

  bool activeIn(int week) => GameTime.yearOf(week) >= startYear;
}

abstract final class Charts {
  static const usSongs = 0;
  static const ukSongs = 1;
  static const globalSongs = 2;
  static const usAlbums = 3;
  static const ukAlbums = 4;
  static const globalAlbums = 5;
  static const platformGlobal = 6;
  static const platformNorthAmerica = 7;
  static const platformEurope = 8;

  static const all = <ChartDef>[
    ChartDef(
        id: usSongs,
        key: 'chart.us.songs',
        kind: ChartKind.songs,
        market: ChartMarket.us,
        size: 100,
        recurrent: true),
    ChartDef(
        id: ukSongs,
        key: 'chart.uk.songs',
        kind: ChartKind.songs,
        market: ChartMarket.uk,
        size: 100,
        recurrent: true),
    ChartDef(
        id: globalSongs,
        key: 'chart.global.songs',
        kind: ChartKind.songs,
        market: ChartMarket.global,
        size: 200),
    ChartDef(
        id: usAlbums,
        key: 'chart.us.albums',
        kind: ChartKind.albums,
        market: ChartMarket.us,
        size: 100),
    ChartDef(
        id: ukAlbums,
        key: 'chart.uk.albums',
        kind: ChartKind.albums,
        market: ChartMarket.uk,
        size: 100),
    ChartDef(
        id: globalAlbums,
        key: 'chart.global.albums',
        kind: ChartKind.albums,
        market: ChartMarket.global,
        size: 100),
    ChartDef(
        id: platformGlobal,
        key: 'chart.platform.global',
        kind: ChartKind.songs,
        market: ChartMarket.platformGlobal,
        size: 50,
        startYear: 2009),
    ChartDef(
        id: platformNorthAmerica,
        key: 'chart.platform.na',
        kind: ChartKind.songs,
        market: ChartMarket.platformNorthAmerica,
        size: 50,
        startYear: 2011),
    ChartDef(
        id: platformEurope,
        key: 'chart.platform.europe',
        kind: ChartKind.songs,
        market: ChartMarket.platformEurope,
        size: 50,
        startYear: 2009),
  ];

  static const count = 9;

  /// Song charts whose positions feed back into exposure and dormancy.
  static const mainSongCharts = [usSongs, ukSongs, globalSongs];
  static const mainAlbumCharts = [usAlbums, ukAlbums, globalAlbums];

  /// Song chart rules per market (docs/simulation.md §4).
  static ChartRules songRules(ChartMarket m, int week) {
    final y = GameTime.yearOf(week);
    return switch (m) {
      ChartMarket.us => ChartRules(
          countsDownloads: y >= 2005,
          streamFactor: y < 2007 ? 0.0 : (y < 2012 ? 0.25 : 1.0),
          albumUsesUnits: y >= 2015),
      ChartMarket.uk => ChartRules(
          countsDownloads: y >= 2005,
          streamFactor: y < 2014 ? 0.0 : 1.0,
          albumUsesUnits: y >= 2015),
      _ => ChartRules(
          countsDownloads: y >= 2005,
          streamFactor: y < 2007 ? 0.0 : 1.0,
          albumUsesUnits: y >= 2015),
    };
  }
}
