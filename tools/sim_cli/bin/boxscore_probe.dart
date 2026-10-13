import 'package:simulation_core/simulation_core.dart';

/// Top-grossing tours per year (docs K77): rivals' tours as booked.
void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2015;
  final w = WorldGen.create(seed: 77, startYear: year, realNames: true);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(year + 3)) {
    sim.step();
  }
  for (var y = year; y < year + 3; y++) {
    final ranked = [...w.tourRecords]
      ..sort((a, b) => b.grossIn(y).compareTo(a.grossIn(y)));
    final n = ranked.where((r) => r.grossIn(y) > 0).length;
    print('$y: $n tours');
    for (final r in ranked.take(10)) {
      print('  ${w.artists[r.artistId].name.padRight(22)} '
          '${r.name.padRight(34)} \$${(r.grossIn(y) / 1e8).toStringAsFixed(1)}M '
          '(total \$${(r.grossCents / 1e8).toStringAsFixed(1)}M, '
          '${r.shows} shows, ${(r.tickets / 1e6).toStringAsFixed(2)}M tickets)');
    }
  }
}
