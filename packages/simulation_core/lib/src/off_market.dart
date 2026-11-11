import 'actions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'world.dart';

/// Taking a record off the market (docs K293): off the streaming services
/// and out of the shops, as artists do with records they disown or rights
/// they fight over. Its tracks stop playing and selling; everything it
/// did is kept, its chart runs included, and it can come back any time,
/// its streams and sales where they were.
abstract final class OffMarket {
  /// Whether [a] can take [al] off now: theirs, out, on sale.
  static bool canTakeOff(World w, Artist a, Album al) =>
      al.artistId == a.id &&
      al.releaseWeek >= 0 &&
      al.releaseWeek < w.week &&
      !al.isOff &&
      al.planned == null;

  /// [al]'s own tracks (not those a later record took over).
  static Iterable<Song> tracks(World w, Album al) => [
        for (final id in al.songIds)
          if (w.songs[id].albumId == al.id) w.songs[id]
      ];

  static void takeOff(World w, Artist a, Album al) {
    if (!canTakeOff(w, a, al)) throw ActionException('Not on sale');
    for (final s in tracks(w, al)) {
      if (s.status == SongStatus.active) Lifecycle.makeSongDormant(w, s);
      if (s.status == SongStatus.dormant && s.dormantRate > 0) {
        s.heldRate = s.dormantRate;
        Lifecycle.scaleDormant(w, s, 0);
      }
      s.radioLevel = s.radioLevel > 0 ? 0 : s.radioLevel;
      w.dirtySongs.add(s.id);
    }
    if (al.status == AlbumStatus.active) Lifecycle.makeAlbumDormant(w, al);
    al.offWeek = w.week;
    w.dirtyAlbums.add(al.id);
  }

  /// Back on the market: its tracks play again from where they were.
  static void putBack(World w, Artist a, Album al) {
    if (al.artistId != a.id || !al.isOff) {
      throw ActionException('Not off the market');
    }
    al.offWeek = -1;
    for (final s in tracks(w, al)) {
      if (s.heldRate > 0) {
        Lifecycle.restoreDormant(w, s, s.heldRate);
        s.heldRate = 0;
      }
    }
    w.dirtyAlbums.add(al.id);
  }
}
