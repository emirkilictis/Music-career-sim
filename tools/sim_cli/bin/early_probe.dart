import 'package:simulation_core/simulation_core.dart';

/// First songs of a free start (docs T13): quality and estimated grade of
/// the first 10 songs written alone on a low budget, and with a medium one.
void main() {
  for (final budget in [BudgetTier.low, BudgetTier.medium]) {
    final q = <double>[], g = <int>[];
    for (var seed = 1; seed <= 10; seed++) {
      final w = WorldGen.create(seed: seed, startYear: 2018);
      final p = WorldGen.addPlayer(w,
          name: 'P',
          genre: 0,
          tier: StartTier.unknown,
          money: StartMoney.millionaire);
      for (var i = 0; i < 10; i++) {
        p.creativeEnergy = 100;
        final s = Actions.writeSong(w, p, budget: budget);
        q.add(s.quality);
        g.add(s.estimatedGrade);
        w.week++;
        p.songsWrittenThisWeek = 0;
      }
    }
    q.sort();
    g.sort();
    String letter(int x) => x >= 90
        ? 'A+'
        : x >= 80
            ? 'A'
            : x >= 70
                ? 'B'
                : x >= 55
                    ? 'C'
                    : x >= 40
                        ? 'D'
                        : 'E';
    final counts = <String, int>{};
    for (final x in g) {
      counts[letter(x)] = (counts[letter(x)] ?? 0) + 1;
    }
    print(
        '${budget.name.padRight(6)} quality median ${q[q.length ~/ 2].round()} '
        'p10 ${q[q.length ~/ 10].round()} p90 ${q[q.length * 9 ~/ 10].round()} '
        'grades (new cut-offs) $counts');
  }
}
