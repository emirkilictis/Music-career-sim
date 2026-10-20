import 'dart:math' as math;

import 'actions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// Free uploads to the audio-sharing site (docs K148), the SoundCloud
/// route: an unreleased song put up for free, heard only there. It pays
/// almost nothing and does not chart, but unknowns get discovered there
/// and songs blow up (most of all in its rap years, 2014–2019). Put out
/// officially later, a song that did well there comes out with a wave.
abstract final class Cloud {
  /// The site opens.
  static const openYear = 2008;

  /// Its biggest years for breaking songs.
  static const peakFrom = 2014, peakTo = 2019;

  /// Share of its usual listening a free upload gets: more for unknowns,
  /// who are discovered there.
  static double reach(Artist a) => 0.15 * (1.6 - a.fame);

  /// How much more likely a free upload is to catch on.
  static double viralFactor(int year) =>
      year >= peakFrom && year <= peakTo ? 2.5 : 1.5;

  /// What its plays pay against a stream elsewhere.
  static const payFactor = 0.3;

  /// Whether [a] can put [s] up for free now.
  static bool canUpload(World w, Artist a, Song s) =>
      GameTime.yearOf(w.week) >= openYear &&
      s.primaryArtistId == a.id &&
      s.status == SongStatus.vault &&
      s.rerecordOf < 0 &&
      !a.scheduled.any((sr) => sr.songIds.contains(s.id));

  /// Puts vault song [s] up for free.
  static void upload(World w, Artist a, Song s) {
    if (!canUpload(w, a, s)) throw ActionException('Not now');
    s.releasedWeek = w.week;
    s.cloudWeek = w.week;
    s.cloudOnly = true;
    s.campaign = Campaign.none;
    s.campaignPower = 1;
    Lifecycle.activateSong(w, s);
    w.dirtySongs.add(s.id);
  }

  /// Attention [s] keeps while only on the site.
  static double attention(World w, Song s) =>
      s.cloudOnly ? reach(w.artists[s.primaryArtistId]) : 1.0;

  /// The wave a song brings from the site when it comes out officially:
  /// bigger the more it was played there.
  static double officialBoost(double plays) =>
      math.min(0.5, 0.1 * math.max(0, math.log(plays / 1e5) / math.ln10));

  /// [s] comes out officially (as a single or on a record): everywhere,
  /// on the charts, fresh, with what the site gave it.
  static void goOfficial(World w, Song s) {
    if (!s.cloudOnly) return;
    s.cloudOnly = false;
    s.cloudPlays = w.songLifetimeStreams(s);
    s.releasedWeek = w.week;
    s.versionBoost += officialBoost(s.cloudPlays);
    w.dirtySongs.add(s.id);
  }
}
