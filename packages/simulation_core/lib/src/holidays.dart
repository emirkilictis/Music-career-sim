import 'config/sim_config.dart';
import 'model.dart';
import 'time.dart';

/// Holiday songs (docs K136): played little most of the year, they come
/// back every December, the best of them for decades.
abstract final class Holidays {
  /// Share of rivals' autumn songs that are holiday songs.
  static const aiShare = 0.05;

  /// Rivals record holiday songs in the autumn, for the season ahead.
  static bool writingSeason(int weekOfYear) =>
      weekOfYear >= 40 && weekOfYear <= 47;

  /// Week of the year dormant holiday songs come back.
  static const returnWeek = 45;

  /// Off-season: people play holiday songs less than others.
  static const offSeason = 0.5;

  /// How much of the holiday listening there is in [weekOfYear], at most
  /// 1 the week before Christmas.
  static double curve(int weekOfYear) => switch (weekOfYear) {
        45 => 0.1,
        46 => 0.25,
        47 => 0.45,
        48 => 0.6,
        49 => 0.75,
        50 => 0.9,
        51 => 1.0,
        52 => 0.85,
        _ => 0,
      };

  static bool inSeason(int weekOfYear) => curve(weekOfYear) > 0;

  /// The season's listening of [s] in [week], before quality and luck:
  /// everyone puts on the songs they know.
  static double part(SimConfig c, Song s, int week) {
    if (!s.holiday) return 0;
    final x = curve(GameTime.weekOfYear(week));
    if (x <= 0) return 0;
    return c.publicPool * s.commercial * x * 0.05 * s.quality / 100;
  }

  /// What [s]'s usual listening is worth in [week].
  static double season(Song s, int week) =>
      !s.holiday || inSeason(GameTime.weekOfYear(week)) ? 1 : offSeason;
}
