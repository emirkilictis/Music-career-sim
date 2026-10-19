import 'dart:convert';
import 'dart:math' as math;

import 'config/regions.dart';
import 'model.dart';
import 'world.dart';

/// A K-pop music show's week (docs K114): the winner and runner-up.
class MusicShowWeek {
  const MusicShowWeek(
      {required this.week,
      required this.songId,
      required this.score,
      this.runnerUpId = -1,
      this.runnerUpScore = 0,
      this.tripleCrown = false});
  final int week;
  final int songId;

  /// Points out of 10,000.
  final int score;
  final int runnerUpId;
  final int runnerUpScore;

  /// The third win in a row: the song leaves the show.
  final bool tripleCrown;

  List<int> toJson() => [
        week,
        songId,
        score,
        runnerUpId,
        runnerUpScore,
        tripleCrown ? 1 : 0,
      ];

  static MusicShowWeek fromJson(List<dynamic> j) => MusicShowWeek(
        week: j[0] as int,
        songId: j[1] as int,
        score: j[2] as int,
        runnerUpId: j[3] as int,
        runnerUpScore: j[4] as int,
        tripleCrown: j[5] == 1,
      );
}

/// The show's record: recent weeks and every song's wins.
class MusicShowState {
  final List<MusicShowWeek> weeks = [];

  /// Wins per song.
  final Map<int, int> wins = {};

  /// Songs that took the Triple Crown (retired from the show).
  final Set<int> crowned = {};

  String encode() => jsonEncode({
        'w': [for (final x in weeks) x.toJson()],
        'n': {for (final e in wins.entries) '${e.key}': e.value},
        'c': crowned.toList(),
      });

  void decode(String? s) {
    if (s == null || s.isEmpty) return;
    final j = jsonDecode(s) as Map<String, dynamic>;
    weeks
      ..clear()
      ..addAll(
          [for (final x in j['w'] as List) MusicShowWeek.fromJson(x as List)]);
    wins
      ..clear()
      ..addAll({
        for (final e in (j['n'] as Map<String, dynamic>).entries)
          int.parse(e.key): e.value as int
      });
    crowned
      ..clear()
      ..addAll((j['c'] as List).cast<int>());
  }
}

/// A weekly K-pop music show (docs K114). Every week the K-pop singles
/// out in the last [eligibleWeeks] compete: digital (streams and
/// downloads where the genre lives) half, album and CD sales a quarter,
/// broadcast 15%, fans' votes 10%. The winner's fans are thrilled; three
/// wins in a row is a Triple Crown and the song leaves the show.
abstract final class MusicShow {
  /// [genreNames] index of K-pop.
  static const genre = 18;

  /// Weeks a single can compete after it comes out.
  static const eligibleWeeks = 8;

  /// Weeks of results kept.
  static const kept = 30;

  /// The show starts with the K-pop wave.
  static const startYear = 2010;

  static bool _eligible(World w, Song s) =>
      s.isSingle &&
      s.status == SongStatus.active &&
      w.artists[s.primaryArtistId].genre == genre &&
      w.week - s.singleWeek < eligibleWeeks &&
      !w.musicShow.crowned.contains(s.id);

  /// Holds this week's show; null without at least two songs.
  static MusicShowWeek? weekly(World w, int year) {
    if (year < startYear) return null;
    final songs = [
      for (final id in w.activeSongIds)
        if (_eligible(w, w.songs[id])) w.songs[id]
    ];
    if (songs.length < 2) return null;
    final other = Region.other.index;
    double digital(Song s) =>
        (s.weekRegion?[other] ?? 0) +
        150 * (s.weekRegion?[regionCount + other] ?? 0);
    double physical(Song s) {
      var x = s.weekPhysical;
      if (s.albumId >= 0) {
        final al = w.albums[s.albumId];
        if (w.week - al.releaseWeek < eligibleWeeks) x += al.weekPure;
      }
      return x;
    }

    double broadcast(Song s) => s.weekRadio;
    double vote(Song s) {
      final a = w.artists[s.primaryArtistId];
      return a.coreFans * (0.3 + a.devotion);
    }

    double top(double Function(Song) f) =>
        songs.map(f).fold(0.0, math.max) + 1e-9;
    final d = top(digital), p = top(physical), b = top(broadcast);
    final v = top(vote);
    final scored = [
      for (final s in songs)
        (
          s,
          (10000 *
                  (0.5 * digital(s) / d +
                      0.25 * physical(s) / p +
                      0.15 * broadcast(s) / b +
                      0.10 * vote(s) / v))
              .round()
        )
    ]..sort((x, y) {
        final c = y.$2.compareTo(x.$2);
        return c != 0 ? c : x.$1.id.compareTo(y.$1.id);
      });
    final (win, score) = scored[0];
    final st = w.musicShow;
    // Three in a row: this win and the two weeks before it.
    var streak = 1;
    for (var i = st.weeks.length - 1;
        i >= 0 && streak < 3 && st.weeks[i].songId == win.id;
        i--) {
      if (st.weeks[i].week != w.week - streak) break;
      streak++;
    }
    final crown = streak >= 3;
    st.wins[win.id] = (st.wins[win.id] ?? 0) + 1;
    if (crown) st.crowned.add(win.id);
    final result = MusicShowWeek(
      week: w.week,
      songId: win.id,
      score: score,
      runnerUpId: scored[1].$1.id,
      runnerUpScore: scored[1].$2,
      tripleCrown: crown,
    );
    st.weeks.add(result);
    if (st.weeks.length > kept) st.weeks.removeRange(0, st.weeks.length - kept);
    // The fandom celebrates, mostly the first time: a win every week
    // must not become a hype machine (docs K105).
    final a = w.artists[win.primaryArtistId];
    final first = (st.wins[win.id] ?? 0) == 1;
    a.hype += first ? 0.02 : 0.005;
    a.devotion = math.min(1.0, a.devotion + (first ? 0.004 : 0.001));
    w.dirtyArtists.add(a.id);
    return result;
  }
}
