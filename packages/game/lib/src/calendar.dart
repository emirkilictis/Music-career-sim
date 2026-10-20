import 'package:simulation_core/simulation_core.dart';

import 'views.dart';

/// What happens in a week of the release calendar (docs K177).
enum CalendarKind {
  /// One of the player's releases comes out ([CalendarEntry.type]).
  release,

  /// One of the player's dated releases is announced.
  announce,

  /// An extra edition of the player's album comes out.
  edition,

  /// The player's album held off streaming arrives there (K174).
  onStreaming,

  /// Tour nights ([CalendarEntry.title]: the cities).
  tour,

  /// A festival the player is booked at.
  festival,

  /// A big rival's announced album.
  rivalAlbum,

  /// Last week a release counts for the awards of [CalendarEntry.year].
  awardCutoff,
  nominations,
  ceremony,

  /// Holiday songs come back; the Christmas season starts.
  holidays,

  /// The songs of the summer race starts and ends (K137).
  summerStart,
  summerEnd,

  /// The year-end charts and the streaming app's Wrapped come out.
  yearEnd,
  wrapped,
}

class CalendarEntry {
  const CalendarEntry(this.kind,
      {this.title = '',
      this.artistName = '',
      this.year = 0,
      this.type = AlbumType.single,
      this.albumId = -1,
      this.artistId = -1});
  final CalendarKind kind;
  final String title;
  final String artistName;

  /// The award show or chart year it is about.
  final int year;
  final AlbumType type;
  final int albumId;
  final int artistId;

  bool get isPlayer => switch (kind) {
        CalendarKind.release ||
        CalendarKind.announce ||
        CalendarKind.edition ||
        CalendarKind.onStreaming ||
        CalendarKind.tour ||
        CalendarKind.festival =>
          true,
        _ => false,
      };

  bool get isSeason => !isPlayer && kind != CalendarKind.rivalAlbum;
}

class CalendarWeek {
  const CalendarWeek(this.week, this.entries);
  final int week;
  final List<CalendarEntry> entries;
}

/// The release calendar (docs K177): the next weeks with the player's own
/// dates, big rivals' announced albums and the dates of the year that
/// matter when picking a release week.
abstract final class ReleaseCalendar {
  static const weeks = 26;

  static List<CalendarWeek> build(World w,
      {required List<UpcomingRelease> rivals,
      required List<FestivalView> festivals,
      int span = weeks}) {
    final p = w.player!;
    final from = w.week, to = w.week + span;
    final by = <int, List<CalendarEntry>>{};
    void add(int week, CalendarEntry e) {
      if (week >= from && week < to) (by[week] ??= []).add(e);
    }

    for (final sr in p.scheduled) {
      if (sr.isDraft) continue;
      final title = sr.isAlbum ? sr.title : w.songs[sr.songIds.single].title;
      add(sr.releaseWeek,
          CalendarEntry(CalendarKind.release, title: title, type: sr.type));
      if (!sr.isSurprise && sr.announceWeek > w.week) {
        add(sr.announceWeek,
            CalendarEntry(CalendarKind.announce, title: title, type: sr.type));
      }
      for (var k = 1; k < sr.variantWeeks.length; k++) {
        if (sr.variantWeeks[k] > 0) {
          add(sr.releaseWeek + sr.variantWeeks[k],
              CalendarEntry(CalendarKind.edition, title: title, type: sr.type));
        }
      }
    }
    for (final al in w.albums) {
      if (al.artistId != p.id || al.releaseWeek + 40 < from) continue;
      for (var k = 1; k < al.variantWeeks.length; k++) {
        if (al.variantWeeks[k] > 0) {
          add(
              al.releaseWeek + al.variantWeeks[k],
              CalendarEntry(CalendarKind.edition,
                  title: al.title, type: al.type, albumId: al.id));
        }
      }
      if (al.windowUntil > al.releaseWeek) {
        add(
            al.windowUntil,
            CalendarEntry(CalendarKind.onStreaming,
                title: al.title, type: al.type, albumId: al.id));
      }
    }
    final tour = p.tour;
    if (tour != null) {
      final cities = <int, List<String>>{};
      for (final s in tour.shows) {
        final c = s.market.cities[s.city].name;
        final list = cities[s.week] ??= [];
        if (!list.contains(c)) list.add(c);
      }
      cities.forEach((week, list) => add(
          week, CalendarEntry(CalendarKind.tour, title: list.join(', '))));
    }
    for (final f in festivals) {
      if (f.booked != null) {
        add(f.week,
            CalendarEntry(CalendarKind.festival, title: f.festival.name));
      }
    }
    for (final r in rivals) {
      add(
          r.week,
          CalendarEntry(CalendarKind.rivalAlbum,
              title: r.title, artistName: r.artistName, artistId: r.artistId));
    }
    for (var week = from; week < to; week++) {
      final woy = GameTime.weekOfYear(week);
      final year = GameTime.yearOf(week);
      CalendarEntry season(CalendarKind k, [int y = 0]) =>
          CalendarEntry(k, year: y);
      if (woy == Awards.windowStartWeekOfYear - 1) {
        add(week, season(CalendarKind.awardCutoff, year + 1));
      }
      if (woy == Awards.nominationsWeekOfYear) {
        add(week, season(CalendarKind.nominations, year + 1));
      }
      if (woy == Awards.ceremonyWeekOfYear) {
        add(week, season(CalendarKind.ceremony, year));
      }
      if (woy == Holidays.returnWeek) add(week, season(CalendarKind.holidays));
      if (woy == YearEnd.summerFromWeekOfYear) {
        add(week, season(CalendarKind.summerStart, year));
      }
      if (woy == YearEnd.summerToWeekOfYear) {
        add(week, season(CalendarKind.summerEnd, year));
      }
      if (woy == YearEnd.publishWeekOfYear) {
        add(week, season(CalendarKind.yearEnd, year));
      }
      if (woy == Wrapped.publishWeekOfYear && year >= Wrapped.firstYear) {
        add(week, season(CalendarKind.wrapped, year));
      }
    }
    final out = [
      for (final week in by.keys.toList()..sort())
        CalendarWeek(week, by[week]!..sort((a, b) {
          // The player's own dates first, then rivals, then the seasons.
          int rank(CalendarEntry e) => e.isPlayer ? 0 : (e.isSeason ? 2 : 1);
          return rank(a).compareTo(rank(b));
        }))
    ];
    return out;
  }
}
