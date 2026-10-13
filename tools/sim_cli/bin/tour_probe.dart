import 'package:simulation_core/simulation_core.dart';

/// Tour economics by artist size (docs K63, K76): a US + Europe + UK tour
/// at each venue size, standard price and production.
void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2015;
  final w = WorldGen.create(seed: 3, startYear: year);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(year)) {
    sim.step();
  }
  String m(double c) => '\$${(c / 100 / 1e6).toStringAsFixed(2)}M';
  for (final tier in StartTier.values) {
    final a = WorldGen.addPlayer(w,
        name: 'P$tier', genre: 0, tier: tier, money: StartMoney.millionaire);
    for (final kind in TourKind.values) {
      final legs = [
        TourLeg(TourMarket.usa, kind,
            (Tours.maxShows(TourMarket.usa, kind) * 0.6).round()),
        TourLeg(TourMarket.ukIreland, kind,
            (Tours.maxShows(TourMarket.ukIreland, kind) * 0.5).round()),
        TourLeg(TourMarket.europe, kind,
            (Tours.maxShows(TourMarket.europe, kind) * 0.4).round()),
      ];
      final t = Tours.plan(w, a, legs: legs);
      final (e, _) = Tours.estimate(w, a, t);
      if (args.length > 1 &&
          tier == StartTier.superstar &&
          kind == TourKind.arena) {
        printSchedule(w, a, t);
      }
      print('${tier.name.padRight(10)} fans ${(a.coreFans / 1e3).round()}K '
          '${kind.name.padRight(8)} ok ${a.coreFans >= kind.minFans ? 'y' : 'n'} '
          '${e.shows} shows ${t.weeks}w fill ${(e.fill * 100).round()}% '
          'sold out ${e.soldOut} tickets ${(e.tickets / 1e3).round()}K '
          'gross ${m(e.grossCents)} merch ${m(e.merchCents)} '
          'costs ${m(e.costCents)} net ${m(Tours.netFor(a, e))} '
          'fans +${(e.fans / 1e3).round()}K');
    }
  }
}

/// One planned tour night by night (run with `schedule`).
void printSchedule(World w, Artist a, Tour t) {
  final (_, each) = Tours.estimate(w, a, t);
  for (var i = 0; i < t.shows.length; i++) {
    final s = t.shows[i];
    print('  wk ${s.week - t.startWeek + 1} ${s.cityName.padRight(14)} '
        '${s.venue.padRight(28)} cap ${s.capacity} \$${s.priceCents ~/ 100} '
        'sold ${each[i].sold.round()}');
  }
}
