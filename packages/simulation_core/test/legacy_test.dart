import 'package:simulation_core/simulation_core.dart';
import 'package:test/test.dart';

void main() {
  group('legacy (docs K288)', () {
    LegacyParts parts(
        {double units = 0, int top10 = 0, int wins = 0, double no1 = 0}) {
      final p = LegacyParts()
        ..units = units
        ..sales = units / 1e6
        ..top10 = top10
        ..hits = top10 * Legacy.perTop10
        ..awardWins = wins
        ..awards = wins * Legacy.perBigWin
        ..numberOnes = no1;
      return p;
    }

    test('titles follow the score, the rank and the hits', () {
      expect(Legacy.title(parts(units: 400e6), 3, 20), LegacyTitle.legend);
      expect(Legacy.title(parts(units: 200e6), 30, 20), LegacyTitle.icon);
      expect(Legacy.title(parts(units: 200e6), 80, 20), LegacyTitle.star);
      expect(Legacy.title(parts(units: 20e6, top10: 6), 200, 20),
          LegacyTitle.hitmaker);
      expect(Legacy.title(parts(units: 5e6, top10: 1), 400, 10),
          LegacyTitle.oneHitWonder);
      expect(Legacy.title(parts(units: 1e6, wins: 1), 400, 10),
          LegacyTitle.cultFavourite);
      expect(Legacy.title(parts(), 0, 2), LegacyTitle.rising);
      expect(Legacy.title(null, 0, 12), LegacyTitle.working);
    });

    test('the score adds up sales, hits, number ones, awards and years', () {
      final w = WorldGen.create(seed: 288, startYear: 2012);
      final sim = Simulator(w);
      for (var i = 0; i < 30; i++) {
        sim.step();
      }
      final all = Legacy.all(w);
      final ranking = Legacy.ranking(all);
      expect(ranking, isNotEmpty);
      for (var i = 1; i < ranking.length; i++) {
        expect(ranking[i].$2, lessThanOrEqualTo(ranking[i - 1].$2));
      }
      final (top, score) = ranking.first;
      final p = all[top]!;
      expect(score,
          closeTo(p.sales + p.hits + p.numberOnes + p.awards + p.longevity, 1e-9));
      expect(p.sales, closeTo(p.units / 1e6, 1e-9));
      expect(p.longevity, p.hitYears > 1 ? (p.hitYears - 1) * 5.0 : 0);
    });

    test('no Hall of Fame without a player; kept as it was saved', () {
      final w = WorldGen.create(seed: 289, startYear: 2012);
      final sim = Simulator(w);
      while (GameTime.weekOfYear(w.week) != HallOfFame.weekOfYear) {
        sim.step();
      }
      expect(HallOfFame.induct(w).$1, isEmpty);
      final h = [const HallOfFamer(3, 2020, 140.5), const HallOfFamer(9, 2021, 99)];
      final back = HallOfFame.decode(HallOfFame.encode(h));
      expect([for (final x in back) (x.artistId, x.year, x.score)],
          [(3, 2020, 140.5), (9, 2021, 99.0)]);
      expect(HallOfFame.decode(''), isEmpty);
    });
  });
}
