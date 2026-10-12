import 'package:simulation_core/simulation_core.dart';

/// Chart churn per year: distinct #1s and #1 debuts (US albums / songs).
void main(List<String> args) {
  final seed = args.isEmpty ? 42 : int.parse(args.first);
  final w = WorldGen.create(seed: seed, startYear: 2010);
  final sim = Simulator(w);
  final end = GameTime.firstWeekOf(2026);
  final albumNo1 = <int, Set<int>>{}, songNo1 = <int, Set<int>>{};
  final albumDebutNo1 = <int, int>{};
  while (w.week < end) {
    final r = sim.step();
    final y = GameTime.yearOf(r.week);
    if (y < 2010) continue;
    final a = r.charts[Charts.usAlbums], s = r.charts[Charts.usSongs];
    if (a.isNotEmpty) {
      (albumNo1[y] ??= {}).add(a.first.entityId);
      if (a.first.isDebut) albumDebutNo1[y] = (albumDebutNo1[y] ?? 0) + 1;
    }
    if (s.isNotEmpty) (songNo1[y] ??= {}).add(s.first.entityId);
  }
  print('year | US album #1s | debuting at #1 | US song #1s');
  for (final y in albumNo1.keys) {
    print('$y | ${albumNo1[y]!.length} | ${albumDebutNo1[y] ?? 0} | ${songNo1[y]!.length}');
  }
}
