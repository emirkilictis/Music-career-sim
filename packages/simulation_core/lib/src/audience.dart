import 'dart:math' as math;

import 'model.dart';
import 'world.dart';

/// Fans and listeners won outside the weekly listening (shows, posts,
/// awards, interviews; docs K105). They saturate the way the weekly
/// conversion does: nobody can be won twice, so a superstar's audience
/// stops growing instead of feeding on itself.
abstract final class Audience {
  /// Core fans an artist can have at most.
  static double fanCap(World w) => w.config.fanCap;

  /// The player's fandom can grow this much bigger than a rival's (docs
  /// K215, F90): the number keeps climbing for years...
  static const playerFanCapScale = 2.5;

  /// ...but fans past [engagedKnee] count less and less for what they do
  /// (play the songs, buy the records and tickets, join the club): a big
  /// fandom is mostly people who like you and stream someone else today.
  static const engagedKnee = 2e6, engagedPower = 0.55;

  /// The player's fans that act like [engaged] ones: the inverse of
  /// [engaged], for a start that should buy and play as before (docs K215).
  static double rawFor(double engaged) => engaged <= engagedKnee
      ? engaged
      : engagedKnee *
          math.pow(engaged / engagedKnee, 1 / engagedPower).toDouble();

  /// How much faster the player wins fans past [engagedKnee] (docs
  /// K215): light fans are easy to win, up to half again as fast at
  /// twice the knee.
  static double growth(Artist a) => a.tier != ArtistTier.player ||
          a.coreFans <= engagedKnee
      ? 1.0
      : 1 + 0.5 * math.min(1.0, (a.coreFans - engagedKnee) / engagedKnee);

  /// Core fans [a] can have at most.
  static double capOf(World w, Artist a) => a.tier == ArtistTier.player
      ? w.config.fanCap * playerFanCapScale
      : w.config.fanCap;

  /// Share of new fans [a] can still win (see [SimConfig.fanRoom]).
  static double room(World w, Artist a) =>
      w.config.fanRoom(a.coreFans, cap: capOf(w, a));

  /// The fans who act like fans (docs K215): all of a rival's, the
  /// player's up to [engagedKnee], fewer for each one past it.
  static double engaged(Artist a) => a.tier != ArtistTier.player ||
          a.coreFans <= engagedKnee
      ? a.coreFans
      : engagedKnee *
          math.pow(a.coreFans / engagedKnee, engagedPower).toDouble();

  /// Adds [n] core fans (fewer the closer the artist is to [fanCap]);
  /// returns how many were actually won. Losses are not damped.
  static double addFans(World w, Artist a, double n) {
    final before = a.coreFans;
    if (n > 0) {
      a.coreFans += n * room(w, a);
    } else {
      a.coreFans += n;
    }
    if (a.coreFans < 100) a.coreFans = 100;
    return a.coreFans - before;
  }

  /// Adds [n] casual listeners (fewer the closer to [SimConfig.casualCap]).
  static double addCasual(World w, Artist a, double n) {
    final before = a.casual;
    if (n > 0) {
      final room = 1 - a.casual / w.config.casualCap;
      a.casual += n * (room < 0 ? 0 : room);
    } else {
      a.casual += n;
    }
    if (a.casual < 1000) a.casual = 1000;
    return a.casual - before;
  }
}
