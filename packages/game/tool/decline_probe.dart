// Weekly streams of a new artist's singles, week by week (docs K304):
// how each one falls, whether two fall the same, whether one drops to 0.
//
//   dart run tool/decline_probe.dart [startYear] [tier] [seed]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2024;
  final tier = args.length > 1 ? StartTier.values.byName(args[1]) : StartTier.unknown;
  final seed = args.length > 2 ? int.parse(args[2]) : 11;
  final dir = Directory.systemTemp.createTempSync('decline');
  final g = GameSession.start(
      SaveSlots(Directory('${dir.path}/s')),
      CareerSetup(
          name: 'New Kid',
          genre: 0,
          startYear: year,
          tier: tier,
          money: StartMoney.basic,
          premium: tier != StartTier.unknown,
          seed: seed),
      slotId: 'p');
  final w = g.world;
  final singles = <int>[];
  final last = <int, double>{};
  void week() {
    g.advanceWeek();
    final cells = <String>[];
    for (final id in singles) {
      final s = w.songs[id];
      final c = g.streamCounter(EntityKind.song, id).rows.single;
      final v = c.daily;
      final before = last[id];
      final pct = before == null || before == 0 ? '' : ((v / before - 1) * 100).toStringAsFixed(2);
      cells.add('${v.toStringAsFixed(0)}/d ${pct.padLeft(6)}% ${(c.changeShare*100).toStringAsFixed(2)} ${s.status.name[0]}');
      last[id] = v;
    }
    print('${GameTime.label(w.week).padRight(16)} ${cells.join(' | ')}');
  }

  for (var n = 0; n < 4; n++) {
    int? id;
    while (id == null) {
      try {
        id = g.writeSong(budget: BudgetTier.low).id;
      } on Object {
        week();
      }
    }
    for (final c in Campaign.values.reversed) {
      try {
        g.releaseSingle(id, campaign: c);
        singles.add(id);
        break;
      } on Object {
        continue;
      }
    }
    for (var i = 0; i < 10; i++) {
      week();
    }
  }
}
