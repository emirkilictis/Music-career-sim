/// Game time. A week is an absolute index; week 0 is the first week of
/// [baseYear]. Game years have exactly 52 weeks, which keeps arithmetic simple
/// and is invisible to the player.
abstract final class GameTime {
  static const baseYear = 1980;
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
