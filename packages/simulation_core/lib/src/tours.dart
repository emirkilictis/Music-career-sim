import 'dart:convert';
import 'dart:math' as math;

import 'audience.dart';
import 'config/regions.dart';
import 'model.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// Venue sizes (docs K63, K76): who can fill them, how big a venue is, what
/// a ticket costs (2020 money; [Tours.eraPrice] scales it), what one show
/// and moving the production to another continent cost, and how many nights
/// one city takes.
enum TourKind {
  club(
      minFans: 5e3,
      minCapacity: 300,
      maxCapacity: 1000,
      priceCents: 2500,
      showCostCents: 150000,
      freightCents: 500000,
      maxNights: 2),
  theater(
      minFans: 1e5,
      minCapacity: 1500,
      maxCapacity: 4000,
      priceCents: 6000,
      showCostCents: 2500000,
      freightCents: 4000000,
      maxNights: 3),
  arena(
      minFans: 1e6,
      minCapacity: 10000,
      maxCapacity: 20000,
      priceCents: 11000,
      showCostCents: 20000000,
      freightCents: 30000000,
      maxNights: 5),
  stadium(
      minFans: 5e6,
      minCapacity: 40000,
      maxCapacity: 80000,
      priceCents: 14000,
      showCostCents: 200000000,
      freightCents: 200000000,
      maxNights: 6);

  const TourKind({
    required this.minFans,
    required this.minCapacity,
    required this.maxCapacity,
    required this.priceCents,
    required this.showCostCents,
    required this.freightCents,
    required this.maxNights,
  });

  final double minFans;
  final int minCapacity;
  final int maxCapacity;

  /// A typical ticket in 2020 money.
  final int priceCents;
  final int showCostCents;

  /// Shipping the production to a continent (half at home).
  final int freightCents;

  /// Most nights one city can take at this size.
  final int maxNights;

  /// A typical venue's seats.
  int get capacity => (minCapacity + maxCapacity) ~/ 2;
}

/// A city on the touring map: its pull on the market's fans.
class TourCity {
  const TourCity(this.name, this.weight);
  final String name;
  final double weight;
}

/// Where a leg plays (docs K76): a market inside one of the simulation's
/// regions, with its share of that region's listeners and its cities in
/// routing order.
enum TourMarket {
  usa(Region.northAmerica, 0.88, [
    TourCity('New York', 10),
    TourCity('Boston', 4),
    TourCity('Philadelphia', 4),
    TourCity('Washington', 4),
    TourCity('Atlanta', 4),
    TourCity('Miami', 4),
    TourCity('Nashville', 3),
    TourCity('Houston', 4),
    TourCity('Dallas', 4),
    TourCity('Chicago', 6),
    TourCity('Detroit', 3),
    TourCity('Minneapolis', 3),
    TourCity('Denver', 3),
    TourCity('Phoenix', 3),
    TourCity('Las Vegas', 3),
    TourCity('Los Angeles', 9),
    TourCity('San Francisco', 4),
    TourCity('Seattle', 3),
  ]),
  canada(Region.northAmerica, 0.12, [
    TourCity('Toronto', 5),
    TourCity('Montreal', 3),
    TourCity('Calgary', 2),
    TourCity('Vancouver', 3),
  ]),
  ukIreland(Region.europe, 0.35, [
    TourCity('London', 10),
    TourCity('Birmingham', 3),
    TourCity('Manchester', 4),
    TourCity('Leeds', 2),
    TourCity('Glasgow', 3),
    TourCity('Dublin', 3),
  ]),
  europe(Region.europe, 0.65, [
    TourCity('Paris', 6),
    TourCity('Brussels', 3),
    TourCity('Amsterdam', 4),
    TourCity('Copenhagen', 3),
    TourCity('Stockholm', 3),
    TourCity('Berlin', 5),
    TourCity('Warsaw', 3),
    TourCity('Prague', 2),
    TourCity('Vienna', 3),
    TourCity('Munich', 3),
    TourCity('Zurich', 2),
    TourCity('Milan', 4),
    TourCity('Istanbul', 3),
    TourCity('Barcelona', 4),
    TourCity('Madrid', 4),
    TourCity('Lisbon', 2),
  ]),
  latinAmerica(Region.other, 0.40, [
    TourCity('Mexico City', 6),
    TourCity('Monterrey', 2),
    TourCity('Bogotá', 3),
    TourCity('Lima', 2),
    TourCity('Santiago', 3),
    TourCity('Buenos Aires', 5),
    TourCity('São Paulo', 6),
    TourCity('Rio de Janeiro', 4),
  ]),
  asia(Region.other, 0.45, [
    TourCity('Tokyo', 8),
    TourCity('Osaka', 3),
    TourCity('Seoul', 5),
    TourCity('Taipei', 2),
    TourCity('Hong Kong', 3),
    TourCity('Manila', 3),
    TourCity('Bangkok', 3),
    TourCity('Singapore', 3),
    TourCity('Jakarta', 3),
    TourCity('Mumbai', 2),
  ]),
  oceania(Region.other, 0.15, [
    TourCity('Perth', 2),
    TourCity('Melbourne', 5),
    TourCity('Sydney', 5),
    TourCity('Brisbane', 2),
    TourCity('Auckland', 2),
  ]);

  const TourMarket(this.region, this.share, this.cities);

  /// The simulation region whose listeners buy the tickets.
  final Region region;

  /// This market's share of that region's listeners.
  final double share;
  final List<TourCity> cities;

  double get totalWeight => cities.fold(0.0, (t, c) => t + c.weight);
}

/// How big the show is: what it costs, and how much a night wins people
/// over (docs K76).
enum TourProduction {
  basic(costFactor: 0.7, quality: 0.85),
  standard(costFactor: 1.0, quality: 1.0),
  spectacle(costFactor: 1.8, quality: 1.25);

  const TourProduction({required this.costFactor, required this.quality});
  final double costFactor;
  final double quality;
}

/// One leg: a market, a venue size and a number of shows.
class TourLeg {
  const TourLeg(this.market, this.kind, this.shows);
  final TourMarket market;
  final TourKind kind;
  final int shows;
}

/// One night: where, when, how big, and once played how it sold.
class TourShow {
  TourShow({
    required this.week,
    required this.leg,
    required this.market,
    required this.city,
    required this.venue,
    required this.capacity,
    required this.priceCents,
    this.sold = -1,
    this.grossCents = 0,
  });

  final int week;

  /// Index of its leg in [Tour.legs].
  final int leg;
  final TourMarket market;

  /// Index in [TourMarket.cities].
  final int city;
  final String venue;
  final int capacity;
  final int priceCents;

  /// Tickets sold (-1 until played) and the box office.
  double sold;
  double grossCents;

  bool get played => sold >= 0;
  bool get soldOut => played && sold >= capacity * Tours.soldOutShare;
  String get cityName => market.cities[city].name;

  List<Object> toJson() => [
        week,
        leg,
        market.index,
        city,
        venue,
        capacity,
        priceCents,
        sold,
        grossCents
      ];

  static TourShow fromJson(List<dynamic> j) => TourShow(
        week: j[0] as int,
        leg: j[1] as int,
        market: TourMarket.values[j[2] as int],
        city: j[3] as int,
        venue: j[4] as String,
        capacity: j[5] as int,
        priceCents: j[6] as int,
        sold: (j[7] as num).toDouble(),
        grossCents: (j[8] as num).toDouble(),
      );
}

/// A tour under way or planned (docs K63, K76).
class Tour {
  Tour({
    this.name = '',
    required this.legs,
    required this.startWeek,
    this.priceFactor = 1.0,
    this.production = TourProduction.standard,
    this.openerId = -1,
    this.cut = Tours.artistCut,
    List<TourShow>? shows,
    this.tickets = 0,
    this.grossCents = 0,
    this.costCents = 0,
    this.merchCents = 0,
    this.fans = 0,
    this.soldOut = 0,
  }) : shows = shows ?? [];

  /// The player's name for it ('' = named after its biggest venues).
  final String name;
  final List<TourLeg> legs;
  final int startWeek;

  /// Ticket prices against the era's usual price for each venue size.
  final double priceFactor;
  final TourProduction production;

  /// The support act's artist id (-1: none).
  final int openerId;

  /// The artist's share of ticket money (better with a manager; K68).
  final double cut;

  /// Every night, in order.
  final List<TourShow> shows;

  /// Running totals.
  double tickets;
  double grossCents;
  double costCents;
  double merchCents;
  double fans;
  int soldOut;

  /// The biggest venues on the tour.
  TourKind get kind =>
      legs.map((l) => l.kind).reduce((a, b) => a.index >= b.index ? a : b);

  int get endWeek => shows.isEmpty ? startWeek + 1 : shows.last.week + 1;
  int get weeks => endWeek - startWeek;

  /// Nights this week.
  List<TourShow> showsIn(int week) => [
        for (final s in shows)
          if (s.week == week) s
      ];

  /// The artist's take: their share of the box office, merch, less costs.
  double get netCents => grossCents * cut + merchCents - costCents;

  Map<String, Object?> toJson() => {
        'v': 2,
        'n': name,
        'legs': [
          for (final l in legs) [l.market.index, l.kind.index, l.shows]
        ],
        'w': startWeek,
        'pf': priceFactor,
        'pr': production.index,
        'op': openerId,
        'cut': cut,
        'sh': [for (final s in shows) s.toJson()],
        't': tickets,
        'g': grossCents,
        'c': costCents,
        'm': merchCents,
        'f': fans,
        'so': soldOut,
      };

  static Tour fromJson(Map<String, Object?> j) {
    final double Function(String) d = (k) => (j[k] as num?)?.toDouble() ?? 0;
    if (j['v'] == null) {
      // A tour saved before docs K76: one leg per region at one size, the
      // same weeks as before; its shows are laid out on its next week.
      final kind = TourKind.values[j['k'] as int];
      const legacyWeeks = [3, 4, 5, 6];
      return Tour(
        legs: [
          for (final r in j['r'] as List)
            TourLeg(
                switch (r as int) {
                  0 => TourMarket.usa,
                  1 => TourMarket.europe,
                  _ => TourMarket.asia,
                },
                kind,
                legacyWeeks[kind.index] * Tours.showsPerWeek),
        ],
        startWeek: j['w'] as int,
        cut: (j['cut'] as num?)?.toDouble() ?? Tours.artistCut,
        tickets: d('t'),
        grossCents: d('g'),
        costCents: d('c'),
        fans: d('f'),
      );
    }
    return Tour(
      name: j['n'] as String? ?? '',
      legs: [
        for (final l in j['legs'] as List)
          TourLeg(TourMarket.values[(l as List)[0] as int],
              TourKind.values[l[1] as int], l[2] as int),
      ],
      startWeek: j['w'] as int,
      priceFactor: d('pf'),
      production: TourProduction.values[j['pr'] as int],
      openerId: j['op'] as int,
      cut: d('cut'),
      shows: [
        for (final s in j['sh'] as List) TourShow.fromJson(s as List),
      ],
      tickets: d('t'),
      grossCents: d('g'),
      costCents: d('c'),
      merchCents: d('m'),
      fans: d('f'),
      soldOut: j['so'] as int? ?? 0,
    );
  }

  static String? encode(Tour? t) => t == null ? null : jsonEncode(t.toJson());
  static Tour? decode(String? s) => s == null || s.isEmpty
      ? null
      : fromJson(jsonDecode(s) as Map<String, Object?>);
}

/// A tour's numbers: as estimated before it starts, or for one week.
class TourWeek {
  TourWeek({
    required this.tickets,
    required this.fill,
    required this.grossCents,
    required this.costCents,
    required this.fans,
    this.merchCents = 0,
    this.productionCents = 0,
    this.openerCents = 0,
    this.freightCents = 0,
    this.shows = 0,
    this.soldOut = 0,
  });
  final double tickets;

  /// Share of seats sold (0–1).
  final double fill;
  final double grossCents;

  /// All costs: [productionCents] + [openerCents] + [freightCents].
  final double costCents;
  final double fans;
  final double merchCents;
  final double productionCents;
  final double openerCents;
  final double freightCents;
  final int shows;
  final int soldOut;
}

/// One night's expected or actual turnout.
typedef ShowResult = ({double sold, double grossCents});

abstract final class Tours {
  /// Shows a week on the road.
  static const showsPerWeek = 3;

  /// Share of the ticket money the artist keeps (the rest: promoter,
  /// venue, agent).
  static const artistCut = 0.7;

  /// A night counts as sold out from this share of seats.
  static const soldOutShare = 0.98;

  /// Ticket price range against the era's usual price.
  static const minPriceFactor = 0.6, maxPriceFactor = 2.0;

  /// Share of merch money the artist keeps after making the goods.
  static const merchKeep = 0.6;

  /// Most shows in one leg.
  static const maxShowsPerLeg = 60;

  /// The artist's share of ticket money with their manager (docs K68).
  static double cutFor(Artist a) => artistCut + a.manager.tourCut;

  /// What [a] would keep of a tour estimated as [e].
  static double netFor(Artist a, TourWeek e) {
    final net = e.grossCents * cutFor(a) + e.merchCents - e.costCents;
    return net > 0 ? a.manager.net(net) : net;
  }

  /// Energy a tour week takes.
  static const energyPerWeek = 12.0;

  /// Whether the artist can play [kind] venues: enough fans, no tour on.
  static bool canStart(Artist a, TourKind kind) =>
      a.tour == null && a.coreFans >= kind.minFans;

  /// Ticket and merch prices against 2020 (≈0.5 in 2000, 1.15 in 2026).
  static double eraPrice(int year) =>
      (0.5 + 0.025 * (year - 2000)).clamp(0.4, 1.4).toDouble();

  /// A ticket at [kind] venues in [year] at [priceFactor].
  static int priceFor(TourKind kind, int year, double priceFactor) =>
      (kind.priceCents * eraPrice(year) * priceFactor).round();

  /// Merch a fan buys at a show.
  static double merchPerHeadCents(int year) => 1500 * eraPrice(year);

  /// Most shows a leg can have in [market] at [kind] venues.
  static int maxShows(TourMarket market, TourKind kind) =>
      math.min(maxShowsPerLeg, market.cities.length * kind.maxNights);

  /// A support act's fee per night: more for a known name.
  static int openerFeeCents(Artist o) =>
      (100000 * (1 + 150 * o.fame * o.fame)).round();

  /// Who could open for [a]: rivals smaller than them with a following,
  /// same genre first, then the best known.
  static List<Artist> openerCandidates(World w, Artist a, {int max = 15}) {
    final ceiling = math.max(0.05, 0.9 * a.fame);
    final list = [
      for (final id in w.activeArtistIds)
        if (id != a.id &&
            w.artists[id].tier != ArtistTier.player &&
            !w.artists[id].isRetired &&
            w.artists[id].fame < ceiling &&
            w.artists[id].coreFans >= 1e4)
          w.artists[id]
    ]..sort((x, y) {
        final g = (y.genre == a.genre ? 1 : 0) - (x.genre == a.genre ? 1 : 0);
        if (g != 0) return g;
        final f = y.fame.compareTo(x.fame);
        return f != 0 ? f : x.id.compareTo(y.id);
      });
    return list.take(max).toList();
  }

  /// The venue of [kind] size in a city: same name and size every time in
  /// this world (fictional names; docs K76).
  static (String, int) venue(World w, TourMarket m, int city, TourKind kind) {
    final r = RandomStream.keyed(
        w.seed, m.index * 100 + city, kind.index, RngPurpose.tour);
    final name = m.cities[city].name;
    final cap = (kind.minCapacity +
            r.nextDouble() * (kind.maxCapacity - kind.minCapacity))
        .round();
    final rounded = cap >= 10000 ? (cap ~/ 500) * 500 : (cap ~/ 50) * 50;
    String pick(List<String> xs) => xs[r.nextInt(xs.length)];
    final venue = switch (kind) {
      TourKind.club => r.chance(0.5)
          ? 'The ${pick(_clubWords)} ${pick(_clubPlaces)}'
          : '${pick(_clubWords)} ${pick(_clubPlaces)} $name',
      TourKind.theater => r.chance(0.5)
          ? 'The ${pick(_theaterNames)} Theatre'
          : '$name ${pick(_hallWords)}',
      TourKind.arena => r.chance(0.7)
          ? '${pick(_sponsors)} ${pick(_arenaWords)}'
          : '$name ${pick(_arenaWords)}',
      TourKind.stadium => r.chance(0.6)
          ? '${pick(_sponsors)} ${pick(_stadiumWords)}'
          : '$name ${pick(_civicStadiums)}',
    };
    return (venue, rounded);
  }

  /// Lays out a tour's nights from [startWeek]: each leg spreads its shows
  /// over the market's cities by their pull (big cities get extra nights),
  /// plays them in routing order, three a week, and starts a new week.
  static List<TourShow> schedule(
      World w, List<TourLeg> legs, int startWeek, double priceFactor) {
    final shows = <TourShow>[];
    var cursor = startWeek;
    for (var li = 0; li < legs.length; li++) {
      final leg = legs[li];
      final cities = leg.market.cities;
      final nights = List.filled(cities.length, 0);
      for (var n = 0; n < leg.shows; n++) {
        var best = -1;
        var bestScore = -1.0;
        for (var c = 0; c < cities.length; c++) {
          if (nights[c] >= leg.kind.maxNights) continue;
          final score = cities[c].weight / (nights[c] + 1);
          if (score > bestScore) {
            bestScore = score;
            best = c;
          }
        }
        if (best < 0) break;
        nights[best]++;
      }
      var i = 0;
      for (var c = 0; c < cities.length; c++) {
        if (nights[c] == 0) continue;
        final (name, cap) = venue(w, leg.market, c, leg.kind);
        for (var k = 0; k < nights[c]; k++) {
          final week = cursor + i ~/ showsPerWeek;
          shows.add(TourShow(
              week: week,
              leg: li,
              market: leg.market,
              city: c,
              venue: name,
              capacity: cap,
              priceCents:
                  priceFor(leg.kind, GameTime.yearOf(week), priceFactor)));
          i++;
        }
      }
      cursor += (i + showsPerWeek - 1) ~/ showsPerWeek;
    }
    return shows;
  }

  /// Builds a tour starting this week (not yet on the road).
  static Tour plan(
    World w,
    Artist a, {
    required List<TourLeg> legs,
    String name = '',
    double priceFactor = 1.0,
    TourProduction production = TourProduction.standard,
    int openerId = -1,
  }) {
    final pf = priceFactor.clamp(minPriceFactor, maxPriceFactor).toDouble();
    return Tour(
      name: name.trim(),
      legs: legs,
      startWeek: w.week,
      priceFactor: pf,
      production: production,
      openerId: openerId,
      cut: cutFor(a),
      shows: schedule(w, legs, w.week, pf),
    );
  }

  /// People in [m] who would buy a ticket on this tour, over all its nights
  /// there: core fans most, casual listeners some (both fewer when tickets
  /// cost more, casual ones much fewer), more when the artist is hot and a
  /// great live act, plus some of the support act's fans.
  static double marketDemand(
      World w, Artist a, TourMarket m, double priceFactor, Artist? opener) {
    final share = a.regionShare[m.region.index] * m.share;
    final hot = 1 + a.hype + 0.5 * a.popularity;
    final live = 0.6 + 0.8 * a.skills.performance / 100;
    final core =
        a.coreFans * share * 0.18 * math.pow(priceFactor, -0.5).toDouble();
    final casual =
        a.casual * share * 0.007 * math.pow(priceFactor, -1.6).toDouble();
    final support = opener == null
        ? 0.0
        : opener.coreFans *
            opener.regionShare[m.region.index] *
            m.share *
            0.03 /
            priceFactor;
    return (core + casual) * hot * live * a.kind.tourDemand + support;
  }

  /// A night's turnout: the market's demand shared by the cities on the
  /// route (fans from cities skipped travel in, a quarter of them), then
  /// split over that city's nights, up to the seats.
  static ShowResult showResult(World w, Artist a, Tour t, TourShow s,
      {double noise = 1}) {
    final m = s.market;
    final opener = t.openerId >= 0 ? w.artists[t.openerId] : null;
    final legShows = [
      for (final x in t.shows)
        if (x.leg == s.leg) x
    ];
    final visited = <int>{for (final x in legShows) x.city};
    var visitedWeight = 0.0;
    for (final c in visited) {
      visitedWeight += m.cities[c].weight;
    }
    final reach = visitedWeight / m.totalWeight;
    final pool = marketDemand(w, a, m, t.priceFactor, opener) *
        (reach + 0.25 * (1 - reach));
    final nights = legShows.where((x) => x.city == s.city).length;
    final demand =
        pool * m.cities[s.city].weight / visitedWeight / nights * noise;
    final sold = math.min(s.capacity.toDouble(), demand);
    return (sold: sold, grossCents: sold * s.priceCents);
  }

  /// Costs of one night: the production, the support act, and shipping the
  /// show when a leg begins.
  static ({double production, double opener, double freight}) showCosts(
      World w, Artist a, Tour t, TourShow s) {
    final kind = t.legs[s.leg].kind;
    final first = t.shows.firstWhere((x) => x.leg == s.leg) == s;
    final home = a.homeCountry.region == s.market.region;
    return (
      production: kind.showCostCents * t.production.costFactor,
      opener: t.openerId >= 0
          ? openerFeeCents(w.artists[t.openerId]).toDouble()
          : 0.0,
      freight: first ? kind.freightCents * (home ? 0.5 : 1.0) : 0.0,
    );
  }

  /// Fans made at a night: a great show turns casual buyers into fans.
  static double fansFrom(Artist a, Tour t, double sold) =>
      sold * (0.15 + 0.25 * a.skills.performance / 100) * t.production.quality;

  /// The whole tour as things stand (planning screen), with each night's
  /// expected turnout.
  static (TourWeek, List<ShowResult>) estimate(World w, Artist a, Tour t) {
    var tickets = 0.0, seats = 0.0, gross = 0.0, merch = 0.0, fans = 0.0;
    var production = 0.0, opener = 0.0, freight = 0.0;
    var soldOut = 0;
    final each = <ShowResult>[];
    for (final s in t.shows) {
      final r = showResult(w, a, t, s);
      each.add(r);
      final c = showCosts(w, a, t, s);
      tickets += r.sold;
      seats += s.capacity;
      gross += r.grossCents;
      merch += r.sold *
          merchPerHeadCents(GameTime.yearOf(s.week)) *
          a.kind.merch *
          merchKeep;
      fans += fansFrom(a, t, r.sold);
      production += c.production;
      opener += c.opener;
      freight += c.freight;
      if (r.sold >= s.capacity * soldOutShare) soldOut++;
    }
    return (
      TourWeek(
        tickets: tickets,
        fill: seats == 0 ? 0 : tickets / seats,
        grossCents: gross,
        costCents: production + opener + freight,
        fans: fans,
        merchCents: merch,
        productionCents: production,
        openerCents: opener,
        freightCents: freight,
        shows: t.shows.length,
        soldOut: soldOut,
      ),
      each,
    );
  }

  /// Puts a planned tour on the road.
  static Tour start(World w, Artist a, Tour t) {
    if (a.tour != null) throw StateError('Already on tour');
    if (t.legs.isEmpty ||
        t.legs.map((l) => l.market).toSet().length != t.legs.length) {
      throw ArgumentError('Pick each market once');
    }
    for (final l in t.legs) {
      if (a.coreFans < l.kind.minFans) {
        throw StateError('Not enough fans for ${l.kind.name} venues');
      }
      if (l.shows < 1 || l.shows > maxShows(l.market, l.kind)) {
        throw ArgumentError('Shows out of range');
      }
    }
    a.tour = t;
    w.dirtyArtists.add(a.id);
    return t;
  }

  /// Plays this week's nights. Returns the finished tour on its last week.
  static Tour? playWeek(World w, Artist a) {
    final t = a.tour;
    if (t == null || w.week < t.startWeek) return null;
    if (t.shows.isEmpty) {
      // Saved before docs K76: lay it out now, past weeks already paid.
      t.shows.addAll([
        for (final s in schedule(w, t.legs, t.startWeek, t.priceFactor))
          if (s.week >= w.week) s
      ]);
    }
    final tonight = t.showsIn(w.week);
    if (tonight.isNotEmpty) {
      var net = 0.0, fill = 0.0;
      for (final s in tonight) {
        final noise = RandomStream.keyed(
                w.seed, w.week, a.id * 64 + t.shows.indexOf(s), RngPurpose.tour)
            .logNormal(0.06);
        final r = showResult(w, a, t, s, noise: noise);
        final c = showCosts(w, a, t, s);
        final cost = c.production + c.opener + c.freight;
        final merch = r.sold *
            merchPerHeadCents(GameTime.yearOf(w.week)) *
            a.kind.merch *
            merchKeep;
        final fans = fansFrom(a, t, r.sold);
        s.sold = r.sold;
        s.grossCents = r.grossCents;
        if (s.soldOut) t.soldOut++;
        t.tickets += r.sold;
        t.grossCents += r.grossCents;
        t.costCents += cost;
        t.merchCents += merch;
        t.fans += fans;
        Audience.addFans(w, a, fans);
        net += r.grossCents * t.cut + merch - cost;
        fill += r.sold / s.capacity;
        // The support act wins some of the crowd.
        if (t.openerId >= 0) {
          final o = w.artists[t.openerId];
          Audience.addFans(w, o, 0.01 * r.sold);
          w.dirtyArtists.add(o.id);
        }
      }
      fill /= tonight.length;
      // The manager's cut comes out of a profit, not a loss.
      a.moneyCents += (net > 0 ? a.manager.net(net) : net).round();
      a.devotion =
          math.min(1.0, a.devotion + 0.002 * fill * t.production.quality);
      a.hype = math.max(a.hype, 0.1 * fill * t.production.quality);
      a.skills.performance += 0.15 * (1 - a.skills.performance / 100);
      w.dirtyArtists.add(a.id);
    }
    if (w.week + 1 >= t.endWeek) {
      a.tour = null;
      w.dirtyArtists.add(a.id);
      return t;
    }
    return null;
  }

  /// Weeks left (including this one).
  static int weeksLeft(World w, Tour t) => t.endWeek - w.week;
}

const _clubWords = [
  'Velvet',
  'Blue',
  'Neon',
  'Copper',
  'Black Cat',
  'Lantern',
  'Echo',
  'Basement',
  'Paper Moon',
  'Wildflower',
  'Ruby',
  'Harbor',
];
const _clubPlaces = ['Room', 'Lounge', 'Hall', 'Club', 'Cellar', 'Social'];
const _theaterNames = [
  'Majestic',
  'Orpheum',
  'Paramount',
  'Royal',
  'Grand',
  'Apollo',
  'Regent',
  'Lyric',
  'Palace',
  'Empire',
];
const _hallWords = ['Music Hall', 'Opera House', 'Concert Hall', 'Theatre'];
const _sponsors = [
  'Northline',
  'Vantage',
  'Crestbank',
  'Helio',
  'Summit Mobile',
  'Pinnacle',
  'Atlas Energy',
  'Meridian',
  'Bluewave',
  'Orbit Air',
  'Keystone',
  'Lumen',
];
const _arenaWords = ['Arena', 'Center', 'Dome', 'Garden', 'Forum'];
const _stadiumWords = ['Stadium', 'Field', 'Park'];
const _civicStadiums = ['Olympic Stadium', 'National Stadium', 'Stadium'];

/// A tour on the books for the box-office rankings (docs K77): a rival's
/// (projected when it is booked) or the player's (as played).
class TourRecord {
  TourRecord({
    required this.artistId,
    required this.name,
    required this.startWeek,
    required this.endWeek,
    required this.shows,
    required this.tickets,
    required this.grossCents,
  });
  final int artistId;
  final String name;
  final int startWeek;

  /// First week after the last show.
  final int endWeek;
  final int shows;
  final double tickets;
  final double grossCents;

  int get weeks => math.max(1, endWeek - startWeek);

  /// Share of the tour played by the end of [week] (its money comes in
  /// evenly over its weeks).
  double playedBy(int week) =>
      ((week - startWeek) / weeks).clamp(0.0, 1.0).toDouble();

  /// Box office earned within [year].
  double grossIn(int year) {
    final from = GameTime.firstWeekOf(year),
        to = GameTime.firstWeekOf(year + 1);
    final overlap =
        math.max(0, math.min(endWeek, to) - math.max(startWeek, from));
    return grossCents * overlap / weeks;
  }

  List<Object> toJson() =>
      [artistId, name, startWeek, endWeek, shows, tickets, grossCents];

  static TourRecord fromJson(List<dynamic> j) => TourRecord(
        artistId: j[0] as int,
        name: j[1] as String,
        startWeek: j[2] as int,
        endWeek: j[3] as int,
        shows: j[4] as int,
        tickets: (j[5] as num).toDouble(),
        grossCents: (j[6] as num).toDouble(),
      );

  static String encode(List<TourRecord> r) =>
      jsonEncode([for (final x in r) x.toJson()]);

  static List<TourRecord> decode(String? s) => s == null || s.isEmpty
      ? []
      : [for (final x in jsonDecode(s) as List) fromJson(x as List)];
}

/// Rivals' tours (docs K77): they do not change the weekly simulation, but
/// fill the box-office rankings the player's tours compete in.
abstract final class RivalTours {
  /// Rivals this big may tour.
  static const minFans = 2e5;

  /// Books this year's tours for rivals with a recent album who have not
  /// toured lately: their biggest affordable venues, the markets where
  /// they have listeners, as many nights as their fans fill.
  static void bookYear(World w) {
    final year = GameTime.yearOf(w.week);
    final lastTour = <int, int>{};
    for (final r in w.tourRecords) {
      lastTour[r.artistId] = math.max(lastTour[r.artistId] ?? -1, r.endWeek);
    }
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      if (a.tier == ArtistTier.player || a.coreFans < minFans) continue;
      if (a.lastReleaseWeek < w.week - 78) continue;
      if ((lastTour[id] ?? -1000) > w.week - 2 * GameTime.weeksPerYear) {
        continue;
      }
      final r = RandomStream.keyed(w.seed, w.week, id, RngPurpose.tour);
      if (!r.chance(0.6)) continue;
      // The biggest venues they can fill a run of (at least 10 nights).
      var shows = 0, tickets = 0.0, gross = 0.0, legs = 0;
      for (final kind in TourKind.values.reversed) {
        if (a.coreFans < kind.minFans) continue;
        shows = 0;
        tickets = 0;
        gross = 0;
        legs = 0;
        for (final m in TourMarket.values) {
          final demand = Tours.marketDemand(w, a, m, 1.0, null);
          final n = (demand / (kind.capacity * 0.85))
              .round()
              .clamp(0, Tours.maxShows(m, kind))
              .toInt();
          if (n < 3) continue;
          final sold = math.min(demand, n * kind.capacity.toDouble());
          shows += n;
          tickets += sold;
          gross += sold * Tours.priceFor(kind, year, 1.0);
          legs++;
        }
        if (shows >= 10 || kind == TourKind.club) break;
      }
      if (shows == 0) continue;
      final start = w.week + 4 + r.nextInt(30);
      w.tourRecords.add(TourRecord(
        artistId: id,
        name: _name(w, a, r),
        startWeek: start,
        endWeek: start +
            (shows + Tours.showsPerWeek - 1) ~/ Tours.showsPerWeek +
            legs,
        shows: shows,
        tickets: tickets,
        grossCents: gross,
      ));
    }
  }

  static String _name(World w, Artist a, RandomStream r) {
    for (var i = w.albums.length - 1; i >= 0; i--) {
      final al = w.albums[i];
      if (al.artistId != a.id) continue;
      if (al.releaseWeek < w.week - 104) break;
      return r.chance(0.5) ? '${al.title} Tour' : '${al.title} World Tour';
    }
    return '${a.name} Live';
  }
}
