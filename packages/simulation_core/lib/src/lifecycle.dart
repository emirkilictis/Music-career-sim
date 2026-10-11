import 'model.dart';
import 'world.dart';

/// Song / album state transitions (ACTIVE <-> DORMANT) with lazy accrual.
/// See docs/simulation.md §5.
abstract final class Lifecycle {
  static void activateSong(World w, Song s) {
    s.status = SongStatus.active;
    World.insertSorted(w.activeSongIds, s.id);
  }

  static void makeSongDormant(World w, Song s) {
    final a = w.primaryOf(s);
    final rate = s.lastAttention / a.catalogFactor;
    s.dormantRate = rate;
    s.indexAtSettleStreams = a.catalogIndexStreams;
    s.indexAtSettleDownloads = a.catalogIndexDownloads;
    s.status = SongStatus.dormant;
    s.weeksBelowCutoff = 0;
    s.viralBoost = 0;
    s.lastPos = 0;
    a.sumDormantRate += rate;
    a.dormantSongIds.add(s.id);
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
    s.lifetimeStreams = w.songLifetimeStreams(s);
    s.lifetimeDownloads = w.songLifetimeDownloads(s);
    a.sumDormantRate -= s.dormantRate;
    if (a.sumDormantRate < 0) a.sumDormantRate = 0;
    a.dormantSongIds.remove(s.id);
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
    al.lifetimeUnits = w.albumLifetimeUnits(al);
    al.indexAtSettle = w.artists[al.artistId].catalogIndexStreams;
  }

  static void makeAlbumDormant(World w, Album al) {
    al.status = AlbumStatus.dormant;
    al.indexAtSettle = w.artists[al.artistId].catalogIndexStreams;
    al.weeksBelowCutoff = 0;
    al.lastPos = 0;
    _removeSorted(w.activeAlbumIds, al.id);
  }

  static void reactivateAlbum(World w, Album al) {
    if (al.status != AlbumStatus.dormant) return;
    settleAlbum(w, al);
    al.status = AlbumStatus.active;
    World.insertSorted(w.activeAlbumIds, al.id);
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
