import 'dart:math' as math;

import 'actions.dart';
import 'model.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// How a snippet went down (docs K152), worst first.
enum SnippetReaction { cold, lukewarm, good, hot }

/// Snippet tests (docs K152): from 2019 artists tease a few seconds of an
/// unreleased song on the short-video app to see how people take it. The
/// reaction tells how catchy the song really is (with some noise), fans
/// start waiting for it, and a teased song leaks more easily.
abstract final class Snippets {
  static const fromYear = 2019;

  /// Creativity a snippet takes (filming, posting).
  static const energy = 3.0;

  /// Weeks a teased song stays awaited: out within them, it comes with a
  /// wave as big as the reaction.
  static const waitWeeks = 8;

  /// The wave of a release that was teased to a [SnippetReaction.hot]
  /// reaction (a remix brings 0.35).
  static const maxBoost = 0.2;

  /// How much more often a teased song leaks.
  static const leakFactor = 1.5;

  /// The reaction score of [s] (0–100): mostly how catchy, shareable and
  /// lovable it is, with some luck.
  static double score(World w, Song s) {
    final base = 0.5 * s.virality + 0.3 * s.commercial + 0.2 * s.fanAppeal;
    final noise =
        RandomStream.keyed(w.seed, 0, s.id, RngPurpose.snippet).logNormal(0.15);
    return (100 * base * noise).clamp(0.0, 100.0).toDouble();
  }

  static SnippetReaction reaction(double score) => score >= 60
      ? SnippetReaction.hot
      : score >= 45
          ? SnippetReaction.good
          : score >= 30
              ? SnippetReaction.lukewarm
              : SnippetReaction.cold;

  /// Whether [a] can tease [s] now: an unreleased song, once, one snippet
  /// a week.
  static bool can(World w, Artist a, Song s) =>
      GameTime.yearOf(w.week) >= fromYear &&
      s.primaryArtistId == a.id &&
      s.status == SongStatus.vault &&
      s.snippetWeek < 0 &&
      !w.playerSongIds.any((id) => w.songs[id].snippetWeek == w.week);

  /// Teases [s]: its reaction is known from now on.
  static void tease(World w, Artist a, Song s) {
    if (!can(w, a, s)) throw ActionException('No snippet now');
    if (a.creativeEnergy < energy) {
      throw ActionException('Not enough creativity');
    }
    a.creativeEnergy -= energy;
    s.snippetWeek = w.week;
    s.snippetScore = score(w, s);
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// [s] came out: a teased song still awaited brings its wave.
  static void onRelease(World w, Song s) {
    if (s.snippetWeek < 0 ||
        s.releasedWeek != w.week ||
        w.week - s.snippetWeek > waitWeeks) {
      return;
    }
    s.versionBoost += maxBoost * math.pow(s.snippetScore / 100, 1.5);
    w.dirtySongs.add(s.id);
  }
}
