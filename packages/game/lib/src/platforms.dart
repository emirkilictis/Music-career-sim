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
  /// its 60% (see [Streamify.share]); the video site carries streaming
  /// before it and gives way to the second service after 2015. Cut by 15
  /// points in docs K207: the video site and the rest added too much.
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
                  ? 0.32
                  : 0.35 - second,
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

/// A music video on the video site (docs K118).
class VideoRow {
  VideoRow.of(World w, Song s, this.views)
      : songId = s.id,
        title = s.title,
        artistName = w.artists[s.primaryArtistId].name,
        albumId = coverAlbumOf(w, s),
        hasVideo = s.videoBudget >= 0,
        isPlayer = s.primaryArtistId == w.playerArtistId;
  final int songId;
  final String title;
  final String artistName;
  final int albumId;

  /// All-time views (an official video, or audio and lyric uploads).
  final double views;
  final bool hasVideo;
  final bool isPlayer;
}

/// A song in the streaming app's Billions Club (docs K132).
class BillionsRow {
  BillionsRow.of(World w, Song s, this.plays)
      : songId = s.id,
        title = s.title,
        artistId = s.primaryArtistId,
        artistName = w.artists[s.primaryArtistId].name,
        coverAlbumId = coverAlbumOf(w, s),
        releasedWeek = s.releasedWeek,
        isPlayer = s.primaryArtistId == w.playerArtistId;
  final int songId;
  final String title;
  final int artistId;
  final String artistName;
  final int coverAlbumId;
  final int releasedWeek;

  /// All-time plays on the app.
  final double plays;
  final bool isPlayer;
}

abstract final class Platforms {
  static const chartSize = 50;

  /// Play counts on the streaming app the news reports (docs K132), and
  /// the Billions Club.
  static const playMilestones = [1e8, 5e8, 1e9, 2e9, 3e9, 5e9];
  static const billionsClub = 1e9;

  /// All-time plays of [s] on the streaming app, [streamsAgo] streams
  /// back (its share of every stream, all along).
  static double streamifyPlays(World w, Song s, {double streamsAgo = 0}) {
    if (s.releasedWeek < 0) return 0;
    var life = -streamsAgo;
    for (var r = 0; r < regionCount; r++) {
      life += w.songLifetimeStreams(s, r);
    }
    return math.max(0, life) * Streamify.share;
  }

  /// Every song with a billion plays on the app, most played first.
  static List<BillionsRow> billionsClubOf(World w) {
    final rows = <BillionsRow>[];
    for (final s in w.songs) {
      if (s.releasedWeek < 0) continue;
      final v = streamifyPlays(w, s);
      if (v >= billionsClub) rows.add(BillionsRow.of(w, s, v));
    }
    rows.sort((a, b) {
      final d = b.plays.compareTo(a.plays);
      return d != 0 ? d : a.songId.compareTo(b.songId);
    });
    return rows;
  }

  /// Views that make a video certified, and the billion views club (docs
  /// K118).
  static const certifiedViews = 1e8;
  static const billionViews = 1e9;
  static const videoMilestones = [certifiedViews, billionViews, 5e9];

  /// All-time views of [s] on the video site (docs K118), [streamsAgo]
  /// streams back: its share of the song's streams, the music video
  /// pulling far more than the audio and lyric uploads before it.
  static double videoViews(World w, Song s, {double streamsAgo = 0}) {
    if (s.releasedWeek < 0) return 0;
    final year = math.max(
        MusicPlatform.viewTube.launchYear, GameTime.yearOf(s.releasedWeek));
    final share = MusicPlatform.viewTube.streamShare(year);
    var life = -streamsAgo;
    for (var r = 0; r < regionCount; r++) {
      life += w.songLifetimeStreams(s, r);
    }
    if (life <= 0) return 0;
    // Saves before K118: a video counts from the release.
    final before = s.videoBudget < 0
        ? life
        : s.videoWeek < 0
            ? 0.0
            : math.min(life, s.streamsAtVideo);
    return share * (0.6 * before + (0.6 + 2 * s.videoPower) * (life - before));
  }

  /// The biggest videos of all time, everyone's (docs K118).
  static List<VideoRow> topVideos(World w,
      {int limit = 25, bool mine = false}) {
    final rows = [
      for (final s in w.songs)
        if (s.releasedWeek >= 0 &&
            (!mine || s.primaryArtistId == w.playerArtistId))
          (s, videoViews(w, s))
    ]..sort((x, y) => y.$2.compareTo(x.$2));
    return [
      for (final (s, v) in rows.take(limit))
        if (v > 0) VideoRow.of(w, s, v)
    ];
  }

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
        // The player's own uploads bring subscribers too (docs K142).
        final uploads =
            a.id == w.playerArtistId ? w.channelVideos.length : 0;
        return (0.6 * fans + 0.06 * cas) *
            m *
            (0.8 +
                0.4 * math.min(1, videos / 5) +
                0.2 * math.min(1, uploads / 20));
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

/// One video on the player's channel (docs K142): a music video
/// ([kind] null) or an upload.
class ChannelVideoRow {
  ChannelVideoRow(
      {required this.kind,
      required this.songId,
      required this.title,
      required this.albumId,
      required this.week,
      required this.views});
  final VideoKind? kind;

  /// The song (-1: a video about the artist).
  final int songId;
  final String title;

  /// Album for the thumbnail (-1: none).
  final int albumId;
  final int week;
  final double views;
}

/// The player's channel on the video site (docs K142).
class ChannelView {
  ChannelView(
      {required this.name,
      required this.artistId,
      required this.subscribers,
      required this.totalViews,
      required this.videos,
      required this.songs,
      required this.made,
      required this.artistVideoThisWeek,
      required this.open,
      required this.year});
  final String name;
  final int artistId;
  final double subscribers;
  final double totalViews;

  /// Newest first.
  final List<ChannelVideoRow> videos;

  /// Released songs a video can be made for, newest first: id and title.
  final List<(int, String)> songs;

  /// Kinds already made for each song.
  final Map<int, Set<VideoKind>> made;

  /// A behind-the-scenes or vlog is already up this week.
  final bool artistVideoThisWeek;

  /// The site is open.
  final bool open;
  final int year;

  bool get hasVideos => videos.isNotEmpty;
  List<ChannelVideoRow> get popular =>
      [...videos]..sort((a, b) => b.views.compareTo(a.views));

  /// Kinds that can be made in [year].
  List<VideoKind> get kinds => [
        for (final k in VideoKind.values)
          if (year >= k.fromYear) k
      ];

  static ChannelView of(World w) {
    final p = w.player!;
    final year = GameTime.yearOf(w.week);
    final rows = <ChannelVideoRow>[];
    var total = 0.0;
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.releasedWeek < 0 || s.videoBudget < 0) continue;
      final views = Platforms.videoViews(w, s);
      total += views;
      rows.add(ChannelVideoRow(
          kind: null,
          songId: s.id,
          title: s.title,
          albumId: coverAlbumOf(w, s),
          week: s.videoWeek >= 0 ? s.videoWeek : s.releasedWeek,
          views: views));
    }
    final made = <int, Set<VideoKind>>{};
    for (final v in w.channelVideos) {
      final views = v.viewsAt(w.week - 1);
      total += views;
      final s = v.songId >= 0 ? w.songs[v.songId] : null;
      if (s != null) (made[s.id] ??= {}).add(v.kind);
      rows.add(ChannelVideoRow(
          kind: v.kind,
          songId: v.songId,
          title: s?.title ?? '',
          albumId: s == null ? -1 : coverAlbumOf(w, s),
          week: v.week,
          views: views));
    }
    rows.sort((a, b) => b.week.compareTo(a.week));
    final songs = [
      for (final id in w.playerSongIds)
        if (w.songs[id].releasedWeek >= 0 &&
            w.songs[id].status != SongStatus.scrapped)
          w.songs[id]
    ]..sort((a, b) => b.releasedWeek.compareTo(a.releasedWeek));
    return ChannelView(
        name: p.name,
        artistId: p.id,
        subscribers:
            Platforms.followers(w, p, MusicPlatform.viewTube, year) ?? 0,
        totalViews: total,
        videos: rows,
        songs: [for (final s in songs) (s.id, s.title)],
        made: made,
        artistVideoThisWeek:
            w.channelVideos.any((v) => !v.kind.forSong && v.week == w.week),
        open: year >= Channel.openYear,
        year: year);
  }
}
