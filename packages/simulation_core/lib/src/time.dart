/// Game time. A week is an absolute index; week 0 is the first week of
/// [baseYear]. Game years have exactly 52 weeks, which keeps arithmetic simple
/// and is invisible to the player.
abstract final class GameTime {
  /// The year of week 0 for the world in play: 1980, or 1940 for a world
  /// that begins before 1980 (docs K289), so weeks stay positive (-1 means
  /// "none" everywhere). Set when a world is made or loaded; saves from
  /// before carry 1980.
  static int baseYear = defaultBaseYear;
  static const defaultBaseYear = 1980, earlyBaseYear = 1940;

  /// The base for a world whose first year is [worldStartYear].
  static int baseFor(int worldStartYear) =>
      worldStartYear < defaultBaseYear ? earlyBaseYear : defaultBaseYear;
  static const weeksPerYear = 52;

  static int yearOf(int week) => baseYear + week ~/ weeksPerYear;

  /// 1-based week within the year.
  static int weekOfYear(int week) => week % weeksPerYear + 1;

  static int firstWeekOf(int year) => (year - baseYear) * weeksPerYear;

  /// Fractional year, used to interpolate era tables.
  static double fractionalYear(int week) =>
      baseYear + week / weeksPerYear.toDouble();

  static String label(int week) => 'Week ${weekOfYear(week)}, ${yearOf(week)}';
}
