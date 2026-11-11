import 'actions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'world.dart';

/// Taking a record off the market (docs K293, K294): off the streaming
/// services and out of the shops, as artists do with records they disown
/// or rights they fight over. An album takes its other tracks with it;
/// its singles stay out unless the player takes them off one by one.
/// Everything a record did is kept, its chart runs included, and it can
/// come back any time, its streams and sales where they were.
abstract final class OffMarket {
  /// Whether [s] is off the market: taken off on its own, or an album
  /// track of a record that is (a single taken off with its album before
  /// K294 holds its listening too).
  static bool songOff(World w, Song s) =>
      s.offWeek >= 0 ||
      (s.albumId >= 0 &&
          w.albums[s.albumId].isOff &&
          (!s.isSingle || s.heldRate > 0));

  /// Whether [a] can take [al] off now: theirs, out, on sale.
  static bool canTakeOff(World w, Artist a, Album al) =>
      al.artistId == a.id &&
      al.releaseWeek >= 0 &&
      al.releaseWeek < w.week &&
      !al.isOff &&
      al.planned == null;

  /// Whether [a] can take single [s] off on its own.
  static bool canTakeSongOff(World w, Artist a, Song s) =>
      s.isSingle &&
      s.primaryArtistId == a.id &&
      s.releasedWeek >= 0 &&
      s.releasedWeek < w.week &&
      !songOff(w, s);

  /// [al]'s own tracks (not those a later record took over).
  static Iterable<Song> tracks(World w, Album al) => [
        for (final id in al.songIds)
          if (w.songs[id].albumId == al.id) w.songs[id]
      ];

  /// Stops [s] playing and selling, its listening held.
  static void _hold(World w, Song s) {
    if (s.status == SongStatus.active) Lifecycle.makeSongDormant(w, s);
    if (s.status == SongStatus.dormant && s.dormantRate > 0) {
      s.heldRate = s.dormantRate;
      Lifecycle.scaleDormant(w, s, 0);
    }
    if (s.radioLevel > 0) s.radioLevel = 0;
    w.dirtySongs.add(s.id);
  }

  static void _release(World w, Song s) {
    if (s.heldRate > 0) {
      Lifecycle.restoreDormant(w, s, s.heldRate);
      s.heldRate = 0;
    }
    w.dirtySongs.add(s.id);
  }

  static void takeOff(World w, Artist a, Album al) {
    if (!canTakeOff(w, a, al)) throw ActionException('Not on sale');
    for (final s in tracks(w, al)) {
      // Its singles stay out (docs K294).
      if (s.isSingle || s.offWeek >= 0) continue;
      _hold(w, s);
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
      // A single taken off on its own stays off.
      if (s.offWeek >= 0) continue;
      _release(w, s);
    }
    w.dirtyAlbums.add(al.id);
  }

  /// Takes single [s] off the market on its own (docs K294).
  static void takeSongOff(World w, Artist a, Song s) {
    if (!canTakeSongOff(w, a, s)) throw ActionException('Not on sale');
    _hold(w, s);
    s.offWeek = w.week;
  }

  static void putSongBack(World w, Artist a, Song s) {
    if (s.primaryArtistId != a.id || s.offWeek < 0) {
      throw ActionException('Not off the market');
    }
    s.offWeek = -1;
    _release(w, s);
  }
}
