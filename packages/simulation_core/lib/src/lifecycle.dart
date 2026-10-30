import 'dart:math' as math;

import 'config/charts.dart';
import 'config/regions.dart';
import 'config/sim_config.dart';
import 'leaks.dart';
import 'model.dart';
import 'rerecords.dart';
import 'rng.dart';
import 'snippets.dart';
import 'world.dart';

/// Song / album state transitions (ACTIVE <-> DORMANT) with lazy accrual.
/// See docs/simulation.md §5.
abstract final class Lifecycle {
  static void activateSong(World w, Song s) {
    s.status = SongStatus.active;
    World.insertSorted(w.activeSongIds, s.id);
    w.dirtySongs.add(s.id);
    Rerecords.onRelease(w, s);
    Leaks.onRelease(w, s);
    Snippets.onRelease(w, s);
  }

  /// Scales dormant [s]'s catalog listening by [f] from now on, what it
  /// played so far kept (docs K139).
  static void scaleDormant(World w, Song s, double f) {
    if (s.status != SongStatus.dormant) return;
    final a = w.primaryOf(s);
    w.settleRetired(a);
    for (var r = 0; r < regionCount; r++) {
      s.reg[SongReg.lifeStreams + r] = w.songLifetimeStreams(s, r);
      s.reg[SongReg.lifeDownloads + r] = w.songLifetimeDownloads(s, r);
      s.reg[SongReg.indexStreams + r] = w.artistIndexStreams(a, r);
      s.reg[SongReg.indexDownloads + r] = w.artistIndexDownloads(a, r);
    }
    final delta = s.dormantRate * (f - 1);
    a.sumDormantRate = math.max(0.0, a.sumDormantRate + delta);
    if (a.isRetired) {
      for (var r = 0; r < regionCount; r++) {
        w.retiredDormantAttention[r] +=
            delta * a.catalogFactor * a.regionShare[r];
      }
    }
    if (s.albumId >= 0) {
      final al = w.albums[s.albumId];
      settleAlbum(w, al);
      al.sumDormantRate = math.max(0.0, al.sumDormantRate + delta);
    }
    s.dormantRate *= f;
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// How much of its last listening a song keeps in the catalog (docs
  /// K85): people come back to the hits, not to an album's other tracks.
  /// Top-10 singles keep far more than deep cuts that never charted; the
  /// overall level is [SimConfig.catalogLevel].
  static double catalogWeight(Song s) {
    var best = 999;
    for (final ch in Charts.mainSongCharts) {
      final peak = s.statsOrNull(ch)?.peak ?? 0;
      if (peak > 0 && peak < best) best = peak;
    }
    if (s.isSingle) {
      return best <= 10
          ? 1.8
          : best <= 40
              ? 1.2
              : 0.7;
    }
    return best <= 10
        ? 1.0
        : best <= 40
            ? 0.5
            : 0.25;
  }

  /// Listeners give an artist's back catalog only so much time (docs
  /// K222): beyond [SimConfig.catalogSongs] songs each new one gets less,
  /// so a hundred quick releases do not pay like a hundred hits.
  static double catalogShare(SimConfig c, int songs) => songs <= c.catalogSongs
      ? 1.0
      : math.pow(c.catalogSongs / songs, c.catalogShareExponent).toDouble();

  /// An old song's trend for quarter [quarter] (docs K261): mostly its
  /// usual level; now and then found again (a film, a show, a nostalgia
  /// wave: 1.4–3×) or out of fashion (0.55–0.8×) for that quarter.
  static double catalogTrend(int seed, int quarter, int songId) {
    final u = keyedUnit(seed, quarter, songId, RngPurpose.catalogTrend);
    if (u < resurgenceChance) {
      return 1.4 + 1.6 * (u / resurgenceChance);
    }
    if (u < resurgenceChance + slumpChance) {
      return 0.55 + 0.25 * ((u - resurgenceChance) / slumpChance);
    }
    return 1;
  }

  /// Weeks between an artist's catalog updates ([Simulator]'s fade).
  static const fadeWeeks = 13;

  /// The last week at or before [week] when artist [artistId]'s catalog
  /// was updated (each artist's turn comes every [fadeWeeks] weeks).
  static int lastCatalogUpdate(int week, int artistId) =>
      week - (week - artistId) % fadeWeeks;

  /// A quarter's chances of an old song being found again, or out of
  /// fashion (docs K261).
  static const resurgenceChance = 0.06, slumpChance = 0.06;

  /// Weekly plays one unit of [a]'s dormant rate brings at last week's
  /// market (the drift averages out).
  static double playsPerRate(World w, Artist a) {
    var perRate = 0.0;
    for (var r = 0; r < regionCount; r++) {
      perRate += a.catalogFactor * a.regionShare[r] * w.lastSpa[r];
    }
    return perRate;
  }

  static void makeSongDormant(World w, Song s) {
    final a = w.primaryOf(s);
    w.settleRetired(a);
    final fresh = s.lastAttention /
        a.catalogFactor *
        catalogWeight(s) *
        w.config.catalogLevel *
        catalogShare(w.config, a.dormantSongIds.length + 1) *
        // The trend the artist's next catalog update takes off (docs
        // K261): the quarter of its last one.
        catalogTrend(w.seed, lastCatalogUpdate(w.week, a.id) ~/ fadeWeeks,
            s.id);
    // Back in the catalog after a comeback: at least where it was.
    final rate = math.max(fresh, s.dormantRate);
    s.dormantRate = rate;
    // The catalog floor's yardstick (docs K265).
    final perRate = playsPerRate(w, a);
    if (perRate > 0) {
      s.catalogBase =
          math.max(s.catalogBase, w.songLifetimeStreams(s) / perRate);
    }
    for (var r = 0; r < regionCount; r++) {
      s.reg[SongReg.indexStreams + r] = a.reg[ArtistReg.indexStreams + r];
      s.reg[SongReg.indexDownloads + r] = a.reg[ArtistReg.indexDownloads + r];
    }
    s.status = SongStatus.dormant;
    s.weekRegion = null;
    s.weeksBelowCutoff = 0;
    s.viralBoost = 0;
    _clearLastPos(s);
    a.sumDormantRate += rate;
    if (a.isRetired) {
      for (var r = 0; r < regionCount; r++) {
        w.retiredDormantAttention[r] +=
            rate * a.catalogFactor * a.regionShare[r];
      }
    }
    a.dormantSongIds.add(s.id);
    w.dormantSongCount++;
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
    if (s.albumId >= 0) {
      final al = w.albums[s.albumId];
      settleAlbum(w, al);
      al.sumDormantRate += rate;
    }
    _removeSorted(w.activeSongIds, s.id);
  }

  static void reactivateSong(World w, Song s) {
    if (s.status != SongStatus.dormant) return;
    final a = w.primaryOf(s);
    w.settleRetired(a);
    for (var r = 0; r < regionCount; r++) {
      final streams = w.songLifetimeStreams(s, r);
      final downloads = w.songLifetimeDownloads(s, r);
      s.reg[SongReg.lifeStreams + r] = streams;
      s.reg[SongReg.lifeDownloads + r] = downloads;
    }
    a.sumDormantRate -= s.dormantRate;
    if (a.sumDormantRate < 0) a.sumDormantRate = 0;
    if (a.isRetired) {
      for (var r = 0; r < regionCount; r++) {
        w.retiredDormantAttention[r] -=
            s.dormantRate * a.catalogFactor * a.regionShare[r];
      }
    }
    a.dormantSongIds.remove(s.id);
    w.dormantSongCount--;
    w.dirtyArtists.add(a.id);
    if (s.albumId >= 0) {
      final al = w.albums[s.albumId];
      settleAlbum(w, al);
      al.sumDormantRate -= s.dormantRate;
      if (al.sumDormantRate < 0) al.sumDormantRate = 0;
      if (al.status == AlbumStatus.dormant) reactivateAlbum(w, al);
    }
    // Its catalog listening is kept while it is back (docs K262): the
    // active song plays it on top, and it is the least it goes back to.
    activateSong(w, s);
  }

  /// Folds lazily accrued SEA into the album's settled lifetime units.
  static void settleAlbum(World w, Album al) {
    if (al.status != AlbumStatus.dormant) return;
    final a = w.artists[al.artistId];
    for (var r = 0; r < regionCount; r++) {
      final units = w.albumLifetimeUnits(al, r);
      al.reg[AlbumReg.lifeUnits + r] = units;
      al.reg[AlbumReg.indexStreams + r] = w.artistIndexStreams(a, r);
    }
    w.dirtyAlbums.add(al.id);
  }

  static void makeAlbumDormant(World w, Album al) {
    al.status = AlbumStatus.dormant;
    final a = w.artists[al.artistId];
    for (var r = 0; r < regionCount; r++) {
      al.reg[AlbumReg.indexStreams + r] = w.artistIndexStreams(a, r);
    }
    w.dirtyAlbums.add(al.id);
    al.weeksBelowCutoff = 0;
    _clearLastPos(al);
    _removeSorted(w.activeAlbumIds, al.id);
  }

  static void reactivateAlbum(World w, Album al) {
    if (al.status != AlbumStatus.dormant) return;
    settleAlbum(w, al);
    al.status = AlbumStatus.active;
    World.insertSorted(w.activeAlbumIds, al.id);
    w.dirtyAlbums.add(al.id);
  }

  static void _clearLastPos(Charted e) {
    final cs = e.charts;
    if (cs == null) return;
    for (final c in cs) {
      c?.lastPos = 0;
    }
  }

  static void _removeSorted(List<int> list, int id) {
    var lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid] < id) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo < list.length && list[lo] == id) list.removeAt(lo);
  }
}
