import 'package:simulation_core/simulation_core.dart';

/// How often a player's songs go viral in a first year, by start size
/// (docs T12): share of careers with at least one viral song, and the
/// money peak.
void main(List<String> args) {
  final seeds = args.isNotEmpty ? int.parse(args[0]) : 12;
  for (final tier in [StartTier.unknown, StartTier.localBuzz, StartTier.risingStar]) {
    var withViral = 0, virals = 0;
    final peaks = <double>[];
    for (var seed = 1; seed <= seeds; seed++) {
      final w = WorldGen.create(seed: seed, startYear: 2020);
      final sim = Simulator(w);
      while (w.week < GameTime.firstWeekOf(2020)) {
        sim.step();
      }
      final p = WorldGen.addPlayer(w,
          name: 'P', genre: 0, tier: tier, money: StartMoney.comfortable);
      final mine = <int>{};
      var any = false, peak = p.moneyCents / 100;
      for (var week = 0; week < 52; week++) {
        if (week % 5 == 0 && week < 45) {
          final s = Actions.writeSong(w, p, producerSkill: 40, aiMode: true);
          Actions.releaseSingle(w, p, s, campaign: Campaign.none);
          mine.add(s.id);
        }
        final r = sim.step();
        for (final id in r.viralSongs) {
          if (mine.contains(id)) {
            virals++;
            any = true;
          }
        }
        if (p.moneyCents / 100 > peak) peak = p.moneyCents / 100;
      }
      if (any) withViral++;
      peaks.add(peak);
    }
    peaks.sort();
    print('${tier.name.padRight(10)} careers with a viral: $withViral/$seeds, '
        'virals $virals, money peak median \$${(peaks[peaks.length ~/ 2] / 1e3).round()}K '
        'max \$${(peaks.last / 1e3).round()}K');
  }
}
