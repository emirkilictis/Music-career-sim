// An old hit's daily plays against its total (docs K258): one big single,
// then years of nothing new, printed once a year. On Spotify an old hit
// plays about 0.03% of its total a day (The Hills 3.2B, 1.05M a day).
//
//   dart run tool/hit_tail_probe.dart [startYear] [years]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2015;
  final years = args.length > 1 ? int.parse(args[1]) : 10;
  for (final seed in [3, 5]) {
    final dir = Directory.systemTemp.createTempSync('tail');
    final g = GameSession.start(
        SaveSlots(dir),
        CareerSetup(
            name: 'Probe',
            genre: 0,
            startYear: year,
            tier: StartTier.superstar,
            money: StartMoney.millionaire,
            premium: true,
            seed: seed),
        slotId: 'p');
    final w = g.world;
    final p = w.player!;
    p.skills
      ..songwriting = 90
      ..vocals = 90
      ..production = 90
      ..performance = 90;
    p.creativeEnergy = 100;
    final id = g.writeSong(budget: BudgetTier.high).id;
    g.releaseSingle(id, campaign: Campaign.standard);
    final s = w.songs[id];
    final quarters = <String>[];
    for (var y = 0; y < years; y++) {
      for (var q = 0; q < 4; q++) {
        g.advanceWeeks(13, stop: SkipStop.never);
        quarters.add((w.songWeekStreamsIn(s, ChartMarket.global) / 7 / 1e3)
            .round()
            .toString());
      }
      final weekly = w.songWeekStreamsIn(s, ChartMarket.global);
      final total = w.songLifetimeStreams(s);
      print('seed $seed year ${y + 1}: ${(weekly / 7 / 1e3).round()}K a day, '
          'total ${(total / 1e9).toStringAsFixed(2)}B, '
          'daily/total ${(weekly / 7 / total * 1e4).toStringAsFixed(2)} per 10k '
          '(${s.status.name}, peak #${s.statsOrNull(Charts.usSongs)?.peak ?? 0})');
    }
    print('  each quarter, K a day: ${quarters.join(' ')}');
    g.close();
    dir.deleteSync(recursive: true);
  }
}
