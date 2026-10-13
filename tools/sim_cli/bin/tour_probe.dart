import 'package:simulation_core/simulation_core.dart';

/// Tour economics by artist size (docs K63): fill, gross, costs, net, fans.
void main() {
  final w = WorldGen.create(seed: 3, startYear: 2010);
  for (final tier in StartTier.values) {
    final a = WorldGen.addPlayer(w,
        name: '$tier', genre: 0, tier: tier, money: StartMoney.millionaire);
    for (final kind in TourKind.values) {
      final e = Tours.estimate(w, a, kind, [0, 1, 2]);
      String m(double c) => '\$${(c / 100 / 1e6).toStringAsFixed(2)}M';
      print('${tier.name.padRight(10)} fans ${(a.coreFans / 1e3).round()}K '
          '${kind.name.padRight(8)} ok ${Tours.canStart(a, kind)} '
          'fill ${(e.fill * 100).round()}% tickets ${(e.tickets / 1e3).round()}K '
          'gross ${m(e.grossCents)} costs ${m(e.costCents)} '
          'net ${m(e.grossCents * Tours.artistCut - e.costCents)} '
          'fans +${(e.fans / 1e3).round()}K');
    }
  }
}
