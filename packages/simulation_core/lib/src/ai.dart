import 'actions.dart';
import 'model.dart';
import 'names.dart';
import 'real_artists.dart';
import 'rng.dart';
import 'streaming_tools.dart';
import 'time.dart';
import 'tours.dart';
import 'world.dart';
import 'world_gen.dart';

/// A rival's album that met the player's announced album in the same
/// week (docs K109): moved out of the way ([toWeek] later), or kept for a
/// head-to-head ([moved] false).
class RivalClash {
  const RivalClash(
      {required this.artistId,
      required this.title,
      required this.fromWeek,
      required this.toWeek,
      required this.playerWeek});
  final int artistId;
  final String title;
  final int fromWeek;
  final int toWeek;
  final int playerWeek;
  bool get moved => toWeek != fromWeek;
}

/// AI artist behaviour: era planning and release execution (Tier A/B), plus
/// yearly world upkeep (retirements, newcomers, tier re-ranking).
abstract final class AiPlanner {
  /// Weeks before its album a rival looks at the player's calendar.
  static const clashLookahead = 3;

  /// Runs the rivals' week; returns their answers to the player's
  /// announced albums.
  static List<RivalClash> step(World w) {
    if (GameTime.weekOfYear(w.week) == 1) _yearlyUpkeep(w);
    final clashes = <RivalClash>[];
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      // The player and their members' solo names (docs K158) plan
      // nothing; songs given to a member are still released.
      if (a.tier == ArtistTier.player) continue;
      if (a.managedBy >= 0) {
        _executeDue(w, a);
        continue;
      }
      if (a.plan.isEmpty && w.week >= a.nextEraWeek) _planEra(w, a);
      final clash = _avoidClash(w, a);
      if (clash != null) clashes.add(clash);
      _executeDue(w, a);
    }
    return clashes;
  }

  /// Three weeks before a rival's album, a clash with the player's
  /// announced album is settled (docs K109): a less famous rival moves two
  /// or three weeks past it; a star as big or bigger keeps the date.
  static RivalClash? _avoidClash(World w, Artist a) {
    final me = w.player;
    if (me == null) return null;
    final i = a.plan.indexWhere((p) => p.kind == PlannedKind.album);
    if (i < 0 || a.plan[i].week - w.week != clashLookahead) return null;
    final week = a.plan[i].week;
    ScheduledRelease? mine;
    for (final sr in me.scheduled) {
      if (sr.isAlbum &&
          sr.announcedBy(w.week) &&
          (sr.releaseWeek - week).abs() <= 1) {
        mine = sr;
        break;
      }
    }
    if (mine == null) return null;
    // Only the charts' contenders care.
    if (a.tier != ArtistTier.a && a.fame < 0.3) return null;
    if (a.fame >= me.fame - 0.1) {
      return RivalClash(
          artistId: a.id,
          title: a.pendingAlbumTitle,
          fromWeek: week,
          toWeek: week,
          playerWeek: mine.releaseWeek);
    }
    final r =
        RandomStream.keyed(w.seed, w.week, a.id, RngPurpose.aiPlanning + 41);
    final shift = mine.releaseWeek - week + 2 + r.nextInt(2);
    for (var j = 0; j < a.plan.length; j++) {
      final p = a.plan[j];
      if (p.week >= week) {
        a.plan[j] = PlannedRelease(
            week: p.week + shift, kind: p.kind, songId: p.songId);
      }
    }
    w.dirtyArtists.add(a.id);
    return RivalClash(
        artistId: a.id,
        title: a.pendingAlbumTitle,
        fromWeek: week,
        toWeek: week + shift,
        playerWeek: mine.releaseWeek);
  }

  static void _executeDue(World w, Artist a) {
    while (a.plan.isNotEmpty && a.plan.first.week <= w.week) {
      final p = a.plan.removeAt(0);
      switch (p.kind) {
        case PlannedKind.leadSingle || PlannedKind.single:
          // Stars' labels promote hard: a bigger campaign, and heavy radio
          // for the lead single (docs K84). Working artists get the usual.
          final star = a.tier == ArtistTier.a;
          Actions.releaseSingle(w, a, w.songs[p.songId],
              campaign: star ? Campaign.intensive : Campaign.standard,
              radio: star && p.kind == PlannedKind.leadSingle
                  ? RadioPush.heavy
                  : RadioPush.standard);
          // Their fans stream in parties; some teams buy streams (K95).
          if (star && p.kind == PlannedKind.leadSingle) {
            StreamingTools.starRelease(w, a, w.songs[p.songId]);
          }
          // Stars sell a CD single of the lead to fans again (docs K92).
          if (star &&
              p.kind == PlannedKind.leadSingle &&
              GameTime.yearOf(w.week) >= 2019 &&
              RandomStream.keyed(
                      w.seed, w.week, a.id, RngPurpose.aiPlanning + 40)
                  .chance(0.5)) {
            Actions.releaseVariant(w, a, w.songs[p.songId], SingleFormat.cd);
          }
        case PlannedKind.album:
          Actions.releaseAlbum(w, a, a.pendingAlbumTitle, a.pendingAlbumSongIds,
              type: a.pendingAlbumType, variantWeeks: a.pendingVariantWeeks);
          a.pendingAlbumSongIds.clear();
      }
    }
  }

  /// The artist's genre, sometimes with a crossover genre (own stream, so
  /// planning draws are unaffected).
  static List<int> _songGenres(World w, Artist a, int track) {
    final g = RandomStream.keyed(
        w.seed, w.week, a.id * 64 + track, RngPurpose.songGenres);
    if (!g.chance(0.2)) return [a.genre];
    final extra =
        (a.genre + 1 + g.nextInt(genreNames.length - 1)) % genreNames.length;
    return [a.genre, extra];
  }

  static void _planEra(World w, Artist a) {
    final r = RandomStream.keyed(w.seed, w.week, a.id, RngPurpose.aiPlanning);
    final isA = a.tier == ArtistTier.a;
    final producerSkill = isA ? r.range(72, 94) : r.range(42, 76);

    // Tier B sometimes runs a singles-only cycle.
    if (!isA && r.chance(0.15)) {
      final s = Actions.writeSong(w, a,
          producerSkill: producerSkill,
          aiMode: true,
          featured: _maybeFeature(w, a, r),
          genres: _songGenres(w, a, 0));
      a.plan.add(PlannedRelease(
          week: w.week, kind: PlannedKind.leadSingle, songId: s.id));
      a.nextEraWeek = w.week + 20 + r.nextInt(40);
      return;
    }

    final isEp = !isA && r.chance(0.25);
    final trackCount =
        isEp ? 5 + r.nextInt(3) : (isA ? 12 + r.nextInt(4) : 9 + r.nextInt(4));
    final tracks = <Song>[];
    for (var i = 0; i < trackCount; i++) {
      tracks.add(Actions.writeSong(w, a,
          producerSkill: producerSkill,
          aiMode: true,
          featured: i < 3 ? _maybeFeature(w, a, r) : const [],
          genres: _songGenres(w, a, i)));
    }
    // Best commercial prospects become singles.
    final ranked = List.of(tracks)
      ..sort((x, y) {
        final c = _singleScore(y).compareTo(_singleScore(x));
        return c != 0 ? c : x.id.compareTo(y.id);
      });
    final lead = ranked[0];
    final albumWeek = w.week + 6 + r.nextInt(5);
    a.plan.add(PlannedRelease(
        week: w.week, kind: PlannedKind.leadSingle, songId: lead.id));
    a.plan.add(PlannedRelease(week: albumWeek, kind: PlannedKind.album));
    if (ranked.length > 1) {
      a.plan.add(PlannedRelease(
          week: albumWeek + 6 + r.nextInt(7),
          kind: PlannedKind.single,
          songId: ranked[1].id));
    }
    // Stars keep an era going with more singles (docs K84).
    if (isA && ranked.length > 2) {
      a.plan.add(PlannedRelease(
          week: albumWeek + 16 + r.nextInt(8),
          kind: PlannedKind.single,
          songId: ranked[2].id));
    }
    if (isA && ranked.length > 3 && r.chance(0.5)) {
      a.plan.add(PlannedRelease(
          week: albumWeek + 28 + r.nextInt(10),
          kind: PlannedKind.single,
          songId: ranked[3].id));
    }
    a.pendingAlbumSongIds
      ..clear()
      ..addAll(tracks.map((s) => s.id));
    a.pendingAlbumTitle =
        Names.album(RandomStream.keyed(w.seed, w.week, a.id, RngPurpose.names));
    a.pendingAlbumType = isEp ? AlbumType.ep : AlbumType.album;
    a.pendingVariantWeeks = _variantPlan(w, a, r, albumWeek, isA);

    // Superstars take 2–4 years (sometimes a long hiatus); working artists
    // put out a project about once a year; vocal groups come back faster
    // (docs/game-design.md §2.4). Release volume drives album-chart churn.
    var gap = isA
        ? (r.chance(0.10) ? 260 + r.nextInt(105) : 90 + r.nextInt(95))
        : 26 + r.nextInt(50);
    if (a.kind == ArtistKind.vocalGroup) gap = (gap * 0.6).round();
    a.nextEraWeek = albumWeek + gap;
  }

  /// Stars in the collector era release many variants; half of them stagger
  /// variants over the following weeks to stay at #1.
  static List<int> _variantPlan(
      World w, Artist a, RandomStream r, int albumWeek, bool isA) {
    final collector = w.config.era.forWeek(albumWeek).collectorFactor;
    final int extra;
    if (isA) {
      extra = (a.fame * 8 * collector * r.range(0.5, 1.2)).round().clamp(0, 9);
    } else {
      extra = r.chance(0.5 * collector) ? 1 : 0;
    }
    final stagger = isA && r.chance(0.5);
    final weeks = [0];
    for (var i = 1; i <= extra; i++) {
      weeks.add(stagger && i > extra ~/ 2 ? i - extra ~/ 2 : 0);
    }
    return weeks;
  }

  static double _singleScore(Song s) =>
      0.6 * s.commercial + 0.4 * s.quality / 100;

  static List<int> _maybeFeature(World w, Artist a, RandomStream r) {
    if (!r.chance(0.12)) return const [];
    for (var tries = 0; tries < 5; tries++) {
      final other = w.artists[r.nextInt(w.artists.length)];
      if (other.id != a.id &&
          !other.isRetired &&
          other.tier != ArtistTier.player) {
        return [other.id];
      }
    }
    return const [];
  }

  /// Real stars get their first 12 years to break through before a weak
  /// start can end their career (docs K66).
  static bool _protected(World w, Artist a, double yearsActive) =>
      w.realNames && yearsActive < 12 && realStar(a.name) >= 2;

  static void _yearlyUpkeep(World w) {
    final c = w.config;
    // Retirements.
    for (final a in w.artists) {
      if (a.tier == ArtistTier.player || a.isRetired || a.managedBy >= 0) {
        continue;
      }
      final r = RandomStream.keyed(w.seed, w.week, a.id, RngPurpose.newArtists);
      final yearsActive = (w.week - a.debutWeek) / GameTime.weeksPerYear;
      // A real star's label push helps them break through, then their
      // songs and fans have to carry them; otherwise every year's stars
      // would pile up and crowd out everyone else (docs K70).
      if (w.realNames &&
          yearsActive >= c.realStarPushYears &&
          a.labelReach > 1.0 &&
          realStar(a.name) >= 2) {
        a.labelReach = 1.0;
        w.dirtyArtists.add(a.id);
      }
      if (_protected(w, a, yearsActive)) continue;
      final weak = a.fame < 0.06 && yearsActive > 4;
      final p = (weak ? 0.15 : 0.0) + (yearsActive > 25 ? 0.10 : 0.0);
      if (r.chance(p) && a.plan.isEmpty) w.retire(a);
    }
    // Population control: keep the number of active AI artists at the target
    // so a 100-year career does not grow the world (docs/simulation.md §8).
    final target = c.tierACount + c.tierBCount;
    final alive = w.artists
        .where((a) =>
            a.tier != ArtistTier.player && !a.isRetired && a.managedBy < 0)
        .toList()
      ..sort((x, y) {
        final f = x.fame.compareTo(y.fame);
        return f != 0 ? f : x.id.compareTo(y.id);
      });
    var excess = alive.length + c.newArtistsPerYear - target;
    for (final a in alive) {
      if (excess <= 0) break;
      if (a.plan.isNotEmpty || a.eraOpen) continue;
      if (_protected(w, a, (w.week - a.debutWeek) / GameTime.weeksPerYear)) {
        continue;
      }
      w.retire(a);
      excess--;
    }
    // Newcomers.
    for (var i = 0; i < c.newArtistsPerYear; i++) {
      WorldGen.addNewAiArtist(w);
    }
    // Re-rank tiers by fame: top N non-player artists are Tier A.
    final ai = w.artists
        .where((a) =>
            a.tier != ArtistTier.player && !a.isRetired && a.managedBy < 0)
        .toList()
      ..sort((x, y) {
        final f = y.fame.compareTo(x.fame);
        return f != 0 ? f : x.id.compareTo(y.id);
      });
    for (var i = 0; i < ai.length; i++) {
      ai[i].tier = i < c.tierACount ? ArtistTier.a : ArtistTier.b;
    }
    // Rivals' tours for the box-office rankings (docs K77).
    RivalTours.bookYear(w);
  }
}
