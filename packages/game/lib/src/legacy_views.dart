import 'package:simulation_core/simulation_core.dart';

import 'best_sellers.dart';
import 'events.dart' show EntityKind;
import 'views.dart';

/// One artist on the all-time list (docs K288).
class LegacyRow {
  const LegacyRow({
    required this.rank,
    required this.artistId,
    required this.name,
    required this.score,
    required this.isPlayer,
    required this.hallOfFameYear,
    required this.retired,
    required this.title,
  });
  final int rank;
  final int artistId;
  final String name;
  final double score;
  final bool isPlayer;

  /// The year they went into the Hall of Fame (0: not in).
  final int hallOfFameYear;
  final bool retired;
  final LegacyTitle title;
}

/// One of the player's biggest records on the legacy page.
class LegacyRecord {
  const LegacyRecord({
    required this.kind,
    required this.id,
    required this.title,
    required this.albumId,
    required this.year,
    required this.units,
    required this.peak,
  });
  final EntityKind kind;
  final int id;
  final String title;

  /// For the cover (-1: none).
  final int albumId;
  final int year;
  final double units;

  /// Best place on a main chart (0: never charted).
  final int peak;
}

/// The Hall of Fame, year by year (docs K288).
class HallOfFameRow {
  const HallOfFameRow({
    required this.year,
    required this.artistId,
    required this.name,
    required this.score,
    required this.isPlayer,
  });
  final int year;
  final int artistId;
  final String name;
  final double score;
  final bool isPlayer;
}

/// The player's legacy page and career summary (docs K288).
class LegacyView {
  const LegacyView({
    required this.name,
    required this.artistId,
    required this.firstYear,
    required this.lastYear,
    required this.retired,
    required this.score,
    required this.rank,
    required this.ranked,
    required this.title,
    required this.sales,
    required this.hits,
    required this.numberOnes,
    required this.awards,
    required this.longevity,
    required this.units,
    required this.recordsSold,
    required this.streams,
    required this.no1Singles,
    required this.no1Albums,
    required this.top10,
    required this.awardWins,
    required this.hitYears,
    required this.hallOfFameYear,
    required this.yearsToEligible,
    required this.topSongs,
    required this.topAlbums,
    required this.canRetire,
  });
  final String name;
  final int artistId;

  /// The career's first year, and its last (the retirement year, or this
  /// one).
  final int firstYear, lastYear;
  final bool retired;
  final double score;

  /// All-time rank (0: not on the list yet) among [ranked] artists.
  final int rank, ranked;
  final LegacyTitle title;

  /// The score's parts.
  final double sales, hits, numberOnes, awards, longevity;
  final double units, recordsSold, streams;

  /// #1 singles and albums on the US or the global chart (each record
  /// once).
  final int no1Singles, no1Albums;
  final int top10, awardWins, hitYears;

  /// The Hall of Fame year (0: not in), and the years until the player
  /// can go in (0: can now).
  final int hallOfFameYear, yearsToEligible;
  final List<LegacyRecord> topSongs, topAlbums;

  /// Whether the career can end now (not on tour, nothing scheduled).
  final bool canRetire;
}

abstract final class LegacyViews {
  static const listSize = 50;

  static int _hofYear(World w, int id) {
    for (final h in w.hallOfFame) {
      if (h.artistId == id) return h.year;
    }
    return 0;
  }

  static int _peak(Charted e, List<int> charts) {
    var best = 0;
    for (final ch in charts) {
      final p = e.statsOrNull(ch)?.peak ?? 0;
      if (p > 0 && (best == 0 || p < best)) best = p;
    }
    return best;
  }

  /// The all-time list (docs K288) from [parts] and [ranking].
  static List<LegacyRow> list(World w, Map<int, LegacyParts> parts,
      List<(int, double)> ranking,
      {int limit = listSize}) {
    var rank = 0;
    return [
      for (final (id, score) in ranking.take(limit))
        LegacyRow(
          rank: ++rank,
          artistId: id,
          name: w.artists[id].name,
          score: score,
          isPlayer: id == w.playerArtistId,
          hallOfFameYear: _hofYear(w, id),
          retired: w.artists[id].isRetired,
          title: Legacy.title(parts[id], rank,
              (w.week - w.artists[id].debutWeek) / GameTime.weeksPerYear),
        ),
    ];
  }

  /// Latest class first, each class by score.
  static List<HallOfFameRow> hallOfFame(World w) => [
        for (final h in [...w.hallOfFame]..sort((a, b) {
            final d = b.year.compareTo(a.year);
            return d != 0 ? d : b.score.compareTo(a.score);
          }))
          HallOfFameRow(
            year: h.year,
            artistId: h.artistId,
            name: w.artists[h.artistId].name,
            score: h.score,
            isPlayer: h.artistId == w.playerArtistId,
          ),
      ];

  /// The player's place in [ranking] (0: not on it).
  static int rankOf(World w, List<(int, double)> ranking) {
    for (var i = 0; i < ranking.length; i++) {
      if (ranking[i].$1 == w.playerArtistId) return i + 1;
    }
    return 0;
  }

  static LegacyView of(World w, Map<int, LegacyParts> parts,
      List<(int, double)> ranking) {
    final p = w.player!;
    final mine = parts[p.id];
    final rank = rankOf(w, ranking);
    final retired = w.playerRetiredWeek >= 0;
    final years = (w.week - p.debutWeek) / GameTime.weeksPerYear;
    final songs = [
      for (final id in w.playerSongIds)
        if (w.songs[id].releasedWeek >= 0 &&
            w.songs[id].primaryArtistId == p.id)
          w.songs[id]
    ];
    final songRows = [
      for (final s in songs)
        LegacyRecord(
          kind: EntityKind.song,
          id: s.id,
          title: s.title,
          albumId: coverAlbumOf(w, s),
          year: GameTime.yearOf(s.releasedWeek),
          units: BestSellers.songUnits(w, s),
          peak: _peak(s, Charts.mainSongCharts),
        )
    ]..sort((a, b) {
        final d = b.units.compareTo(a.units);
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    final albumRows = [
      for (final al in w.albums)
        if (al.artistId == p.id &&
            al.releaseWeek >= 0 &&
            al.releaseWeek <= w.week)
          LegacyRecord(
            kind: EntityKind.album,
            id: al.id,
            title: al.title,
            albumId: al.id,
            year: GameTime.yearOf(al.releaseWeek),
            units: w.albumLifetimeUnits(al),
            peak: _peak(al, Charts.mainAlbumCharts),
          )
    ]..sort((a, b) {
        final d = b.units.compareTo(a.units);
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    var no1Singles = 0;
    for (final s in songs) {
      if ((s.statsOrNull(Charts.usSongs)?.peak ?? 0) == 1 ||
          (s.statsOrNull(Charts.globalSongs)?.peak ?? 0) == 1) {
        no1Singles++;
      }
    }
    var no1Albums = 0;
    for (final al in w.albums) {
      if (al.artistId != p.id) continue;
      if ((al.statsOrNull(Charts.usAlbums)?.peak ?? 0) == 1 ||
          (al.statsOrNull(Charts.globalAlbums)?.peak ?? 0) == 1) {
        no1Albums++;
      }
    }
    return LegacyView(
      name: p.name,
      artistId: p.id,
      firstYear: GameTime.yearOf(p.debutWeek),
      lastYear: GameTime.yearOf(retired ? w.playerRetiredWeek : w.week),
      retired: retired,
      score: mine?.total ?? 0,
      rank: rank,
      ranked: ranking.length,
      title: Legacy.title(mine, rank, years),
      sales: mine?.sales ?? 0,
      hits: mine?.hits ?? 0,
      numberOnes: mine?.numberOnes ?? 0,
      awards: mine?.awards ?? 0,
      longevity: mine?.longevity ?? 0,
      units: mine?.units ?? 0,
      recordsSold: BestSellers.playerSales(w),
      streams: w.playerCareerStreams,
      no1Singles: no1Singles,
      no1Albums: no1Albums,
      top10: mine?.top10 ?? 0,
      awardWins: mine?.awardWins ?? 0,
      hitYears: mine?.hitYears ?? 0,
      hallOfFameYear: _hofYear(w, p.id),
      yearsToEligible: HallOfFame.yearsToEligible(w, p),
      topSongs: songRows.take(5).toList(),
      topAlbums: albumRows.take(5).toList(),
      canRetire: !retired && p.tour == null && p.scheduled.isEmpty,
    );
  }
}
