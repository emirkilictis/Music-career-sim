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
      var retiredChecked = 0;
      for (final a in w.artists) {
        final life = w.artistLifetimeStreams(a);
        if (life < 1e6) continue;
        var sum = 0.0;
        for (final s in w.songs) {
          if (s.primaryArtistId == a.id && s.releasedWeek >= 0) {
            sum += w.songLifetimeStreams(s);
          }
        }
        expect((sum - life).abs() / life, lessThan(1e-6), reason: a.name);
        checked++;
        if (a.isRetired) retiredChecked++;
      }
      expect(retiredChecked, greaterThan(0));
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

  group('mega debuts', megaDebutTests);
  group('album shape', albumShapeTests);

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

/// Mega debut scenarios (docs/game-design.md §5, §8.5, §10): with the right
/// moves a devoted superstar can sell millions in the streaming era; without
/// them the same artist cannot.
({Album album, double week2Pure}) _debut({
  required int year,
  required double devotion,
  required double hype,
  required List<int> variants,
}) {
  final w = WorldGen.create(seed: 77, startYear: year);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(year)) {
    sim.step();
  }
  final a = WorldGen.addPlayer(w,
      name: 'Star',
      genre: 0,
      tier: StartTier.superstar,
      money: StartMoney.millionaire);
  a.devotion = devotion;
  a.hype = hype;
  final songs = [
    for (var i = 0; i < 12; i++)
      Actions.writeSong(w, a, producerSkill: 90, aiMode: true).id,
  ];
  final album =
      Actions.releaseAlbum(w, a, 'Mega', songs, variantWeeks: variants);
  sim.step();
  sim.step();
  return (album: album, week2Pure: album.weekPure);
}

void megaDebutTests() {
  test('right moves in 2025: devoted fans + anticipation + variants → 3M+', () {
    final r = _debut(
        year: 2025,
        devotion: 1.0,
        hype: 0.8,
        variants: const [0, 0, 0, 0, 0, 0, 1, 2]);
    printOnFailure('first week pure: ${r.album.firstWeekPure}');
    expect(r.album.firstWeekPure, greaterThan(3e6));
    expect(r.album.debutPos, 1);
  });

  test('same superstar without devotion, hype or variants stays far lower', () {
    final r = _debut(year: 2025, devotion: 0.4, hype: 0, variants: const [0]);
    expect(r.album.firstWeekPure, lessThan(1.2e6));
  });

  test('staggered variants boost the second week', () {
    final launchAll = _debut(
        year: 2025, devotion: 0.9, hype: 0.5, variants: const [0, 0, 0, 0, 0]);
    final staggered = _debut(
        year: 2025, devotion: 0.9, hype: 0.5, variants: const [0, 0, 0, 1, 1]);
    expect(staggered.week2Pure, greaterThan(launchAll.week2Pure * 1.5));
    expect(
        staggered.album.firstWeekPure, lessThan(launchAll.album.firstWeekPure));
  });
}

/// Releases an album of [tracks] songs by a superstar whose skills set the
/// album quality, and returns weekly units for [weeks] weeks.
List<double> _albumRun(
    {required int tracks, required double skill, int weeks = 9}) {
  final w = WorldGen.create(seed: 77, startYear: 2024);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(2024)) {
    sim.step();
  }
  final a = WorldGen.addPlayer(w,
      name: 'Star',
      genre: 0,
      tier: StartTier.superstar,
      money: StartMoney.millionaire);
  a.skills.songwriting = skill;
  a.skills.vocals = skill;
  final songs = [
    for (var i = 0; i < tracks; i++)
      Actions.writeSong(w, a, producerSkill: skill, aiMode: true).id,
  ];
  final al = Actions.releaseAlbum(w, a, 'X', songs);
  return [
    for (var i = 0; i < weeks; i++) (sim..step()).world.albums[al.id].weekUnits,
  ];
}

void albumShapeTests() {
  test('good albums hold their sales better than weak ones', () {
    final good = _albumRun(tracks: 10, skill: 90);
    final weak = _albumRun(tracks: 10, skill: 25);
    expect(good.last / good.first, greaterThan(1.5 * weak.last / weak.first));
  });

  test('more tracks raise the debut with diminishing returns', () {
    final ten = _albumRun(tracks: 10, skill: 90, weeks: 1).first;
    final forty = _albumRun(tracks: 40, skill: 90, weeks: 1).first;
    expect(forty, greaterThan(1.15 * ten));
    expect(forty, lessThan(1.8 * ten));
  });
}
