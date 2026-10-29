// Year-end album sales in the 2000s (docs K259): the world from 2000,
// the top five global albums each year with what they sold that year,
// and how a big album's weeks hold up.
//
//   dart run tool/yearend_probe.dart [fromYear] [toYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final from = args.isNotEmpty ? int.parse(args[0]) : 2001;
  final to = args.length > 1 ? int.parse(args[1]) : 2007;
  final dir = Directory.systemTemp.createTempSync('yearend');
  final g = GameSession.start(
      SaveSlots(dir),
      CareerSetup(
          name: 'Probe',
          genre: 0,
          startYear: from,
          tier: StartTier.unknown,
          money: StartMoney.basic,
          seed: 7),
      slotId: 'p');
  g.advanceWeeks((to - from + 1) * 52 + 1, stop: SkipStop.never);
  String m(double x) => '${(x / 1e6).toStringAsFixed(2)}M';
  for (var y = from; y <= to; y++) {
    final rows = g.yearEnd(Charts.globalAlbums, y, limit: 5);
    print('$y: ${rows.map((r) => '${m(r.points.toDouble())} (${r.weeksOn}w)').join('  ')}');
  }
  g.close();
  dir.deleteSync(recursive: true);
}
