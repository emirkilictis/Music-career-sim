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
  platformEurope,

  /// US radio airplay audience (docs K129).
  usRadio,

  /// US streams, and US download sales (docs K166).
  usStreaming,
  usDigital,

  /// US album copies sold, and US album streams (docs K168).
  usAlbumSales,
  usStreamingAlbums,

  /// US ringtone sales (docs K183).
  usRingtones,

  /// UK radio airplay audience (docs K248).
  ukRadio,
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
    this.endYear = 9999,
    this.retired = false,
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

  /// ...and up to this year (the ringtone chart, docs K183).
  final int endYear;

  /// No longer kept (docs K202): too many charts, and nobody follows the
  /// side ones. The id stays so old saves still read.
  final bool retired;

  bool get isPlatform =>
      market == ChartMarket.platformGlobal ||
      market == ChartMarket.platformNorthAmerica ||
      market == ChartMarket.platformEurope;

  bool activeIn(int week) {
    if (retired) return false;
    final y = GameTime.yearOf(week);
    return y >= startYear && y <= endYear;
  }
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

  /// US radio airplay (docs K129).
  static const usRadio = 9;

  /// The Hot 100's parts (docs K166): streams alone, downloads alone.
  static const usStreaming = 10;
  static const usDigital = 11;

  /// The album chart's parts (docs K168): copies sold alone, streams
  /// alone.
  static const usAlbumSales = 12;
  static const usStreamingAlbums = 13;

  /// Ringtone sales (docs K183), 2004–2010.
  static const usRingtones = 14;

  /// UK radio airplay (docs K248).
  static const ukRadio = 15;

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
        size: 100),
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
    ChartDef(
        id: usRadio,
        key: 'chart.us.radio',
        kind: ChartKind.songs,
        market: ChartMarket.usRadio,
        size: 50),
    ChartDef(
        id: usStreaming,
        key: 'chart.us.streaming',
        kind: ChartKind.songs,
        market: ChartMarket.usStreaming,
        size: 50,
        startYear: 2013,
        retired: true),
    ChartDef(
        id: usDigital,
        key: 'chart.us.digital',
        kind: ChartKind.songs,
        market: ChartMarket.usDigital,
        size: 50,
        startYear: 2005,
        retired: true),
    ChartDef(
        id: usAlbumSales,
        key: 'chart.us.albumSales',
        kind: ChartKind.albums,
        market: ChartMarket.usAlbumSales,
        size: 50,
        startYear: 2015,
        retired: true),
    ChartDef(
        id: usStreamingAlbums,
        key: 'chart.us.streamingAlbums',
        kind: ChartKind.albums,
        market: ChartMarket.usStreamingAlbums,
        size: 50,
        startYear: 2015,
        retired: true),
    ChartDef(
        id: usRingtones,
        key: 'chart.us.ringtones',
        kind: ChartKind.songs,
        market: ChartMarket.usRingtones,
        size: 50,
        startYear: 2004,
        endYear: 2010,
        retired: true),
    // Back with a UK one (docs K248): Emir wanted the radio charts.
    ChartDef(
        id: ukRadio,
        key: 'chart.uk.radio',
        kind: ChartKind.songs,
        market: ChartMarket.ukRadio,
        size: 50),
  ];

  static const count = 16;

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
