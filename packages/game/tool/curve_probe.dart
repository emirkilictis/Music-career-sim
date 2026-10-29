// A song's weekly streams over its first year (docs K247): how fast a big
// single comes down from its debut and how much it keeps.
//
//   dart run tool/curve_probe.dart [tier] [startYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final tier =
      args.isNotEmpty ? StartTier.values.byName(args[0]) : StartTier.superstar;
  final year = args.length > 1 ? int.parse(args[1]) : 2018;
  for (final seed in [3, 5, 9]) {
    final dir = Directory.systemTemp.createTempSync('curve');
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
      ..performance = 85
      ..charisma = 85;
    final ids = [
      for (var i = 0; i < 3; i++)
        (() {
          p.creativeEnergy = 100;
          p.burnoutUntilWeek = -1;
          return g.writeSong(budget: BudgetTier.high).id;
        })(),
    ];
    final s = w.songs[ids[0]];
    g.releaseSingle(s.id, campaign: Campaign.standard);
    final out = <String>[];
    final first = <double>[];
    for (var wk = 0; wk < 104; wk++) {
      final dbg = wk < 14 && Platform.environment['PARTS'] != null;
      if (dbg) Simulator.debugParts = {};
      g.advanceWeek();
      if (dbg) {
        print('   $wk ${Simulator.debugParts!.map((k, v) => MapEntry(k, v < 10 ? v.toStringAsFixed(3) : (v / 1e3).toStringAsFixed(0)))}');
        Simulator.debugParts = null;
      }
      final v = w.songWeekStreamsIn(s, ChartMarket.global);
      first.add(v);
      if (wk < 12 || wk % 8 == 0 || wk == 103) {
        out.add('$wk:${(v / 1e6).toStringAsFixed(1)}'
            '${s.status == SongStatus.dormant ? 'd' : ''}');
      }
    }
    final peak = first.reduce((a, b) => a > b ? a : b);
    int when(double f) => first.indexWhere((v) => v < peak * f);
    print('seed $seed q${s.quality.round()} peak ${(peak / 1e6).toStringAsFixed(1)}M '
        '<50% wk ${when(0.5)} <33% wk ${when(0.33)} <10% wk ${when(0.1)}  '
        'year ${(first.take(52).fold(0.0, (a, b) => a + b) / 1e6).round()}M '
        'year2 ${(first.skip(52).fold(0.0, (a, b) => a + b) / 1e6).round()}M');
    print('  ${out.join(' ')}');
    g.close();
    dir.deleteSync(recursive: true);
  }
}
