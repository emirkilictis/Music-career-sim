import 'dart:math' as math;

import 'package:simulation_core/simulation_core.dart';

import 'views.dart';

/// What a platform counts.
enum PlatformMetric { downloads, views, plays, videos }

/// The music platforms (docs K67), fictional names for the real services,
/// each opening in its real launch year. They split numbers the simulation
/// already has (streams, downloads, viral trends); nothing here changes the
/// weekly simulation.
enum MusicPlatform {
  /// The download store (iTunes): North America from 2003, everywhere 2004.
  fruitTunes(2003, PlatformMetric.downloads),

  /// The video site (YouTube): music videos and plays of songs.
  viewTube(2005, PlatformMetric.views),

  /// The audio-sharing site (SoundCloud): where smaller artists get heard.
  noiseCloud(2008, PlatformMetric.plays),

  /// The big streaming app (Spotify); has its own screen and charts.
  streamify(2009, PlatformMetric.plays),

  /// The second streaming service (Apple Music), strongest in North
  /// America.
  fruitMusic(2015, PlatformMetric.plays),

  /// The short-video app (TikTok): the sounds people make videos with.
  tikTak(2018, PlatformMetric.videos);

  const MusicPlatform(this.launchYear, this.metric);
  final int launchYear;
  final PlatformMetric metric;

  String get displayName => switch (this) {
        fruitTunes => 'Fruit Tunes',
        viewTube => 'ViewTube',
        noiseCloud => 'NoiseCloud',
        streamify => 'Streamify',
        fruitMusic => 'Fruit Music',
        tikTak => 'TikTak',
      };

  bool openIn(int year) => year >= launchYear;

  /// Share of all on-demand streams played here in [year]. Streamify keeps
  /// its 45% (see [Streamify.share]); the video site carries streaming
  /// before it and gives way to the second service after 2015.
  double streamShare(int year) {
    if (!openIn(year)) return 0;
    final second =
        year < 2015 ? 0.0 : math.min(0.2, 0.05 + 0.05 * (year - 2015));
    return switch (this) {
      streamify => Streamify.share,
      fruitMusic => second,
      noiseCloud => year < 2009 ? 0.15 : (year < 2015 ? 0.08 : 0.05),
      viewTube => year < 2008
          ? 1.0
          : year < 2009
              ? 0.85
              : year < 2015
                  ? 0.47
                  : 0.5 - second,
      _ => 0,
    };
  }

  /// Share of all track downloads sold here.
  double downloadShare(int year, Region r) => this != fruitTunes
      ? 0
      : year < 2003 || (year == 2003 && r != Region.northAmerica)
          ? 0
          : 0.75;
}

/// One song on a platform chart.
class PlatformRow {
  PlatformRow({
    required this.position,
    required this.songId,
    required this.title,
    required this.artistId,
    required this.artistName,
    required this.coverAlbumId,
    required this.value,
    required this.isPlayer,
  });
  final int position;
  final int songId;
  final String title;
  final int artistId;
  final String artistName;
  final int coverAlbumId;

  /// This week's downloads, views, plays or new videos here.
  final double value;
  final bool isPlayer;
}

/// A platform this week: its Top 50 and the player's numbers there.
class PlatformView {
  PlatformView({
    required this.platform,
    required this.week,
    required this.rows,
    required this.playerWeek,
    required this.playerBestSongId,
    required this.playerBestTitle,
    required this.playerBestValue,
  });
  final MusicPlatform platform;

  /// The week the numbers are from.
  final int week;
  final List<PlatformRow> rows;

  /// The player's total there this week.
  final double playerWeek;

  /// The player's biggest song there this week (-1: none).
  final int playerBestSongId;
  final String playerBestTitle;
  final double playerBestValue;
}

abstract final class Platforms {
  static const chartSize = 50;

  /// Platforms open in [year], in launch order.
  static List<MusicPlatform> openIn(int year) => [
        for (final p in MusicPlatform.values)
          if (p.openIn(year)) p
      ];

  /// What [s] did on [p] last week.
  static double songWeek(World w, MusicPlatform p, Song s, int year) {
    final a = w.primaryOf(s);
    switch (p) {
      case MusicPlatform.fruitTunes:
        var d = 0.0;
        final wr = s.weekRegion;
        for (final r in Region.values) {
          final dl = wr == null
              ? s.weekDownloads * a.regionShare[r.index]
              : wr[regionCount + r.index];
          d += dl * p.downloadShare(year, r);
        }
        return d;
      case MusicPlatform.viewTube:
        // Songs with a music video get watched far more there.
        return w.songWeekStreamsIn(s, ChartMarket.global) *
            p.streamShare(year) *
            (0.6 + 2 * s.videoPower);
      case MusicPlatform.noiseCloud:
        // Discovery: smaller artists punch above their weight.
        return w.songWeekStreamsIn(s, ChartMarket.global) *
            p.streamShare(year) *
            (1.6 - a.fame);
      case MusicPlatform.streamify:
        return w.songWeekStreamsIn(s, ChartMarket.global) * p.streamShare(year);
      case MusicPlatform.fruitMusic:
        final na = w.songWeekStreamsRegion(s, Region.northAmerica.index);
        final all = w.songWeekStreamsIn(s, ChartMarket.global);
        return (1.4 * na + 0.7 * (all - na)) * p.streamShare(year);
      case MusicPlatform.tikTak:
        // New videos made with the sound this week.
        if (s.viralBoost < 0.002) return 0;
        return s.viralBoost * 4e6 * (0.5 + s.virality);
    }
  }

  /// [p] last week: Top 50 songs and the player's numbers.
  static PlatformView view(World w, MusicPlatform p) {
    final week = w.week - 1;
    final year = GameTime.yearOf(week);
    final player = w.player;
    final scored = <(Song, double)>[];
    var mine = 0.0, best = -1, bestValue = 0.0;
    for (final id in w.activeSongIds) {
      final s = w.songs[id];
      final v = songWeek(w, p, s, year);
      if (v <= 0) continue;
      scored.add((s, v));
      if (player != null && s.primaryArtistId == player.id) {
        mine += v;
        if (v > bestValue) {
          bestValue = v;
          best = s.id;
        }
      }
    }
    scored.sort((x, y) {
      final d = y.$2.compareTo(x.$2);
      return d != 0 ? d : x.$1.id.compareTo(y.$1.id);
    });
    return PlatformView(
      platform: p,
      week: week,
      rows: [
        for (final (i, (s, v)) in scored.take(chartSize).indexed)
          PlatformRow(
            position: i + 1,
            songId: s.id,
            title: s.title,
            artistId: s.primaryArtistId,
            artistName: w.artists[s.primaryArtistId].name,
            coverAlbumId: coverAlbumOf(w, s),
            value: v,
            isPlayer: s.primaryArtistId == w.playerArtistId,
          ),
      ],
      playerWeek: mine,
      playerBestSongId: best,
      playerBestTitle: best >= 0 ? w.songs[best].title : '',
      playerBestValue: bestValue,
    );
  }
}
