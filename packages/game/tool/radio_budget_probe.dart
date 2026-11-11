// The radio budget (docs K290): a superstar's single at each level, and an
// old single worked to the stations again years later.
//
//   dart run tool/radio_budget_probe.dart [startYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2008;
  GameSession start() => GameSession.start(
      SaveSlots(Directory.systemTemp.createTempSync('radio')),
      CareerSetup(
          name: 'Probe',
          genre: 0,
          startYear: year,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 9),
      slotId: 'p');
  String m(num x) => '${(x / 1e6).toStringAsFixed(1)}M';
  for (final level in [-1, 0, 25, 50]) {
    final g = start();
    final p = g.world.player!..creativeEnergy = 100;
    final id = g.writeSong(budget: BudgetTier.high).id;
    g.releaseSingle(id, campaign: Campaign.standard);
    if (level >= 0) g.setRadioLevel(id, level);
    var radio = 0.0;
    for (var i = 0; i < 8; i++) {
      g.advanceWeek();
      radio += g.world.songs[id].weekRadio;
    }
    final s = g.world.songs[id];
    print('level $level: 8 weeks radio ${m(radio)}, US #${s.statsOrNull(Charts.usSongs)?.peak ?? 0}, '
        'radio chart #${s.statsOrNull(Charts.usRadio)?.peak ?? 0}, '
        'cost/wk ${level > 0 ? RadioTools.levelWeeklyCents(p, level) ~/ 100 : 0}\$');
    if (level == 50) {
      while (s.status != SongStatus.dormant) {
        g.advanceWeeks(13, stop: SkipStop.never);
      }
      g.advanceWeeks(104, stop: SkipStop.never);
      final before = s.lifetimeRadio;
      g.setRadioLevel(id, 50);
      for (var i = 0; i < 8; i++) {
        g.advanceWeek();
      }
      print('  ${GameTime.yearOf(g.world.week)}, again at 50: 8 weeks radio '
          '${m(s.lifetimeRadio - before)}, radio chart now #${s.lastPosOn(Charts.usRadio)}, '
          'US #${s.lastPosOn(Charts.usSongs)}');
    }
    g.close();
  }
}
