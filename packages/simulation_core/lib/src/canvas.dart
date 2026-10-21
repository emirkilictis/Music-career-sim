import 'actions.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// Canvas (docs K190), like Spotify's: a few seconds of looping video
/// behind a song in the app. People who see it skip the song less and
/// share it more, so the algorithm (autoplay, the discovery mixes) plays
/// it more too. Cheap: a designer's day, not a music video.
abstract final class SongCanvas {
  static const fromYear = 2019;
  static const costCents = 300000;

  /// How much less people skip a song with one (of [StreamingTools]'
  /// skip rate).
  static const skipCut = 0.06;

  /// The listening shares bring.
  static const lift = 0.08;

  static bool open(World w) => GameTime.yearOf(w.week) >= fromYear;

  /// Whether [a] can give [s] a Canvas now: their own song, out or in the
  /// vault, without one yet.
  static bool can(World w, Artist a, Song s) =>
      open(w) &&
      s.primaryArtistId == a.id &&
      s.status != SongStatus.scrapped &&
      !s.cloudOnly &&
      s.canvasWeek < 0;

  static void add(World w, Artist a, Song s) {
    if (!can(w, a, s)) throw ActionException('No canvas for this song');
    if (a.moneyCents < costCents) throw ActionException('Not enough money');
    a.moneyCents -= costCents;
    s.campaignCostCents += costCents;
    s.canvasWeek = w.week;
    w.dirtyArtists.add(a.id);
    w.dirtySongs.add(s.id);
  }

  static double skipCutOf(Song s) => s.canvasWeek >= 0 ? skipCut : 0;
  static double liftOf(Song s) => s.canvasWeek >= 0 ? lift : 0;
}
