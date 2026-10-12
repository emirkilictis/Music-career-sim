import 'package:simulation_core/simulation_core.dart';

/// 2025 superstar first weeks (US) for several setups, averaged over seeds
/// so album noise does not hide the level.
void main(List<String> args) {
  final difficulty =
      Difficulty.values.byName(args.isEmpty ? 'normal' : args[0]);
  final setups = [
    ('no moves (devotion 0.4)', 0.4, 0.0, const [0], Campaign.standard),
    ('no moves, devoted (0.9)', 0.9, 0.0, const [0], Campaign.standard),
    ('good moves', 0.7, 0.4, const [0, 0, 0, 1], Campaign.intensive),
    ('max moves', 1.0, 0.8, const [0, 0, 0, 0, 0, 0, 1, 2], Campaign.global),
  ];
  for (final (label, dev, hype, vars, camp) in setups) {
    final units = <double>[];
    for (final seed in [77, 78, 79]) {
      final x =
          WorldGen.create(seed: seed, startYear: 2025, difficulty: difficulty);
      final s = Simulator(x);
      while (x.week < GameTime.firstWeekOf(2025)) {
        s.step();
      }
      final p = WorldGen.addPlayer(x,
          name: 'Star',
          genre: 0,
          tier: StartTier.superstar,
          money: StartMoney.millionaire);
      p.devotion = dev;
      p.hype = hype;
      final songs = [
        for (var i = 0; i < 12; i++)
          Actions.writeSong(x, p, producerSkill: 90, aiMode: true).id,
      ];
      final al = Actions.releaseAlbum(x, p, 'X', songs,
          variantWeeks: vars, campaign: camp);
      s.step();
      units.add(x.albumFirstWeekIn(al, ChartMarket.us));
    }
    final avg = units.reduce((a, b) => a + b) / units.length;
    print('${difficulty.name} $label: US ${(avg / 1e3).round()}K units (seeds: '
        '${units.map((u) => '${(u / 1e3).round()}K').join(', ')})');
  }
}
