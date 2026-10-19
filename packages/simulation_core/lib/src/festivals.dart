import 'dart:convert';
import 'dart:math' as math;

import 'audience.dart';
import 'model.dart';
import 'time.dart';
import 'tours.dart';
import 'world.dart';

/// Where on the bill an act plays (docs K77): who is big enough, what share
/// of the crowd watches, and the fee against a headliner's.
enum FestivalSlot {
  headliner(minFans: 3e6, minFame: 0.55, reach: 0.6, feeShare: 1.0),
  subHeadliner(minFans: 8e5, minFame: 0.3, reach: 0.35, feeShare: 0.25),
  mainStage(minFans: 1.5e5, minFame: 0.12, reach: 0.18, feeShare: 0.05),
  smallStage(minFans: 1e4, minFame: 0.02, reach: 0.06, feeShare: 0.008);

  const FestivalSlot({
    required this.minFans,
    required this.minFame,
    required this.reach,
    required this.feeShare,
  });

  /// Enough core fans, or fame, for this slot.
  final double minFans;
  final double minFame;

  /// Share of the crowd that watches the set.
  final double reach;

  /// Fee against the festival's headline fee.
  final double feeShare;
}

/// A festival on the yearly calendar (fictional names; docs K77).
class Festival {
  const Festival({
    required this.name,
    required this.city,
    required this.market,
    required this.weekOfYear,
    required this.days,
    required this.crowd,
    required this.headlineFeeCents,
    this.genres = const [],
    this.since = 1990,
  });
  final String name;
  final String city;
  final TourMarket market;

  /// Week of the year it takes place (1–52).
  final int weekOfYear;
  final int days;

  /// People a day.
  final int crowd;

  /// A headliner's fee in 2020 money ([Tours.eraPrice] scales it).
  final int headlineFeeCents;

  /// Genres it books ([genreNames] indexes); empty = every genre.
  final List<int> genres;

  /// First year it runs.
  final int since;

  bool books(int genre) => genres.isEmpty || genres.contains(genre);
}

/// The festival calendar, in date order.
const festivals = <Festival>[
  Festival(
      name: 'Harbour Lights',
      city: 'Sydney',
      market: TourMarket.oceania,
      weekOfYear: 4,
      days: 3,
      crowd: 60000,
      headlineFeeCents: 120000000),
  Festival(
      name: 'Desert Bloom',
      city: 'Palm Springs',
      market: TourMarket.usa,
      weekOfYear: 16,
      days: 3,
      crowd: 125000,
      headlineFeeCents: 400000000),
  Festival(
      name: 'Cactus Country Jam',
      city: 'Austin',
      market: TourMarket.usa,
      weekOfYear: 18,
      days: 3,
      crowd: 80000,
      headlineFeeCents: 150000000,
      genres: [4]),
  Festival(
      name: 'Riverside Rock',
      city: 'Nuremberg',
      market: TourMarket.europe,
      weekOfYear: 22,
      days: 3,
      crowd: 85000,
      headlineFeeCents: 200000000,
      genres: [3, 8, 9, 7]),
  Festival(
      name: 'Mar Azul',
      city: 'Barcelona',
      market: TourMarket.europe,
      weekOfYear: 23,
      days: 3,
      crowd: 70000,
      headlineFeeCents: 150000000,
      genres: [7, 0, 5, 2],
      since: 2001),
  Festival(
      name: 'Big Apple Weekend',
      city: 'New York',
      market: TourMarket.usa,
      weekOfYear: 24,
      days: 3,
      crowd: 60000,
      headlineFeeCents: 200000000,
      since: 2006),
  Festival(
      name: 'Greenhill',
      city: 'Somerset',
      market: TourMarket.ukIreland,
      weekOfYear: 26,
      days: 5,
      crowd: 200000,
      headlineFeeCents: 300000000),
  Festival(
      name: 'Northern Lights',
      city: 'Copenhagen',
      market: TourMarket.europe,
      weekOfYear: 27,
      days: 4,
      crowd: 80000,
      headlineFeeCents: 150000000),
  Festival(
      name: 'Istanbul Soundwaves',
      city: 'Istanbul',
      market: TourMarket.europe,
      weekOfYear: 28,
      days: 2,
      crowd: 40000,
      headlineFeeCents: 60000000,
      since: 2004),
  Festival(
      name: 'Rolling Block',
      city: 'Miami',
      market: TourMarket.usa,
      weekOfYear: 29,
      days: 3,
      crowd: 70000,
      headlineFeeCents: 200000000,
      genres: [1, 2, 17],
      since: 2015),
  Festival(
      name: 'Dreamland',
      city: 'Antwerp',
      market: TourMarket.europe,
      weekOfYear: 30,
      days: 3,
      crowd: 70000,
      headlineFeeCents: 200000000,
      genres: [5, 0],
      since: 2005),
  Festival(
      name: 'Lakeshore',
      city: 'Chicago',
      market: TourMarket.usa,
      weekOfYear: 31,
      days: 4,
      crowd: 100000,
      headlineFeeCents: 300000000),
  Festival(
      name: 'Neon Tokyo',
      city: 'Tokyo',
      market: TourMarket.asia,
      weekOfYear: 33,
      days: 2,
      crowd: 100000,
      headlineFeeCents: 250000000),
  Festival(
      name: 'Sunset Sound',
      city: 'Rio de Janeiro',
      market: TourMarket.latinAmerica,
      weekOfYear: 38,
      days: 4,
      crowd: 100000,
      headlineFeeCents: 250000000),
  Festival(
      name: 'Austin City Sounds',
      city: 'Austin',
      market: TourMarket.usa,
      weekOfYear: 40,
      days: 3,
      crowd: 75000,
      headlineFeeCents: 200000000,
      since: 2002),
  Festival(
      name: 'Cumbre',
      city: 'Mexico City',
      market: TourMarket.latinAmerica,
      weekOfYear: 46,
      days: 2,
      crowd: 80000,
      headlineFeeCents: 150000000,
      genres: [6, 0, 3, 7]),
];

/// A festival the player has a slot at.
class FestivalBooking {
  const FestivalBooking(this.festival, this.year, this.slot);

  /// Index in [festivals].
  final int festival;
  final int year;
  final FestivalSlot slot;

  Festival get info => festivals[festival];
  int get week => GameTime.firstWeekOf(year) + info.weekOfYear - 1;

  static String encode(List<FestivalBooking> b) => jsonEncode([
        for (final x in b) [x.festival, x.year, x.slot.index]
      ]);

  static List<FestivalBooking> decode(String? s) => s == null || s.isEmpty
      ? []
      : [
          for (final x in jsonDecode(s) as List)
            FestivalBooking(
                x[0] as int, x[1] as int, FestivalSlot.values[x[2] as int]),
        ];
}

/// What a set did.
typedef FestivalSet = ({
  FestivalBooking booking,
  double watched,
  int feeCents,
  double fans,
  double listeners
});

abstract final class Festivals {
  /// The calendar ([festivals]).
  static const all = festivals;

  /// The best slot [a] would get now, or null when too small.
  static FestivalSlot? slotFor(Artist a) {
    for (final s in FestivalSlot.values) {
      if (a.coreFans >= s.minFans || a.fame >= s.minFame) return s;
    }
    return null;
  }

  /// The festival's next edition: this year if it is still ahead (from next
  /// week), else next year.
  static int nextYear(World w, Festival f) {
    final year = GameTime.yearOf(w.week);
    final thisYear = GameTime.firstWeekOf(year) + f.weekOfYear - 1;
    final y = thisYear > w.week ? year : year + 1;
    return math.max(y, f.since);
  }

  /// A set's fee in [year].
  static int feeCents(Festival f, FestivalSlot s, int year) =>
      (f.headlineFeeCents * s.feeShare * Tours.eraPrice(year)).round();

  /// People who watch the set over the festival (more for a great live act
  /// and a festival that books the artist's genre).
  static double watched(Festival f, FestivalSlot s, Artist a) =>
      f.crowd *
      f.days *
      s.reach *
      (f.genres.isEmpty || f.books(a.genre) ? 1.0 : 0.6) *
      (0.7 + 0.6 * a.skills.performance / 100);

  /// Books [a] at [f]'s next edition in the slot they get now.
  static FestivalBooking book(World w, Artist a, int festival) {
    final f = festivals[festival];
    final slot = slotFor(a);
    if (slot == null) throw StateError('Too small for festivals');
    if (!f.books(a.genre)) throw StateError('Not this festival\'s genre');
    final year = nextYear(w, f);
    if (w.festivalBookings
        .any((b) => b.festival == festival && b.year == year)) {
      throw StateError('Already booked');
    }
    final b = FestivalBooking(festival, year, slot);
    w.festivalBookings.add(b);
    return b;
  }

  /// Calls off a booking (no cost).
  static void cancel(World w, int festival, int year) => w.festivalBookings
      .removeWhere((b) => b.festival == festival && b.year == year);

  /// Plays this week's set, if any: the fee, new listeners and fans, buzz.
  static FestivalSet? playWeek(World w, Artist a) {
    final i = w.festivalBookings.indexWhere((b) => b.week == w.week);
    if (i < 0) return null;
    final b = w.festivalBookings.removeAt(i);
    final f = b.info;
    final seen = watched(f, b.slot, a);
    final fee = feeCents(f, b.slot, b.year);
    final charm = 0.03 + 0.05 * a.skills.charisma / 100;
    final fans = seen * charm;
    final listeners = seen * 0.4;
    a.moneyCents += a.manager.net(fee.toDouble()).round();
    Audience.addFans(w, a, fans);
    Audience.addCasual(w, a, listeners);
    a.hype = math.max(a.hype, 0.25 * b.slot.reach);
    a.skills.performance += 0.3 * (1 - a.skills.performance / 100);
    w.dirtyArtists.add(a.id);
    return (
      booking: b,
      watched: seen,
      feeCents: fee,
      fans: fans,
      listeners: listeners
    );
  }

  /// The bill of [f]'s edition in [year]: rivals by how big they are now
  /// (genre festivals book their genres), the player in their slot.
  static Map<FestivalSlot, List<int>> lineup(World w, int festival, int year) {
    final f = festivals[festival];
    final acts = [
      for (final id in w.activeArtistIds)
        if (w.artists[id].tier != ArtistTier.player &&
            f.books(w.artists[id].genre))
          w.artists[id]
    ]..sort((x, y) {
        final d = (y.fame + y.popularity).compareTo(x.fame + x.popularity);
        return d != 0 ? d : x.id.compareTo(y.id);
      });
    const sizes = {
      FestivalSlot.headliner: 3,
      FestivalSlot.subHeadliner: 5,
      FestivalSlot.mainStage: 8,
      FestivalSlot.smallStage: 10,
    };
    final mine = w.festivalBookings
        .where((b) => b.festival == festival && b.year == year)
        .firstOrNull;
    final bill = <FestivalSlot, List<int>>{};
    var next = 0;
    for (final s in FestivalSlot.values) {
      final row = <int>[];
      if (mine?.slot == s && w.player != null) row.add(w.player!.id);
      while (row.length < sizes[s]! && next < acts.length) {
        row.add(acts[next++].id);
      }
      bill[s] = row;
    }
    return bill;
  }
}
