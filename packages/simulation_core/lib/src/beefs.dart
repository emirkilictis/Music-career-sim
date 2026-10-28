import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'audience.dart';
import 'model.dart';
import 'opportunities.dart';
import 'rng.dart';
import 'social.dart';
import 'time.dart';
import 'world.dart';

/// What a move in a beef was (docs K229).
enum BeefMoveKind { tweet, track }

/// How a beef ended.
enum BeefEnd {
  /// The public sided with the player.
  won,

  /// The public sided with the rival.
  lost,

  /// The two made peace.
  truce,

  /// It died down with no winner.
  fizzled,
}

/// A diss in a beef: a post or a diss track ([songId]).
class BeefMove {
  BeefMove(this.week, this.byPlayer, this.kind,
      {this.songId = -1, this.resolved = false});
  final int week;
  final bool byPlayer;
  final BeefMoveKind kind;
  final int songId;

  /// A diss track's round was scored.
  bool resolved;

  List<int> toJson() =>
      [week, byPlayer ? 1 : 0, kind.index, songId, resolved ? 1 : 0];

  static BeefMove fromJson(List<dynamic> j) => BeefMove(
      j[0] as int, j[1] == 1, BeefMoveKind.values[j[2] as int],
      songId: j[3] as int, resolved: j[4] == 1);
}

/// The player's feud with a rival (docs K229): how hot it is (how much
/// people talk about it) and whose side the public is on.
class Beef {
  Beef(
      {required this.rivalId,
      required this.startWeek,
      required this.playerStarted,
      this.heat = 0,
      this.opinion = 0.5});
  final int rivalId;
  final int startWeek;
  final bool playerStarted;

  /// 0..1: how much people talk about it. It cools every week.
  double heat;

  /// 0..1: the public's share on the player's side.
  double opinion;
  final List<BeefMove> moves = [];
  int endWeek = -1;
  BeefEnd? end;

  bool get active => endWeek < 0;

  List<Object?> toJson() => [
        rivalId,
        startWeek,
        playerStarted ? 1 : 0,
        heat,
        opinion,
        endWeek,
        end?.index ?? -1,
        [for (final m in moves) m.toJson()],
      ];

  static Beef fromJson(List<dynamic> j) => Beef(
        rivalId: j[0] as int,
        startWeek: j[1] as int,
        playerStarted: j[2] == 1,
        heat: (j[3] as num).toDouble(),
        opinion: (j[4] as num).toDouble(),
      )
        ..endWeek = j[5] as int
        ..end = (j[6] as int) < 0 ? null : BeefEnd.values[j[6] as int]
        ..moves.addAll(
            [for (final m in j[7] as List) BeefMove.fromJson(m as List)]);

  static String encode(List<Beef> b) =>
      jsonEncode([for (final x in b) x.toJson()]);

  static List<Beef> decode(String? s) => s == null || s.isEmpty
      ? []
      : [for (final x in jsonDecode(s) as List) fromJson(x as List)];
}

/// Why the player cannot start on a rival now.
enum DissBlock {
  /// Not a rival: the player themself or someone retired.
  notRival,

  /// Already beefing with someone else.
  busy,

  /// Made up or fell out with them too lately.
  cooldown,

  /// No social media yet, or no posts left this week (a post only).
  noPost,
}

/// What happened in the player's beef this week, for the news.
sealed class BeefNews {
  const BeefNews(this.rivalId);
  final int rivalId;
}

/// A rival started on the player.
class BeefRivalStarted extends BeefNews {
  const BeefRivalStarted(super.rivalId, {this.songId = -1});

  /// Their diss track (-1: a post).
  final int songId;
}

/// The rival answered the player's diss.
class BeefFiredBack extends BeefNews {
  const BeefFiredBack(super.rivalId, {this.songId = -1});
  final int songId;
}

/// A diss track's round was scored: whose track did better.
class BeefRound extends BeefNews {
  const BeefRound(super.rivalId,
      {required this.playerWon,
      required this.playerSongId,
      required this.rivalSongId});
  final bool playerWon;
  final int playerSongId;

  /// -1: the other side never answered it with a track.
  final int rivalSongId;
}

/// The beef is over.
class BeefOver extends BeefNews {
  const BeefOver(super.rivalId, this.end);
  final BeefEnd end;
}

/// Beefs (docs K229): the player disses a rival in a post or a diss track,
/// the rival fires back, the public picks a side, and it cools down to a
/// win, a loss or nothing; or the two make peace. Rivals sometimes start
/// on the player. The haters can get a diss too.
abstract final class Beefs {
  /// [Song.dissTarget] of a diss track at the haters.
  static const haters = -2;

  /// Weeks before the player can start on the same rival again.
  static const cooldownWeeks = 26;

  /// How much of its heat a beef keeps each week, and the heat it is over
  /// at.
  static const heatKeep = 0.85;
  static const overHeat = 0.06;

  /// Weeks a diss track's round runs: the other side has this long to
  /// answer with a track of their own.
  static const roundWeeks = 3;

  static Beef? active(World w) {
    for (final b in w.beefs.reversed) {
      if (b.active) return b;
    }
    return null;
  }

  /// Why the player cannot start on [rivalId] now, or null.
  static DissBlock? block(World w, Artist a, int rivalId,
      {bool post = false}) {
    if (rivalId < 0 ||
        rivalId >= w.artists.length ||
        rivalId == a.id ||
        w.artists[rivalId].isRetired ||
        w.artists[rivalId].tier == ArtistTier.player) {
      return DissBlock.notRival;
    }
    final b = active(w);
    if (b != null && b.rivalId != rivalId) return DissBlock.busy;
    if (b == null) {
      for (final x in w.beefs) {
        if (x.rivalId == rivalId && w.week - x.endWeek < cooldownWeeks) {
          return DissBlock.cooldown;
        }
      }
    }
    if (post && !_canPost(w)) return DissBlock.noPost;
    return null;
  }

  static bool _canPost(World w) =>
      Social.canPostIn(GameTime.yearOf(w.week)) &&
      w.social.postsIn(w.week) < Social.postsPerWeek;

  /// How the public takes going at [rival]: going at someone far smaller
  /// is bullying, at someone far bigger is brave.
  static double punch(Artist a, Artist rival) => rival.fame < a.fame * 0.4
      ? -0.08
      : rival.fame > a.fame * 1.5 + 0.05
          ? 0.03
          : 0;

  static Beef _beefWith(World w, Artist a, int rivalId,
      {required bool playerStarted, double heat = 0}) {
    final b = active(w);
    if (b != null && b.rivalId == rivalId) return b;
    // Going at someone else ends the old one quietly.
    if (b != null) _end(w, a, b, BeefEnd.fizzled);
    final n = Beef(
        rivalId: rivalId,
        startWeek: w.week,
        playerStarted: playerStarted,
        heat: heat);
    w.beefs.add(n);
    return n;
  }

  static void _shift(Beef b, double d) =>
      b.opinion = (b.opinion + d).clamp(0.05, 0.95);

  /// The player disses [rivalId] in a post (one of the week's posts).
  /// Returns the opinion it moved.
  static double dissPost(World w, Artist a, int rivalId) {
    final why = block(w, a, rivalId, post: true);
    if (why != null) throw ActionException('No diss: ${why.name}');
    final rival = w.artists[rivalId];
    final b = _beefWith(w, a, rivalId, playerStarted: true);
    final made = w.social.postsIn(w.week);
    final r = RandomStream.keyed(
        w.seed, w.week, rivalId * 8 + made, RngPurpose.beef);
    final charm = a.skills.charisma / 100;
    final d = 0.05 * (2 * charm - 1) + punch(a, rival) + r.range(-0.04, 0.04);
    _shift(b, d);
    b.heat = math.min(1.0, b.heat + 0.25);
    b.moves.add(BeefMove(w.week, true, BeefMoveKind.tweet));
    a.hype += 0.03 + 0.03 * b.heat;
    a.buzz += 0.15;
    Audience.addCasual(w, a, a.casual * 0.003);
    _usePost(w);
    final likes =
        (Social.followers(w, a) * r.range(0.05, 0.12)).round();
    Social.add(
        w,
        SocialItem(
            week: w.week,
            topic: FanTopic.postDiss,
            variant: r.nextInt(Social.variants),
            likes: likes,
            artistId: rivalId));
    _sides(w, r, d, rivalId, likes);
    w.dirtyArtists.add(a.id);
    return d;
  }

  /// The player answers a rival's diss in a post, a week's post or not.
  static void fireBack(World w, Artist a) {
    final b = active(w);
    if (b == null) return;
    if (!Social.canPostIn(GameTime.yearOf(w.week))) {
      // No social media yet: an answer in the press.
      _shift(b, 0.02);
      b.heat = math.min(1.0, b.heat + 0.2);
      b.moves.add(BeefMove(w.week, true, BeefMoveKind.tweet));
      return;
    }
    if (!_canPost(w)) {
      // Over the week's posts: it goes out anyway, the post count stays.
      final st = w.social;
      st.postsThisWeek = Social.postsPerWeek - 1;
      st.postWeek = w.week;
    }
    dissPost(w, a, b.rivalId);
  }

  /// The player disses the haters in a post: fans rally, unless it comes
  /// off as thin-skinned.
  static bool dissHatersPost(World w, Artist a) {
    if (!_canPost(w)) throw ActionException('No posts left');
    final made = w.social.postsIn(w.week);
    final r = RandomStream.keyed(
        w.seed, w.week, a.id * 8 + made, RngPurpose.beef + 1);
    final charm = a.skills.charisma / 100;
    final backlash = r.chance(0.35 - 0.2 * charm);
    if (backlash) {
      a.popularity = math.max(0.0, a.popularity - 0.01);
    } else {
      a.devotion = math.min(1.0, a.devotion + 0.01 + 0.01 * charm);
      a.hype += 0.02;
    }
    _usePost(w);
    final likes = (Social.followers(w, a) * r.range(0.04, 0.1)).round();
    Social.add(
        w,
        SocialItem(
            week: w.week,
            topic: FanTopic.postDissHaters,
            variant: r.nextInt(Social.variants),
            likes: likes));
    for (var i = 0; i < 2; i++) {
      Social.add(
          w,
          SocialItem(
              week: w.week,
              topic: backlash ? FanTopic.replyBacklash : FanTopic.hateDefend,
              variant: (r.nextInt(Social.variants) + i) % Social.variants,
              fan: r.nextInt(1 << 20),
              likes: (likes * r.range(0.005, 0.04)).round()));
    }
    w.dirtyArtists.add(a.id);
    return backlash;
  }

  static void _usePost(World w) {
    final st = w.social;
    st.postsThisWeek = st.postsIn(w.week) + 1;
    st.postWeek = w.week;
    st.engagement = math.min(1.0, st.engagement + 0.03);
  }

  /// Fans take sides in the feed: more for whoever the diss helped.
  static void _sides(
      World w, RandomStream r, double d, int rivalId, int likes) {
    for (var i = 0; i < 2; i++) {
      final mine = i == 0 ? d >= 0 : r.chance(0.5);
      Social.add(
          w,
          SocialItem(
              week: w.week,
              topic: mine ? FanTopic.replyDissFor : FanTopic.replyDissAgainst,
              variant: (r.nextInt(Social.variants) + i) % Social.variants,
              fan: r.nextInt(1 << 20),
              likes: (likes * r.range(0.005, 0.05)).round(),
              artistId: rivalId));
    }
  }

  /// A diss track came out as a single ([Actions.releaseSingle]): people
  /// play it to hear who it is about, and the beef heats up.
  static void onRelease(World w, Artist a, Song s) {
    final target = s.dissTarget;
    final player = w.player;
    if (target == haters) {
      a.devotion = math.min(1.0, a.devotion + 0.02);
      a.hype += 0.05;
      s.versionBoost += 0.1;
      if (a.id == w.playerArtistId) {
        final r = RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.beef);
        Social.add(
            w,
            SocialItem(
                week: w.week,
                topic: FanTopic.dissTrackHaters,
                variant: r.nextInt(Social.variants),
                fan: r.nextInt(1 << 20),
                songId: s.id));
      }
      w.dirtySongs.add(s.id);
      return;
    }
    if (player == null || target < 0 || target >= w.artists.length) return;
    final byPlayer = a.id == player.id;
    // A beef is the player's with a rival; a rival's track only counts
    // when it goes at the player.
    if (!byPlayer && target != player.id) return;
    final rivalId = byPlayer ? target : a.id;
    if (w.artists[rivalId].isRetired) return;
    final b = _beefWith(w, player, rivalId,
        playerStarted: byPlayer && active(w)?.rivalId != rivalId);
    final other = w.artists[byPlayer ? rivalId : player.id];
    final r = RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.beef + 2);
    // A good track wins people over; a weak one hands them to the other
    // side.
    final d = 0.08 * (s.quality - 60) / 40 +
        (byPlayer ? punch(player, other) : -punch(a, player)) +
        r.range(-0.03, 0.03);
    _shift(b, byPlayer ? d : -d);
    b.heat = math.min(1.0, b.heat + 0.5);
    b.moves.add(BeefMove(w.week, byPlayer, BeefMoveKind.track, songId: s.id));
    s.versionBoost += math.min(0.4, 0.15 + 0.25 * other.fame);
    a.hype += 0.08;
    a.buzz += 0.3;
    if (byPlayer) {
      Social.add(
          w,
          SocialItem(
              week: w.week,
              topic: FanTopic.dissTrackOut,
              variant: r.nextInt(Social.variants),
              fan: r.nextInt(1 << 20),
              songId: s.id,
              artistId: rivalId));
      _sides(w, r, d, rivalId, (Social.followers(w, a) * 0.05).round());
    }
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// The player makes peace with the rival.
  static void makePeace(World w, Artist a) {
    final b = active(w);
    if (b == null) throw ActionException('No beef');
    // Folding while losing looks weak.
    if (b.opinion < 0.4) a.popularity = math.max(0.0, a.popularity - 0.01);
    a.devotion = math.min(1.0, a.devotion + 0.01);
    _end(w, a, b, BeefEnd.truce);
  }

  /// Rising above a rival's diss: some respect it, and it cools faster.
  static void riseAbove(World w, Artist a) {
    final b = active(w);
    if (b == null) return;
    _shift(b, 0.04);
    b.heat *= 0.5;
  }

  static void _end(World w, Artist a, Beef b, BeefEnd end) {
    b.endWeek = w.week;
    b.end = end;
    b.heat = 0;
    final rival = w.artists[b.rivalId];
    switch (end) {
      case BeefEnd.won:
        if (!a.isRetired) {
          a.fame = math.min(1.0, a.fame + 0.01);
          a.updateRegionShare();
        }
        a.popularity = math.min(1.0, a.popularity + 0.03);
        a.devotion = math.min(1.0, a.devotion + 0.02);
        rival.popularity = math.max(0.0, rival.popularity - 0.03);
      case BeefEnd.lost:
        a.popularity = math.max(0.0, a.popularity - 0.05);
        a.devotion = math.max(0.0, a.devotion - 0.02);
        rival.popularity = math.min(1.0, rival.popularity + 0.03);
      case BeefEnd.truce || BeefEnd.fizzled:
        break;
    }
    w.dirtyArtists.add(a.id);
    w.dirtyArtists.add(rival.id);
  }

  /// The beef's week: rounds of diss tracks are scored, the rival may
  /// fire back, the heat keeps both talked about and cools; or a rival
  /// starts on the player.
  static List<BeefNews> weekly(World w) {
    final p = w.player;
    if (p == null) return const [];
    final news = <BeefNews>[];
    final b = active(w);
    final r = RandomStream.keyed(w.seed, w.week, p.id, RngPurpose.beef + 3);
    if (b == null) {
      final started = _rivalStarts(w, p, r);
      if (started != null) news.add(started);
      return news;
    }
    final rival = w.artists[b.rivalId];
    if (rival.isRetired) {
      _end(w, p, b, BeefEnd.fizzled);
      return [BeefOver(b.rivalId, BeefEnd.fizzled)];
    }
    // Diss track rounds.
    for (final m in b.moves) {
      if (m.kind != BeefMoveKind.track || m.resolved) continue;
      if (w.week - m.week < roundWeeks) continue;
      m.resolved = true;
      final answer = b.moves
          .where((x) =>
              x.kind == BeefMoveKind.track &&
              x.byPlayer != m.byPlayer &&
              x.week >= m.week &&
              x.week - m.week < roundWeeks)
          .firstOrNull;
      bool mineWon;
      if (answer == null) {
        // Nobody answered it: it stands.
        mineWon = m.byPlayer;
        _shift(b, m.byPlayer ? 0.06 : -0.06);
      } else {
        answer.resolved = true;
        final mine = m.byPlayer ? m.songId : answer.songId;
        final theirs = m.byPlayer ? answer.songId : m.songId;
        mineWon = w.songLifetimeStreams(w.songs[mine]) >=
            w.songLifetimeStreams(w.songs[theirs]);
        _shift(b, mineWon ? 0.12 : -0.12);
      }
      final mine = m.byPlayer ? m.songId : (answer?.songId ?? -1);
      final theirs = m.byPlayer ? (answer?.songId ?? -1) : m.songId;
      news.add(BeefRound(b.rivalId,
          playerWon: mineWon, playerSongId: mine, rivalSongId: theirs));
    }
    // The rival answers a fresh diss: the last word was the player's.
    final last = b.moves.isEmpty ? null : b.moves.last;
    if (last != null &&
        last.byPlayer &&
        last.week >= w.week - 1 &&
        r.chance(math.min(0.8, 0.25 + 0.4 * b.heat))) {
      final big = rival.fame > 0.4 || rival.tier == ArtistTier.a;
      final track = r.chance(big ? 0.25 + 0.3 * b.heat : 0.1);
      news.add(BeefFiredBack(b.rivalId,
          songId: _rivalMove(w, p, rival, b, r, track: track)));
    }
    // Being talked about.
    p.hype += 0.01 * b.heat;
    rival.hype += 0.01 * b.heat;
    b.heat *= heatKeep;
    if (b.heat < overHeat) {
      final end = b.opinion > 0.6
          ? BeefEnd.won
          : b.opinion < 0.4
              ? BeefEnd.lost
              : BeefEnd.fizzled;
      _end(w, p, b, end);
      news.add(BeefOver(b.rivalId, end));
    }
    w.dirtyArtists.add(p.id);
    w.dirtyArtists.add(rival.id);
    return news;
  }

  /// The rival's diss: a post, or a diss track out as a single. Returns
  /// the track (-1: a post).
  static int _rivalMove(
      World w, Artist p, Artist rival, Beef b, RandomStream r,
      {required bool track}) {
    if (track) {
      final s = Actions.writeSong(w, rival, aiMode: true);
      s.dissTarget = p.id;
      Actions.releaseSingle(w, rival, s, prepaid: true);
      return s.id;
    }
    final d = 0.03 + 0.05 * rival.fame + punch(rival, p) + r.range(-0.03, 0.03);
    _shift(b, -d);
    b.heat = math.min(1.0, b.heat + 0.2);
    b.moves.add(BeefMove(w.week, false, BeefMoveKind.tweet));
    rival.hype += 0.03;
    Social.add(
        w,
        SocialItem(
            week: w.week,
            topic: FanTopic.rivalPost,
            variant: r.nextInt(Social.variants),
            fan: SocialItem.byRival,
            likes: (Social.followers(w, p) * r.range(0.04, 0.1)).round(),
            artistId: rival.id));
    // Their post, then the fans talking about it (docs K234).
    Social.add(
        w,
        SocialItem(
            week: w.week,
            topic: FanTopic.rivalDiss,
            variant: r.nextInt(Social.variants),
            fan: r.nextInt(1 << 20),
            likes: (Social.followers(w, p) * r.range(0.001, 0.006)).round(),
            artistId: rival.id));
    return -1;
  }

  /// Now and then a rival about the player's size starts on them.
  static BeefNews? _rivalStarts(World w, Artist p, RandomStream r) {
    if (p.fame < 0.12 || !r.chance(0.004)) return null;
    final pool = [
      for (final id in w.activeArtistIds)
        if (w.artists[id] case final x
            when x.tier != ArtistTier.player &&
                !x.isRetired &&
                (x.fame - p.fame).abs() < 0.15 &&
                block(w, p, id) == null)
          x
    ];
    if (pool.isEmpty) return null;
    final rival = pool[r.nextInt(pool.length)];
    final b = _beefWith(w, p, rival.id, playerStarted: false, heat: 0.15);
    final song = _rivalMove(w, p, rival, b, r, track: r.chance(0.2));
    // The player gets to answer (docs K229).
    p.opportunity ??= Opportunity(
        kind: OpportunityKind.dissed,
        week: w.week,
        partnerArtistId: rival.id);
    return BeefRivalStarted(rival.id, songId: song);
  }
}
