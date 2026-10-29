// An old album track made a single years later (docs K247), next to a new
// song released as a single the same week.
//
//   dart run tool/old_single_probe.dart [startYear] [yearsLater]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2015;
  final later = args.length > 1 ? int.parse(args[1]) : 3;
  for (final seed in [3, 5, 9]) {
    final dir = Directory.systemTemp.createTempSync('old');
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
      ..performance = 85
      ..charisma = 85;
    List<int> write(int k) => [
          for (var i = 0; i < k; i++)
            (() {
              p.creativeEnergy = 100;
              p.burnoutUntilWeek = -1;
              return g.writeSong(budget: BudgetTier.high).id;
            })(),
        ];
    final album = write(10);
    g.releaseAlbum('Old', album, campaign: Campaign.standard);
    g.advanceWeeks(later * 52, stop: SkipStop.never);
    // The best of the old tracks against a fresh song of the same grade.
    album.sort((a, b) => w.songs[b].quality.compareTo(w.songs[a].quality));
    final old = w.songs[album[0]];
    final fresh = w.songs[write(1).first];
    String m(double x) => (x / 1e6).toStringAsFixed(1);
    final before = w.songWeekStreamsIn(old, ChartMarket.global);
    List<double> run(Song x) {
      g.releaseSingle(x.id, campaign: Campaign.standard);
      return [
        for (var wk = 0; wk < 16; wk++)
          (() {
            g.advanceWeek();
            return w.songWeekStreamsIn(x, ChartMarket.global);
          })(),
      ];
    }

    final ro = run(old), rf = run(fresh);
    String row(List<double> r) => '${[
          for (var i = 0; i < 16; i++)
            if (i < 6 || i % 5 == 0) m(r[i])
        ].join(' ')} = ${m(r.fold(0.0, (a, b) => a + b))}M';
    final o = row(ro), f = row(rf);
    print('seed $seed: old q${old.quality.round()} was ${m(before)}M/wk; '
        'as a single $o; '
        'new q${fresh.quality.round()} $f');
    g.close();
    dir.deleteSync(recursive: true);
  }
}
