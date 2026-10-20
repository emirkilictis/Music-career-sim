import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'audience.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// Videos the player can put on their own video-site channel besides the
/// music video (docs K142). Index order is stored.
enum VideoKind {
  /// Lyrics on screen: cheap, and people search the words.
  lyric(costCents: 500000, energy: 2, fromYear: 2008, lift: 0.06, views: 0.8),

  /// A looping visual for the audio: the cheapest, the least watched.
  visualizer(
      costCents: 300000, energy: 2, fromYear: 2012, lift: 0.04, views: 0.4),

  /// A filmed live performance: as good as the artist on stage.
  live(costCents: 3000000, energy: 10, fromYear: 2005, lift: 0.1, views: 0.6),

  /// A stripped-down version: as good as the voice.
  acoustic(
      costCents: 1500000, energy: 8, fromYear: 2005, lift: 0.12, views: 0.7),

  /// Choreography people copy: biggest once short videos rule.
  dance(costCents: 4000000, energy: 10, fromYear: 2005, lift: 0.1, views: 1.2),

  /// Behind the scenes of the record: fans feel close.
  behindScenes(
      costCents: 800000, energy: 4, fromYear: 2005, lift: 0, views: 0.25),

  /// A vlog: life on the road, cheap and personal.
  vlog(costCents: 200000, energy: 5, fromYear: 2006, lift: 0, views: 0.3);

  const VideoKind(
      {required this.costCents,
      required this.energy,
      required this.fromYear,
      required this.lift,
      required this.views});
  final int costCents;

  /// Creativity it takes.
  final double energy;

  /// First year people make it.
  final int fromYear;

  /// The wave of listening it brings its song (a remix brings 0.35).
  final double lift;

  /// Views relative to the audience it reaches.
  final double views;

  /// Made for a song; the others are about the artist.
  bool get forSong => this != behindScenes && this != vlog;

  /// The skill that makes it good (null: anyone can).
  SkillKind? get skill => switch (this) {
        live || dance => SkillKind.performance,
        acoustic => SkillKind.vocals,
        behindScenes || vlog => SkillKind.charisma,
        lyric || visualizer => null,
      };

  /// The wave it brings its song in [year]: a dance video is the trend
  /// starter once short videos rule.
  double liftIn(int year) =>
      this == dance && year >= 2018 ? 0.2 : lift;
}

/// One video on the player's channel.
class ChannelVideo {
  ChannelVideo(this.kind,
      {required this.songId,
      required this.week,
      required this.power,
      required this.baseViews});
  final VideoKind kind;

  /// The song it is made for (-1: about the artist).
  final int songId;
  final int week;

  /// How good it came out (0.6–1.4).
  final double power;

  /// Views it reaches in the long run.
  final double baseViews;

  /// Views by [week]: most in its first two months.
  double viewsAt(int week) {
    final age = week - this.week;
    if (age < 0) return 0;
    return baseViews * (1 - math.exp(-(age + 1) / Channel.viewWeeks));
  }

  List<Object> toJson() =>
      [kind.index, songId, week, power, baseViews];

  static ChannelVideo fromJson(List j) => ChannelVideo(
      VideoKind.values[j[0] as int],
      songId: j[1] as int,
      week: j[2] as int,
      power: (j[3] as num).toDouble(),
      baseViews: (j[4] as num).toDouble());

  static String encode(List<ChannelVideo> v) =>
      jsonEncode([for (final x in v) x.toJson()]);

  static List<ChannelVideo> decode(String? s) => s == null || s.isEmpty
      ? []
      : [for (final x in jsonDecode(s) as List) fromJson(x as List)];
}

/// Why a video cannot be made.
enum VideoBlock { notOpen, tooEarly, needsSong, notReleased, made, weekly }

/// The player's channel on the video site (docs K142).
abstract final class Channel {
  /// The video site's first year.
  static const openYear = 2005;

  /// Weeks for a video to get most of its views.
  static const viewWeeks = 8.0;

  /// Videos about the artist: one a week.
  static const artistVideosPerWeek = 1;

  /// Core fans an artist video wins, per casual listener, at full power.
  static const fanRate = {VideoKind.behindScenes: 0.002, VideoKind.vlog: 0.003};

  /// Song videos win a few fans too.
  static const songFanRate = 0.0004;

  /// How good [a]'s [kind] video comes out.
  static double power(Artist a, VideoKind kind) {
    final k = kind.skill;
    if (k == null) return 1;
    return 0.6 + 0.8 * a.skills[k] / 100;
  }

  /// The audience a channel video reaches before views from the song.
  static double reach(Artist a) => 0.6 * a.coreFans + 0.06 * a.casual;

  /// What stops [a] making [kind] (for [s]) now, or null.
  static VideoBlock? block(World w, Artist a, VideoKind kind, Song? s) {
    final year = GameTime.yearOf(w.week);
    if (year < openYear) return VideoBlock.notOpen;
    if (year < kind.fromYear) return VideoBlock.tooEarly;
    if (kind.forSong) {
      if (s == null) return VideoBlock.needsSong;
      if (s.primaryArtistId != a.id ||
          s.releasedWeek < 0 ||
          s.status == SongStatus.scrapped) {
        return VideoBlock.notReleased;
      }
      if (w.channelVideos.any((v) => v.kind == kind && v.songId == s.id)) {
        return VideoBlock.made;
      }
    } else if (w.channelVideos
            .where((v) => !v.kind.forSong && v.week == w.week)
            .length >=
        artistVideosPerWeek) {
      return VideoBlock.weekly;
    }
    return null;
  }

  /// Makes and uploads [kind] (for [s]); returns the video.
  static ChannelVideo upload(World w, Artist a, VideoKind kind, {Song? s}) {
    final why = block(w, a, kind, s);
    if (why != null) throw ActionException('Cannot make it: ${why.name}');
    if (a.moneyCents < kind.costCents) {
      throw ActionException('Not enough money');
    }
    if (a.creativeEnergy < kind.energy) {
      throw ActionException('Not enough creativity');
    }
    a.moneyCents -= kind.costCents;
    a.creativeEnergy -= kind.energy;
    final pw = power(a, kind);
    final year = GameTime.yearOf(w.week);
    var base = reach(a) * kind.views * pw;
    if (s != null) {
      // A hit's videos ride its listening.
      base += 4 * s.weekStreams * kind.views * pw;
      // Each video on a song adds less (as versions do).
      final recent = w.channelVideos
          .where((v) => v.songId == s.id && w.week - v.week < 8)
          .length;
      if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
      s.weeksBelowCutoff = 0;
      s.versionBoost +=
          kind.liftIn(year) * pw * math.pow(0.7, recent).toDouble();
      s.productionCostCents += kind.costCents;
      w.dirtySongs.add(s.id);
      Audience.addFans(w, a, a.casual * songFanRate * pw);
    } else {
      Audience.addFans(w, a, a.casual * (fanRate[kind] ?? 0) * pw);
    }
    final v = ChannelVideo(kind,
        songId: s?.id ?? -1, week: w.week, power: pw, baseViews: base);
    w.channelVideos.add(v);
    w.dirtyArtists.add(a.id);
    return v;
  }
}
