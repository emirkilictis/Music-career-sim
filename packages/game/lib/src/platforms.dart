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

/// The player's own page on a platform (docs K82).
class PlatformProfile {
  PlatformProfile({
    required this.artistId,
    required this.name,
    required this.followers,
    required this.monthlyListeners,
    required this.verified,
    this.worldRank = 0,
  });
  final int artistId;
  final String name;

  /// Place in the world by listeners on the streaming apps (docs K113;
  /// 0: below the top 500 or not a streaming app).
  final int worldRank;

  /// Followers (subscribers on the video site); null in the download store.
  final double? followers;

  /// On the streaming apps (0 elsewhere).
  final double monthlyListeners;

  /// The blue tick: a known name there.
  final bool verified;
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
    this.profile,
  });

  /// The player's page there (null before a career has a player).
  final PlatformProfile? profile;
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

  /// Followers of [a] on [p] in [year] (docs K82): core fans follow, a
  /// few casual listeners too, more the longer the platform has been
  /// around (full after 4 years). Each platform has its own crowd: the
  /// video site follows music videos, the short-video app charisma, the
  /// second streaming service North America. Null in the download store.
  static double? followers(World w, Artist a, MusicPlatform p, int year) {
    if (!p.openIn(year)) return 0;
    final m = ((year - p.launchYear + 1) / 4).clamp(0.25, 1.0);
    final fans = a.coreFans, cas = a.casual;
    switch (p) {
      case MusicPlatform.fruitTunes:
        return null;
      case MusicPlatform.streamify:
        return (0.85 * fans + 0.05 * cas) * m;
      case MusicPlatform.fruitMusic:
        return (0.25 * fans + 0.02 * cas) *
            m *
            (0.5 + a.regionShare[Region.northAmerica.index]);
      case MusicPlatform.viewTube:
        var videos = 0;
        for (final s in w.songs) {
          if (s.primaryArtistId == a.id && s.videoBudget >= 0) videos++;
        }
        return (0.6 * fans + 0.06 * cas) *
            m *
            (0.8 + 0.4 * math.min(1, videos / 5));
      case MusicPlatform.noiseCloud:
        return (0.1 * fans + 0.008 * cas) * m;
      case MusicPlatform.tikTak:
        return (0.25 * fans + 0.06 * cas) *
            m *
            (0.6 + 0.8 * a.skills.charisma / 100);
    }
  }

  /// Monthly listeners on a streaming app from a week's plays there
  /// (about 12 plays per listener a month; see [Streamify]).
  static double monthlyListeners(MusicPlatform p, double weekPlays) =>
      p == MusicPlatform.streamify || p == MusicPlatform.fruitMusic
          ? weekPlays * 4.3 / 12
          : 0;

  /// Last week's streams of every artist with any, from their songs and
  /// back catalog (kept in the save, unlike the artists' own tally).
  static Map<int, double> weekStreamsByArtist(World w) {
    final out = <int, double>{};
    for (final id in w.activeSongIds) {
      final s = w.songs[id];
      out[s.primaryArtistId] = (out[s.primaryArtistId] ?? 0) +
          w.songWeekStreamsIn(s, ChartMarket.global);
    }
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      if (a.sumDormantRate <= 0) continue;
      var catalog = 0.0;
      for (var k = 0; k < regionCount; k++) {
        catalog += a.sumDormantRate *
            a.catalogFactor *
            a.regionShare[k] *
            w.lastSpa[k];
      }
      out[id] = (out[id] ?? 0) + catalog;
    }
    return out;
  }

  /// [a]'s place among every artist by last week's streams (docs K113),
  /// the way the apps rank monthly listeners; 0 below the top 500.
  static int worldRank(World w, Artist a, [Map<int, double>? streams]) {
    final all = streams ?? weekStreamsByArtist(w);
    final mine = all[a.id] ?? 0;
    if (mine <= 0) return 0;
    var ahead = 0;
    for (final e in all.entries) {
      if (e.key != a.id && e.value > mine) ahead++;
    }
    return ahead < 500 ? ahead + 1 : 0;
  }

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
      profile: player == null
          ? null
          : PlatformProfile(
              artistId: player.id,
              name: player.name,
              followers: followers(w, player, p, year),
              monthlyListeners: monthlyListeners(p, mine),
              worldRank:
                  monthlyListeners(p, mine) > 0 ? worldRank(w, player) : 0,
              verified: player.fame >= 0.1 ||
                  (followers(w, player, p, year) ?? 0) >= 1e5,
            ),
    );
  }
}
