// Pre-released singles in their album's week (docs K286): a single out
// 4, 8 or 12 weeks before the album, its streams the week before the
// album and the album's first weeks, against a deep cut of the album.
//
//   dart run tool/pre_single_probe.dart [startYear] [tier]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2018;
  final tier = args.length > 1
      ? StartTier.values.byName(args[1])
      : StartTier.superstar;
  for (final seed in [3, 5]) {
    for (final gap in [4, 8, 12]) {
      final dir = Directory.systemTemp.createTempSync('presingle');
      final g = GameSession.start(
          SaveSlots(dir),
          CareerSetup(
              name: 'Probe',
              genre: 0,
              startYear: year,
              tier: tier,
              money: StartMoney.millionaire,
              premium: true,
              seed: seed),
          slotId: 'p');
      final w = g.world;
      final p = w.player!;
      p.skills
        ..songwriting = 85
        ..vocals = 85
        ..production = 85
        ..performance = 85;
      final ids = [
        for (var i = 0; i < 10; i++)
          (() {
            p.creativeEnergy = 100;
            p.burnoutUntilWeek = -1;
            return g.writeSong(budget: BudgetTier.high).id;
          })(),
      ];
      final s = w.songs[ids[0]];
      final cut = w.songs[ids[4]];
      g.releaseSingle(s.id, campaign: Campaign.standard);
      double before = 0;
      for (var i = 0; i < gap; i++) {
        g.advanceWeek();
        before = w.songWeekStreamsIn(s, ChartMarket.global);
      }
      final posBefore = s.statsOrNull(Charts.usSongs)?.lastPos ?? 0;
      g.releaseAlbum('Album', ids, campaign: Campaign.standard);
      final weeks = <double>[], cuts = <double>[], pos = <int>[];
      for (var wk = 0; wk < 8; wk++) {
        g.advanceWeek();
        weeks.add(w.songWeekStreamsIn(s, ChartMarket.global));
        cuts.add(w.songWeekStreamsIn(cut, ChartMarket.global));
        pos.add(s.statsOrNull(Charts.usSongs)?.lastPos ?? 0);
      }
      String m(double x) => (x / 1e6).toStringAsFixed(1);
      print('seed $seed gap $gap: before ${m(before)} (#$posBefore) -> '
          '${[for (final x in weeks) m(x)].join(' ')}  '
          'x${(weeks[0] / before).toStringAsFixed(2)}  '
          'US #${pos.join(' #')}  cut ${m(cuts[0])} ${m(cuts[2])}');
      g.close();
      dir.deleteSync(recursive: true);
    }
  }
}
