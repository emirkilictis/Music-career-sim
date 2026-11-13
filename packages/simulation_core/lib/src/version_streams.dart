import 'dart:math' as math;

import 'model.dart';
import 'time.dart';
import 'world.dart';

/// Each version of a song counts its own plays (docs K300): a remix, a
/// sped-up or a slowed version is its own track on the apps, with its
/// own play count, while sales, certifications and the charts still add
/// every version up. From the week it came out a version takes a share
/// of the song's plays, most at first and a steady part after; the
/// original keeps the rest.
abstract final class VersionStreams {
  /// A version's share of the song's plays while it is new, by kind and
  /// year (sped-up and slowed are a short-video thing).
  static double kind(SongVersion v, int year) => switch (v) {
        SongVersion.remix => 0.20,
        SongVersion.spedUp => year >= 2021
            ? 0.25
            : year >= 2018
                ? 0.12
                : 0.05,
        SongVersion.slowed => year >= 2021
            ? 0.20
            : year >= 2018
                ? 0.10
                : 0.05,
        SongVersion.acapella => 0.03,
        SongVersion.instrumental => 0.04,
        SongVersion.session => 0.08,
      };

  /// What a version keeps once it is old, of its share while new.
  static const steady = 0.35;
  static const freshWeeks = 10.0;

  /// The most of a song's plays its versions take together.
  static const maxShare = 0.6;

  /// The shares of [s]'s versions [week] by week, scaled down together
  /// to [maxShare] at most. With [old], their steady shares.
  static List<double> shares(Song s, int week, {bool old = false}) {
    final year = GameTime.yearOf(week);
    final out = [
      for (final (v, at) in s.versions)
        kind(v, year) *
            (old
                ? steady
                : steady +
                    (1 - steady) *
                        math.exp(-math.max(0, week - at) / freshWeeks))
    ];
    final sum = out.fold(0.0, (a, b) => a + b);
    if (sum > maxShare) {
      for (var i = 0; i < out.length; i++) {
        out[i] *= maxShare / sum;
      }
    }
    return out;
  }

  /// Brings [s]'s version counts up to its plays so far: [weekPlays] at
  /// this week's shares, anything played while it sat in the catalog at
  /// the steady shares.
  static void settle(World w, Song s, {double weekPlays = 0}) {
    if (s.versions.isEmpty) return;
    while (s.versionStreams.length < s.versions.length) {
      s.versionStreams.add(0);
    }
    final life = w.songLifetimeStreams(s);
    // A save from before K300: its versions count from now.
    if (s.versionSettled <= 0) {
      s.versionSettled = life;
      return;
    }
    final gap = math.max(0.0, life - s.versionSettled - weekPlays);
    final now = shares(s, w.week);
    final tail = gap > 0 ? shares(s, w.week, old: true) : now;
    for (var i = 0; i < s.versions.length; i++) {
      s.versionStreams[i] += weekPlays * now[i] + gap * tail[i];
    }
    s.versionSettled = life;
    w.dirtySongs.add(s.id);
  }

  /// A new version of [s] came out: the others are brought up to date
  /// first, and it starts from nothing.
  static void added(World w, Song s) {
    final n = s.versions.length - 1;
    if (n > 0) {
      // Settle the older ones before the new one takes its share.
      final v = s.versions.removeLast();
      settle(w, s);
      s.versions.add(v);
    }
    while (s.versionStreams.length < s.versions.length) {
      s.versionStreams.add(0);
    }
    s.versionSettled = w.songLifetimeStreams(s);
    w.dirtySongs.add(s.id);
  }

  /// Each version's plays now, catalog plays since the last count
  /// included (in the order of [Song.versions]).
  static List<double> of(World w, Song s) {
    if (s.versions.isEmpty) return const [];
    final out = [
      for (var i = 0; i < s.versions.length; i++)
        i < s.versionStreams.length ? s.versionStreams[i] : 0.0
    ];
    if (s.versionSettled > 0) {
      final gap = math.max(0.0, w.songLifetimeStreams(s) - s.versionSettled);
      if (gap > 0) {
        final tail = shares(s, w.week, old: true);
        for (var i = 0; i < out.length; i++) {
          out[i] += gap * tail[i];
        }
      }
    }
    return out;
  }

  /// The original's own plays: all of [s]'s plays less its versions'.
  static double original(World w, Song s) =>
      math.max(0.0,
          w.songLifetimeStreams(s) - of(w, s).fold(0.0, (a, b) => a + b));
}
