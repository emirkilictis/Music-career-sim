import 'package:simulation_core/simulation_core.dart';

/// Biggest US album weeks per year (AI only world): how many weeks above
/// 500K / 1M, and the top three. Usage: dart run bin/big_weeks_probe.dart [seed]
void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 42;
  final w = WorldGen.create(seed: seed, startYear: 2002);
  final sim = Simulator(w);
  // Burn-in years before the start are played but not counted.
  while (w.week < GameTime.firstWeekOf(2003)) {
    sim.step();
  }
  for (var year = 2003; year <= 2012; year++) {
    final weeks = <(double, String)>[];
    while (w.week < GameTime.firstWeekOf(year + 1)) {
      final r = sim.step();
      if (r.charts[Charts.usAlbums].isEmpty) continue;
      final top = r.charts[Charts.usAlbums].first;
      final al = w.albums[top.entityId];
      weeks.add((
        top.points,
        '${al.title} (${w.artists[al.artistId].name}, wk${top.weeksOn})'
      ));
    }
    weeks.sort((a, b) => b.$1.compareTo(a.$1));
    final over500 = weeks.where((x) => x.$1 > 5e5).length;
    final over1m = weeks.where((x) => x.$1 > 1e6).length;
    print(
        '$year  >500K: $over500  >1M: $over1m  top: ${weeks.take(3).map((x) => '${(x.$1 / 1e6).toStringAsFixed(2)}M ${x.$2}').join(' | ')}');
  }
}
