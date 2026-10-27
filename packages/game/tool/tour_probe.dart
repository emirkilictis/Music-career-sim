// What a tour does for the setlist and its album (docs K223): the same
// world twice, with and without a tour, compared week by week.
//
//   dart run tool/tour_probe.dart [startYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2019;
  final dir = Directory.systemTemp.createTempSync('tour');
  List<double> run(bool tour, String slot) {
    final g = GameSession.start(
        SaveSlots(Directory('${dir.path}/$slot')),
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
    for (var i = 0; i < 10; i++) {
      g.world.player!.creativeEnergy = 100;
      ids.add(g.writeSong(budget: BudgetTier.high).id);
    }
    g.releaseAlbum('Probe Album', ids, campaign: Campaign.standard);
    g.advanceWeeks(20, stop: SkipStop.never);
    final album = g.world.songs[ids.first].albumId;
    if (tour) {
      g.startTour(TourRequest(
          legs: [TourLeg(TourMarket.usa, TourKind.arena, 24)],
          setlist: ids.take(6).toList()));
    }
    final out = <double>[];
    for (var w = 0; w < 8; w++) {
      g.advanceWeek();
      final al = g.world.albums[album];
      final streams = ids
          .take(6)
          .fold(0.0, (t, id) => t + g.world.songs[id].weekStreams);
      out
        ..add(al.weekPure)
        ..add(streams);
    }
    g.close();
    return out;
  }

  final off = run(false, 'a'), on = run(true, 'b');
  for (var w = 0; w < 8; w++) {
    String pct(double a, double b) =>
        '${((b / a - 1) * 100).toStringAsFixed(0)}%';
    print('week ${w + 1}: album sales ${off[2 * w].round()} → '
        '${on[2 * w].round()} (${pct(off[2 * w], on[2 * w])}), set streams '
        '${(off[2 * w + 1] / 1e6).toStringAsFixed(1)}M → '
        '${(on[2 * w + 1] / 1e6).toStringAsFixed(1)}M '
        '(${pct(off[2 * w + 1], on[2 * w + 1])})');
  }
  dir.deleteSync(recursive: true);
}
