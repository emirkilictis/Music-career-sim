import 'actions.dart';
import 'model.dart';
import 'names.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';
import 'world_gen.dart';

/// AI artist behaviour: era planning and release execution (Tier A/B), plus
/// yearly world upkeep (retirements, newcomers, tier re-ranking).
abstract final class AiPlanner {
  static void step(World w) {
    if (GameTime.weekOfYear(w.week) == 1) _yearlyUpkeep(w);
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      if (a.tier == ArtistTier.player) continue;
      if (a.plan.isEmpty && w.week >= a.nextEraWeek) _planEra(w, a);
      _executeDue(w, a);
    }
  }

  static void _executeDue(World w, Artist a) {
    while (a.plan.isNotEmpty && a.plan.first.week <= w.week) {
      final p = a.plan.removeAt(0);
      switch (p.kind) {
        case PlannedKind.leadSingle || PlannedKind.single:
          Actions.releaseSingle(w, a, w.songs[p.songId]);
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
    if (!isA && r.chance(0.35)) {
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
    if (isA && ranked.length > 2 && r.chance(0.6)) {
      a.plan.add(PlannedRelease(
          week: albumWeek + 18 + r.nextInt(9),
          kind: PlannedKind.single,
          songId: ranked[2].id));
    }
    a.pendingAlbumSongIds
      ..clear()
      ..addAll(tracks.map((s) => s.id));
    a.pendingAlbumTitle =
        Names.album(RandomStream.keyed(w.seed, w.week, a.id, RngPurpose.names));
    a.pendingAlbumType = isEp ? AlbumType.ep : AlbumType.album;
    a.pendingVariantWeeks = _variantPlan(w, a, r, albumWeek, isA);

    final int gap;
    if (isA) {
      gap = r.chance(0.10) ? 260 + r.nextInt(105) : 100 + r.nextInt(100);
    } else {
      gap = 50 + r.nextInt(80);
    }
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

  static void _yearlyUpkeep(World w) {
    final c = w.config;
    // Retirements.
    for (final a in w.artists) {
      if (a.tier == ArtistTier.player || a.isRetired) continue;
      final r = RandomStream.keyed(w.seed, w.week, a.id, RngPurpose.newArtists);
      final yearsActive = (w.week - a.debutWeek) / GameTime.weeksPerYear;
      final weak = a.fame < 0.06 && yearsActive > 4;
      final p = (weak ? 0.15 : 0.0) + (yearsActive > 25 ? 0.10 : 0.0);
      if (r.chance(p) && a.plan.isEmpty) w.retire(a);
    }
    // Population control: keep the number of active AI artists at the target
    // so a 100-year career does not grow the world (docs/simulation.md §8).
    final target = c.tierACount + c.tierBCount;
    final alive = w.artists
        .where((a) => a.tier != ArtistTier.player && !a.isRetired)
        .toList()
      ..sort((x, y) {
        final f = x.fame.compareTo(y.fame);
        return f != 0 ? f : x.id.compareTo(y.id);
      });
    var excess = alive.length + c.newArtistsPerYear - target;
    for (final a in alive) {
      if (excess <= 0) break;
      if (a.plan.isNotEmpty || a.eraOpen) continue;
      w.retire(a);
      excess--;
    }
    // Newcomers.
    for (var i = 0; i < c.newArtistsPerYear; i++) {
      WorldGen.addNewAiArtist(w);
    }
    // Re-rank tiers by fame: top N non-player artists are Tier A.
    final ai = w.artists
        .where((a) => a.tier != ArtistTier.player && !a.isRetired)
        .toList()
      ..sort((x, y) {
        final f = y.fame.compareTo(x.fame);
        return f != 0 ? f : x.id.compareTo(y.id);
      });
    for (var i = 0; i < ai.length; i++) {
      ai[i].tier = i < c.tierACount ? ArtistTier.a : ArtistTier.b;
    }
  }
}
