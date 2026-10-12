import 'package:simulation_core/simulation_core.dart';

/// Digital-era single sales: per year, the best-selling song worldwide and
/// in North America, and the median weekly downloads of the US #1.
/// Usage: dart run bin/download_probe.dart [hitExponent lateExponent] [seed]
void main(List<String> args) {
  final d = SimConfig();
  final exp = args.isNotEmpty ? double.parse(args[0]) : d.downloadHitExponent;
  final late =
      args.length > 1 ? double.parse(args[1]) : d.downloadHitExponentLate;
  final seed = args.length > 2 ? int.parse(args[2]) : 42;
  const from = 2005, to = 2014;
  final w = WorldGen.create(
      seed: seed,
      startYear: from,
      config:
          SimConfig(downloadHitExponent: exp, downloadHitExponentLate: late));
  final sim = Simulator(w);
  final na = Region.northAmerica.index;
  for (var year = from; year <= to; year++) {
    final world = <int, double>{}, nam = <int, double>{};
    final top = <double>[];
    var market = 0.0;
    while (w.week < GameTime.firstWeekOf(year + 1)) {
      final r = sim.step();
      if (GameTime.yearOf(r.week) != year) continue;
      for (final id in w.activeSongIds) {
        final s = w.songs[id];
        world[id] = (world[id] ?? 0) + s.weekDownloads;
        nam[id] = (nam[id] ?? 0) + (s.weekRegion?[3 + na] ?? 0);
        market += s.weekDownloads;
      }
      final no1 = w.songs[r.charts[Charts.usSongs].first.entityId];
      top.add(no1.weekRegion?[3 + na] ?? 0);
    }
    double best(Map<int, double> m) =>
        m.values.fold(0.0, (a, b) => a > b ? a : b);
    top.sort();
    String c(double v) => '${(v / 1e6).toStringAsFixed(2)}M';
    print('$year  best song world ${c(best(world))}  NA ${c(best(nam))}'
        '  US#1 weekly NA dl median ${(top[top.length ~/ 2] / 1e3).toStringAsFixed(0)}K'
        '  simulated-songs market ${c(market)}');
  }
}
