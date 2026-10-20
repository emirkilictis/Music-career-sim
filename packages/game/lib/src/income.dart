import 'package:simulation_core/simulation_core.dart';

import 'platforms.dart';

/// Where the player's record money comes from (docs K145).
enum IncomeSource {
  streamify,
  fruitMusic,
  viewTube,
  noiseCloud,
  downloads,
  physical,
  albumSales,
}

/// Record income split by source (docs K145). The simulation pays a song's
/// streams one average rate; this shares that money out the way the
/// services pay: the second streaming service about twice the big app per
/// play, the video site a quarter, so the totals stay the simulation's.
class IncomeBreakdown {
  IncomeBreakdown(this.cents);

  /// The player's share, by source (only sources with money).
  final Map<IncomeSource, double> cents;

  double get total => cents.values.fold(0.0, (a, b) => a + b);
}

abstract final class Income {
  /// What each service pays per play against the big app.
  static const rate = {
    MusicPlatform.streamify: 1.0,
    MusicPlatform.fruitMusic: 2.0,
    MusicPlatform.viewTube: 0.25,
    MusicPlatform.noiseCloud: 0.8,
  };

  /// The average the simulation pays a stream, in cents.
  static const averageCents = 0.35;

  static const _source = {
    MusicPlatform.streamify: IncomeSource.streamify,
    MusicPlatform.fruitMusic: IncomeSource.fruitMusic,
    MusicPlatform.viewTube: IncomeSource.viewTube,
    MusicPlatform.noiseCloud: IncomeSource.noiseCloud,
  };

  /// Each service's part of [year]'s stream money (adds up to 1).
  static Map<MusicPlatform, double> moneyShares(int year) {
    final w = <MusicPlatform, double>{};
    var sum = 0.0;
    for (final e in rate.entries) {
      final v = e.key.streamShare(year) * e.value;
      if (v <= 0) continue;
      w[e.key] = v;
      sum += v;
    }
    if (sum <= 0) return {MusicPlatform.viewTube: 1.0};
    return {for (final e in w.entries) e.key: e.value / sum};
  }

  /// What [p] pays per stream in [year], in cents.
  static double perStreamCents(MusicPlatform p, int year) {
    var plays = 0.0, money = 0.0;
    for (final e in rate.entries) {
      final share = e.key.streamShare(year);
      plays += share;
      money += share * e.value;
    }
    if (money <= 0 || !rate.containsKey(p)) return 0;
    return averageCents * (rate[p]! * plays / money);
  }

  /// Stream money shares averaged over [fromYear]..[toYear] (a song's or a
  /// career's years).
  static Map<MusicPlatform, double> _averageShares(int fromYear, int toYear) {
    final out = <MusicPlatform, double>{};
    final years = toYear - fromYear + 1;
    for (var y = fromYear; y <= toYear; y++) {
      for (final e in moneyShares(y).entries) {
        out[e.key] = (out[e.key] ?? 0) + e.value / years;
      }
    }
    return out;
  }

  /// [s]'s lifetime record money for the player (their share).
  static IncomeBreakdown ofSong(World w, Song s) {
    final out = <IncomeSource, double>{};
    if (s.releasedWeek < 0) return IncomeBreakdown(out);
    final a = w.primaryOf(s);
    final share = Rerecords.songShare(a, s);
    final streams = w.songLifetimeStreams(s) *
        averageCents *
        s.autoplay.royalty *
        share;
    final from = GameTime.yearOf(s.releasedWeek);
    final to = GameTime.yearOf(w.week);
    for (final e in _averageShares(from, to).entries) {
      out[_source[e.key]!] = streams * e.value;
    }
    final dl = w.songLifetimeDownloads(s) * 70 * share;
    if (dl > 0) out[IncomeSource.downloads] = dl;
    final ph = s.lifetimePhysical * 100 * share;
    if (ph > 0) out[IncomeSource.physical] = ph;
    out.removeWhere((_, v) => v <= 0);
    return IncomeBreakdown(out);
  }

  /// The player's whole career of record money by source: every song and
  /// every album's copies.
  static IncomeBreakdown ofCareer(World w) {
    final out = <IncomeSource, double>{};
    final p = w.player;
    if (p == null) return IncomeBreakdown(out);
    // Members' solo songs pay the group (docs K158).
    for (final id in [...w.playerSongIds, ...w.managedSongIds]) {
      for (final e in ofSong(w, w.songs[id]).cents.entries) {
        out[e.key] = (out[e.key] ?? 0) + e.value;
      }
    }
    var albums = 0.0;
    for (final al in w.albums) {
      if (al.artistId != p.id) continue;
      final paid = al.lifetimePure -
          (al.bundle == AlbumBundle.tickets ? al.bundleUnits : 0);
      albums += paid * 600 * Rerecords.albumShare(p, al);
    }
    if (albums > 0) out[IncomeSource.albumSales] = albums;
    return IncomeBreakdown(out);
  }
}
