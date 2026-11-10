import 'dart:convert';

import 'config/charts.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// What a career's legacy is made of (docs K288), in points.
class LegacyParts {
  double sales = 0;
  double hits = 0;
  double numberOnes = 0;
  double awards = 0;
  double longevity = 0;

  /// Top-10 songs (primary artist, any main song chart).
  int top10 = 0;

  /// Golden Record Awards won.
  int awardWins = 0;

  /// Years with a top-10 song out.
  int hitYears = 0;

  /// Units: album units plus singles on no album (as the best sellers
  /// count them).
  double units = 0;

  double get total => sales + hits + numberOnes + awards + longevity;

  final Set<int> _hitYears = {};
}

/// The name a career earns (docs K288). Stored by index: append only.
enum LegacyTitle {
  legend,
  icon,
  star,
  hitmaker,
  oneHitWonder,
  cultFavourite,
  rising,
  working,
}

/// The player's place in music history (docs K288): one score from what a
/// career sold, its hits and number ones, its awards and how long it kept
/// having hits; every artist has one, so the player can be ranked among
/// the greatest of all time. Records from before the world's own history
/// are not known to it: a legend whose best years came before it ranks
/// below their real place.
abstract final class Legacy {
  /// Points: a million units; a top-10 song, a top-40 one.
  static const perMillionUnits = 1.0;
  static const perTop10 = 4.0, perTop40 = 1.0;

  /// A #1 single or album on the US or the global chart; on the UK one.
  static const perNo1 = 5.0, perUkNo1 = 2.0;

  /// A week at #1 of the US or the global song chart.
  static const perWeekAtNo1 = 1.0;

  /// A Golden Record Award: one of the big four, a genre one; a
  /// nomination.
  static const perBigWin = 8.0, perGenreWin = 3.0, perNomination = 0.5;

  /// Each year with a top-10 song beyond the first.
  static const perHitYear = 5.0;

  /// Song units count streams as certifications do.
  static const streamsPerUnit = 150;

  /// Every artist's parts, in one pass over the world's records.
  static Map<int, LegacyParts> all(World w) {
    final out = <int, LegacyParts>{};
    LegacyParts of(int id) => out.putIfAbsent(id, LegacyParts.new);
    for (final al in w.albums) {
      if (al.releaseWeek < 0 || al.releaseWeek > w.week) continue;
      of(al.artistId).units += w.albumLifetimeUnits(al);
    }
    for (final s in w.songs) {
      if (s.releasedWeek < 0 || s.releasedWeek > w.week) continue;
      final p = of(s.primaryArtistId);
      if (s.albumId < 0) {
        p.units += w.songLifetimeDownloads(s) +
            s.lifetimePhysical +
            w.songLifetimeStreams(s) / streamsPerUnit;
      }
      var best = 0;
      for (final ch in Charts.mainSongCharts) {
        final peak = s.statsOrNull(ch)?.peak ?? 0;
        if (peak > 0 && (best == 0 || peak < best)) best = peak;
      }
      if (best == 0 || best > 40) continue;
      if (best <= 10) {
        p.top10++;
        p.hits += perTop10;
        p._hitYears.add(GameTime.yearOf(s.releasedWeek));
      } else {
        p.hits += perTop40;
      }
    }
    for (final show in w.awardShows) {
      if (!show.held) continue;
      for (final r in show.races) {
        for (final n in r.nominees) {
          of(n.artistId).awards += perNomination;
        }
        final won = r.won;
        if (won == null) continue;
        final p = of(won.artistId);
        p.awardWins++;
        p.awards += r.category.isGeneralField ? perBigWin : perGenreWin;
      }
    }
    for (final a in w.artists) {
      final p = out[a.id];
      if (p == null) continue;
      p.sales = p.units / 1e6 * perMillionUnits;
      p.numberOnes = perNo1 *
              (a.no1Singles[Charts.usSongs] +
                  a.no1Singles[Charts.globalSongs] +
                  a.no1Albums[Charts.usAlbums] +
                  a.no1Albums[Charts.globalAlbums]) +
          perUkNo1 * (a.no1Singles[Charts.ukSongs] + a.no1Albums[Charts.ukAlbums]) +
          perWeekAtNo1 *
              (a.weeksAtNo1[Charts.usSongs] + a.weeksAtNo1[Charts.globalSongs]);
      p.hitYears = p._hitYears.length;
      p.longevity = p.hitYears > 1 ? (p.hitYears - 1) * perHitYear : 0;
    }
    return out;
  }

  /// Artists by score, best first (ties by id).
  static List<(int, double)> ranking(Map<int, LegacyParts> parts) {
    final out = [
      for (final e in parts.entries)
        if (e.value.total > 0) (e.key, e.value.total)
    ]..sort((a, b) {
        final d = b.$2.compareTo(a.$2);
        return d != 0 ? d : a.$1.compareTo(b.$1);
      });
    return out;
  }

  /// The name for a career at [rank] (0: unranked) with [p], [years] in.
  static LegacyTitle title(LegacyParts? p, int rank, double years) {
    if (p == null) return years < 5 ? LegacyTitle.rising : LegacyTitle.working;
    final score = p.total;
    if (rank > 0 && rank <= 10 && score >= 300) return LegacyTitle.legend;
    if (rank > 0 && rank <= 50 && score >= 120) return LegacyTitle.icon;
    if (score >= 120) return LegacyTitle.star;
    if (p.top10 >= 5) return LegacyTitle.hitmaker;
    if (p.top10 == 1 && score < 40 && years >= 5) {
      return LegacyTitle.oneHitWonder;
    }
    if (p.awardWins > 0 && p.top10 == 0) return LegacyTitle.cultFavourite;
    if (years < 5) return LegacyTitle.rising;
    return LegacyTitle.working;
  }
}

/// One artist in the Hall of Fame (docs K288).
class HallOfFamer {
  const HallOfFamer(this.artistId, this.year, this.score);
  final int artistId;
  final int year;

  /// Their legacy score on the day.
  final double score;
}

/// The Hall of Fame (docs K288), as the Rock & Roll one: an artist can go
/// in twenty-five years after their first record; each spring the voters
/// take the biggest legacies not in yet, up to five, ten in its first
/// class.
abstract final class HallOfFame {
  static const eligibleYears = 25;
  static const weekOfYear = 17;
  static const perYear = 5, firstClass = 10;

  /// The score a career needs to be considered.
  static const minScore = 100.0;

  /// Years until [a] can go in (0: can now).
  static int yearsToEligible(World w, Artist a) {
    final left = GameTime.yearOf(a.debutWeek) +
        eligibleYears -
        GameTime.yearOf(w.week);
    return left < 0 ? 0 : left;
  }

  static bool contains(World w, int artistId) =>
      w.hallOfFame.any((h) => h.artistId == artistId);

  /// This spring's ballot: eligible artists not in, by score. With
  /// [parts] (all of them) precomputed.
  static List<(int, double)> ballot(World w, Map<int, LegacyParts> parts) {
    final inside = {for (final h in w.hallOfFame) h.artistId};
    return [
      for (final (id, score) in Legacy.ranking(parts))
        if (score >= minScore &&
            !inside.contains(id) &&
            yearsToEligible(w, w.artists[id]) == 0)
          (id, score)
    ];
  }

  /// The year's class, once a year at [weekOfYear]; only once there is a
  /// player (the world's history before is not ranked). Returns the new
  /// members and the player's place on the ballot (0: not on it).
  static (List<HallOfFamer>, int) induct(World w) {
    if (w.player == null) return (const [], 0);
    if (GameTime.weekOfYear(w.week) != weekOfYear) return (const [], 0);
    final year = GameTime.yearOf(w.week);
    if (w.hallOfFame.any((h) => h.year == year)) return (const [], 0);
    final parts = Legacy.all(w);
    final ballot = HallOfFame.ballot(w, parts);
    final size = w.hallOfFame.isEmpty ? firstClass : perYear;
    final out = [
      for (final (id, score) in ballot.take(size)) HallOfFamer(id, year, score)
    ];
    w.hallOfFame.addAll(out);
    final me = w.playerArtistId;
    var place = 0;
    for (var i = 0; i < ballot.length; i++) {
      if (ballot[i].$1 == me) place = i + 1;
    }
    return (out, place);
  }

  static String encode(List<HallOfFamer> h) => jsonEncode([
        for (final x in h) [x.artistId, x.year, x.score]
      ]);

  static List<HallOfFamer> decode(String? s) => s == null || s.isEmpty
      ? []
      : [
          for (final x in jsonDecode(s) as List)
            HallOfFamer((x as List)[0] as int, x[1] as int,
                (x[2] as num).toDouble())
        ];
}
