import 'dart:math' as math;

import 'config/charts.dart';
import 'config/regions.dart';
import 'model.dart';
import 'rerecords.dart';
import 'world.dart';

/// Song / album state transitions (ACTIVE <-> DORMANT) with lazy accrual.
/// See docs/simulation.md §5.
abstract final class Lifecycle {
  static void activateSong(World w, Song s) {
    s.status = SongStatus.active;
    World.insertSorted(w.activeSongIds, s.id);
    w.dirtySongs.add(s.id);
    Rerecords.onRelease(w, s);
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

  static void makeSongDormant(World w, Song s) {
    final a = w.primaryOf(s);
    w.settleRetired(a);
    final rate = s.lastAttention /
        a.catalogFactor *
        catalogWeight(s) *
        w.config.catalogLevel;
    s.dormantRate = rate;
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
    s.dormantRate = 0;
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
