import 'package:simulation_core/simulation_core.dart';
import 'package:test/test.dart';

void main() {
  group('from the 1950s (docs K289)', () {
    tearDown(() => GameTime.baseYear = GameTime.defaultBaseYear);

    test('a world before 1980 counts its weeks from 1940', () {
      final w = WorldGen.create(seed: 1955, startYear: 1955);
      expect(w.baseYear, GameTime.earlyBaseYear);
      expect(GameTime.baseYear, GameTime.earlyBaseYear);
      expect(w.week, greaterThan(0));
      expect(GameTime.yearOf(w.week), 1952);
      final sim = Simulator(w);
      while (GameTime.yearOf(w.week) < 1955) {
        sim.step();
      }
      expect(GameTime.weekOfYear(w.week), 1);
      // Later starts are as they were.
      final later = WorldGen.create(seed: 1, startYear: 2005);
      expect(later.baseYear, GameTime.defaultBaseYear);
      expect(GameTime.yearOf(later.week), 2002);
    });

    test('genres arrive in their years; the 1950s field is of its day', () {
      expect(genreExistsIn(1, 1978), isFalse); // hip-hop
      expect(genreExistsIn(1, 1979), isTrue);
      expect(genreExistsIn(3, 1953), isFalse); // rock
      expect(genreExistsIn(18, 1991), isFalse); // K-pop
      for (var g = 0; g < genreNames.length; g++) {
        expect(genreExistsIn(g, 2000), isTrue);
        // From 1990 the weights are as they always were.
        expect(genreAiWeight(g, 1995), genreAiWeights[g]);
      }
      final w = WorldGen.create(seed: 7, startYear: 1956);
      for (final a in w.artists) {
        expect(genreExistsIn(a.genre, 1953), isTrue,
            reason: '${a.name}: ${genreNames[a.genre]}');
      }
    });

    test('formats, fans and videos of the day', () {
      expect(EditionFormat.cd.availableIn(1982), isFalse);
      expect(EditionFormat.cd.availableIn(1983), isTrue);
      expect(EditionFormat.cassette.availableIn(1967), isFalse);
      expect(EditionFormat.vinyl.availableIn(1950), isTrue);
      expect(SingleFormat.cd.availableIn(1984), isFalse);
      expect(SingleFormat.vinyl.appeal(1960), 1.0);
      expect(Social.networkIn(1960), SocialNetwork.fanMail);
      expect(Social.networkIn(1999), SocialNetwork.forum);
      final c = SimConfig();
      expect(c.videoEraFactor(1965), lessThan(c.videoEraFactor(1990)));
    });

    test('the market from 1997 on is as it always was', () {
      final era = EraTable.usDefault();
      double singles(int y) =>
          era.forWeek(GameTime.firstWeekOf(y)).physicalSinglesWeekly;
      double albums(int y) =>
          era.forWeek(GameTime.firstWeekOf(y)).casualPurchaseRate;
      for (final y in [1997, 1998, 1999]) {
        expect(singles(y), singles(2000));
        expect(albums(y), albums(2000));
      }
      // Singles sold millions a week; the LP market grew from small.
      expect(singles(1965), greaterThan(3 * singles(2000)));
      expect(albums(1955), lessThan(albums(1975)));
      expect(albums(1975), lessThan(albums(1995)));
    });

    test('living legends arrive only in worlds that begin before 1980', () {
      final early = realArtists.where((a) => a.earlyOnly).toList();
      expect(early.length, greaterThan(50));
      expect(early.every((a) => a.debut < 1980), isTrue);
      final w = WorldGen.create(seed: 3, startYear: 2001, realNames: true);
      final names = {for (final a in w.artists) a.name};
      for (final a in early) {
        expect(names, isNot(contains(a.name)));
      }
    });
  });
}
