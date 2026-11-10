// The legacy list and the Hall of Fame (docs K288): the all-time top and
// the Hall of Fame classes over years of a world, and how long the scores
// take to work out.
//
//   dart run tool/legacy_probe.dart [startYear] [years]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2005;
  final years = args.length > 1 ? int.parse(args[1]) : 20;
  final dir = Directory.systemTemp.createTempSync('legacy');
  final g = GameSession.start(
      SaveSlots(dir),
      CareerSetup(
          name: 'Probe',
          genre: 0,
          startYear: year,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 7),
      slotId: 'p');
  final w = g.world;
  print('songs ${w.songs.length}, albums ${w.albums.length}, '
      'artists ${w.artists.length}');
  for (var y = 0; y < years; y++) {
    final r = g.advanceWeeks(GameTime.weeksPerYear, stop: SkipStop.never);
    final sw = Stopwatch()..start();
    final parts = Legacy.all(w);
    final ranking = Legacy.ranking(parts);
    final ms = sw.elapsedMilliseconds;
    final top = [
      for (final (id, s) in ranking.take(8))
        '${w.artists[id].name} ${s.round()}'
    ];
    final cut = ranking.length > 50 ? ranking[49].$2.round() : 0;
    print('${GameTime.yearOf(w.week)} (${ms}ms, ${ranking.length} ranked, '
        '#50 at $cut): ${top.join(', ')}');
    final hof = [
      for (final e in r.events)
        if (e is HallOfFameClass)
          '${e.year}: ${[for (final id in e.artistIds) '${w.artists[id].name} (${GameTime.yearOf(w.artists[id].debutWeek)})'].join(', ')}'
    ];
    if (hof.isNotEmpty) print('  Hall of Fame ${hof.join(' | ')}');
  }
  final v = g.legacy;
  print('player: ${v.score.round()} #${v.rank} ${v.title.name}');
  g.close();
  dir.deleteSync(recursive: true);
}
