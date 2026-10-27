import 'dart:math' as math;

import 'anniversaries.dart';
import 'model.dart';
import 'world.dart';

/// Why an album cannot have a new version now (docs K225).
enum VersionBlock {
  /// Not the artist's own album.
  notYours,

  /// A mixtape or a greatest hits album.
  kind,

  /// Not out yet.
  notOut,

  /// An edition it came out with is still to come.
  editionsPending,

  /// As many editions as an album can have.
  full,
}

/// New versions of an album after it is out (docs K225): a deluxe, a
/// "3am edition", a platinum edition, an anniversary edition. Each has its
/// own name and cover, may add up to [maxTracks] unreleased songs as bonus
/// tracks and comes out in a format (digital only, CD, vinyl…). Fans buy
/// it that week and the album is talked about again; one after another
/// they buy less and start calling it a cash grab.
abstract final class AlbumVersions {
  /// Editions an album can have in all, those it came out with included.
  static const maxEditions = 12;

  /// Bonus tracks one version can add.
  static const maxTracks = 6;

  /// Versions this close together tire the fans.
  static const fatigueWeeks = 12;

  /// The hype a version brings, halved for each one shortly before it.
  static const hype = 0.1;

  /// What a version costs: its format, plus the remaster for an
  /// anniversary edition.
  static int costCents(EditionFormat format, {bool anniversary = false}) =>
      format.costCents + (anniversary ? Anniversaries.remasterCents : 0);

  /// Why [a] cannot put out a new version of [al] now, or null.
  static VersionBlock? block(World w, Artist a, Album al) {
    if (al.artistId != a.id) return VersionBlock.notYours;
    if (al.type == AlbumType.mixtape || al.hitIds.isNotEmpty) {
      return VersionBlock.kind;
    }
    if (w.week <= al.releaseWeek) return VersionBlock.notOut;
    if (al.variantWeeks.any((x) => al.releaseWeek + x > w.week)) {
      return VersionBlock.editionsPending;
    }
    if (al.variantWeeks.length >= maxEditions) return VersionBlock.full;
    return null;
  }

  /// Versions of [al] out in the [fatigueWeeks] before this week.
  static int recent(World w, Album al) =>
      al.versions.where((v) => w.week - v.week < fatigueWeeks).length;

  /// How much hype the next version of [al] brings.
  static double nextHype(World w, Album al) =>
      hype * math.pow(0.5, recent(w, al));

  /// Whether fans would call the next version of [al] a cash grab.
  static bool tiresFans(World w, Album al) => recent(w, al) >= 2;

  /// The version that made edition [k] of [al], or null (an edition it
  /// came out with, or an older save's deluxe).
  static AlbumVersion? ofEdition(Album al, int k) {
    for (final v in al.versions) {
      if (v.edition == k) return v;
    }
    return null;
  }

  /// The version [songId] came out on as a bonus track, or null.
  static AlbumVersion? ofSong(Album al, int songId) {
    for (final v in al.versions) {
      if (v.songIds.contains(songId)) return v;
    }
    return null;
  }
}
