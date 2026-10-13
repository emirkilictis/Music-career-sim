import 'package:simulation_core/simulation_core.dart';

/// What each campaign earns the player back on one single (16 weeks), by
/// artist size, label and difficulty (docs F16): income above a release
/// with no campaign, against what the player paid.
void main(List<String> args) {
  final seeds = args.isNotEmpty ? int.parse(args[0]) : 4;
  final setups = [
    (StartTier.localBuzz, Label.independent),
    (StartTier.risingStar, Label.mid),
    (StartTier.superstar, Label.giant),
  ];
  for (final diff in [Difficulty.normal, Difficulty.legend]) {
    for (final year in [2005, 2022]) {
      for (final (tier, label) in setups) {
        final base = <Campaign, double>{};
        for (final k in Campaign.values) {
          final income = <double>[],
              paid = <double>[],
              fans = <double>[],
              est = <double>[];
          for (var seed = 1; seed <= seeds; seed++) {
            final w =
                WorldGen.create(seed: seed, startYear: year, difficulty: diff);
            final sim = Simulator(w);
            while (w.week < GameTime.firstWeekOf(year)) {
              sim.step();
            }
            final p = WorldGen.addPlayer(w,
                name: 'P', genre: 0, tier: tier, money: StartMoney.millionaire);
            Actions.signLabel(w, p, label);
            p.moneyCents = 1 << 40;
            final s = Actions.writeSong(w, p, producerSkill: 80, aiMode: true);
            final m0 = p.moneyCents, f0 = p.coreFans;
            Actions.releaseSingle(w, p, s, campaign: k);
            final cost = m0 - p.moneyCents;
            final m1 = p.moneyCents;
            for (var i = 0; i < 16; i++) {
              sim.step();
            }
            income.add((p.moneyCents - m1 - 16 * p.job.wageCents) / 100);
            paid.add(cost / 100);
            fans.add(p.coreFans - f0);
            est.add(s.campaignReturnCents / 100);
          }
          double med(List<double> v) => (v..sort())[v.length ~/ 2];
          base[k] = med(income);
          final gain = med(income) - base[Campaign.none]!;
          print('${diff.name.padRight(6)} $year ${tier.name.padRight(10)} '
              '${label.name.padRight(11)} ${k.name.padRight(9)} '
              'income \$${_c(med(income))} gain \$${_c(gain)} '
              'paid \$${_c(med(paid))} net \$${_c(gain - med(paid))} '
              'est \$${_c(med(est))} fans +${_c(med(fans))}');
        }
      }
    }
  }
}

String _c(double v) {
  final a = v.abs();
  final s = a >= 1e6
      ? '${(a / 1e6).toStringAsFixed(2)}M'
      : a >= 1e3
          ? '${(a / 1e3).toStringAsFixed(0)}K'
          : a.toStringAsFixed(0);
  return v < 0 ? '-$s' : s;
}
