import 'dart:math' as math;

import 'actions.dart';
import 'anniversaries.dart';
import 'model.dart';
import 'time.dart';
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

  /// A dated version is set already (docs K255).
  planned,
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
    if (al.planned != null) return VersionBlock.planned;
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

  /// Longest lead time for a dated version (docs K255).
  static const maxLeadWeeks = 26;

  /// Pre-orders reach at most this share of the fans' expected copies of
  /// the album, times the format's appeal; each announced week takes
  /// [preOrderRate] of what is left.
  static const preOrderCeiling = 0.3, preOrderRate = 0.12;

  /// Sets a version of [al] for [releaseWeek], announced in [announceWeek]
  /// ([releaseWeek]: a surprise; docs K255). Paid now; the songs wait in
  /// the vault for it.
  static PlannedVersion schedule(World w, Artist a, Album al,
      {required String name,
      required EditionFormat format,
      List<int> songIds = const [],
      required int releaseWeek,
      required int announceWeek}) {
    final why = block(w, a, al);
    if (why != null) throw ActionException('No new version: ${why.name}');
    if (al.planned != null) throw ActionException('One is set already');
    if (releaseWeek <= w.week || releaseWeek > w.week + maxLeadWeeks) {
      throw ActionException('Release week out of range');
    }
    if (announceWeek < w.week || announceWeek > releaseWeek) {
      throw ActionException('Announce week out of range');
    }
    if (songIds.length > maxTracks ||
        songIds.toSet().length != songIds.length) {
      throw ActionException('Up to $maxTracks bonus tracks');
    }
    for (final id in songIds) {
      final s = w.songs[id];
      if (s.primaryArtistId != a.id || s.status != SongStatus.vault) {
        throw ActionException('Only unreleased songs');
      }
      if (reserved(w, id)) throw ActionException('Song is set for a version');
    }
    final cost = costCents(format);
    if (a.moneyCents < cost) throw ActionException('Not enough money');
    a.moneyCents -= cost;
    final p = PlannedVersion(
        name: name.trim(),
        format: format,
        songIds: List.of(songIds),
        releaseWeek: releaseWeek,
        announceWeek: announceWeek);
    al.planned = p;
    w.dirtyAlbums.add(al.id);
    w.dirtyArtists.add(a.id);
    return p;
  }

  /// Song [id] waits for a dated version of one of the albums.
  static bool reserved(World w, int id) {
    for (final al in w.albums) {
      if (al.planned?.songIds.contains(id) ?? false) return true;
    }
    return false;
  }

  /// Calls off [al]'s dated version; nothing is refunded.
  static void cancel(World w, Album al) {
    if (al.planned == null) throw ActionException('Nothing set');
    al.planned = null;
    w.dirtyAlbums.add(al.id);
  }

  /// Before the week is played (docs K255): announced versions build hype
  /// and take pre-orders; those due come out, their pre-orders shipping.
  static void weekly(World w, Artist a) {
    final year = GameTime.yearOf(w.week);
    for (final al in w.albums) {
      if (al.artistId != a.id) continue;
      al.versionShipping = 0;
      final p = al.planned;
      if (p == null) continue;
      if (w.week >= p.releaseWeek) {
        al.planned = null;
        final songs = [
          for (final id in p.songIds)
            if (w.songs[id].status == SongStatus.vault) id
        ];
        if (block(w, a, al) == null) {
          Actions.releaseAlbumVersion(w, a, al,
              name: p.name, songIds: songs, format: p.format, paid: true);
          al.versionShipping = p.preOrders;
          // The wait made it an event.
          a.hype += p.buzz * 0.5;
        }
        w.dirtyAlbums.add(al.id);
        continue;
      }
      if (!p.announcedBy(w.week)) continue;
      final cap = nextHype(w, al) * 1.5;
      if (p.buzz < cap) p.buzz += (cap - p.buzz) * 0.25;
      a.hype = math.max(a.hype, 0.5 * p.buzz);
      final most = preOrderCeiling *
          Actions.expectedFanCopies(w, a, al.songIds) *
          p.format.appeal(year) *
          (tiresFans(w, al) ? 0.5 : 1);
      if (p.preOrders < most) {
        p.preOrders += (most - p.preOrders) * preOrderRate;
      }
      w.dirtyAlbums.add(al.id);
      w.dirtyArtists.add(a.id);
    }
  }

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
