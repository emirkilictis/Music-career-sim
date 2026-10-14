import 'package:simulation_core/simulation_core.dart';

/// How long albums last on the US album chart in the streaming era (SZA's
/// SOS: 200 weeks on the Billboard 200, never below #25). Runs a world from
/// [start] to [end] and prints the longest runs: weeks on the chart, the
/// longest unbroken stretch in the top 25, weeks in the top 10.
void main(List<String> args) {
  final start = args.isNotEmpty ? int.parse(args[0]) : 2012;
  final end = args.length > 1 ? int.parse(args[1]) : 2026;
  final w = WorldGen.create(seed: 7, startYear: start, realNames: true);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(start)) {
    sim.step();
  }
  final weeksOn = <int, int>{}, top10 = <int, int>{}, best25 = <int, int>{};
  final run25 = <int, int>{}, peak = <int, int>{};
  final catalogShare = <int, List<double>>{};
  final perArtist = <int, List<int>>{};
  while (w.week < GameTime.firstWeekOf(end)) {
    final chart = sim.step().charts[Charts.usAlbums];
    // Catalog: out over two years.
    final y = GameTime.yearOf(w.week);
    final old = chart
        .where((e) => w.week - w.albums[e.entityId].releaseWeek > 104)
        .length;
    (catalogShare[y] ??= []).add(old / chart.length);
    final by = <int, int>{};
    for (final e in chart) {
      final a = w.albums[e.entityId].artistId;
      by[a] = (by[a] ?? 0) + 1;
    }
    (perArtist[y] ??= []).add(by.values.fold(0, (m, v) => v > m ? v : m));
    final inTop25 = <int>{};
    for (final e in chart) {
      final id = e.entityId;
      weeksOn[id] = (weeksOn[id] ?? 0) + 1;
      if (e.position <= 10) top10[id] = (top10[id] ?? 0) + 1;
      if (e.position <= 25) inTop25.add(id);
      peak[id] =
          peak[id] == null || e.position < peak[id]! ? e.position : peak[id]!;
    }
    for (final id in {...run25.keys, ...inTop25}) {
      run25[id] = inTop25.contains(id) ? (run25[id] ?? 0) + 1 : 0;
      if (run25[id]! > (best25[id] ?? 0)) best25[id] = run25[id]!;
    }
  }
  String name(int id) {
    final al = w.albums[id];
    return '${w.artists[al.artistId].name} – ${al.title} '
        '(${GameTime.yearOf(al.releaseWeek)}, ${al.songIds.length} tr)';
  }

  final weeks = end - start;
  print('US albums chart (top ${Charts.all[Charts.usAlbums].size}), '
      '$start–$end ($weeks years), ${weeksOn.length} albums charted');
  print('\nMost weeks on the chart:');
  for (final id in (weeksOn.keys.toList()
        ..sort((a, b) => weeksOn[b]!.compareTo(weeksOn[a]!)))
      .take(12)) {
    final al = w.albums[id];
    final active =
        al.songIds.where((x) => w.songs[x].status == SongStatus.active);
    print('       tracks active ${active.length}/${al.songIds.length}, '
        'streams/wk ${[
      for (final x in al.songIds.take(5))
        (w.songs[x].weekStreams / 1e6).toStringAsFixed(1)
    ]}M, '
        'artist fame ${w.artists[al.artistId].fame.toStringAsFixed(2)} '
        'pop ${w.artists[al.artistId].popularity.toStringAsFixed(2)} '
        'dormant ${al.sumDormantRate.toStringAsExponential(1)} '
        'weights ${[
      for (final x in al.songIds) Lifecycle.catalogWeight(w.songs[x])
    ]} '
        'rates ${[
      for (final x in al.songIds.take(4))
        w.songs[x].dormantRate.toStringAsExponential(1)
    ]}');
    print('       last week: pure ${al.weekPure.round()} '
        'sea ${al.weekSea.round()} tea ${al.weekTea.round()} '
        'units ${al.weekUnits.round()}');
    print('  ${weeksOn[id]!.toString().padLeft(4)} wk  peak #${peak[id]}  '
        'top-25 run ${best25[id] ?? 0}  top-10 ${top10[id] ?? 0}  ${name(id)}');
  }
  final last = w.charts[Charts.usAlbums];
  print(
      '\n#1 ${last.first.points.round()} pts, #50 ${last[49].points.round()}, '
      '#100 ${last.last.points.round()}');
  print('\nLongest unbroken top-25 run:');
  for (final id in (best25.keys.toList()
        ..sort((a, b) => best25[b]!.compareTo(best25[a]!)))
      .take(8)) {
    print(
        '  ${best25[id]!.toString().padLeft(4)} wk  (on chart ${weeksOn[id]}, '
        'peak #${peak[id]})  ${name(id)}');
  }
  print('\nShare of the chart older than 2 years, and the most albums one '
      'artist has on it (yearly average):');
  for (final y in catalogShare.keys) {
    final c = catalogShare[y]!, m = perArtist[y]!;
    print(
        '  $y  catalog ${(c.reduce((a, b) => a + b) / c.length * 100).round()}%'
        '  one artist up to ${(m.reduce((a, b) => a + b) / m.length).toStringAsFixed(1)}');
  }
  {
    var cat = 0.0, act = 0.0;
    for (var r = 0; r < 3; r++) {
      cat += w.retiredDormantAttention[r];
    }
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      cat += a.sumDormantRate * a.catalogFactor;
    }
    for (final id in w.activeSongIds) {
      act += w.songs[id].lastAttention;
    }
    print(
        'catalog share of attention ${(cat / (cat + act) * 100).toStringAsFixed(1)}%');
  }
  print(
      'dormant songs ${w.dormantSongCount}, all songs ${w.songs.length}, retired artists ${w.artists.where((a) => a.isRetired).length}');
  final counts = [52, 104, 200];
  for (final c in counts) {
    print('albums with ${c}+ weeks on: '
        '${weeksOn.values.where((v) => v >= c).length}');
  }
}
