import 'model.dart';
import 'time.dart';

/// Ringtones (docs K183): from 2004 to about 2010 people bought a song's
/// hook for their phone, a business as big as download singles at its
/// peak, strongest for hip-hop, R&B and pop. Labels put out every single
/// as a ringtone; how many sell follows its downloads.
abstract final class Ringtones {
  static const fromYear = 2004, toYear = 2010;

  /// What a ringtone pays the artist's side, in cents (the phone company
  /// and the seller kept most of the price).
  static const payCents = 40;

  /// Ringtones sold per download sale in [year].
  static double eraFactor(int year) => switch (year) {
        2004 => 0.15,
        2005 => 0.4,
        2006 || 2007 => 0.6,
        2008 => 0.45,
        2009 => 0.25,
        2010 => 0.12,
        _ => 0.0,
      };

  /// How ringtone-friendly a genre is ([genreNames] index): hooks people
  /// want to hear when the phone rings.
  static double genreFactor(int genre) => switch (genre) {
        1 => 1.3,
        2 || 10 => 1.2,
        0 || 6 || 16 => 1.1,
        5 || 12 => 1.1,
        4 || 15 => 0.8,
        3 || 8 || 9 => 0.7,
        _ => 0.9,
      };

  /// Ringtones [s] sells for [downloads] download sales in [year].
  static double sold(Song s, double downloads, int year) {
    if (!s.isSingle) return 0;
    final era = eraFactor(year);
    if (era <= 0) return 0;
    return downloads * era * genreFactor(s.genre) * (0.5 + s.commercial);
  }

  static bool era(int week) {
    final y = GameTime.yearOf(week);
    return y >= fromYear && y <= toYear;
  }
}
