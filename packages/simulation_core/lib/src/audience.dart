import 'model.dart';
import 'world.dart';

/// Fans and listeners won outside the weekly listening (shows, posts,
/// awards, interviews; docs K105). They saturate the way the weekly
/// conversion does: nobody can be won twice, so a superstar's audience
/// stops growing instead of feeding on itself.
abstract final class Audience {
  /// Core fans an artist can have at most.
  static double fanCap(World w) => w.config.fanCap;

  /// Adds [n] core fans (fewer the closer the artist is to [fanCap]);
  /// returns how many were actually won. Losses are not damped.
  static double addFans(World w, Artist a, double n) {
    final before = a.coreFans;
    if (n > 0) {
      final room = 1 - a.coreFans / fanCap(w);
      a.coreFans += n * (room < 0 ? 0 : room);
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
