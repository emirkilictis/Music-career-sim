// Where does a big single enter the US chart, and where does it peak
// (docs K217)? A star writes ten songs, picks the best, releases it with
// the biggest campaign and plays eight weeks.
//
//   dart run tool/debut_probe.dart [startYear] [tier]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2019;
  final tier =
      args.length > 1 ? StartTier.values.byName(args[1]) : StartTier.superstar;
  final us = Charts.all.indexWhere((c) => c.key == 'chart.us.songs');
  final dir = Directory.systemTemp.createTempSync('debut');
  final seeds =
      Platform.environment['PROBE_SEEDS']?.split(',').map(int.parse).toList() ??
          [11, 22, 33, 44, 55, 66];
  for (final seed in seeds) {
    final g = GameSession.start(
        SaveSlots(Directory('${dir.path}/$seed')),
        CareerSetup(
            name: 'Probe Star',
            genre: 0,
            startYear: year,
            tier: tier,
            money: StartMoney.millionaire,
            premium: true,
            seed: seed),
        slotId: 'p');
    final p = g.world.player!;
    p.moneyCents = 1 << 40;
    // A quiet half year first: fans wait for something new.
    g.advanceWeeks(26, stop: SkipStop.never);
    final ids = <int>[];
    for (var i = 0; i < 10; i++) {
      p.creativeEnergy = 100;
      ids.add(g.writeSong(budget: BudgetTier.high).id);
    }
    ids.sort((a, b) =>
        g.world.songs[b].quality.compareTo(g.world.songs[a].quality));
    final id = ids.first;
    // The biggest campaign the label allows.
    for (final c in Campaign.values.reversed) {
      try {
        g.releaseSingle(id, campaign: c);
        break;
      } on GameException {
        continue;
      }
    }
    final pos = <int>[];
    final streams = <String>[];
    for (var w = 0; w < 8; w++) {
      g.advanceWeek();
      final s = g.world.songs[id];
      pos.add(s.lastPosOn(us));
      streams.add((g.world.songWeekStreamsIn(s, ChartMarket.us) / 1e6)
          .toStringAsFixed(1));
    }
    // The rivals' #1s of the last two years: where they came in.
    final from = g.week - 104;
    final debuts = <int>[];
    for (final x in g.world.songs) {
      final st = x.statsOrNull(us);
      if (st == null || st.peak != 1 || x.primaryArtistId == p.id) continue;
      if (x.releasedWeek < from) continue;
      debuts.add(st.debutPos);
    }
    debuts.sort();
    final s = g.world.songs[id];
    print('   rival #1s debuted at $debuts');
    print('seed $seed fame ${(p.fame * 100).round()}% hype '
        '${p.hype.toStringAsFixed(2)} q ${s.quality.round()} '
        'pos $pos US M $streams');
    g.close();
  }
}
