import 'package:simulation_core/simulation_core.dart';

/// Where real stars stand after the burn-in (docs K66): fame of a few
/// real superstars by year, and the top 10 artists by fame.
void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2022;
  final real = args.length < 2 || args[1] != 'fake';
  final w = WorldGen.create(seed: 7, startYear: year, realNames: real);
  final sim = Simulator(w);
  final no1 = <String, int>{};
  WeekResult? last;
  while (w.week < GameTime.firstWeekOf(year)) {
    last = sim.step();
    if (GameTime.yearOf(last.week) >= year - 4) {
      final top = last.charts[Charts.usSongs].firstOrNull;
      if (top != null) {
        final a = w.artists[w.songs[top.entityId].primaryArtistId];
        final k = '${a.name} (${GameTime.yearOf(a.debutWeek)})';
        no1[k] = (no1[k] ?? 0) + 1;
      }
    }
  }
  final weeks = no1.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  print(
      'US #1 weeks ${year - 4}–${year - 1}: ${weeks.take(12).map((e) => '${e.key} ${e.value}').join(', ')}');
  print('Last US top 10: ${last!.charts[Charts.usSongs].take(10).map((e) {
    final a = w.artists[w.songs[e.entityId].primaryArtistId];
    return '${a.name} (${GameTime.yearOf(a.debutWeek)})';
  }).join(', ')}');
  var fans = 0.0, cas = 0.0, top30 = 0.0;
  final alive = w.artists
      .where((a) => a.tier != ArtistTier.player && !a.isRetired)
      .toList()
    ..sort((x, y) => y.coreFans.compareTo(x.coreFans));
  for (final a in alive) {
    fans += a.coreFans;
    cas += a.casual;
  }
  for (final a in alive.take(30)) {
    top30 += a.coreFans;
  }
  print(
      'AI alive ${alive.length}: core fans ${(fans / 1e6).toStringAsFixed(1)}M, casual ${(cas / 1e6).toStringAsFixed(0)}M, top-30 fans ${(top30 / 1e6).toStringAsFixed(1)}M');
  final watch = [
    'Taylor Swift',
    'Drake',
    'Rihanna',
    'Ariana Grande',
    'Billie Eilish',
    'Olivia Rodrigo',
    'Bad Bunny',
    'The Weeknd',
    'Madonna',
    'Jay-Z',
    "Destiny's Child",
    'Shania Twain'
  ];
  for (final n in watch) {
    final a = w.artists.where((x) => x.name == n).firstOrNull;
    if (a == null) {
      print('$n: not in world');
      continue;
    }
    print('${n.padRight(16)} fame ${(a.fame * 100).round()}% fans '
        '${(a.coreFans / 1e6).toStringAsFixed(2)}M retired ${a.isRetired} '
        'debut ${GameTime.yearOf(a.debutWeek)}');
  }
  final top = w.artists.where((a) => !a.isRetired).toList()
    ..sort((x, y) => y.fame.compareTo(x.fame));
  print(
      'Top 10 by fame: ${top.take(10).map((a) => '${a.name} (${GameTime.yearOf(a.debutWeek)})').join(', ')}');
}
