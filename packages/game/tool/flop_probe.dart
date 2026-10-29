// Can an album flop after the first #1 (docs K245)? Plays a career that
// puts out an album a year (two singles before each), some of them good,
// some of them weak, and prints how each did: its era result, US peak,
// first week and first half year.
//
//   dart run tool/flop_probe.dart [tier] [startYear] [pattern]
//   pattern: g = good album, b = weak album, f = fast (6 months after the
//   last one), e.g. gbgfbg
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final tier =
      args.isNotEmpty ? StartTier.values.byName(args[0]) : StartTier.superstar;
  final year = args.length > 1 ? int.parse(args[1]) : 2016;
  final pattern = args.length > 2 ? args[2] : 'gbggbg';
  for (final seed in [3, 5, 9]) {
    final dir = Directory.systemTemp.createTempSync('flop');
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
    final usAlb = Charts.usAlbums;
    print('--- $tier $year seed $seed');
    var n = 0;
    final lines = <String>[];
    for (final c in pattern.split('')) {
      if (c == 'f') continue;
      final weak = c == 'b';
      // A middling record: written half spent (a quarter weaker).
      final middling = c == 'm';
      // An A record: every skill maxed.
      if (c == 'a') {
        p.skills
          ..songwriting = 100
          ..vocals = 100
          ..production = 100
          ..performance = 100
          ..charisma = 100;
      }
      final fast = n < pattern.length - 1 && pattern[n + 1 == pattern.length ? n : n + 1] == 'f';
      n++;
      List<int> write(int k) => [
            for (var i = 0; i < k; i++)
              (() {
                // A weak record: written spent, it comes out much weaker.
                p.creativeEnergy = weak
                    ? 0
                    : middling
                        ? 10
                        : 100;
                p.burnoutUntilWeek = -1;
                return g
                    .writeSong(
                        budget: weak ? BudgetTier.low : BudgetTier.high)
                    .id;
              })(),
          ];
      final songs = write(10);
      g.releaseSingle(songs[0], campaign: Campaign.standard);
      g.advanceWeeks(4, stop: SkipStop.never);
      g.releaseSingle(songs[1], campaign: Campaign.standard);
      g.advanceWeeks(4, stop: SkipStop.never);
      final score = p.eraOpen ? p.eraUnits / p.eraExpected : 0.0;
      g.releaseAlbum('Album $n', songs, campaign: Campaign.standard);
      // Opening this era closed the last one.
      if (n > 1) {
        lines[n - 2] +=
            '  era ${p.lastEraResult?.name} (${score.toStringAsFixed(2)})';
      }
      final al = w.albums.last;
      g.advanceWeeks(26, stop: SkipStop.never);
      final v = g.album(al.id);
      final q = [for (final id in songs) w.songs[id].quality]
        ..sort();
      final grade = q[q.length ~/ 2];
      g.advanceWeeks(fast ? 0 : 18, stop: SkipStop.never);
      lines.add('album $n ${weak ? 'WEAK' : middling ? 'mid ' : c == 'a' ? 'A   ' : 'good'} median q ${grade.toStringAsFixed(0)}'
          '  US peak ${al.peakOn(usAlb)}  wk1 ${(v.firstWeekUsUnits / 1e3).round()}K'
          '  26wk ${(v.lifetimeUnits.total / 1e6).toStringAsFixed(2)}M'
          '  fame ${(p.fame * 100).round()}%');
    }
    // The last era's result.
    g.advanceWeeks(30, stop: SkipStop.never);
    lines[lines.length - 1] += '  era ${p.lastEraResult?.name}';
    lines.forEach(print);
    g.close();
    dir.deleteSync(recursive: true);
  }
}
