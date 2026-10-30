// What the radio tools do to a player's single (docs K265): the same
// single by a star, plain and with every radio tool, against the biggest
// rival's radio.
//
//   dart run tool/radio_power_probe.dart [startYear] [tier]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2014;
  final tier = args.length > 1
      ? StartTier.values.byName(args[1])
      : StartTier.superstar;
  for (final all in [false, true]) {
    final dir = Directory.systemTemp.createTempSync('rpow');
    final g = GameSession.start(
        SaveSlots(dir),
        CareerSetup(
            name: 'Probe',
            genre: 0,
            startYear: year,
            tier: tier,
            money: StartMoney.millionaire,
            premium: true,
            seed: 5),
        slotId: 'p');
    final w = g.world;
    final p = w.player!;
    p.creativeEnergy = 100;
    final id = g.writeSong(budget: BudgetTier.high).id;
    g.releaseSingle(id, radio: all ? g.maxRadioPush : RadioPush.none);
    if (all) g.cutRadioEdit(id);
    var top = 999, weeks1 = 0, radio = 0.0, rivalRadio = 0.0;
    var streams = 0.0, radioPts = 0.0, pts = 0.0, rivalStreams = 0.0;
    for (var k = 0; k < 12; k++) {
      if (all) {
        p.creativeEnergy = 100;
        for (final m in RadioMarket.values) {
          if (g.radioVisits.markets.any((x) => x.market == m && x.can)) {
            g.visitRadio(m);
          }
        }
      }
      g.advanceWeek();
      final s = w.songs[id];
      final rank = ([for (final x in w.activeSongIds) w.songs[x]]
            ..sort((a, b) => b.weekPtsUs.compareTo(a.weekPtsUs)))
          .indexWhere((x) => x.id == id);
      if (rank + 1 < top) top = rank + 1;
      if (rank == 0) weeks1++;
      radio += s.weekRadio;
      streams += s.weekStreams;
      radioPts += s.weekRadioPtsUs;
      pts += s.weekPtsUs;
      final rivals = [
        for (final x in w.activeSongIds)
          if (w.songs[x].primaryArtistId != p.id) w.songs[x]
      ];
      rivalRadio += rivals.map((x) => x.weekRadio).reduce((a, b) => a > b ? a : b);
      rivalStreams += rivals.map((x) => x.weekStreams).reduce((a, b) => a > b ? a : b);
    }
    String m(double x) => '${(x / 12 / 1e6).toStringAsFixed(1)}M';
    print('${all ? 'every radio tool' : 'no radio push  '}: US peak #$top, '
        '$weeks1 wk at #1; radio ${m(radio)}/wk (top rival ${m(rivalRadio)}),'
        ' radio ${(radioPts / pts * 100).round()}% of US points;'
        ' streams ${m(streams)}/wk (top rival ${m(rivalStreams)})');
    g.close();
    dir.deleteSync(recursive: true);
  }
}
