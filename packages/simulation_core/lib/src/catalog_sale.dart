import 'actions.dart';
import 'config/regions.dart';
import 'model.dart';
import 'rerecords.dart';
import 'time.dart';
import 'world.dart';

/// Selling the catalog (docs K153): from 2018 investment funds bought
/// artists' old recordings for many years of their earnings at once, most
/// eagerly in 2020–2021. The player can sell the masters of their songs
/// three years and older: money now, and from then on those songs pay the
/// buyer. A sold album can still be re-recorded (docs K139).
abstract final class CatalogSale {
  static const fromYear = 2018;

  /// Songs this old count as catalog.
  static const ageWeeks = 3 * GameTime.weeksPerYear;

  /// The smallest catalog a fund looks at, a year's earnings.
  static const minYearCents = 1000000;

  /// Years of earnings a fund pays in [year].
  static double multiple(int year) => switch (year) {
        < fromYear => 0,
        2018 => 10,
        2019 => 12,
        2020 => 16,
        2021 => 20,
        2022 => 16,
        _ => 14,
      };

  /// The player's catalog songs they still own a part of.
  static List<Song> songs(World w, Artist a) => [
        for (final id in w.playerSongIds)
          if (w.songs[id].releasedWeek >= 0 &&
              w.songs[id].status != SongStatus.scrapped &&
              w.week - w.songs[id].releasedWeek >= ageWeeks &&
              Rerecords.songShare(a, w.songs[id]) > 0)
            w.songs[id]
      ];

  /// [s]'s money last week for its artist [a] (their share).
  static double weekCents(World w, Artist a, Song s) {
    var cents = 0.0;
    if (s.status == SongStatus.active) {
      cents = s.weekStreams * 0.35 * s.autoplay.royalty +
          s.weekDownloads * 70 +
          s.weekPhysical * 100;
    } else if (s.status == SongStatus.dormant) {
      for (var r = 0; r < regionCount; r++) {
        cents += w.songWeekStreamsRegion(s, r) * 0.35 * s.autoplay.royalty;
      }
    }
    return cents * Rerecords.songShare(a, s);
  }

  /// What the catalog earns [a] in a year at last week's pace.
  static double yearCents(World w, Artist a) => songs(w, a)
      .fold(0.0, (t, s) => t + weekCents(w, a, s) * GameTime.weeksPerYear);

  /// A fund's offer now (0: none).
  static int offerCents(World w, Artist a) {
    final year = yearCents(w, a);
    if (year < minYearCents) return 0;
    return (year * multiple(GameTime.yearOf(w.week))).round();
  }

  /// Sells the catalog: paid now, the songs and their albums pay the
  /// buyer from now on. Returns the price.
  static int sell(World w, Artist a) {
    final price = offerCents(w, a);
    if (price <= 0) throw ActionException('No offer');
    final sold = songs(w, a);
    for (final s in sold) {
      s.masterShare = 0;
      w.dirtySongs.add(s.id);
    }
    final ids = {for (final s in sold) s.id};
    for (final al in w.albums) {
      if (al.artistId == a.id &&
          al.songIds.isNotEmpty &&
          al.songIds.every(ids.contains)) {
        al.masterShare = 0;
        w.dirtyAlbums.add(al.id);
      }
    }
    a.moneyCents += price;
    w.dirtyArtists.add(a.id);
    return price;
  }
}
