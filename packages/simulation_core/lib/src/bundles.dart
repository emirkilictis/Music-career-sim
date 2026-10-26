import 'audience.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// Album bundles (docs K144): from 2014 the album charts counted a copy
/// bundled with merch or concert tickets as a sale, until the rules
/// changed late in 2020. Merch bundles sell to fans and pay a margin;
/// ticket bundles count a copy for every ticket redeemed for the tour
/// ahead, but the copies are free: they pay nothing.
abstract final class Bundles {
  static const fromYear = 2014;
  static const untilYear = 2020;

  static bool open(int year) => year >= fromYear && year <= untilYear;

  /// Core fans who buy the merch bundle (more with hype).
  static const merchRate = 0.012;

  /// What a merch bundle leaves beyond the album, per copy.
  static const merchMarginCents = 600;

  /// Share of tickets redeemed for a copy.
  static const ticketRedeem = 0.35;

  /// Tour shows within this many weeks count.
  static const ticketWeeks = 26;

  /// Seats on [a]'s shows in the coming [ticketWeeks] weeks.
  static double upcomingSeats(World w, Artist a) {
    final t = a.tour;
    if (t == null) return 0;
    var seats = 0.0;
    for (final s in t.shows) {
      if (s.week >= w.week && s.week < w.week + ticketWeeks) {
        seats += s.capacity;
      }
    }
    return seats;
  }

  /// Copies [bundle] adds to [a]'s album's first week.
  static double units(World w, Artist a, AlbumBundle bundle) =>
      switch (bundle) {
        AlbumBundle.none => 0,
        AlbumBundle.merch => Audience.engaged(a) * merchRate * (1 + a.hype),
        AlbumBundle.tickets => upcomingSeats(w, a) * ticketRedeem,
      };

  /// Whether [a] can bundle an album of [type] with [bundle] now.
  static bool can(World w, Artist a, AlbumType type, AlbumBundle bundle) {
    if (bundle == AlbumBundle.none) return true;
    if (!open(GameTime.yearOf(w.week))) return false;
    if (type != AlbumType.album && type != AlbumType.ep) return false;
    return bundle != AlbumBundle.tickets || upcomingSeats(w, a) > 0;
  }
}
