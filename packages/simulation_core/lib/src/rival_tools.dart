import 'actions.dart';
import 'canvas.dart';
import 'config/charts.dart';
import 'model.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// Rivals use the player's streaming tools too (docs K201): their teams
/// give new singles a Canvas once the app has them, and put out a remix
/// or a sped-up or slowed version of a hit while it is high on the chart,
/// to keep it there. Drawn from the song and the week, so nothing new is
/// stored beyond what the tools themselves keep.
abstract final class RivalTools {
  /// How often a star's (or a working artist's) new single gets a Canvas.
  static const canvasStar = 0.8, canvasWorking = 0.35;

  /// A star's album tracks get one this often.
  static const canvasAlbum = 0.5;

  /// The weeks after the single a hit gets a version, the US chart spot it
  /// must be in, the weekly chance then (a star's team moves faster) and
  /// the most versions a song gets this way.
  static const fromWeek = 2, toWeek = 12, topPosition = 20;
  static const versionChance = 0.12, versionStarChance = 0.2;
  static const maxVersions = 2;

  static bool _rival(Artist a) =>
      a.tier != ArtistTier.player && a.managedBy < 0 && !a.isRetired;

  static RandomStream _r(World w, Song s, int n) =>
      RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.rivalTools + n);

  /// [a]'s new single [s], out this week.
  static void onSingle(World w, Artist a, Song s) {
    if (!SongCanvas.open(w) || !_rival(a) || s.canvasWeek >= 0) return;
    final odds = a.tier == ArtistTier.a ? canvasStar : canvasWorking;
    if (_r(w, s, 0).chance(odds)) _canvas(w, s);
  }

  /// [a]'s new album [al], out this week.
  static void onAlbum(World w, Artist a, Album al) {
    if (!SongCanvas.open(w) || !_rival(a) || a.tier != ArtistTier.a) return;
    if (!RandomStream.keyed(w.seed, w.week, al.id, RngPurpose.rivalTools + 1)
        .chance(canvasAlbum)) {
      return;
    }
    for (final id in al.songIds) {
      final s = w.songs[id];
      if (s.primaryArtistId == a.id && s.canvasWeek < 0) _canvas(w, s);
    }
  }

  static void _canvas(World w, Song s) {
    s.canvasWeek = w.week;
    w.dirtySongs.add(s.id);
  }

  /// The versions a song can get in [year]: remixes always; sped-up and
  /// slowed ones once short videos made them a thing, and mostly then.
  static List<(SongVersion, double)> _menu(int year) => year >= 2021
      ? const [
          (SongVersion.spedUp, 0.4),
          (SongVersion.slowed, 0.2),
          (SongVersion.remix, 0.4),
        ]
      : year >= 2018
          ? const [(SongVersion.spedUp, 0.25), (SongVersion.remix, 0.75)]
          : const [(SongVersion.remix, 1.0)];

  /// Rivals' hits high on the US chart get a new version (before this
  /// week's listening, by last week's chart).
  static void weekly(World w) {
    final year = GameTime.yearOf(w.week);
    for (final id in List.of(w.activeSongIds)) {
      final s = w.songs[id];
      if (!s.isSingle || s.singleWeek < 0) continue;
      final age = w.week - s.singleWeek;
      if (age < fromWeek || age > toWeek) continue;
      final pos = s.lastPosOn(Charts.usSongs);
      if (pos == 0 || pos > topPosition) continue;
      if (s.versions.length >= maxVersions) continue;
      final a = w.artists[s.primaryArtistId];
      if (!_rival(a)) continue;
      // One version every few weeks at most.
      if (s.versions.isNotEmpty && w.week - s.versions.last.$2 < 4) continue;
      final r = _r(w, s, 2);
      if (!r
          .chance(a.tier == ArtistTier.a ? versionStarChance : versionChance)) {
        continue;
      }
      final menu = [
        for (final m in _menu(year))
          if (!s.versions.any((x) => x.$1 == m.$1)) m
      ];
      if (menu.isEmpty) continue;
      final total = menu.fold(0.0, (t, m) => t + m.$2);
      var x = r.nextDouble() * total;
      var pick = menu.last.$1;
      for (final m in menu) {
        x -= m.$2;
        if (x < 0) {
          pick = m.$1;
          break;
        }
      }
      Actions.releaseVersion(w, a, s, pick);
    }
  }
}
