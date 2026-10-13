import 'package:simulation_core/simulation_core.dart';

/// Distinct #1 albums and songs per year on the US charts, and the longest
/// run, for an AI-only world. Usage: dart run bin/no1_turnover_probe.dart [seed]
void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 42;
  final w = WorldGen.create(seed: seed, startYear: 2003);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(2003)) {
    sim.step();
  }
  for (var year = 2003; year <= 2024; year += 1) {
    final albums = <int, int>{}, songs = <int, int>{};
    final second = <double>[];
    while (w.week < GameTime.firstWeekOf(year + 1)) {
      final r = sim.step();
      final a = r.charts[Charts.usAlbums], s = r.charts[Charts.usSongs];
      if (a.isNotEmpty)
        albums[a.first.entityId] = (albums[a.first.entityId] ?? 0) + 1;
      if (s.isNotEmpty)
        songs[s.first.entityId] = (songs[s.first.entityId] ?? 0) + 1;
      if (a.length > 1) second.add(a.first.points);
    }
    second.sort();
    final med = second.isEmpty ? 0 : second[second.length ~/ 2];
    print(
        '$year  #1 albums ${albums.length} (longest ${albums.values.fold(0, (m, x) => x > m ? x : m)}w, '
        'median #1 week ${(med / 1e3).round()}K)  #1 songs ${songs.length} '
        '(longest ${songs.values.fold(0, (m, x) => x > m ? x : m)}w)');
  }
}
