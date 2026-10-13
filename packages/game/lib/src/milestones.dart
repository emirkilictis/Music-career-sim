import 'dart:math' as math;

import 'package:simulation_core/simulation_core.dart';

import 'views.dart';

/// Career milestones (docs K61): goals between the big moments, each
/// worth skill points. Ids are the enum index (stored), so new ones go
/// last.
enum Milestone {
  firstRelease(5),
  firstChart(5),
  top40Single(5),
  top10Single(10),
  numberOneSingle(25),
  numberOneAlbum(25),
  gold(10),
  platinum(10),
  diamond(25),
  fans100k(5),
  fans1m(10),
  fans10m(25),
  money1m(5),
  money100m(10),
  billionStreams(25),
  firstFestival(5),
  awardWin(25);

  const Milestone(this.skillPoints);

  /// Reward when reached.
  final int skillPoints;

  /// For count goals: where the player stands and the target (null for
  /// yes/no goals).
  (double, double)? progress(World w, Artist p) => switch (this) {
        fans100k => (p.coreFans, 1e5),
        fans1m => (p.coreFans, 1e6),
        fans10m => (p.coreFans, 1e7),
        money1m => (p.moneyCents / 100, 1e6),
        money100m => (p.moneyCents / 100, 1e8),
        billionStreams => (_bestSongStreams(w, p), 1e9),
        gold || platinum || diamond => (
            _bestUsUnits(w, p),
            switch (this) {
              gold => Certification.gold.units,
              platinum => Certification.platinum.units,
              _ => Certification.diamond.units,
            }
          ),
        _ => null,
      };

  /// Reached now? ([firstFestival] and [awardWin] are marked when they
  /// happen.)
  bool reached(World w, Artist p) {
    if (progress(w, p) case (final have, final need)) return have >= need;
    return switch (this) {
      firstRelease =>
        w.playerSongIds.any((id) => w.songs[id].releasedWeek >= 0),
      firstChart => _bestPeak(w, p, songs: true, albums: true) < 999,
      top40Single => _bestPeak(w, p, songs: true) <= 40,
      top10Single => _bestPeak(w, p, songs: true) <= 10,
      numberOneSingle => _bestPeak(w, p, songs: true) == 1,
      numberOneAlbum => _bestPeak(w, p, albums: true) == 1,
      _ => false,
    };
  }

  static const _songCharts = [
    Charts.usSongs,
    Charts.ukSongs,
    Charts.globalSongs
  ];
  static const _albumCharts = [
    Charts.usAlbums,
    Charts.ukAlbums,
    Charts.globalAlbums
  ];

  static int _bestPeak(World w, Artist p,
      {bool songs = false, bool albums = false}) {
    var best = 999;
    void check(Charted c, List<int> charts) {
      for (final ch in charts) {
        final peak = c.statsOrNull(ch)?.peak ?? 0;
        if (peak > 0) best = math.min(best, peak);
      }
    }

    if (songs) {
      for (final id in w.playerSongIds) {
        if (w.songs[id].primaryArtistId == p.id) {
          check(w.songs[id], _songCharts);
        }
      }
    }
    if (albums) {
      for (final al in w.albums) {
        if (al.artistId == p.id) check(al, _albumCharts);
      }
    }
    return best;
  }

  static double _bestUsUnits(World w, Artist p) {
    var best = 0.0;
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.primaryArtistId == p.id && s.releasedWeek >= 0) {
        best = math.max(best, usSingleUnits(w, s));
      }
    }
    for (final al in w.albums) {
      if (al.artistId == p.id) best = math.max(best, usAlbumUnits(w, al));
    }
    return best;
  }

  static double _bestSongStreams(World w, Artist p) {
    var best = 0.0;
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.primaryArtistId == p.id) {
        best = math.max(best, w.songLifetimeStreams(s));
      }
    }
    return best;
  }

  /// Marks [m] reached this week (and pays its skill points); false if it
  /// already was.
  bool mark(World w, Artist p) {
    if (p.milestones.containsKey(index)) return false;
    p.milestones[index] = w.week;
    p.skillPoints += skillPoints;
    w.dirtyArtists.add(p.id);
    return true;
  }

  /// Every milestone reached since the last check, marked and paid.
  static List<Milestone> check(World w, Artist p) => [
        for (final m in values)
          if (!p.milestones.containsKey(m.index) &&
              m.reached(w, p) &&
              m.mark(w, p))
            m,
      ];
}
