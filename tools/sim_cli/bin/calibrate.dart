import 'package:simulation_core/simulation_core.dart';

/// Calibration report: one line per year with the key real-world reference
/// numbers, plus mega/no-moves debut scenarios.
///
///   dart run bin/calibrate.dart --seed 42
void main(List<String> args) {
  final seed = args.length > 1 ? int.parse(args[1]) : 42;
  const start = 2005, years = 21;
  final w = WorldGen.create(seed: seed, startYear: start);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(start)) {
    sim.step();
  }
  String f(num v) => v >= 1e6
      ? '${(v / 1e6).toStringAsFixed(1)}M'
      : v >= 1e3
          ? '${(v / 1e3).toStringAsFixed(0)}K'
          : v.toStringAsFixed(0);
  double med(List<double> v) {
    if (v.isEmpty) return 0;
    final s = List.of(v)..sort();
    return s[s.length ~/ 2];
  }

  // Viral catalog revivals: song id → (start week, best US position since).
  final tracked = <int, (int, int)>{};
  final viralByYear = <int, List<String>>{};
  print(
      'year | US#1 str | UK#1 str | GL#1 str | US#1 alb | US#100 alb | max wks@#1 US/UK/GL | biggest US debut');
  for (var y = start; y < start + years; y++) {
    final usStr = <double>[], ukStr = <double>[], glStr = <double>[];
    final usAlb = <double>[], usAlbLast = <double>[];
    final runs = [<int, int>{}, <int, int>{}, <int, int>{}];
    var biggest = 0.0;
    while (GameTime.yearOf(w.week) == y) {
      final r = sim.step();
      for (final id in r.viralSongs) {
        final s = w.songs[id];
        final age = (r.week - s.releasedWeek) / GameTime.weeksPerYear;
        if (age >= 3 && !tracked.containsKey(id)) tracked[id] = (r.week, 0);
      }
      for (final e in tracked.entries.toList()) {
        final (startWeek, best) = e.value;
        final pos = w.songs[e.key].lastPosOn(Charts.usSongs);
        final nb = pos > 0 && (best == 0 || pos < best) ? pos : best;
        if (r.week - startWeek >= 15) {
          final s = w.songs[e.key];
          final age =
              ((startWeek - s.releasedWeek) / GameTime.weeksPerYear).round();
          (viralByYear[GameTime.yearOf(startWeek)] ??= []).add(nb == 0
              ? '-'
              : '#$nb${nb <= 10 ? ' "${s.title}" (${age}y old)' : ''}');
          tracked.remove(e.key);
        } else {
          tracked[e.key] = (startWeek, nb);
        }
      }
      for (final (i, ch, m, into) in [
        (0, Charts.usSongs, ChartMarket.us, usStr),
        (1, Charts.ukSongs, ChartMarket.uk, ukStr),
        (2, Charts.globalSongs, ChartMarket.global, glStr),
      ]) {
        final c = r.charts[ch];
        if (c.isEmpty) continue;
        final id = c.first.entityId;
        runs[i][id] = (runs[i][id] ?? 0) + 1;
        into.add(w.songWeekStreamsIn(w.songs[id], m));
      }
      final a = r.charts[Charts.usAlbums];
      if (a.isNotEmpty) {
        usAlb.add(a.first.points);
        usAlbLast.add(a.last.points);
      }
      for (final id in r.albumDebuts) {
        final v = w.albumFirstWeekIn(w.albums[id], ChartMarket.us);
        if (v > biggest) biggest = v;
      }
    }
    int maxRun(Map<int, int> m) => m.values.fold(0, (a, b) => a > b ? a : b);
    print(
        '$y | ${f(med(usStr)).padLeft(8)} | ${f(med(ukStr)).padLeft(8)} | ${f(med(glStr)).padLeft(8)} | '
        '${f(med(usAlb)).padLeft(8)} | ${f(med(usAlbLast)).padLeft(10)} | '
        '${maxRun(runs[0])}/${maxRun(runs[1])}/${maxRun(runs[2])} | ${f(biggest)}');
  }
  print(
      '\nViral catalog revivals (songs >=3 years old): count · reached US top 40 · top 10');
  for (final e in viralByYear.entries) {
    final v = e.value;
    final top40 = v
        .where(
            (x) => x != '-' && int.parse(x.substring(1).split(' ').first) <= 40)
        .length;
    final top10 = v.where((x) => x.contains('"')).toList();
    print(
        '${e.key}: ${v.length} · top 40: $top40 · top 10: ${top10.length} ${top10.take(3).join(', ')}');
  }
  print(
      'active songs ${w.activeSongIds.length} · active albums ${w.activeAlbumIds.length}');

  // Debut scenarios for a superstar player in 2025.
  for (final (label, devotion, hype, variants, campaign) in [
    ('no moves', 0.4, 0.0, [0], Campaign.standard),
    ('good moves', 0.7, 0.4, [0, 0, 0, 1], Campaign.intensive),
    ('max moves', 1.0, 0.8, [0, 0, 0, 0, 0, 0, 1, 2], Campaign.global),
  ]) {
    final x = WorldGen.create(seed: 77, startYear: 2025);
    final s = Simulator(x);
    while (x.week < GameTime.firstWeekOf(2025)) {
      s.step();
    }
    final p = WorldGen.addPlayer(x,
        name: 'Star',
        genre: 0,
        tier: StartTier.superstar,
        money: StartMoney.millionaire);
    p.devotion = devotion;
    p.hype = hype;
    final songs = [
      for (var i = 0; i < 12; i++)
        Actions.writeSong(x, p, producerSkill: 90, aiMode: true).id,
    ];
    final al = Actions.releaseAlbum(x, p, 'X', songs,
        variantWeeks: variants, campaign: campaign);
    s.step();
    print(
        '2025 superstar, $label: US ${f(x.albumFirstWeekIn(al, ChartMarket.us))} units / '
        '${f(x.albumFirstWeekIn(al, ChartMarket.us, pure: true))} pure · global ${f(al.firstWeekUnits)}');
  }
}
