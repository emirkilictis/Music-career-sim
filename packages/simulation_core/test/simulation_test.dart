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

    test('no weekly limit: low creativity weakens songs (K46)', () {
      for (var i = 0; i < 4; i++) {
        Actions.writeSong(w, p, budget: BudgetTier.low);
      }
      expect(p.creativeEnergy, 20);
      expect(Actions.canWrite(w, p), isTrue);
      expect(Actions.creativityPenalty(100), 0);
      expect(Actions.creativityPenalty(50), 0);
      expect(Actions.creativityPenalty(40), closeTo(0.1, 1e-9));
      expect(Actions.creativityPenalty(20), closeTo(0.3, 1e-9));
      expect(Actions.creativityPenalty(0), closeTo(0.5, 1e-9));
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

    test('starting stats: premium gets a bigger pool and a higher cap', () {
      final free = StartingStats.auto(premium: false);
      final premium = StartingStats.auto(premium: true);
      // The free auto build is the calibrated default player.
      expect(
          [free.songwriting, free.vocals, free.production], [37.0, 35.0, 29.0]);
      expect(StartingStats.isValid(free, premium: false), isTrue);
      expect(StartingStats.isValid(premium, premium: true), isTrue);
      expect(StartingStats.isValid(premium, premium: false), isFalse);
      expect(premium.songwriting, greaterThan(free.songwriting));
      Skills one(double sw) => Skills(
          songwriting: sw,
          vocals: 25,
          production: 25,
          performance: 25,
          charisma: 25);
      expect(StartingStats.isValid(one(55), premium: false), isTrue);
      expect(StartingStats.isValid(one(61), premium: false), isFalse);
      expect(StartingStats.isValid(one(70), premium: true), isTrue);
      expect(StartingStats.isValid(one(71), premium: true), isFalse);
    });

    test('a song has 1–3 distinct genres; the primary comes first', () {
      final s = Actions.writeSong(w, p, budget: BudgetTier.low, genres: [6, 0]);
      expect(s.genre, 6);
      expect(s.genres, [6, 0]);
      for (final bad in [
        <int>[],
        [0, 0],
        [0, 1, 2, 3],
        [genreNames.length],
      ]) {
        expect(() => Actions.writeSong(w, p, aiMode: true, genres: bad),
            throwsA(isA<SongwritingException>()));
      }
      expect(Actions.writeSong(w, p, budget: BudgetTier.low).genres, [p.genre]);
    });

    test('genre tables cover every genre; AI genres follow the weights', () {
      expect(genreRegionAffinity.length, genreNames.length);
      expect(genreAiWeights.length, genreNames.length);
      final counts = List.filled(genreNames.length, 0);
      for (final a in w.artists) {
        if (a.tier != ArtistTier.player) counts[a.genre]++;
      }
      // Pop is far more common than classical among AI artists.
      expect(counts[0], greaterThan(5 * counts[20] + 10));
      // Some AI songs are crossovers.
      final sim = Simulator(w);
      for (var i = 0; i < 20; i++) {
        sim.step();
      }
      expect(w.songs.any((s) => s.extraGenres.isNotEmpty), isTrue);
    });

    test('famous producers refuse unknown artists', () {
      final star = w.collaborators.firstWhere((c) => c.minFame > 0.3);
      expect(() => Actions.writeSong(w, p, producer: star),
          throwsA(isA<SongwritingException>()));
    });
  });

  group('campaigns', campaignTests);
  group('groups', groupTests);
  group('side income', sideIncomeTests);
  group('difficulty', difficultyTests);
  group('mega debuts', megaDebutTests);
  group('album shape', albumShapeTests);
  group('viral', viralTests);

  test('in 2015 every album collects its earlier streams (K44, K49)', () {
    final w = WorldGen.create(seed: 15, startYear: 2014);
    final sim = Simulator(w);
    while (w.week < GameTime.firstWeekOf(2015)) {
      sim.step();
    }
    // The most streamed album released before the streaming-unit era.
    final old = w.albums.where((al) => al.releaseWeek < w.week).toList()
      ..sort((x, y) => w
          .songLifetimeStreams(w.songs[y.songIds.first])
          .compareTo(w.songLifetimeStreams(w.songs[x.songIds.first])));
    final al = old.first;
    double units() => [
          for (var k = 0; k < regionCount; k++) al.reg[AlbumReg.lifeUnits + k]
        ].fold(0.0, (a, b) => a + b);
    var owed = 0.0;
    for (final id in al.songIds) {
      final s = w.songs[id];
      // Track sales were already counted week by week.
      owed += w.songLifetimeStreams(s) / w.config.streamEquivalentAlbum;
    }
    expect(owed, greaterThan(100));
    final before = units();
    sim.step();
    expect(units() - before, greaterThanOrEqualTo(owed * 0.999));
  });

  test('pre-released singles count in the total, not the album weeks (K56)',
      () {
    final w = WorldGen.create(seed: 56, startYear: 2018);
    final sim = Simulator(w);
    final a = WorldGen.addPlayer(w,
        name: 'Star',
        genre: 0,
        tier: StartTier.superstar,
        money: StartMoney.millionaire);
    final lead = Actions.writeSong(w, a, producerSkill: 90, aiMode: true);
    Actions.releaseSingle(w, a, lead);
    for (var i = 0; i < 6; i++) {
      sim.step();
    }
    final rest = [
      for (var i = 0; i < 9; i++)
        Actions.writeSong(w, a, producerSkill: 90, aiMode: true).id,
    ];
    final al = Actions.releaseAlbum(w, a, 'LP', [lead.id, ...rest]);
    // Its six weeks so far are credited at release.
    final owed = w.songLifetimeStreams(lead) / w.config.streamEquivalentAlbum +
        (w.songLifetimeDownloads(lead) + lead.lifetimePhysical) /
            w.config.trackEquivalentAlbum;
    expect(owed, greaterThan(1000));
    expect(al.preSingleUnits, closeTo(owed, owed * 1e-6));
    expect(al.lifetimeUnits, closeTo(owed, owed * 1e-6));
    sim.step();
    // The first week is the album's own; the lead single's week only grows
    // the lifetime total.
    final pre = al.preSingleUnits;
    expect(pre, greaterThan(owed));
    expect(al.firstWeekUnits, closeTo(al.weekUnits, 1e-6));
    expect(al.lifetimeUnits, closeTo(al.firstWeekUnits + pre, 1e-3 * pre));
  });

  test('the player\'s old songs fade, keeping what they earned (K58)', () {
    final w = WorldGen.create(seed: 58, startYear: 2016);
    final sim = Simulator(w);
    final a = WorldGen.addPlayer(w,
        name: 'Star',
        genre: 0,
        tier: StartTier.superstar,
        money: StartMoney.millionaire);
    final s = Actions.writeSong(w, a, producerSkill: 90, aiMode: true);
    Actions.releaseSingle(w, a, s);
    while (s.status != SongStatus.dormant) {
      sim.step();
    }
    final rate0 = s.dormantRate;
    var life = w.songLifetimeStreams(s);
    for (var i = 0; i < 2 * GameTime.weeksPerYear; i++) {
      sim.step();
      final now = w.songLifetimeStreams(s);
      // Settling never loses streams already counted.
      expect(now, greaterThanOrEqualTo(life));
      life = now;
    }
    // About 5% a year in its first decade.
    expect(s.dormantRate / rate0, closeTo(0.9, 0.02));
  });

  group('eras and anticipation', () {
    test('a CD-era smash does not make a later era look disappointing', () {
      final w = WorldGen.create(seed: 13, startYear: 2013);
      final a = WorldGen.addPlayer(w, name: 'Big', genre: 0);
      a.coreFans = 3e6;
      a.casual = 2e7;
      a.fame = 0.9;
      // 2006: 146M against a 50M expectation (a smash).
      a.eraOpen = true;
      a.eraUnits = 146e6;
      a.eraExpected = 50e6;
      Eras.close(w, a);
      expect(a.lastEraResult, EraResult.smash);
      // 2013: a new album; expectations follow today's market.
      final al = Album(
          id: w.albums.length,
          title: 'Next',
          artistId: a.id,
          type: AlbumType.album,
          releaseWeek: w.week,
          songIds: const [],
          quality: 80);
      w.albums.add(al);
      Eras.open(w, a, al);
      expect(a.eraExpected, lessThan(46e6));
      a.eraUnits = 46e6;
      Eras.close(w, a);
      expect(a.lastEraResult,
          anyOf(EraResult.success, EraResult.smash, EraResult.normal));
    });

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
({World world, Album album, double week2Pure}) _debut({
  required int year,
  required double devotion,
  required double hype,
  required List<int> variants,
  Difficulty difficulty = Difficulty.normal,
  Campaign campaign = Campaign.standard,
}) {
  final w = WorldGen.create(seed: 77, startYear: year, difficulty: difficulty);
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
  // Campaigns are priced for the audience (a superstar's global push ~\$1M).
  a.moneyCents += 100000000;
  final songs = [
    for (var i = 0; i < 12; i++)
      Actions.writeSong(w, a, producerSkill: 90, aiMode: true).id,
  ];
  final album = Actions.releaseAlbum(w, a, 'Mega', songs,
      variantWeeks: variants, campaign: campaign);
  sim.step();
  sim.step();
  return (world: w, album: album, week2Pure: album.weekPure);
}

void megaDebutTests() {
  test('right moves in 2025: devoted fans + anticipation + variants → 3M+', () {
    final r = _debut(
        year: 2025,
        devotion: 1.0,
        hype: 0.8,
        variants: const [0, 0, 0, 0, 0, 0, 1, 2]);
    final usPure =
        r.world.albumFirstWeekIn(r.album, ChartMarket.us, pure: true);
    printOnFailure('US first week pure: $usPure');
    // Reference: 2025 record debut ≈ 4.0M US units / 3.5M pure.
    expect(usPure, greaterThan(3e6));
    expect(r.album.statsOrNull(Charts.usAlbums)?.debutPos, 1);
    // Worldwide it sells more than in the US alone.
    expect(r.album.firstWeekPure, greaterThan(usPure * 1.3));
  });

  test('same superstar without devotion, hype or variants stays far lower', () {
    final r = _debut(year: 2025, devotion: 0.4, hype: 0, variants: const [0]);
    expect(r.world.albumFirstWeekIn(r.album, ChartMarket.us, pure: true),
        lessThan(1.2e6));
  });

  test('legend mode: a record week is reachable, realistic stays near 4M', () {
    const maxMoves = [0, 0, 0, 0, 0, 0, 1, 2];
    final legend = _debut(
        year: 2025,
        devotion: 1.0,
        hype: 0.8,
        variants: maxMoves,
        campaign: Campaign.global,
        difficulty: Difficulty.legend);
    final real = _debut(
        year: 2025,
        devotion: 1.0,
        hype: 0.8,
        variants: maxMoves,
        campaign: Campaign.global);
    final legendUs =
        legend.world.albumFirstWeekIn(legend.album, ChartMarket.us);
    final realUs = real.world.albumFirstWeekIn(real.album, ChartMarket.us);
    printOnFailure('legend $legendUs, realistic $realUs');
    // Same artist, same moves: Legend opens above the real record (~4M);
    // the 1.5–2× gap over a career comes from faster growth (docs K58).
    expect(legendUs, greaterThan(4.5e6));
    expect(legendUs, greaterThan(1.15 * realUs));
    expect(realUs, lessThan(4.8e6));
  });

  test('legend mode holds the AI back a little', () {
    final c = Difficulty.legend;
    expect(c.aiExposure, lessThan(1));
    expect(c.aiAlbumDemand, lessThan(1));
    expect(Difficulty.normal.aiExposure, 1);
    expect(Difficulty.normal.albumDemand, 1);
  });

  test('a devoted superstar goes #1 even without any moves', () {
    // An event album: a Taylor-level career sells big on name alone.
    final r = _debut(year: 2025, devotion: 0.9, hype: 0, variants: const [0]);
    expect(
        r.world.albumFirstWeekIn(r.album, ChartMarket.us), greaterThan(450e3));
    expect(r.album.statsOrNull(Charts.usAlbums)?.debutPos, 1);
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
    // About +25% for 4× the tracks (longer tracklist + streaming
    // equivalents of the extra tracks), never anything like 4×.
    print('40 vs 10 tracks: ${(forty / ten).toStringAsFixed(3)}');
    expect(forty / ten, inInclusiveRange(1.18, 1.35));
    expect(forty, lessThan(1.8 * ten));
  });
}

/// Short-video virality (docs/game-design.md §7.3): old catalog songs can go
/// viral and climb the charts in the short-video era, but not before it.
void viralTests() {
  test('old songs go viral and some climb the US chart in the short-video era',
      () {
    final w = WorldGen.create(seed: 42, startYear: 2016);
    final sim = Simulator(w);
    while (w.week < GameTime.firstWeekOf(2016)) {
      sim.step();
    }
    final revived = <int>{};
    var bestPos = 0;
    while (w.week < GameTime.firstWeekOf(2026)) {
      final r = sim.step();
      for (final id in r.viralSongs) {
        if (r.week - w.songs[id].releasedWeek >= 3 * GameTime.weeksPerYear) {
          revived.add(id);
        }
      }
      for (final id in revived) {
        final pos = w.songs[id].lastPosOn(Charts.usSongs);
        if (pos > 0 && (bestPos == 0 || pos < bestPos)) bestPos = pos;
      }
    }
    expect(revived.length, greaterThan(50));
    expect(bestPos, inInclusiveRange(1, 40));
  });

  test('viral strength is weak before short-video platforms', () {
    final c = SimConfig();
    expect(c.viralEraFactor(2008), lessThan(0.2));
    expect(c.viralEraFactor(2022), greaterThan(1.0));
  });
}

/// Free start, day job and rewarded ads (docs/game-design.md §20.1).
void sideIncomeTests() {
  late World w;
  late Artist p;
  late Simulator sim;
  setUp(() {
    w = WorldGen.create(seed: 21, startYear: 2010);
    sim = Simulator(w);
    while (w.week < GameTime.firstWeekOf(2010)) {
      sim.step();
    }
    p = WorldGen.addPlayer(w, name: 'Free', genre: 0);
  });

  test('the free start can pay for a few cheap songs, not a pricey one', () {
    expect(p.moneyCents, 500000);
    expect(() => Actions.writeSong(w, p, budget: BudgetTier.high),
        throwsA(isA<SongwritingException>()));
    Actions.writeSong(w, p, budget: BudgetTier.low);
  });

  test('the premium daily bonus adds money', () {
    final before = p.moneyCents;
    Actions.grantDailyBonus(w, p);
    expect(p.moneyCents - before, Actions.dailyBonusCents);
  });

  test('jobs pay and cost energy; resting restores it', () {
    final twin = WorldGen.create(seed: 21, startYear: 2010);
    final twinSim = Simulator(twin);
    while (twin.week < GameTime.firstWeekOf(2010)) {
      twinSim.step();
    }
    final q = WorldGen.addPlayer(twin, name: 'Free', genre: 0);
    p.moneyCents = q.moneyCents = 1000000;
    p.creativeEnergy = q.creativeEnergy = 40;
    Actions.setJob(w, p, Job.cafe);
    sim.step();
    twinSim.step();
    // An idle week restores energy; the job takes a little of it.
    expect(q.creativeEnergy, 40 + Actions.energyRegenIdle);
    expect(p.creativeEnergy, q.creativeEnergy - Job.cafe.energyCost);
    expect(p.moneyCents - q.moneyCents, Job.cafe.wageCents);

    // A writing week restores less.
    Actions.setJob(w, p, Job.none);
    p.creativeEnergy = 60;
    Actions.writeSong(w, p, budget: BudgetTier.low);
    sim.step();
    expect(p.creativeEnergy,
        60 - Actions.energyCostPerSong + Actions.energyRegenWriting);

    // Resting: no writing that week, extra energy at its end.
    p.creativeEnergy = 10;
    Actions.rest(w, p);
    expect(Actions.canWrite(w, p), isFalse);
    expect(() => Actions.writeSong(w, p, budget: BudgetTier.low),
        throwsA(isA<SongwritingException>()));
    sim.step();
    expect(p.creativeEnergy,
        10 + Actions.energyRegenIdle + Actions.energyRestBonus);
    expect(Actions.canWrite(w, p), isTrue);
    Actions.writeSong(w, p, budget: BudgetTier.low);
    expect(() => Actions.rest(w, p), throwsA(isA<ActionException>()));

    // A studio job teaches production on the side.
    final prod = p.skills.production;
    Actions.setJob(w, p, Job.studioAssistant);
    for (var i = 0; i < 4; i++) {
      sim.step();
    }
    expect(p.skills.production, greaterThan(prod));
  });

  test('catalog (dormant) songs keep paying the player', () {
    p.moneyCents = 10000000;
    final s = Actions.writeSong(w, p, budget: BudgetTier.high);
    Actions.releaseSingle(w, p, s, campaign: Campaign.none);
    for (var i = 0; i < 150 && s.status != SongStatus.dormant; i++) {
      sim.step();
    }
    expect(s.status, SongStatus.dormant);
    final m0 = p.moneyCents;
    sim.step();
    var streams = 0.0;
    for (var r = 0; r < regionCount; r++) {
      streams += w.songWeekStreamsRegion(s, r);
    }
    expect(streams, greaterThan(0));
    expect(p.moneyCents - m0, (streams * 0.35 * p.artistShare).round());
  });

  test('collaborators want fans: none at skill 45, more for better ones', () {
    Collaborator c(double skill) => Collaborator(
        id: 0,
        name: 'x',
        role: CollaboratorRole.producer,
        skill: skill,
        genre: 0,
        feeCents: 0,
        minFame: 1);
    expect(Actions.requiredFans(c(40)), 0);
    expect(Actions.requiredFans(c(45)), 0);
    expect(Actions.requiredFans(c(52)), 10000);
    expect(Actions.requiredFans(c(73)), 80000);
    expect(Actions.requiredFans(c(94)), inInclusiveRange(600000, 700000));
    p.coreFans = 25000;
    p.fame = 0;
    expect(Actions.collaboratorAvailable(c(60), p), isTrue);
    expect(Actions.collaboratorAvailable(c(70), p), isFalse);
    p.fame = 1;
    expect(Actions.collaboratorAvailable(c(99), p), isTrue);
  });

  test('ads are always available, at most three per week', () {
    for (var week = 0; week < 3; week++) {
      expect(Actions.adsLeftThisWeek(w, p), Actions.maxAdsPerWeek);
      for (var i = 0; i < Actions.maxAdsPerWeek; i++) {
        Actions.claimAdReward(w, p);
      }
      expect(
          () => Actions.claimAdReward(w, p), throwsA(isA<ActionException>()));
      sim.step();
    }
    expect(p.moneyCents, 500000 + 9 * Actions.adRewardCents);
  });
}

void difficultyTests() {
  test('normal ("realistic") is the calibrated balance', () {
    expect(Difficulty.normal.exposure, 1.0);
    expect(Difficulty.normal.fanConversion, 1.0);
    expect(Difficulty.normal.qualityBonus, 0);
    expect(WorldGen.create(seed: 1, startYear: 2010).difficulty,
        Difficulty.normal);
  });

  test('difficulty scales the player; only legend holds the AI back', () {
    final runs = {
      for (final d in Difficulty.values)
        d: () {
          final w = WorldGen.create(seed: 8, startYear: 2012, difficulty: d);
          final sim = Simulator(w);
          while (w.week < GameTime.firstWeekOf(2012)) {
            sim.step();
          }
          final p = WorldGen.addPlayer(w,
              name: 'D', genre: 0, money: StartMoney.millionaire);
          final song = Actions.writeSong(w, p, budget: BudgetTier.high);
          Actions.releaseSingle(w, p, song);
          for (var i = 0; i < 12; i++) {
            sim.step();
          }
          var aiFans = 0.0;
          for (final a in w.artists) {
            if (a.tier != ArtistTier.player) aiFans += a.coreFans;
          }
          return (fans: p.coreFans, aiFans: aiFans);
        }(),
    };
    final easy = runs[Difficulty.legend]!, normal = runs[Difficulty.normal]!;
    final hard = runs[Difficulty.hard]!;
    expect(easy.fans, greaterThan(normal.fans));
    expect(normal.fans, greaterThan(hard.fans));
    // Realistic and hard leave the AI alone (it only feels the player
    // through the shared market); legend holds it back a little.
    expect((normal.aiFans - hard.aiFans).abs() / normal.aiFans, lessThan(1e-3));
    expect(easy.aiFans, lessThan(normal.aiFans));
  });
}

/// Bands and vocal groups (docs/game-design.md §2.4).
void groupTests() {
  World fresh() => WorldGen.create(seed: 31, startYear: 2010);
  const four = ['Ava', 'Mia', 'Zoe', 'Lia'];

  test('a group needs 2–7 members, a solo artist none', () {
    expect(
        () => WorldGen.addPlayer(fresh(),
            name: 'G', genre: 0, kind: ArtistKind.vocalGroup, members: ['A']),
        throwsArgumentError);
    expect(
        () => WorldGen.addPlayer(fresh(),
            name: 'G',
            genre: 0,
            kind: ArtistKind.band,
            members: List.filled(8, 'X')),
        throwsArgumentError);
    expect(
        () => WorldGen.addPlayer(fresh(), name: 'S', genre: 0, members: four),
        throwsArgumentError);
    final g = WorldGen.addPlayer(fresh(),
        name: 'Girls', genre: 0, kind: ArtistKind.vocalGroup, members: four);
    expect(g.members, four);
    expect(g.kind.isGroup, isTrue);
  });

  test('auto stats suit the kind and stay within the rules', () {
    for (final kind in ArtistKind.values) {
      for (final premium in [false, true]) {
        final s = StartingStats.auto(premium: premium, kind: kind);
        expect(StartingStats.isValid(s, premium: premium), isTrue);
        final spent = s.songwriting +
            s.vocals +
            s.production +
            s.performance +
            s.charisma -
            5 * StartingStats.base;
        expect(spent, StartingStats.points(premium: premium));
      }
      final q = kind.qualityWeights;
      expect(q.writing + q.production + q.vocals + q.perf, closeTo(1, 1e-12));
    }
    final band = StartingStats.auto(premium: false, kind: ArtistKind.band);
    final group =
        StartingStats.auto(premium: false, kind: ArtistKind.vocalGroup);
    expect(band.production, greaterThan(group.production));
    expect(group.vocals, greaterThan(band.vocals));
  });

  test('the AI world has bands and vocal groups with members', () {
    final w = fresh();
    final bands = w.artists.where((a) => a.kind == ArtistKind.band).toList();
    final groups =
        w.artists.where((a) => a.kind == ArtistKind.vocalGroup).toList();
    expect(bands.length, greaterThan(15));
    expect(groups.length, greaterThan(10));
    for (final a in [...bands, ...groups]) {
      expect(a.members.length, inInclusiveRange(3, 7));
    }
    expect(
        w.artists
            .where((a) => a.kind == ArtistKind.solo)
            .every((a) => a.members.isEmpty),
        isTrue);
  });

  test('vocal groups build a devoted fandom faster', () {
    double gain(ArtistKind kind) {
      final a = WorldGen.addPlayer(fresh(),
          name: 'X',
          genre: 0,
          kind: kind,
          members: kind.isGroup ? four : const []);
      final before = a.devotion;
      a.eraOpen = true;
      a.eraUnits = 3e6;
      a.eraExpected = 1e6;
      Eras.close(WorldGen.create(seed: 31, startYear: 2010), a);
      return a.devotion - before;
    }

    expect(
        gain(ArtistKind.vocalGroup), greaterThan(1.3 * gain(ArtistKind.solo)));
  });
}

/// Campaign levels and the radio → playlist shift (docs/game-design.md §9).
void campaignTests() {
  ({World w, Simulator sim, Artist p}) setup(int year) {
    final w = WorldGen.create(seed: 51, startYear: year);
    final sim = Simulator(w);
    while (w.week < GameTime.firstWeekOf(year)) {
      sim.step();
    }
    final p = WorldGen.addPlayer(w,
        name: 'P',
        genre: 0,
        tier: StartTier.localBuzz,
        money: StartMoney.millionaire);
    return (w: w, sim: sim, p: p);
  }

  test('campaigns cost more for big audiences and tire listeners (K57)', () {
    final (:w, :sim, :p) = setup(2022);
    // (Another world: a career has one player.)
    final w2 = WorldGen.create(seed: 52, startYear: 2022);
    final star = WorldGen.addPlayer(w2,
        name: 'S',
        genre: 0,
        tier: StartTier.superstar,
        money: StartMoney.millionaire);
    // A newcomer pays the base price; a superstar several times it.
    expect(
        Actions.campaignCostFor(p, Campaign.global), Campaign.global.costCents);
    expect(Actions.campaignCostFor(star, Campaign.global),
        greaterThan(3 * Campaign.global.costCents));
    // Bigger labels pay more of it.
    Actions.signLabel(w2, star, Label.giant);
    expect(Actions.campaignCostFor(star, Campaign.global),
        lessThan(Actions.campaignCostFor(p, Campaign.global) * 3));

    p.moneyCents = 1 << 40;
    final a = Actions.writeSong(w, p, producerSkill: 80, aiMode: true);
    Actions.releaseSingle(w, p, a, campaign: Campaign.global);
    expect(a.campaignPower, 1);
    expect(a.campaignCostCents, Campaign.global.costCents);
    // Straight after it, the next push lands at half strength.
    final b = Actions.writeSong(w, p, producerSkill: 80, aiMode: true);
    Actions.releaseSingle(w, p, b, campaign: Campaign.global);
    expect(b.campaignPower, closeTo(0.5, 1e-9));
    expect(w.config.campaignExposure(Campaign.global, 2022, b.campaignPower),
        lessThan(w.config.campaignExposure(Campaign.global, 2022)));
    // Weeks later the audience has recovered most of the way, and the
    // campaign's income has been counted.
    for (var i = 0; i < 16; i++) {
      sim.step();
    }
    expect(Actions.campaignPowerFor(p), greaterThan(0.7));
    expect(a.campaignReturnCents, greaterThan(0));
  });

  test('standard is the calibrated baseline in every year', () {
    final c = SimConfig();
    for (var y = 1990; y <= 2030; y++) {
      expect(c.campaignExposure(Campaign.standard, y), 1.0);
      expect(c.campaignRadio(Campaign.standard, y), 1.0);
    }
  });

  test('promotion shifts from radio to playlists over the years', () {
    final c = SimConfig();
    double radioGain(int y) =>
        c.campaignRadio(Campaign.global, y) / c.campaignRadio(Campaign.none, y);
    double reachGain(int y) =>
        c.campaignExposure(Campaign.global, y) /
        c.campaignExposure(Campaign.none, y);
    expect(radioGain(2005), greaterThan(radioGain(2022)));
    expect(reachGain(2022), greaterThan(reachGain(2005)));
    expect(c.playlistShare(2005), lessThan(0.1));
    expect(c.playlistShare(2022), greaterThan(0.8));
  });

  test('the player pays for the campaign; no money, no release', () {
    final x = setup(2022);
    final s = Actions.writeSong(x.w, x.p, budget: BudgetTier.low);
    final before = x.p.moneyCents;
    Actions.releaseSingle(x.w, x.p, s, campaign: Campaign.intensive);
    expect(before - x.p.moneyCents, Campaign.intensive.costCents);
    expect(s.campaign, Campaign.intensive);

    final t = Actions.writeSong(x.w, x.p, budget: BudgetTier.low);
    x.p.moneyCents = Campaign.global.costCents - 1;
    expect(() => Actions.releaseSingle(x.w, x.p, t, campaign: Campaign.global),
        throwsA(isA<ActionException>()));
    expect(t.status, SongStatus.vault);
    expect(x.p.moneyCents, Campaign.global.costCents - 1);
  });

  test('a bigger campaign brings more listeners', () {
    double streams(Campaign k) {
      final x = setup(2022);
      final s = Actions.writeSong(x.w, x.p, producerSkill: 75, aiMode: true);
      Actions.releaseSingle(x.w, x.p, s, campaign: k);
      var total = 0.0;
      for (var i = 0; i < 8; i++) {
        x.sim.step();
        total += s.weekStreams;
      }
      return total;
    }

    expect(streams(Campaign.global), greaterThan(1.3 * streams(Campaign.none)));
  });

  test('editorial playlist adds happen in the playlist era, not before', () {
    int adds(int year) {
      final x = setup(year);
      x.p.moneyCents = 1 << 40;
      var n = 0;
      for (var i = 0; i < 60; i++) {
        final s = Actions.writeSong(x.w, x.p, producerSkill: 80, aiMode: true);
        Actions.releaseSingle(x.w, x.p, s, campaign: Campaign.global);
        if (s.playlistAdd != PlaylistAdd.none) {
          expect(s.playlistWeek, x.w.week);
          expect(s.playlistBoost, greaterThan(0));
          n++;
        }
      }
      return n;
    }

    final modern = adds(2022), old = adds(2005);
    expect(modern, greaterThan(15));
    expect(old, lessThan(modern ~/ 3));
  });

  test('the week result reports playlist adds', () {
    final x = setup(2022);
    x.p.moneyCents = 1 << 40;
    final added = <int>[];
    for (var i = 0; i < 30 && added.isEmpty; i++) {
      final s = Actions.writeSong(x.w, x.p, producerSkill: 85, aiMode: true);
      Actions.releaseSingle(x.w, x.p, s, campaign: Campaign.global);
      final r = x.sim.step();
      if (s.playlistAdd != PlaylistAdd.none) {
        expect(r.playlistAdds, contains(s.id));
        added.add(s.id);
      }
    }
    expect(added, isNotEmpty);
  });
}
