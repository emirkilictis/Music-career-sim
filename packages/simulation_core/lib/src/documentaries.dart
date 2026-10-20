import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'audience.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// Where a documentary comes out (docs K172). Index order is stored.
enum DocDeal {
  /// The artist pays for it and puts it out free on the video site:
  /// everyone can watch.
  selfFunded,

  /// A streaming service makes it as an original and pays for it: fewer
  /// watch it, but the artist is paid.
  original,
}

/// The player's documentary, in production or out.
class Documentary {
  Documentary(
      {required this.startWeek,
      required this.deal,
      required this.title,
      this.feeCents = 0,
      this.premiered = false});
  final int startWeek;
  final DocDeal deal;
  final String title;
  final int feeCents;
  bool premiered;

  int get premiereWeek => startWeek + Documentaries.productionWeeks;

  List<Object> toJson() =>
      [startWeek, deal.index, title, feeCents, premiered ? 1 : 0];
  static Documentary fromJson(List<dynamic> j) => Documentary(
      startWeek: j[0] as int,
      deal: DocDeal.values[j[1] as int],
      title: j[2] as String,
      feeCents: j[3] as int,
      premiered: j[4] == 1);

  static String encode(List<Documentary> d) =>
      jsonEncode([for (final x in d) x.toJson()]);
  static List<Documentary> decode(String? s) => s == null || s.isEmpty
      ? []
      : [for (final x in jsonDecode(s) as List) fromJson(x as List)];
}

/// What stops a documentary now.
enum DocBlock { tooEarly, notKnown, filming, tooSoon }

/// A documentary (docs K172), the Miss Americana move: half a year of
/// filming, then a premiere that sends people back to the songs.
abstract final class Documentaries {
  static const fromYear = 2015;
  static const minFame = 0.5;
  static const productionWeeks = 26;

  /// Years between two.
  static const gapYears = 5;

  /// What making one costs the artist themselves.
  static const selfCostCents = 50000000;

  /// What a streaming service pays for an original.
  static int originalFeeCents(Artist a) =>
      (500000000 * a.fame * a.fame).round();

  /// Songs sent back to the charts at the premiere, and the wave.
  static const songs = 10;
  static const wave = 0.25;

  /// Share of listeners who become fans, by deal.
  static double fanShare(DocDeal d) =>
      d == DocDeal.selfFunded ? 0.012 : 0.006;

  static DocBlock? block(World w, Artist a) {
    if (GameTime.yearOf(w.week) < fromYear) return DocBlock.tooEarly;
    if (a.fame < minFame) return DocBlock.notKnown;
    for (final d in w.documentaries) {
      if (!d.premiered) return DocBlock.filming;
      if (w.week - d.premiereWeek < gapYears * GameTime.weeksPerYear) {
        return DocBlock.tooSoon;
      }
    }
    return null;
  }

  /// Starts filming [title] under [deal].
  static Documentary start(World w, Artist a, DocDeal deal, String title) {
    if (block(w, a) case final b?) throw ActionException('No doc: $b');
    final t = title.trim();
    if (t.isEmpty) throw ActionException('Name it');
    var fee = 0;
    if (deal == DocDeal.selfFunded) {
      if (a.moneyCents < selfCostCents) {
        throw ActionException('Not enough money');
      }
      a.moneyCents -= selfCostCents;
    } else {
      fee = originalFeeCents(a);
      a.moneyCents += fee;
    }
    w.dirtyArtists.add(a.id);
    final d = Documentary(startWeek: w.week, deal: deal, title: t, feeCents: fee);
    w.documentaries.add(d);
    return d;
  }

  /// The premiere, in its week: the biggest songs are heard again, people
  /// become fans and the fans feel closer. Returns the documentary.
  static Documentary? weekly(World w) {
    final a = w.player;
    if (a == null) return null;
    for (final d in w.documentaries) {
      if (d.premiered || d.premiereWeek != w.week) continue;
      d.premiered = true;
      final best = [
        for (final id in w.playerSongIds)
          if (w.songs[id].releasedWeek >= 0 &&
              w.songs[id].status != SongStatus.scrapped)
            w.songs[id]
      ]..sort((x, y) =>
          w.songLifetimeStreams(y).compareTo(w.songLifetimeStreams(x)));
      for (final s in best.take(songs)) {
        if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
        s.weeksBelowCutoff = 0;
        s.versionBoost += wave;
        w.dirtySongs.add(s.id);
      }
      Audience.addFans(w, a, a.casual * fanShare(d.deal));
      a.devotion = math.min(1.0, a.devotion + 0.03);
      a.hype += 0.1;
      w.dirtyArtists.add(a.id);
      return d;
    }
    return null;
  }
}
