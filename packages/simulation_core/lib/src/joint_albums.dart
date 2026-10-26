import 'actions.dart';
import 'audience.dart';
import 'features.dart';
import 'model.dart';
import 'world.dart';

/// Joint albums (docs K150), the Watch the Throne move: the player and a
/// rival put out a record together. The rival is on every track, and their
/// fans buy it too.
abstract final class JointAlbums {
  /// Their fee: three verses' worth for a whole record.
  static int feeCents(Artist rival) => Features.feeCents(rival) * 3;

  /// Share of the partner's fans who buy it like their own.
  static const partnerFans = 0.5;

  /// Whether [rival] would make a record with [a].
  static bool willing(Artist rival, Artist a) =>
      rival.id != a.id &&
      !rival.isRetired &&
      rival.tier != ArtistTier.player &&
      Features.willing(rival, a);

  /// Makes just-released [al] a joint album with [rival]: they are paid
  /// and appear on every track with room for them.
  static void join(World w, Artist a, Album al, Artist rival) {
    if (al.artistId != a.id || al.partnerId >= 0) {
      throw ActionException('Not your album');
    }
    if (!willing(rival, a)) throw ActionException('Out of reach');
    final fee = feeCents(rival);
    if (a.moneyCents < fee) throw ActionException('Not enough money');
    a.moneyCents -= fee;
    al.campaignCostCents += fee;
    al.partnerId = rival.id;
    for (final id in al.songIds) {
      final s = w.songs[id];
      if (s.featuredArtistIds.contains(rival.id) ||
          s.featuredArtistIds.length >= Features.maxPerSong) {
        continue;
      }
      s.featuredArtistIds.add(rival.id);
      w.dirtySongs.add(id);
    }
    w.dirtyAlbums.add(al.id);
    w.dirtyArtists.add(a.id);
  }

  /// Core fans buying [al] in region share [share] beyond its artist's.
  static double extraFans(World w, Album al, int region) {
    if (al.partnerId < 0) return 0;
    final p = w.artists[al.partnerId];
    return partnerFans * Audience.engaged(p) * p.regionShare[region];
  }
}
