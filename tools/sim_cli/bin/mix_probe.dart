import 'package:simulation_core/simulation_core.dart';

/// Who the rivals are by home and genre, real vs made-up names (docs K70).
void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2010;
  for (final real in [true, false]) {
    final w = WorldGen.create(seed: 7, startYear: year, realNames: real);
    final sim = Simulator(w);
    final pos = [1, 10, 40, 100];
    final sum = List.filled(pos.length, 0.0);
    var weeks = 0;
    while (w.week < GameTime.firstWeekOf(year)) {
      final r = sim.step();
      if (GameTime.yearOf(r.week) < year - 2) continue;
      final ch = r.charts[Charts.usSongs];
      if (ch.length < 100) continue;
      weeks++;
      for (var i = 0; i < pos.length; i++) {
        sum[i] += ch[pos[i] - 1].points;
      }
    }
    final home = <String, double>{}, genre = <String, double>{};
    var total = 0.0, usAtt = 0.0;
    for (final a in w.artists) {
      if (a.isRetired || a.tier == ArtistTier.player) continue;
      final weight = a.coreFans + a.casual / 5;
      total += weight;
      usAtt += weight * a.regionShare[Region.northAmerica.index];
      home[a.homeCountry.name] = (home[a.homeCountry.name] ?? 0) + weight;
      genre[genreNames[a.genre]] = (genre[genreNames[a.genre]] ?? 0) + weight;
    }
    String top(Map<String, double> m) {
      final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return e
          .take(6)
          .map((x) => '${x.key} ${(100 * x.value / total).round()}%')
          .join(', ');
    }

    print('${real ? 'REAL' : 'FAKE'} audience ${(total / 1e6).round()}M, '
        'NA share ${(100 * usAtt / total).round()}%');
    print('  US song chart points (last 2 years) '
        '${[for (var i = 0; i < pos.length; i++) '#${pos[i]} ${(sum[i] / weeks / 1e3).toStringAsFixed(1)}K'].join(', ')}');
    print('  home: ${top(home)}');
    print('  genre: ${top(genre)}');
  }
}
