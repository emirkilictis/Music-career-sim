import 'dart:convert';
import 'dart:math' as math;

import 'model.dart';
import 'world.dart';

/// Tour sizes (docs K63): who can fill them, how big and how long a leg is,
/// what a ticket costs and what a show costs to put on.
enum TourKind {
  club(
      minFans: 5e3,
      capacity: 500,
      priceCents: 2500,
      showCostCents: 150000,
      weeksPerRegion: 3),
  theater(
      minFans: 1e5,
      capacity: 2500,
      priceCents: 6000,
      showCostCents: 2500000,
      weeksPerRegion: 4),
  arena(
      minFans: 1e6,
      capacity: 15000,
      priceCents: 11000,
      showCostCents: 20000000,
      weeksPerRegion: 5),
  stadium(
      minFans: 5e6,
      capacity: 50000,
      priceCents: 14000,
      showCostCents: 200000000,
      weeksPerRegion: 6);

  const TourKind({
    required this.minFans,
    required this.capacity,
    required this.priceCents,
    required this.showCostCents,
    required this.weeksPerRegion,
  });

  final double minFans;
  final int capacity;
  final int priceCents;
  final int showCostCents;
  final int weeksPerRegion;
}

/// A tour under way (or just planned).
class Tour {
  Tour({
    required this.kind,
    required this.regions,
    required this.startWeek,
    this.tickets = 0,
    this.grossCents = 0,
    this.costCents = 0,
    this.fans = 0,
    this.cut = Tours.artistCut,
  });

  final TourKind kind;

  /// Regions in the order they are played ([Region.index]).
  final List<int> regions;
  final int startWeek;

  /// Running totals.
  double tickets;
  double grossCents;
  double costCents;
  double fans;

  /// The artist's share of ticket money (better with a manager; K68).
  final double cut;

  int get weeks => regions.length * kind.weeksPerRegion;
  int get endWeek => startWeek + weeks;

  /// Region played in [week] of the world.
  int regionAt(int week) => regions[
      ((week - startWeek) ~/ kind.weeksPerRegion).clamp(0, regions.length - 1)];

  /// The artist's take after the promoter's cut and the show costs.
  double get netCents => grossCents * cut - costCents;

  Map<String, Object?> toJson() => {
        'k': kind.index,
        'r': regions,
        'w': startWeek,
        't': tickets,
        'g': grossCents,
        'c': costCents,
        'f': fans,
        'cut': cut,
      };

  static Tour fromJson(Map<String, Object?> j) => Tour(
        kind: TourKind.values[j['k'] as int],
        regions: [for (final r in j['r'] as List) r as int],
        startWeek: j['w'] as int,
        tickets: (j['t'] as num).toDouble(),
        grossCents: (j['g'] as num).toDouble(),
        costCents: (j['c'] as num).toDouble(),
        fans: (j['f'] as num).toDouble(),
        cut: (j['cut'] as num?)?.toDouble() ?? Tours.artistCut,
      );

  static String? encode(Tour? t) => t == null ? null : jsonEncode(t.toJson());
  static Tour? decode(String? s) => s == null || s.isEmpty
      ? null
      : fromJson(jsonDecode(s) as Map<String, Object?>);
}

/// A week (or a whole tour) of shows, for planning and the news.
class TourWeek {
  TourWeek(
      {required this.tickets,
      required this.fill,
      required this.grossCents,
      required this.costCents,
      required this.fans});
  final double tickets;

  /// Share of seats sold (0–1).
  final double fill;
  final double grossCents;
  final double costCents;
  final double fans;
}

abstract final class Tours {
  /// Shows a week on the road.
  static const showsPerWeek = 3;

  /// Share of the ticket money the artist keeps (the rest: promoter,
  /// venue, agent).
  static const artistCut = 0.7;

  /// The artist's share of ticket money with their manager (docs K68).
  static double cutFor(Artist a) => artistCut + a.manager.tourCut;

  /// What [a] would keep of a tour estimated as [e].
  static double netFor(Artist a, TourWeek e) {
    final net = e.grossCents * cutFor(a) - e.costCents;
    return net > 0 ? a.manager.net(net) : net;
  }

  /// Energy a tour week takes.
  static const energyPerWeek = 12.0;

  /// Whether the artist can start [kind]: enough fans, no tour on.
  static bool canStart(Artist a, TourKind kind) =>
      a.tour == null && a.coreFans >= kind.minFans;

  /// One week of shows in region [r]: people who want to go come (core
  /// fans most, casual listeners some, more when the artist is hot), up to
  /// the seats there are.
  static TourWeek week(World w, Artist a, TourKind kind, int r) {
    final share = a.regionShare[r];
    final hot = 1 + a.hype + 0.5 * a.popularity;
    // Over a leg's weeks the same city is not played twice: demand per
    // week is the region's demand spread over the leg.
    final demand = (a.coreFans * share * 0.12 + a.casual * share * 0.004) *
        hot *
        (0.6 + 0.8 * a.skills.performance / 100) /
        kind.weeksPerRegion;
    final seats = (kind.capacity * showsPerWeek).toDouble();
    final tickets = math.min(seats, demand);
    final gross = tickets * kind.priceCents;
    final cost = (kind.showCostCents * showsPerWeek).toDouble();
    // Fans made at the shows: a great show turns casual buyers into fans.
    final fans = tickets * (0.15 + 0.25 * a.skills.performance / 100);
    return TourWeek(
        tickets: tickets,
        fill: tickets / seats,
        grossCents: gross,
        costCents: cost,
        fans: fans);
  }

  /// The whole tour as planned now (for the planning screen).
  static TourWeek estimate(
      World w, Artist a, TourKind kind, List<int> regions) {
    var tickets = 0.0, gross = 0.0, cost = 0.0, fans = 0.0, seats = 0.0;
    for (final r in regions) {
      final wk = week(w, a, kind, r);
      tickets += wk.tickets * kind.weeksPerRegion;
      gross += wk.grossCents * kind.weeksPerRegion;
      cost += wk.costCents * kind.weeksPerRegion;
      fans += wk.fans * kind.weeksPerRegion;
      seats += kind.capacity * showsPerWeek * kind.weeksPerRegion;
    }
    return TourWeek(
        tickets: tickets,
        fill: seats == 0 ? 0 : tickets / seats,
        grossCents: gross,
        costCents: cost,
        fans: fans);
  }

  /// Starts a tour this week.
  static Tour start(World w, Artist a, TourKind kind, List<int> regions) {
    if (regions.isEmpty || regions.toSet().length != regions.length) {
      throw ArgumentError('Pick each region once');
    }
    if (!canStart(a, kind)) throw StateError('Cannot start this tour');
    final t = Tour(
        kind: kind,
        regions: List.of(regions),
        startWeek: w.week,
        cut: cutFor(a));
    a.tour = t;
    w.dirtyArtists.add(a.id);
    return t;
  }

  /// Plays this week's shows. Returns the finished tour on its last week.
  static Tour? playWeek(World w, Artist a) {
    final t = a.tour;
    if (t == null || w.week < t.startWeek) return null;
    final wk = week(w, a, t.kind, t.regionAt(w.week));
    t.tickets += wk.tickets;
    t.grossCents += wk.grossCents;
    t.costCents += wk.costCents;
    t.fans += wk.fans;
    final net = wk.grossCents * t.cut - wk.costCents;
    // The manager's cut comes out of a profit, not a loss.
    a.moneyCents += (net > 0 ? a.manager.net(net) : net).round();
    a.coreFans += wk.fans;
    a.devotion = math.min(1.0, a.devotion + 0.002 * wk.fill);
    a.hype = math.max(a.hype, 0.1 * wk.fill);
    a.skills.performance += 0.15 * (1 - a.skills.performance / 100);
    w.dirtyArtists.add(a.id);
    if (w.week + 1 >= t.endWeek) {
      a.tour = null;
      return t;
    }
    return null;
  }

  /// Weeks left (including this one).
  static int weeksLeft(World w, Tour t) => t.endWeek - w.week;
}
