// How a big album's weeks hold up (docs K264): for every album that sold
// 150K+ pure in its first week, each later week against week one
// (medians), in the year range given.
//
//   dart run tool/album_hold_probe.dart [startYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2002;
  for (final seed in [3, 7]) {
    final dir = Directory.systemTemp.createTempSync('hold');
    final g = GameSession.start(
        SaveSlots(dir),
        CareerSetup(
            name: 'Probe',
            genre: 0,
            startYear: year,
            tier: StartTier.unknown,
            money: StartMoney.basic,
            seed: seed),
        slotId: 'p');
    final w = g.world;
    final runs = <int, List<double>>{};
    final start = w.week;
    for (var wk = 0; wk < 110; wk++) {
      g.advanceWeek();
      for (final al in w.albums) {
        if (al.releaseWeek < start) continue;
        final age = w.week - 1 - al.releaseWeek;
        if (age < 0 || age > 52) continue;
        final r = runs.putIfAbsent(al.id, () => []);
        while (r.length < age) {
          r.add(0);
        }
        if (r.length == age) r.add(al.weekPure);
      }
    }
    final firsts = [for (final r in runs.values) r[0]]..sort();
    print("albums ${firsts.length}, top week ones ${firsts.reversed.take(8).map((x) => (x / 1000).round()).toList()}");
    final big = [
      for (final r in runs.values)
        if (r.length >= 53 && r[0] >= 150000) r
    ];
    double median(List<double> v) => (v..sort())[v.length ~/ 2];
    String pct(double x) => '${(x * 100).toStringAsFixed(0)}%';
    final weeks = [1, 2, 3, 4, 6, 8, 12, 16, 26, 39, 52];
    print('seed $seed, ${big.length} albums; week 1 median '
        '${(median([for (final r in big) r[0]]) / 1000).round()}K');
    print(weeks
        .map((k) => 'w${k + 1} ${pct(median([for (final r in big) r[k] / r[0]]))}')
        .join('  '));
    final yearTotal = median([
      for (final r in big) r.take(52).fold(0.0, (a, b) => a + b) / r[0]
    ]);
    print('first year / week one: ${yearTotal.toStringAsFixed(1)}x');
    g.close();
    dir.deleteSync(recursive: true);
  }
}
