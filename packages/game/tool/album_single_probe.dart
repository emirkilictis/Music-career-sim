// A single put out with its album (docs K251): the same song as a single
// six weeks before the album, the week of the album, and six weeks after,
// against staying an album track.
//
//   dart run tool/album_single_probe.dart [startYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2018;
  for (final seed in [3, 5]) {
    final out = <String>[];
    for (final when in ['before', 'with', 'after', 'never']) {
      final dir = Directory.systemTemp.createTempSync('albsingle');
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
      if (when == 'before') {
        g.releaseSingle(s.id, campaign: Campaign.standard);
        g.advanceWeeks(6, stop: SkipStop.never);
      }
      g.releaseAlbum('Album', ids, campaign: Campaign.standard);
      if (when == 'with') g.releaseSingle(s.id, campaign: Campaign.standard);
      final weeks = <double>[];
      for (var wk = 0; wk < 20; wk++) {
        if (when == 'after' && wk == 6) {
          g.releaseSingle(s.id, campaign: Campaign.standard);
        }
        g.advanceWeek();
        weeks.add(w.songWeekStreamsIn(s, ChartMarket.global));
      }
      String m(double x) => (x / 1e6).toStringAsFixed(1);
      out.add('$when: ${[for (final i in [0, 1, 2, 4, 6, 8, 12, 19]) m(weeks[i])].join(' ')}'
          ' = ${m(weeks.fold(0.0, (a, b) => a + b))}M, '
          'US peak #${s.statsOrNull(Charts.usSongs)?.peak ?? 0}');
      g.close();
      dir.deleteSync(recursive: true);
    }
    print('seed $seed (album weeks 0 1 2 4 6 8 12 19)\n  ${out.join('\n  ')}');
  }
}
