import 'dart:math' as math;

import 'model.dart';
import 'rng.dart';
import 'snippets.dart';
import 'time.dart';
import 'world.dart';

/// Leaks (docs K140): an unreleased song of a famous artist gets out on
/// the internet. Answered by putting it out officially within
/// [answerWeeks] weeks, the talk turns into a wave of listening; left
/// alone, fans have already heard it and an album with it sells less.
abstract final class Leaks {
  /// Leaks start with file sharing.
  static const fromYear = 1999;

  /// Weekly chance for a household name's song after half a year in the
  /// vault (scaled by fame²).
  static const weeklyChance = 0.0015;

  /// Weeks to put a leaked song out officially.
  static const answerWeeks = 3;

  /// The wave an answered leak brings (a remix brings 0.35).
  static const answerBoost = 0.3;

  /// Fans' listening an unanswered leak keeps: they have it already.
  static const fanKeep = 0.85;

  /// Share of an album's sales each unanswered leaked track takes, while
  /// people buy records and after (streams count anyway), and the most.
  static const albumCutDownloadEra = 0.04;
  static const albumCutStreamingEra = 0.015;
  static const albumMaxCut = 0.25;

  /// Weekly chance that vault song [s] of [a] leaks: more the more famous,
  /// the longer it waits and once a release with it is announced.
  static double chance(World w, Artist a, Song s, {bool announced = false}) {
    if (GameTime.yearOf(w.week) < fromYear) return 0;
    final waited = math.min(2.0, (w.week - s.writtenWeek) / 26);
    return weeklyChance *
        a.fame *
        a.fame *
        waited *
        (announced ? 2 : 1) *
        // A teased song leaks more easily (docs K152).
        (s.snippetWeek >= 0 ? Snippets.leakFactor : 1);
  }

  /// Rolls this week's leak among the player's vault songs; returns the
  /// song that leaked, if any (one a week at most).
  static Song? weekly(World w) {
    final p = w.player;
    if (p == null || GameTime.yearOf(w.week) < fromYear) return null;
    final announced = <int>{
      for (final sr in p.scheduled)
        if (!sr.isDraft && sr.announcedBy(w.week)) ...sr.songIds
    };
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.status != SongStatus.vault || s.leakedWeek >= 0) continue;
      final odds = chance(w, p, s, announced: announced.contains(id));
      if (odds <= 0) continue;
      if (keyedUnit(w.seed, w.week, id, RngPurpose.leak) < odds) {
        s.leakedWeek = w.week;
        w.dirtySongs.add(id);
        return s;
      }
    }
    return null;
  }

  /// Out officially soon enough after leaking.
  static bool answered(Song s) =>
      s.leakedWeek >= 0 &&
      s.releasedWeek >= 0 &&
      s.releasedWeek - s.leakedWeek <= answerWeeks;

  /// Leaked and not answered.
  static bool hurts(Song s) => s.leakedWeek >= 0 && !answered(s);

  /// Whether leaked vault song [s] can still be answered in [week].
  static bool canAnswer(Song s, int week) =>
      s.leakedWeek >= 0 &&
      s.releasedWeek < 0 &&
      week - s.leakedWeek <= answerWeeks;

  /// [s] came out: an answered leak brings its wave.
  static void onRelease(World w, Song s) {
    if (s.releasedWeek != w.week || !answered(s)) return;
    s.versionBoost += answerBoost;
    w.dirtySongs.add(s.id);
  }

  /// Fans' listening [s] keeps.
  static double fanFactor(Song s) => hurts(s) ? fanKeep : 1.0;

  /// Sales [al] keeps for its leaked tracks.
  static double albumKeep(World w, Album al) {
    var n = 0;
    for (final id in al.songIds) {
      if (hurts(w.songs[id])) n++;
    }
    if (n == 0) return 1;
    final cut = GameTime.yearOf(al.releaseWeek) < 2015
        ? albumCutDownloadEra
        : albumCutStreamingEra;
    return 1 - math.min(albumMaxCut, cut * n);
  }
}
