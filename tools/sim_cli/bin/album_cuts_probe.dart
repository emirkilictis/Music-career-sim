import 'package:simulation_core/simulation_core.dart';

/// Share of US Songs chart entries that are album cuts (not singles), and
/// how many distinct album cuts charted, per year.
/// Usage: dart run bin/album_cuts_probe.dart [seed]
void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 42;
  final w = WorldGen.create(seed: seed, startYear: 2003);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(2003)) {
    sim.step();
  }
  for (var year = 2003; year <= 2020; year++) {
    var entries = 0, cuts = 0, cutsTop40 = 0;
    final distinct = <int>{};
    while (w.week < GameTime.firstWeekOf(year + 1)) {
      final r = sim.step();
      for (final e in r.charts[Charts.usSongs]) {
        entries++;
        final s = w.songs[e.entityId];
        if (!s.isSingle) {
          cuts++;
          distinct.add(s.id);
          if (e.position <= 40) cutsTop40++;
        }
      }
    }
    print(
        '$year  album cuts ${(100 * cuts / entries).toStringAsFixed(1)}% of entries, '
        '${distinct.length} distinct, top-40 cut entries $cutsTop40');
  }
}
