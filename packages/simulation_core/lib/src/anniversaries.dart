import 'actions.dart';
import 'album_versions.dart';
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
      AlbumVersions.block(w, a, al) == null && due(w, al) >= 0;

  /// Reissues [al] for its anniversary: remastered, on a collector's
  /// vinyl (the quick way; docs K226 lets the player add songs and a new
  /// cover).
  static void reissue(World w, Artist a, Album al) {
    if (!can(w, a, al)) throw ActionException('No anniversary now');
    Actions.releaseAlbumVersion(w, a, al,
        format: EditionFormat.vinyl, anniversary: true);
  }
}
