// Can a new artist chart (docs K282)? An unknown with the free start
// writes a few songs, puts out the best as a single with the campaign it
// can afford, then a second one, and plays on. Prints where the singles
// peak on each song chart and what #100 needs.
//
//   dart run tool/newcomer_probe.dart [startYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2019;
  final tier = args.length > 1 ? StartTier.values.byName(args[1]) : StartTier.unknown;
  final dir = Directory.systemTemp.createTempSync('newcomer');
  final seeds =
      Platform.environment['PROBE_SEEDS']?.split(',').map(int.parse).toList() ??
          [11, 22, 33, 44];
  final songCharts = [
    for (final c in Charts.all)
      if (Charts.mainSongCharts.contains(c.id)) c
  ];
  for (final seed in seeds) {
    final g = GameSession.start(
        SaveSlots(Directory('${dir.path}/$seed')),
        CareerSetup(
            name: 'New Kid',
            genre: 0,
            startYear: year,
            tier: tier,
            money: StartMoney.basic,
            seed: seed),
        slotId: 'p');
    final p = g.world.player!;
    final singles = <int>[];
    void writeSome(int n) {
      final ids = <int>[];
      for (var i = 0; i < n; i++) {
        try {
          ids.add(g.writeSong(budget: BudgetTier.low).id);
        } on Object {
          // no energy / money
        }
        g.advanceWeek();
      }
      ids.sort((a, b) =>
          g.world.songs[b].quality.compareTo(g.world.songs[a].quality));
      if (ids.isEmpty) return;
      for (final c in Campaign.values.reversed) {
        try {
          g.releaseSingle(ids.first, campaign: c);
          singles.add(ids.first);
          return;
        } on Object {
          continue;
        }
      }
    }

    final us = Charts.all.indexWhere((c) => c.key == 'chart.us.songs');
    var best = 0.0, bestRank = 99999, cut = 0.0;
    var newcomers = 0, chartWeeks = 0;
    final newVirals = <int>{};
    void watch(int weeks) {
      for (var i = 0; i < weeks; i++) {
        g.advanceWeek();
        final w = g.world;
        for (final e in w.charts[us]) {
          final a = w.artists[w.songs[e.entityId].primaryArtistId];
          if (a.id != p.id && a.fame < 0.15) newcomers++;
        }
        chartWeeks++;
        for (final id in w.activeSongIds) {
          final x = w.songs[id];
          final a = w.artists[x.primaryArtistId];
          if (a.id != p.id && x.viralBoost >= 0.02 &&
              w.week - x.releasedWeek < SimConfig.breakoutWeeks + 3 &&
              w.week - a.debutWeek < SimConfig.breakoutCareerWeeks) {
            newVirals.add(id);
          }
        }
        final mine = [for (final id in singles) w.songWeekStreamsIn(w.songs[id], ChartMarket.us)];
        if (mine.isEmpty) continue;
        if (Platform.environment['PROBE_VIRAL'] != null) {
          print('  w${w.week} ' + [for (final id in singles) '${w.songs[id].viralBoost.toStringAsFixed(3)}/${(w.songWeekStreamsIn(w.songs[id], ChartMarket.us) / 1e3).round()}k'].join(' '));
        }
        final m = mine.reduce((a, b) => a > b ? a : b);
        if (m <= best) continue;
        best = m;
        final ch = w.charts[us];
        cut = ch.isEmpty ? 0 : w.songWeekStreamsIn(w.songs[ch.last.entityId], ChartMarket.us);
        bestRank = 1 + [for (final id in w.activeSongIds) w.songWeekStreamsIn(w.songs[id], ChartMarket.us)].where((x) => x > m).length;
      }
    }
    writeSome(4);
    watch(8);
    writeSome(4);
    watch(14);
    final out = StringBuffer('rival newcomers on the US chart a week: ${(newcomers / chartWeeks).toStringAsFixed(1)}, viral songs of new artists a year: ${(newVirals.length / chartWeeks * 52).round()}\n'
        'best US week ${(best / 1e3).round()}k streams, rank by streams $bestRank, #100 has ${(cut / 1e3).round()}k\n'
        'seed $seed fame ${(p.fame * 100).toStringAsFixed(1)}% '
        'fans ${(p.coreFans + p.casual).round()} money \$${p.moneyCents ~/ 100}\n');
    for (final id in singles) {
      final s = g.world.songs[id];
      out.write('  "${s.title}" q${s.quality.round()} camp ${s.campaign} '
          'life streams ${(s.lifetimeStreams / 1e3).round()}k sales ${(s.lifetimeDownloads + s.lifetimePhysical).round()} peaks:');
      for (final c in songCharts) {
        final st = s.statsOrNull(c.id);
        out.write(' ${c.key.replaceAll('chart.', '')}=${st?.peak ?? '-'}');
      }
      out.write('\n');
    }
    print(out);
    g.close();
  }
}
