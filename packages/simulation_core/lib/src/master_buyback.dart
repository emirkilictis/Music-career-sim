import 'dart:math' as math;

import 'actions.dart';
import 'catalog_sale.dart';
import 'model.dart';
import 'rerecords.dart';
import 'time.dart';
import 'world.dart';

/// Buying masters back (docs K162): whoever owns a record's masters (the
/// label it came out under, or a fund that bought the catalog) sells them
/// to the artist only for many years of what they bring in, and never
/// cheap. Once bought, the record pays the artist in full.
abstract final class MasterBuyback {
  /// Years of the owner's cut they ask for.
  static const years = 12;

  /// What they ask at the least, however little the record earns.
  static const minCents = 10000000;

  /// A record still selling well (under this many years old) costs more.
  static const recentYears = 5;
  static const recentFactor = 1.5;

  /// The owner's cut of [a]'s song [s] last week.
  static double songWeekCents(World w, Artist a, Song s) {
    final share = Rerecords.songShare(a, s);
    if (share >= 1) return 0;
    // CatalogSale gives the artist's part; the rest is the owner's.
    final mine = CatalogSale.weekCents(w, a, s);
    final full = share > 0 ? mine / share : _fullWeekCents(w, a, s);
    return full * (1 - share);
  }

  static double _fullWeekCents(World w, Artist a, Song s) {
    final keep = s.masterShare;
    s.masterShare = 1;
    final full = CatalogSale.weekCents(w, a, s);
    s.masterShare = keep;
    return full;
  }

  /// The player's songs on [al] the owner still has a cut of.
  static List<Song> songsOf(World w, Artist a, Album al) => [
        for (final id in al.songIds)
          if (w.songs[id].primaryArtistId == a.id &&
              Rerecords.songShare(a, w.songs[id]) < 1)
            w.songs[id]
      ];

  /// Whether [a] can buy [al]'s masters.
  static bool canAlbum(World w, Artist a, Album al) =>
      al.artistId == a.id &&
      w.week > al.releaseWeek &&
      (Rerecords.albumShare(a, al) < 1 || songsOf(w, a, al).isNotEmpty);

  /// Whether [a] can buy loose single [s]'s master.
  static bool canSong(World w, Artist a, Song s) =>
      s.primaryArtistId == a.id &&
      s.albumId < 0 &&
      s.releasedWeek >= 0 &&
      s.releasedWeek < w.week &&
      s.status != SongStatus.scrapped &&
      Rerecords.songShare(a, s) < 1;

  /// Weeks of last week's pace a year is worth: a record still in its
  /// run slows down, the catalog keeps its pace.
  static const activeYearWeeks = 20.0;

  static double _yearOf(Song s, double week) => week *
      (s.status == SongStatus.active
          ? activeYearWeeks
          : GameTime.weeksPerYear.toDouble());

  /// The owner's cut of [al] in the coming year at last week's pace.
  static double albumYearCents(World w, Artist a, Album al) {
    var year = 0.0;
    for (final s in songsOf(w, a, al)) {
      year += _yearOf(s, songWeekCents(w, a, s));
    }
    final share = Rerecords.albumShare(a, al);
    if (share < 1) year += al.weekPure * 600 * (1 - share) * activeYearWeeks;
    return year;
  }

  static int _price(World w, double yearCents, int releaseWeek) {
    final recent = w.week - releaseWeek < recentYears * GameTime.weeksPerYear
        ? recentFactor
        : 1.0;
    return math.max(minCents, (yearCents * years * recent).round());
  }

  /// What [al]'s masters cost [a] now.
  static int albumPriceCents(World w, Artist a, Album al) =>
      _price(w, albumYearCents(w, a, al), al.releaseWeek);

  /// What loose single [s]'s master costs [a] now.
  static int songPriceCents(World w, Artist a, Song s) =>
      _price(w, _yearOf(s, songWeekCents(w, a, s)), s.releasedWeek);

  /// Buys [al]'s masters: it and its songs pay [a] in full from now on.
  /// Returns the price.
  static int buyAlbum(World w, Artist a, Album al) {
    if (!canAlbum(w, a, al)) throw ActionException('Nothing to buy');
    final price = albumPriceCents(w, a, al);
    if (a.moneyCents < price) throw ActionException('Not enough money');
    a.moneyCents -= price;
    for (final s in songsOf(w, a, al)) {
      s.masterShare = 1;
      w.dirtySongs.add(s.id);
    }
    al.masterShare = 1;
    w.dirtyAlbums.add(al.id);
    w.dirtyArtists.add(a.id);
    return price;
  }

  /// Buys loose single [s]'s master. Returns the price.
  static int buySong(World w, Artist a, Song s) {
    if (!canSong(w, a, s)) throw ActionException('Nothing to buy');
    final price = songPriceCents(w, a, s);
    if (a.moneyCents < price) throw ActionException('Not enough money');
    a.moneyCents -= price;
    s.masterShare = 1;
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
    return price;
  }
}
