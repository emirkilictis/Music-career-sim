import 'package:simulation_core/simulation_core.dart';
import 'package:test/test.dart';

World _run({required int seed, required int years, int start = 2010}) {
  final w = WorldGen.create(seed: seed, startYear: start);
  final sim = Simulator(w);
  final end = GameTime.firstWeekOf(start + years);
  while (w.week < end) {
    sim.step();
  }
  return w;
}

void main() {
  group('determinism', () {
    test('same seed produces bit-identical worlds', () {
      final a = _run(seed: 1234, years: 2);
      final b = _run(seed: 1234, years: 2);
      expect(worldHash(a), worldHash(b));
    });

    test('different seeds produce different worlds', () {
      final a = _run(seed: 1, years: 1);
      final b = _run(seed: 2, years: 1);
      expect(worldHash(a), isNot(worldHash(b)));
    });

    test('keyed random streams are reproducible and independent of order', () {
      final x =
          RandomStream.keyed(7, 100, 42, RngPurpose.weeklyNoise).nextDouble();
      RandomStream.keyed(7, 100, 41, RngPurpose.weeklyNoise).nextDouble();
      final y =
          RandomStream.keyed(7, 100, 42, RngPurpose.weeklyNoise).nextDouble();
      expect(x, y);
      expect(x, inInclusiveRange(0.0, 1.0));
    });
  });

  group('lazy catalog accrual', () {
    test(
        'artist lifetime streams equal the sum of their songs (active + dormant)',
        () {
      final w = _run(seed: 99, years: 4);
      var checked = 0;
      for (final a in w.artists) {
        if (a.lifetimeStreams < 1e6) continue;
        var sum = 0.0;
        for (final s in w.songs) {
          if (s.primaryArtistId == a.id && s.releasedWeek >= 0) {
            sum += w.songLifetimeStreams(s);
          }
        }
        expect(
            (sum - a.lifetimeStreams).abs() / a.lifetimeStreams, lessThan(1e-6),
            reason: a.name);
        checked++;
      }
      expect(checked, greaterThan(50));
      expect(w.artists.any((a) => a.dormantSongIds.isNotEmpty), isTrue);
    });

    test('active set stays bounded while history grows', () {
      final w = WorldGen.create(seed: 5, startYear: 2010);
      final sim = Simulator(w);
      final samples = <int>[];
      final end = GameTime.firstWeekOf(2030);
      while (w.week < end) {
        final r = sim.step();
        if (GameTime.weekOfYear(r.week) == 26) samples.add(r.activeSongs);
      }
      final early = samples.sublist(2, 6).reduce((x, y) => x + y) / 4;
      final late =
          samples.sublist(samples.length - 4).reduce((x, y) => x + y) / 4;
      expect(late / early, lessThan(1.4));
      expect(w.songs.length, greaterThan(10 * w.activeSongIds.length));
    });
  });

  group('songwriting', () {
    late World w;
    late Artist p;
    setUp(() {
      w = WorldGen.create(seed: 3, startYear: 2010);
      p = WorldGen.addPlayer(w,
          name: 'Test', genre: 0, money: StartMoney.millionaire);
    });

    test('quality is bounded and the team estimate is a grade', () {
      for (var i = 0; i < 3; i++) {
        final s = Actions.writeSong(w, p, budget: BudgetTier.high);
        expect(s.quality, inInclusiveRange(1, 100));
        expect(s.estimatedGrade, inInclusiveRange(1, 100));
        expect(s.status, SongStatus.vault);
      }
    });

    test('max three songs per week', () {
      for (var i = 0; i < 3; i++) {
        Actions.writeSong(w, p, budget: BudgetTier.low);
      }
      expect(() => Actions.writeSong(w, p, budget: BudgetTier.low),
          throwsA(isA<SongwritingException>()));
    });

    test('writing until energy is gone causes burnout', () {
      for (var week = 0; week < 3 && w.week >= p.burnoutUntilWeek; week++) {
        for (var i = 0; i < 3 && Actions.canWrite(w, p); i++) {
          Actions.writeSong(w, p, budget: BudgetTier.low);
        }
        w.week++;
      }
      expect(p.creativeEnergy, 0);
      expect(Actions.canWrite(w, p), isFalse);
    });

    test('famous producers refuse unknown artists', () {
      final star = w.collaborators.firstWhere((c) => c.minFame > 0.3);
      expect(() => Actions.writeSong(w, p, producer: star),
          throwsA(isA<SongwritingException>()));
    });
  });

  group('eras and anticipation', () {
    test('after a successful era anticipation builds up and never decays', () {
      final w = WorldGen.create(seed: 11, startYear: 2010);
      final a = WorldGen.addPlayer(w, name: 'Hiatus', genre: 0);
      a.eraOpen = true;
      a.eraUnits = 3e6;
      a.eraExpected = 1e6; // smash
      Eras.close(w, a);
      expect(a.lastEraResult, EraResult.smash);
      final sim = Simulator(w);
      final values = <double>[];
      for (var i = 0; i < 52 * 7; i++) {
        sim.step();
        values.add(a.anticipation);
      }
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThanOrEqualTo(values[i - 1]));
      }
      expect(values.last, closeTo(a.anticipationCap, a.anticipationCap * 0.01));
    });

    test('after a flop anticipation does not build', () {
      final w = WorldGen.create(seed: 12, startYear: 2010);
      final a = WorldGen.addPlayer(w, name: 'Flop', genre: 0);
      a.eraOpen = true;
      a.eraUnits = 1e5;
      a.eraExpected = 1e6;
      Eras.close(w, a);
      expect(a.lastEraResult, EraResult.flop);
      expect(a.flopSupport, 1.0);
      final sim = Simulator(w);
      for (var i = 0; i < 104; i++) {
        sim.step();
      }
      expect(a.anticipation, 0);
      expect(a.flopSupport, lessThan(0.1));
    });
  });
}
