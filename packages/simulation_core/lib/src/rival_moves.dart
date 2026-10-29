import 'model.dart';
import 'rng.dart';
import 'stream_windows.dart';
import 'streaming_tools.dart';
import 'time.dart';
import 'world.dart';

/// How a rival star put an album out (docs K175).
enum RivalMove { surprise, exclusive, window }

/// Rival stars use the same release moves as the player (docs K175): a
/// surprise drop nobody saw coming, a streaming exclusive, an album kept
/// off streaming. Drawn from the artist and the album's week, so a date
/// knows its move without anything stored.
abstract final class RivalMoves {
  static const surpriseFrom = 2013;
  static const surpriseChance = 0.15;
  static const exclusiveChance = 0.15;

  /// The years stars held albums back from streaming, and how often.
  static const windowFrom = 2012, windowTo = 2017;
  static const windowChance = 0.1;

  static bool _star(Artist a, double fame) =>
      a.tier == ArtistTier.a && a.fame >= fame;

  static RandomStream _r(World w, Artist a, int week, int n) =>
      RandomStream.keyed(w.seed, week, a.id, RngPurpose.aiPlanning + n);

  /// Whether [a]'s album due in [week] comes out unannounced: it is not
  /// on anyone's calendar until it is out.
  static bool surprise(World w, Artist a, int week) =>
      _star(a, 0) && mayDrop(w, a, week);

  /// The draw behind [surprise] without the star check: an artist can
  /// become a star before the date, so the calendar leaves out every date
  /// that would be a surprise for a star (docs K175).
  static bool mayDrop(World w, Artist a, int week) =>
      GameTime.yearOf(week) >= surpriseFrom &&
      _r(w, a, week, 42).chance(surpriseChance);

  /// Whether [a]'s album out now goes to the second service alone.
  static bool exclusive(World w, Artist a, AlbumType type) =>
      _star(a, 0) &&
      StreamingTools.canGoExclusive(w, a, type) &&
      _r(w, a, w.week, 43).chance(exclusiveChance);

  /// Weeks [a]'s album out now stays off streaming (0: none).
  static int window(World w, Artist a, AlbumType type) {
    final y = GameTime.yearOf(w.week);
    if (y < windowFrom || y > windowTo || !_star(a, 0.45)) return 0;
    if (!StreamWindows.can(w, type)) return 0;
    final r = _r(w, a, w.week, 44);
    if (!r.chance(windowChance)) return 0;
    return StreamWindows.weeks[r.nextInt(StreamWindows.weeks.length)];
  }

  /// The move behind rival album [al], out this week (null: a plain
  /// release).
  static RivalMove? of(World w, Album al) {
    final a = w.artists[al.artistId];
    if (al.exclusiveUntil > 0) return RivalMove.exclusive;
    if (al.windowUntil > 0) return RivalMove.window;
    if (surprise(w, a, al.releaseWeek)) return RivalMove.surprise;
    return null;
  }
}
