// An album's Streamify counter week by week once its songs are in the
// catalog (docs K224): each track should move on its own.
//
//   dart run tool/counter_probe.dart [startYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2019;
  final dir = Directory.systemTemp.createTempSync('counter');
  final g = GameSession.start(
      SaveSlots(dir),
      CareerSetup(
          name: 'Probe',
          genre: 0,
          startYear: year,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 7),
      slotId: 'p');
  final ids = <int>[];
  for (var i = 0; i < 8; i++) {
    g.world.player!.creativeEnergy = 100;
    ids.add(g.writeSong(budget: BudgetTier.high).id);
  }
  g.releaseAlbum('Probe Album', ids, campaign: Campaign.standard);
  g.advanceWeeks(60, stop: SkipStop.never);
  final album = g.world.songs[ids.first].albumId;
  for (var w = 0; w < 6; w++) {
    g.advanceWeek();
    final v = g.streamCounter(EntityKind.album, album);
    print([
      for (final r in v.rows)
        '${r.daily.round()} ${(r.changeShare * 100).toStringAsFixed(1)}%'
    ].join(' | '));
  }
  g.close();
  dir.deleteSync(recursive: true);
}
