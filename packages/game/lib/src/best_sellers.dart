import 'package:simulation_core/simulation_core.dart';

import 'views.dart';

/// What the best-seller lists rank (docs K141).
enum BestSellerKind { artists, albums, songs }

/// How sales are counted: chart units (album units with tracks and
/// streams; song units with 150 streams a unit, as certifications do), or
/// records sold (copies only, the way "best-selling artist" claims go).
enum SalesMeasure { units, sales }

/// One line of a best-seller list.
class BestSellerRow {
  BestSellerRow(
      {required this.rank,
      required this.kind,
      required this.entityId,
      required this.title,
      required this.artistId,
      required this.artistName,
      required this.albumId,
      required this.isPlayer,
      required this.value,
      this.releaseYear = 0});
  final int rank;
  final BestSellerKind kind;

  /// Artist, album or song id.
  final int entityId;

  /// Album or song title (empty for an artist).
  final String title;
  final int artistId;
  final String artistName;

  /// Album for the cover (-1: none).
  final int albumId;
  final bool isPlayer;

  /// Units or records sold.
  final double value;

  /// The year an album or song came out (0 for an artist).
  final int releaseYear;
}

/// One year's winners (docs K141): its biggest song, album and artist.
class YearWinners {
  YearWinners(this.year, {this.song, this.album, this.artist});
  final int year;
  final YearEndRow? song;
  final YearEndRow? album;
  final BestSellerRow? artist;
}

/// All-time best sellers from the world's lifetime numbers (docs K141).
abstract final class BestSellers {
  static const size = 50;

  /// Streams counted as one song unit (as certifications count them).
  static const streamsPerUnit = 150;

  /// Career records sold that make news.
  static const milestones = [
    1e6, 5e6, 10e6, 25e6, 50e6, 100e6, 200e6, 300e6 //
  ];

  /// Copies of [s] sold: downloads and physical singles.
  static double songSales(World w, Song s) =>
      w.songLifetimeDownloads(s) + s.lifetimePhysical;

  /// [s]'s units: copies plus streams.
  static double songUnits(World w, Song s) =>
      songSales(w, s) + w.songLifetimeStreams(s) / streamsPerUnit;

  static double albumValue(World w, Album al, SalesMeasure m) =>
      m == SalesMeasure.units ? w.albumLifetimeUnits(al) : al.lifetimePure;

  static double songValue(World w, Song s, SalesMeasure m) =>
      m == SalesMeasure.units ? songUnits(w, s) : songSales(w, s);

  /// Every artist's career total: their albums, plus their singles (in
  /// units, only those on no album: album units already count their
  /// tracks).
  static Map<int, double> artistTotals(World w, SalesMeasure m) {
    final out = <int, double>{};
    for (final al in w.albums) {
      if (al.releaseWeek > w.week) continue;
      out[al.artistId] = (out[al.artistId] ?? 0) + albumValue(w, al, m);
    }
    for (final s in w.songs) {
      if (s.releasedWeek < 0) continue;
      if (m == SalesMeasure.units && s.albumId >= 0) continue;
      final v = songValue(w, s, m);
      if (v <= 0) continue;
      out[s.primaryArtistId] = (out[s.primaryArtistId] ?? 0) + v;
    }
    return out;
  }

  /// The player's records sold this week, a part of what was added to
  /// [artistTotals] this week (catalog downloads aside), so a milestone
  /// crossing is never counted twice.
  static double playerWeekSales(World w) {
    final p = w.player;
    if (p == null) return 0;
    var t = 0.0;
    for (final id in w.activeAlbumIds) {
      final al = w.albums[id];
      if (al.artistId == p.id) t += al.weekPure;
    }
    for (final id in w.activeSongIds) {
      final s = w.songs[id];
      if (s.primaryArtistId == p.id) t += s.weekDownloads + s.weekPhysical;
    }
    return t;
  }

  /// The player's career records sold.
  static double playerSales(World w) {
    final p = w.player;
    if (p == null) return 0;
    var t = 0.0;
    for (final al in w.albums) {
      if (al.artistId == p.id) t += al.lifetimePure;
    }
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.releasedWeek >= 0) t += songSales(w, s);
    }
    return t;
  }

  /// The all-time list of [kind] by [m].
  static List<BestSellerRow> allTime(World w, BestSellerKind kind,
      {SalesMeasure m = SalesMeasure.units, int limit = size}) {
    final me = w.playerArtistId;
    switch (kind) {
      case BestSellerKind.artists:
        final totals = artistTotals(w, m).entries.toList()
          ..sort((a, b) {
            final d = b.value.compareTo(a.value);
            return d != 0 ? d : a.key.compareTo(b.key);
          });
        var rank = 0;
        return [
          for (final e in totals.take(limit))
            BestSellerRow(
                rank: ++rank,
                kind: kind,
                entityId: e.key,
                title: '',
                artistId: e.key,
                artistName: w.artists[e.key].name,
                albumId: -1,
                isPlayer: e.key == me,
                value: e.value),
        ];
      case BestSellerKind.albums:
        final all = [
          for (final al in w.albums)
            if (al.releaseWeek <= w.week) (al, albumValue(w, al, m))
        ]..sort((a, b) {
            final d = b.$2.compareTo(a.$2);
            return d != 0 ? d : a.$1.id.compareTo(b.$1.id);
          });
        var rank = 0;
        return [
          for (final (al, v) in all.take(limit))
            BestSellerRow(
                rank: ++rank,
                kind: kind,
                entityId: al.id,
                title: al.title,
                artistId: al.artistId,
                artistName: w.artists[al.artistId].name,
                albumId: al.id,
                isPlayer: al.artistId == me,
                value: v,
                releaseYear: GameTime.yearOf(al.releaseWeek)),
        ];
      case BestSellerKind.songs:
        final all = [
          for (final s in w.songs)
            if (s.releasedWeek >= 0) (s, songValue(w, s, m))
        ]..sort((a, b) {
            final d = b.$2.compareTo(a.$2);
            return d != 0 ? d : a.$1.id.compareTo(b.$1.id);
          });
        var rank = 0;
        return [
          for (final (s, v) in all.take(limit))
            BestSellerRow(
                rank: ++rank,
                kind: kind,
                entityId: s.id,
                title: s.title,
                artistId: s.primaryArtistId,
                artistName: w.artists[s.primaryArtistId].name,
                albumId: coverAlbumOf(w, s),
                isPlayer: s.primaryArtistId == me,
                value: v,
                releaseYear: GameTime.yearOf(s.releasedWeek)),
        ];
    }
  }
}
