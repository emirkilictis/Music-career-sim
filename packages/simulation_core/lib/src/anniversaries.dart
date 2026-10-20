import 'actions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// Anniversary reissues (docs K149): ten, twenty, twenty-five and thirty
/// years on, an album can come out again remastered, with a collector's
/// vinyl. Old fans buy it again and its songs are played again.
abstract final class Anniversaries {
  /// The anniversaries, in years; each has a year to be marked.
  static const years = [10, 20, 25, 30];

  /// The remaster's wave for each track (a remix brings 0.35).
  static const remasterBoost = 0.08;

  /// Remastering, on top of the vinyl edition.
  static const remasterCents = 3000000;

  static int costCents() => remasterCents + EditionFormat.vinyl.costCents;

  /// The anniversary [al] can mark now (index into [years]), or -1.
  static int due(World w, Album al) {
    final age = w.week - al.releaseWeek;
    for (var i = 0; i < years.length; i++) {
      final from = years[i] * GameTime.weeksPerYear;
      if (age >= from &&
          age < from + GameTime.weeksPerYear &&
          al.anniversaries & (1 << i) == 0) {
        return i;
      }
    }
    return -1;
  }

  /// Whether [a] can reissue [al] now.
  static bool can(World w, Artist a, Album al) =>
      al.artistId == a.id && al.type != AlbumType.mixtape && due(w, al) >= 0;

  /// Reissues [al] for its anniversary.
  static void reissue(World w, Artist a, Album al) {
    final i = due(w, al);
    if (al.artistId != a.id || al.type == AlbumType.mixtape || i < 0) {
      throw ActionException('No anniversary now');
    }
    final cost = costCents();
    if (a.moneyCents < cost) throw ActionException('Not enough money');
    a.moneyCents -= cost;
    al.campaignCostCents += cost;
    al.anniversaries |= 1 << i;
    if (al.status == AlbumStatus.dormant) Lifecycle.reactivateAlbum(w, al);
    al.weeksBelowCutoff = 0;
    for (final id in al.songIds) {
      final s = w.songs[id];
      if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
      s.weeksBelowCutoff = 0;
      s.versionBoost += remasterBoost;
      w.dirtySongs.add(id);
    }
    // The collector's vinyl comes out this week, among its editions.
    final formats = [
      for (var k = 0; k < al.variantWeeks.length; k++)
        k < al.variantFormats.length ? al.variantFormats[k] : -1
    ];
    al.variantWeeks = [...al.variantWeeks, w.week - al.releaseWeek];
    al.variantFormats = [...formats, EditionFormat.vinyl.index];
    w.dirtyAlbums.add(al.id);
    w.dirtyArtists.add(a.id);
  }
}
