import 'dart:math' as math;

import 'model.dart';
import 'streaming_tools.dart';
import 'time.dart';
import 'world.dart';

/// Keeping an album off the streaming services for its first weeks (docs
/// K174), the Adele 25 / Taylor Swift 1989 move: it is only sold, so the
/// fans who would have streamed it buy it, and everyone else who would
/// have found it on the apps never hears it while it is new.
abstract final class StreamWindows {
  /// Streaming has to matter for holding back to mean anything.
  static const fromYear = 2011;

  /// The windows on offer, in weeks.
  static const weeks = [4, 13];

  static bool can(World w, AlbumType type) =>
      (type == AlbumType.album || type == AlbumType.ep) &&
      GameTime.yearOf(w.week) >= fromYear &&
      StreamingTools.streamingOpen(w);

  /// How many more copies the fans buy while it is not streaming: most in
  /// the years buying was still normal and streaming already big.
  static double buyLift(int year) {
    if (year < 2016) return 1.15 + 0.05 * (year - fromYear);
    if (year <= 2018) return 1.4;
    return math.max(1.15, 1.4 - 0.05 * (year - 2018));
  }

  static bool held(World w, Album al) => w.week < al.windowUntil;

  /// Whether [s] is off the streaming services this week: an album track
  /// of a held album that has not come out as a single.
  static bool songHeld(World w, Song s) =>
      !s.isSingle && s.albumId >= 0 && held(w, w.albums[s.albumId]);

  /// Factor on [al]'s copies sold this week.
  static double salesFactor(World w, Album al) =>
      held(w, al) ? buyLift(GameTime.yearOf(w.week)) : 1.0;
}
