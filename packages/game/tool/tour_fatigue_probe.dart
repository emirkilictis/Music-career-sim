// Touring again and again (docs K249): the same US arena leg played back
// to back, then once more after a long break. Prints each tour's tickets,
// fill, money and fans, and the artist's energy at the end.
//
//   dart run tool/tour_fatigue_probe.dart [tier] [venue] [startYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final tier =
      args.isNotEmpty ? StartTier.values.byName(args[0]) : StartTier.superstar;
  final kind = args.length > 1 ? TourKind.values.byName(args[1]) : TourKind.arena;
  final year = args.length > 2 ? int.parse(args[2]) : 2016;
  final dir = Directory.systemTemp.createTempSync('fatigue');
  final g = GameSession.start(
      SaveSlots(dir),
      CareerSetup(
          name: 'Probe',
          genre: 0,
          startYear: year,
          tier: tier,
          money: StartMoney.millionaire,
          premium: true,
          seed: 7),
      slotId: 'p');
  final p = g.world.player!;
  final ids = <int>[];
  for (var i = 0; i < 10; i++) {
    p.creativeEnergy = 100;
    ids.add(g.writeSong(budget: BudgetTier.high).id);
  }
  g.releaseAlbum('Probe Album', ids, campaign: Campaign.standard);
  g.advanceWeeks(8, stop: SkipStop.never);
  void tour(String label) {
    // Booked as the planner's "fit" does: as many nights as fill up.
    final n = g.suggestTourShows(
        TourRequest(legs: [TourLeg(TourMarket.usa, kind, 1)]), TourMarket.usa);
    final req = TourRequest(legs: [TourLeg(TourMarket.usa, kind, n)]);
    final plan = g.tourPreview(req);
    g.startTour(req);
    final money = p.moneyCents, fans = p.coreFans;
    var minEnergy = 999.0;
    while (p.tour != null) {
      g.advanceWeek();
      if (p.creativeEnergy < minEnergy) minEnergy = p.creativeEnergy;
    }
    final t = g.world.pastTours.last;
    print('$label: mood ${plan.legs.single.mood.toStringAsFixed(2)}, '
        '${t.shows.length} nights, ${(t.tickets / 1e3).round()}K tickets '
        '(${(t.tickets / t.shows.fold(0, (a, s) => a + s.capacity) * 100).round()}% full), '
        'net \$${((p.moneyCents - money) / 1e8).toStringAsFixed(1)}M, '
        'fans +${((p.coreFans - fans) / 1e3).round()}K, '
        'energy low ${minEnergy.round()} end ${p.creativeEnergy.round()}');
  }

  tour('tour 1');
  tour('tour 2 (straight after)');
  tour('tour 3 (straight after)');
  g.advanceWeeks(130, stop: SkipStop.never);
  tour('tour 4 (2.5 years later)');
  g.close();
  dir.deleteSync(recursive: true);
}
