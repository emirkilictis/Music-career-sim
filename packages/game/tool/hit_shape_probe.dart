// The shape of a hit's run across the whole world (docs K247): for every
// single that reached the US top 10, its streams each week against its
// best week (medians), and the world's streams a year.
//
//   dart run tool/hit_shape_probe.dart [startYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2017;
  for (final seed in [3, 7]) {
    final dir = Directory.systemTemp.createTempSync('shape');
    final g = GameSession.start(
        SaveSlots(dir),
        CareerSetup(
            name: 'Probe',
            genre: 0,
            startYear: year,
            tier: StartTier.unknown,
            money: StartMoney.millionaire,
            premium: true,
            seed: seed),
        slotId: 'p');
    final w = g.world;
    final runs = <int, List<double>>{};
    final start = w.week;
    var total = 0.0, catalog = 0.0;
    for (var wk = 0; wk < 130; wk++) {
      g.advanceWeek();
      for (final s in w.songs) {
        if (!s.isSingle || s.singleWeek < start) continue;
        final age = w.week - s.singleWeek;
        if (age < 0 || age > 78) continue;
        final r = runs.putIfAbsent(s.id, () => []);
        while (r.length < age) {
          r.add(0);
        }
        if (r.length == age) r.add(w.songWeekStreamsIn(s, ChartMarket.global));
      }
      if (wk >= 26 && wk < 78) {
        for (final id in w.activeSongIds) {
          total += w.songWeekStreamsIn(w.songs[id], ChartMarket.global);
        }
        if (wk % 4 == 0) {
          for (final s in w.songs) {
            if (s.status == SongStatus.dormant) {
              catalog += 4 * w.songWeekStreamsIn(s, ChartMarket.global);
            }
          }
        }
      }
    }
    final hits = [
      for (final e in runs.entries)
        if (e.value.length >= 79 &&
            (w.songs[e.key].statsOrNull(Charts.usSongs)?.peak ?? 999) <= 10)
          e.value
    ];
    double median(List<double> v) {
      v.sort();
      return v.isEmpty ? 0 : v[v.length ~/ 2];
    }

    final peaks = [for (final r in hits) r.reduce((a, b) => a > b ? a : b)];
    final out = <String>[];
    for (final k in [0, 1, 2, 4, 6, 8, 12, 16, 26, 39, 52, 78]) {
      out.add('$k:${(median([
                for (var i = 0; i < hits.length; i++) hits[i][k] / peaks[i]
              ]) * 100).round()}%');
    }
    int peakWeek(List<double> r) => r.indexOf(r.reduce((a, b) => a > b ? a : b));
    print('seed $seed: ${hits.length} top-10 singles, median peak '
        '${(median([...peaks]) / 1e6).toStringAsFixed(1)}M in week '
        '${median([for (final r in hits) peakWeek(r).toDouble()]).round()}, '
        'first year ${(median([for (final r in hits) r.take(52).fold(0.0, (a, b) => a + b)]) / 1e6).round()}M; '
        'active songs a year ${(total / 1e9).toStringAsFixed(1)}B, catalog '
        '${(catalog / 1e9).toStringAsFixed(1)}B');
    print('  ${out.join(' ')}');
    g.close();
    dir.deleteSync(recursive: true);
  }
}
