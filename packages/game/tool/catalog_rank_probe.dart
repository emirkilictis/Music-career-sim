// A catalog over the years (docs K295): a star puts out thirty songs in two
// years, then nothing for ten. Each year, the yearly streams of the top
// songs and how much the order of the player's songs changed (Spearman's
// rank correlation with the year before: 1 means the same order).
//
//   dart run tool/catalog_rank_probe.dart [startYear] [years]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2016;
  final years = args.length > 1 ? int.parse(args[1]) : 10;
  final g = GameSession.start(
      SaveSlots(Directory.systemTemp.createTempSync('rank')),
      CareerSetup(
          name: 'Probe',
          genre: 0,
          startYear: year,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 21),
      slotId: 'p');
  final w = g.world;
  final p = w.player!;
  final mine = <int>[];
  for (var a = 0; a < 3; a++) {
    final ids = <int>[];
    for (var i = 0; i < 10; i++) {
      p.creativeEnergy = 100;
      p.burnoutUntilWeek = -1;
      ids.add(g.writeSong(budget: BudgetTier.high).id);
    }
    g.releaseSingle(ids[0], campaign: Campaign.standard);
    g.advanceWeeks(4, stop: SkipStop.never);
    g.releaseSingle(ids[1], campaign: Campaign.standard);
    g.advanceWeeks(4, stop: SkipStop.never);
    g.releaseAlbum('Album $a', ids, campaign: Campaign.standard);
    mine.addAll(ids);
    g.advanceWeeks(26, stop: SkipStop.never);
  }
  double life(int id) => w.songLifetimeStreams(w.songs[id]);
  var last = {for (final id in mine) id: life(id)};
  List<int>? prevOrder;
  final stability = <double>[];
  var top5Moves = 0;
  for (var y = 0; y < years; y++) {
    g.advanceWeeks(GameTime.weeksPerYear, stop: SkipStop.never);
    final now = {for (final id in mine) id: life(id)};
    final yearly = {for (final id in mine) id: now[id]! - last[id]!};
    last = now;
    final order = [...mine]..sort((a, b) => yearly[b]!.compareTo(yearly[a]!));
    var rho = double.nan;
    if (prevOrder != null) {
      final r0 = {for (var i = 0; i < prevOrder.length; i++) prevOrder[i]: i};
      var d2 = 0.0;
      for (var i = 0; i < order.length; i++) {
        final d = i - r0[order[i]]!;
        d2 += d * d;
      }
      final n = order.length;
      rho = 1 - 6 * d2 / (n * (n * n - 1));
      stability.add(rho);
    }
    if (prevOrder != null) {
      var moved = 0;
      for (var i = 0; i < 5; i++) {
        if (prevOrder[i] != order[i]) moved++;
      }
      top5Moves += moved;
    }
    prevOrder = order;
    String m(double x) => '${(x / 1e6).toStringAsFixed(0)}M';
    final total = yearly.values.fold(0.0, (a, b) => a + b);
    print('${GameTime.yearOf(w.week)}: total ${m(total)}, top 5 '
        '${[for (final id in order.take(5)) '${mine.indexOf(id)}:${m(yearly[id]!)}'].join(' ')}'
        '${rho.isNaN ? '' : '  rho ${rho.toStringAsFixed(2)}'}');
  }
  final mean = stability.fold(0.0, (a, b) => a + b) / stability.length;
  print('mean rank correlation ${mean.toStringAsFixed(2)}, '
      'top-5 places changed ${(top5Moves / (years - 1)).toStringAsFixed(1)} a year');
  g.close();
}
