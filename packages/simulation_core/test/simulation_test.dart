import 'dart:math' as math;

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
  group('versions and editions', versionTests);
  group('streaming tools', streamingToolTests);
  group('viral', viralTests);
  group('audience limits (K105)', audienceLimitTests);
  group('record deals (K107)', recordDealTests);
  group('novice', noviceTests);

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

  test('old songs fade, the hits slowest, keeping what they earned (K58, K85)',
      () {
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
    // Its class's yearly fade (K85): a top-10 single loses 12% a year in
    // its first decade, other songs faster.
    final perYear = w.config.catalogFadePerYear(Lifecycle.catalogWeight(s), 1);
    expect(s.dormantRate / rate0, closeTo((1 - perYear) * (1 - perYear), 0.03));
    // Rivals' catalogs fade too, a forgotten album track fastest (45% a
    // year).
    final rival = w.songs.firstWhere((x) =>
        x.status == SongStatus.dormant &&
        x.primaryArtistId != a.id &&
        x.dormantRate > 1e5 &&
        Lifecycle.catalogWeight(x) < 0.5);
    final before = rival.dormantRate;
    for (var i = 0; i < GameTime.weeksPerYear; i++) {
      sim.step();
    }
    expect(rival.dormantRate / before, closeTo(0.55, 0.05));
  });

  test('a mixtape is free: streams, buzz, no sales, charts or era (K62)', () {
    final w = WorldGen.create(seed: 62, startYear: 2012);
    final sim = Simulator(w);
    while (w.week < GameTime.firstWeekOf(2012)) {
      sim.step();
    }
    final a = WorldGen.addPlayer(w,
        name: 'MC',
        genre: Actions.hipHopGenre,
        tier: StartTier.risingStar,
        money: StartMoney.millionaire);
    final songs = [
      for (var i = 0; i < 10; i++)
        Actions.writeSong(w, a, producerSkill: 80, aiMode: true).id,
    ];
    final buzz = a.buzz, casual = a.casual;
    final tape = Actions.releaseAlbum(w, a, 'Tape', songs,
        type: AlbumType.mixtape, campaign: Campaign.none);
    expect(a.buzz, greaterThan(buzz));
    expect(a.casual, greaterThan(casual));
    expect(a.eraOpen && a.eraAlbumId == tape.id, isFalse);
    for (var i = 0; i < 4; i++) {
      sim.step();
      expect(tape.weekPure, 0);
      expect(tape.statsOrNull(Charts.usAlbums), isNull);
    }
    final streams =
        songs.fold(0.0, (x, id) => x + w.songLifetimeStreams(w.songs[id]));
    final downloads =
        songs.fold(0.0, (x, id) => x + w.songLifetimeDownloads(w.songs[id]));
    expect(streams, greaterThan(0));
    expect(downloads, 0);
  });

  test('a tour sells tickets, pays, wins fans and ends (K63)', () {
    final w = WorldGen.create(seed: 63, startYear: 2010);
    final sim = Simulator(w);
    final a = WorldGen.addPlayer(w,
        name: 'Star',
        genre: 0,
        tier: StartTier.superstar,
        money: StartMoney.millionaire);
    expect(Tours.canStart(a, TourKind.arena), isTrue);
    a.coreFans = 2e4;
    expect(Tours.canStart(a, TourKind.arena), isFalse);
    expect(
        () => Tours.start(
            w,
            a,
            Tours.plan(w, a,
                legs: const [TourLeg(TourMarket.usa, TourKind.arena, 10)])),
        throwsStateError);
    a.coreFans = 5e6;
    final t = Tours.start(
        w,
        a,
        Tours.plan(w, a, legs: const [
          TourLeg(TourMarket.usa, TourKind.arena, 12),
          TourLeg(TourMarket.ukIreland, TourKind.arena, 6),
        ]));
    // Three a week, a new week for each leg.
    expect(t.shows.length, 18);
    expect(t.weeks, 4 + 2);
    expect(
        () => Tours.start(
            w,
            a,
            Tours.plan(w, a,
                legs: const [TourLeg(TourMarket.usa, TourKind.club, 3)])),
        throwsStateError);
    final money = a.moneyCents;
    Tour? done;
    var weeks = 0;
    while (done == null) {
      final r = sim.step();
      weeks++;
      done = r.tourFinished;
      if (done == null) expect(a.tour, isNotNull);
    }
    expect(weeks, t.weeks);
    expect(a.tour, isNull);
    expect(done.tickets, greaterThan(0));
    expect(done.fans, greaterThan(0));
    expect(done.shows.every((s) => s.played), isTrue);
    expect(done.merchCents, greaterThan(0));
    // A sold arena tour pays well beyond a few weeks of royalties.
    expect(a.moneyCents - money, greaterThan(done.netCents * 0.9));
  });

  test('festivals: slots, booking, a set, a bill (K77)', () {
    final w = WorldGen.create(seed: 77, startYear: 2015);
    final sim = Simulator(w);
    final a = WorldGen.addPlayer(w,
        name: 'Star',
        genre: 0,
        tier: StartTier.risingStar,
        money: StartMoney.millionaire);
    expect(Festivals.slotFor(a), FestivalSlot.subHeadliner);
    a.coreFans = 5e3;
    a.fame = 0;
    expect(Festivals.slotFor(a), isNull);
    expect(() => Festivals.book(w, a, 1), throwsStateError);
    a.coreFans = 4e6;
    expect(Festivals.slotFor(a), FestivalSlot.headliner);
    // A country festival books country acts only.
    final country = festivals.indexWhere((f) => f.name == 'Cactus Country Jam');
    expect(() => Festivals.book(w, a, country), throwsStateError);
    final greenhill = festivals.indexWhere((f) => f.name == 'Greenhill');
    final b = Festivals.book(w, a, greenhill);
    expect(b.week, greaterThan(w.week));
    expect(() => Festivals.book(w, a, greenhill), throwsStateError);
    // The bill: the player among the headliners.
    final bill = Festivals.lineup(w, greenhill, b.year);
    expect(bill[FestivalSlot.headliner], contains(a.id));
    expect(bill[FestivalSlot.headliner]!.length, 3);
    // The set pays and wins fans.
    final money = a.moneyCents;
    FestivalSet? set;
    while (set == null) {
      set = sim.step().festivalSet;
    }
    expect(w.week - 1, b.week);
    expect(
        set.feeCents,
        Festivals.feeCents(
            festivals[greenhill], FestivalSlot.headliner, b.year));
    expect(a.moneyCents, greaterThan(money));
    expect(set.fans, greaterThan(0));
    expect(set.listeners, greaterThan(set.fans));
    expect(w.festivalBookings, isEmpty);
    // Saved and read back.
    final again = FestivalBooking(3, 2016, FestivalSlot.mainStage);
    final back = FestivalBooking.decode(FestivalBooking.encode([again])).single;
    expect((back.festival, back.year, back.slot),
        (3, 2016, FestivalSlot.mainStage));
  });

  test('rivals tour after albums; the box office counts them (K77)', () {
    final w = WorldGen.create(seed: 77, startYear: 2006, realNames: true);
    final sim = Simulator(w);
    while (w.week < GameTime.firstWeekOf(2008)) {
      sim.step();
    }
    expect(w.tourRecords.length, greaterThan(20));
    final r = w.tourRecords.first;
    expect(r.shows, greaterThanOrEqualTo(3));
    expect(r.grossCents, greaterThan(0));
    // Money comes in over its weeks, inside the years it runs.
    final years = [
      for (var y = GameTime.yearOf(r.startWeek);
          y <= GameTime.yearOf(r.endWeek);
          y++)
        r.grossIn(y)
    ];
    expect(years.fold(0.0, (t, x) => t + x), closeTo(r.grossCents, 1));
    expect(TourRecord.decode(TourRecord.encode(w.tourRecords)).length,
        w.tourRecords.length);
  });

  test('tours: cities, venues, prices, support acts (K76)', () {
    final w = WorldGen.create(seed: 76, startYear: 2015);
    final a = WorldGen.addPlayer(w,
        name: 'Star',
        genre: 0,
        tier: StartTier.superstar,
        money: StartMoney.millionaire);
    final t = Tours.plan(w, a,
        legs: const [TourLeg(TourMarket.usa, TourKind.arena, 20)]);
    // Big cities get more nights; every night in a city is the same venue.
    int nights(String city) => t.shows.where((s) => s.cityName == city).length;
    expect(nights('New York'), greaterThan(nights('Seattle')));
    final ny = t.shows.where((s) => s.cityName == 'New York').toList();
    expect(ny.map((s) => s.venue).toSet().length, 1);
    expect(
        ny.first.capacity,
        inInclusiveRange(
            TourKind.arena.minCapacity, TourKind.arena.maxCapacity));
    // The same venue in the same world, every tour.
    final again = Tours.plan(w, a,
        legs: const [TourLeg(TourMarket.usa, TourKind.arena, 3)]);
    expect(again.shows.first.venue, ny.first.venue);
    expect(Tours.maxShows(TourMarket.canada, TourKind.stadium), 24);
    // Ticket prices follow the era.
    expect(Tours.priceFor(TourKind.arena, 2000, 1),
        lessThan(Tours.priceFor(TourKind.arena, 2024, 1)));
    // Dearer tickets sell fewer, mostly to casual fans; gross can rise.
    final cheap = Tours.marketDemand(w, a, TourMarket.usa, 0.7, null);
    final dear = Tours.marketDemand(w, a, TourMarket.usa, 1.8, null);
    expect(dear, lessThan(cheap));
    // A support act costs a fee and draws some of their own fans.
    final opener = Tours.openerCandidates(w, a).first;
    expect(opener.fame, lessThan(a.fame));
    expect(Tours.marketDemand(w, a, TourMarket.usa, 1, opener),
        greaterThan(Tours.marketDemand(w, a, TourMarket.usa, 1, null)));
    final withOpener = Tours.plan(w, a,
        legs: const [TourLeg(TourMarket.usa, TourKind.arena, 20)],
        openerId: opener.id);
    final (alone, _) = Tours.estimate(w, a, t);
    final (helped, _) = Tours.estimate(w, a, withOpener);
    expect(helped.openerCents,
        closeTo(20 * Tours.openerFeeCents(opener).toDouble(), 1));
    expect(alone.openerCents, 0);
    // A spectacle costs more and wins more fans.
    final big = Tours.plan(w, a,
        legs: const [TourLeg(TourMarket.usa, TourKind.arena, 20)],
        production: TourProduction.spectacle);
    final (show, _) = Tours.estimate(w, a, big);
    expect(show.productionCents, greaterThan(alone.productionCents));
    expect(show.fans, greaterThan(alone.fans));
    // Saved and read back, nights and all.
    final back = Tour.decode(Tour.encode(withOpener))!;
    expect(back.shows.length, withOpener.shows.length);
    expect(back.shows.first.venue, withOpener.shows.first.venue);
    expect(back.openerId, opener.id);
    // A tour saved before K76 is laid out when it next plays.
    final old = Tour.decode('{"k":2,"r":[0,1],"w":${w.week},"t":0,"g":0,'
        '"c":0,"f":0,"cut":0.7}')!;
    expect(old.legs.map((l) => l.market), [TourMarket.usa, TourMarket.europe]);
    a.tour = old;
    Tours.playWeek(w, a);
    expect(old.shows.length, 2 * 5 * Tours.showsPerWeek);
    expect(old.shows.where((s) => s.played).length, Tours.showsPerWeek);
  });

  test('streaming-era albums flood the song chart; radio counts (F25, F37)',
      () {
    final c = SimConfig();
    expect(c.songChartRadioDivisor, 450);
    final w = WorldGen.create(seed: 25, startYear: 2022, realNames: true);
    final sim = Simulator(w);
    while (w.week < GameTime.firstWeekOf(2022)) {
      sim.step();
    }
    final p = WorldGen.addPlayer(w,
        name: 'Probe Star',
        genre: 0,
        tier: StartTier.superstar,
        money: StartMoney.millionaire);
    for (final k in SkillKind.values) {
      p.skills[k] = 100;
    }
    Actions.signLabel(w, p, Label.giant);
    final ids = <int>[];
    for (var i = 0; i < 13; i++) {
      p.creativeEnergy = 100;
      ids.add(Actions.writeSong(w, p, budget: BudgetTier.high).id);
    }
    Actions.releaseAlbum(w, p, 'Probe', ids, campaign: Campaign.global);
    final chart = sim.step().charts[Charts.usSongs];
    final mine = [
      for (final e in chart)
        if (w.songs[e.entityId].primaryArtistId == p.id) e.position
    ];
    // Every track charts, several in the top 10.
    expect(mine.length, 13);
    expect(mine.where((x) => x <= 10).length, greaterThanOrEqualTo(3));
    // Radio is a real part of the top established hit's points (the
    // album's own tracks are a week old, with little radio yet).
    final top = w.songs[chart
        .firstWhere((e) => w.songs[e.entityId].primaryArtistId != p.id)
        .entityId];
    expect(top.weekRadioPtsUs / top.weekPtsUs, greaterThan(0.05));
  });

  test('a cheap home recording stops around a B (F35)', () {
    double mean(BudgetTier budget) {
      var sum = 0.0;
      for (var seed = 1; seed <= 6; seed++) {
        final w = WorldGen.create(seed: seed, startYear: 2018);
        final p = WorldGen.addPlayer(w,
            name: 'P',
            genre: 0,
            tier: StartTier.unknown,
            money: StartMoney.millionaire);
        for (final k in SkillKind.values) {
          p.skills[k] = Actions.maxSkill;
        }
        for (var i = 0; i < 5; i++) {
          p.creativeEnergy = 100;
          sum += Actions.writeSong(w, p, budget: budget).quality;
          w.week++;
        }
      }
      return sum / 30;
    }

    final low = mean(BudgetTier.low), high = mean(BudgetTier.high);
    expect(low, inInclusiveRange(70, 80)); // a B
    expect(mean(BudgetTier.medium), inInclusiveRange(80, 90)); // an A
    // A top studio: an A on average, the A+ (90) now and then (K81).
    expect(high, inInclusiveRange(84, 90));
    expect(high, greaterThan(mean(BudgetTier.medium)));
  });

  test('skill points stop at what the skills can use (F34)', () {
    final w = WorldGen.create(seed: 34, startYear: 2015);
    final p = WorldGen.addPlayer(w,
        name: 'P', genre: 0, tier: StartTier.unknown, money: StartMoney.basic);
    for (final k in SkillKind.values) {
      p.skills[k] = 95;
    }
    Actions.grantSkillPoints(p, 1000);
    expect(p.skillPoints, 25);
    // Many at once, never past 100.
    expect(Actions.spendSkillPoints(p, SkillKind.vocals, 10), 5);
    expect(p.skills[SkillKind.vocals], Actions.maxSkill);
    expect(p.skillPoints, 20);
    // Spread: always the lowest skill, until all are full.
    p.skills[SkillKind.charisma] = 90;
    Actions.grantSkillPoints(p, 1000);
    expect(p.skillPoints, 25); // 5 + 5 + 5 + 10 still to learn
    expect(Actions.spreadSkillPoints(p), 25);
    for (final k in SkillKind.values) {
      expect(p.skills[k], Actions.maxSkill);
    }
    // Nothing left to learn: no more points.
    Actions.grantSkillPoints(p, Actions.skillPointsPerWeek);
    expect(p.skillPoints, 0);
  });

  test('artists and collaborators never share a name (C6)', () {
    for (final real in [false, true]) {
      final w = WorldGen.create(seed: 6, startYear: 2015, realNames: real);
      final names = [
        for (final a in w.artists) a.name.toLowerCase(),
        for (final c in w.collaborators) c.name.toLowerCase(),
      ];
      expect(names.toSet().length, names.length);
      // Surnames vary: no surname is shared by more than a handful.
      final surnames = <String, int>{};
      for (final c in w.collaborators) {
        final last = c.name.split(' ').last;
        surnames[last] = (surnames[last] ?? 0) + 1;
      }
      expect(surnames.values.reduce((a, b) => a > b ? a : b),
          lessThanOrEqualTo(4));
    }
  });

  test('rivals carry real names in their own years, never twice (K66)', () {
    final w = WorldGen.create(seed: 66, startYear: 2008, realNames: true);
    final names = [for (final a in w.artists) a.name];
    expect(names.toSet().length, names.length);
    final real = {for (final r in realArtists) r.name};
    final topTier = [
      for (final a in w.artists)
        if (a.tier == ArtistTier.a) a.name
    ];
    // The top tier is all real stars active at the start.
    expect(topTier.every(real.contains), isTrue);
    final start = GameTime.yearOf(w.week);
    for (final a in w.artists) {
      final r = realArtists.where((x) => x.name == a.name).firstOrNull;
      if (r != null) expect(r.debut, lessThanOrEqualTo(start));
    }
    expect(names.contains('Taylor Swift'), isFalse);
    final sim = Simulator(w);
    while (GameTime.yearOf(w.week) <= 2007) {
      sim.step();
    }
    // She arrives as a newcomer in her breakthrough year (or just after).
    final taylor = w.artists.firstWhere((a) => a.name == 'Taylor Swift');
    expect(GameTime.yearOf(taylor.debutWeek), inInclusiveRange(2006, 2008));
    expect(taylor.genre, 4);
    final all = [for (final a in w.artists) a.name.toLowerCase()];
    expect(all.toSet().length, all.length);
    // A player with a real artist's name: the rival gets another name.
    final britney = w.artists.firstWhere((a) => a.name == 'Britney Spears');
    final p = WorldGen.addPlayer(w,
        name: 'Britney Spears',
        genre: 0,
        tier: StartTier.unknown,
        money: StartMoney.basic);
    expect(britney.name, isNot('Britney Spears'));
    expect(p.name, 'Britney Spears');
    // Made-up worlds stay made up.
    final fake = WorldGen.create(seed: 66, startYear: 2008);
    expect(fake.artists.where((a) => real.contains(a.name)), isEmpty);
  });

  test('real names keep the market size; a star push fades (K70)', () {
    (World, double) world(bool real) {
      final w = WorldGen.create(seed: 7, startYear: 2010, realNames: real);
      final sim = Simulator(w);
      while (w.week < GameTime.firstWeekOf(2010)) {
        sim.step();
      }
      var audience = 0.0;
      for (final a in w.artists) {
        if (a.isRetired || a.tier == ArtistTier.player) continue;
        audience += a.coreFans + a.casual / 5;
      }
      return (w, audience);
    }

    final (w, real) = world(true);
    final (_, fake) = world(false);
    // Real stars rise from the same market: no bigger crowd for the
    // player to compete with.
    expect(real / fake, inInclusiveRange(0.9, 1.1));
    // Their extra label reach is gone once they have had their years.
    var pushed = 0, faded = 0;
    for (final a in w.artists) {
      if (a.isRetired || realStar(a.name) < 2) continue;
      final years = (w.week - a.debutWeek) / GameTime.weeksPerYear;
      if (years >= w.config.realStarPushYears + 1) {
        faded++;
        expect(a.labelReach, lessThanOrEqualTo(1.1));
      } else if (a.labelReach > 1.1) {
        pushed++;
      }
    }
    expect(faded, greaterThan(0));
    expect(pushed, greaterThan(0));
    // Players become known faster than the calibrated rivals.
    expect(w.config.playerFameRate, greaterThan(w.config.fameRate));
    expect(Label.independent.reach, 0.85);
  });

  test('a manager books more and better, for a cut (K68)', () {
    int offers(Manager m) {
      final w = WorldGen.create(seed: 68, startYear: 2010);
      final sim = Simulator(w);
      final p = WorldGen.addPlayer(w,
          name: 'Star',
          genre: 0,
          tier: StartTier.superstar,
          money: StartMoney.millionaire);
      p.manager = m;
      var n = 0;
      for (var i = 0; i < 2 * GameTime.weeksPerYear; i++) {
        final r = sim.step();
        if (r.newOpportunity != null) {
          n++;
          // Answer at once so the next one can come.
          Opportunities.answer(w, p, r.newOpportunity!.lapse);
        }
      }
      return n;
    }

    expect(offers(Manager.star), greaterThan(offers(Manager.none)));
    expect(Manager.pro.net(1000), 850);
    // Better tour terms.
    final w = WorldGen.create(seed: 68, startYear: 2010);
    final p = WorldGen.addPlayer(w,
        name: 'Star',
        genre: 0,
        tier: StartTier.superstar,
        money: StartMoney.millionaire);
    final (e, _) = Tours.estimate(
        w,
        p,
        Tours.plan(w, p,
            legs: const [TourLeg(TourMarket.usa, TourKind.arena, 10)]));
    final alone = Tours.netFor(p, e);
    p.manager = Manager.star;
    expect(Tours.cutFor(p), closeTo(0.8, 1e-9));
    expect(Tours.netFor(p, e), isNot(alone));
  });

  group('opportunities (K59)', () {
    ({World w, Simulator sim, Artist p}) star() {
      final w = WorldGen.create(seed: 59, startYear: 2010);
      final sim = Simulator(w);
      final p = WorldGen.addPlayer(w,
          name: 'Star',
          genre: 0,
          tier: StartTier.superstar,
          money: StartMoney.millionaire);
      return (w: w, sim: sim, p: p);
    }

    test('brand deals: fit, tasks, half up front, rest on time (K102)', () {
      final (:w, :sim, :p) = star();
      while (w.week < GameTime.firstWeekOf(2010)) {
        sim.step();
      }
      p.opportunity = null;
      w.brandDeals.clear();
      // A superstar fits a luxury house, not a burger chain.
      final lux = Brands.all.indexWhere((b) => b.name == 'Maison Lumière');
      final burger = Brands.all.indexWhere((b) => b.name == 'Crunch King');
      expect(Brands.fit(Brands.all[lux], p),
          greaterThan(Brands.fit(Brands.all[burger], p)));
      p.opportunity = Opportunity(
          kind: OpportunityKind.brandDeal,
          week: w.week,
          brand: lux,
          feeCents: 10000000);
      final money = p.moneyCents, devotion = p.devotion;
      Opportunities.answer(w, p, OpportunityChoice.accept);
      expect(p.moneyCents - money, 5000000);
      expect(p.devotion, greaterThan(devotion));
      final deal = w.brandDeals.single;
      expect(deal.tasks.map((t) => t.$1),
          [DealTask.sponsoredPost, DealTask.adShoot, DealTask.launchEvent]);
      p.creativeEnergy = 100;
      expect(Brands.doTask(w, p, 0, 0), isNull);
      expect(w.social.feed.first.topic, FanTopic.postSponsored);
      expect(w.social.feed.first.brand, lux);
      expect(() => Brands.doTask(w, p, 0, 0), throwsA(isA<ActionException>()));
      expect(Brands.doTask(w, p, 0, 1), isNull);
      final done = Brands.doTask(w, p, 0, 2)!;
      expect(done.cents, 5000000);
      expect(deal.status, DealStatus.completed);
      expect(p.moneyCents - money, 10000000);

      // A deal left undone breaks after its first task's due week.
      final money2 = p.moneyCents;
      Brands.sign(w, p, burger, 2000000);
      final broken = <DealOutcome>[];
      for (var i = 0; i < 4; i++) {
        broken.addAll(sim.step().brandDealsBroken);
      }
      expect(broken.single.deal.brand, burger);
      expect(w.brandDeals.last.status, DealStatus.broken);
      expect(p.moneyCents, greaterThanOrEqualTo(money2 + 1000000 - 1));
      // Saved and loaded as is.
      final back = BrandDeal.decode(BrandDeal.encode(w.brandDeals));
      expect(back.map((d) => d.status), w.brandDeals.map((d) => d.status));
      expect(back.first.tasks.last.$3, deal.tasks.last.$3);
    });

    test('offers come up for a star, one at a time, and lapse', () {
      final (:w, :sim, :p) = star();
      final kinds = <OpportunityKind>{};
      var lapsed = 0;
      for (var i = 0; i < 2 * GameTime.weeksPerYear; i++) {
        final r = sim.step();
        if (r.newOpportunity case final o?) {
          kinds.add(o.kind);
          expect(p.opportunity, same(o));
        }
        if (r.lapsedOpportunity != null) lapsed++;
        // Never two at once: a new one only once the last is gone.
        if (r.newOpportunity != null && r.lapsedOpportunity == null) {
          expect(w.week - 1, r.week);
        }
      }
      printOnFailure('kinds $kinds');
      expect(kinds.length, greaterThanOrEqualTo(3));
      expect(lapsed, greaterThan(0));
    });

    test('answers pay, cost energy and move fans; choices are checked', () {
      final (:w, :sim, :p) = star();
      p.opportunity = Opportunity(
          kind: OpportunityKind.festival, week: w.week, feeCents: 5000000);
      expect(() => Opportunities.answer(w, p, OpportunityChoice.leanIn),
          throwsArgumentError);
      final money = p.moneyCents, fans = p.coreFans;
      final energy = p.creativeEnergy;
      final out = Opportunities.answer(w, p, OpportunityChoice.accept);
      expect(p.opportunity, isNull);
      expect(p.moneyCents - money, 5000000);
      expect(p.coreFans, greaterThan(fans));
      expect(p.creativeEnergy, lessThan(energy));
      expect(out.moneyCents, 5000000);

      // Declining does nothing.
      p.opportunity = Opportunity(
          kind: OpportunityKind.brandDeal, week: w.week, feeCents: 100);
      final m2 = p.moneyCents;
      Opportunities.answer(w, p, OpportunityChoice.decline);
      expect(p.moneyCents, m2);
    });

    test('award shows: nominations in November, winners in February (K91)', () {
      final (:w, :sim, :p) = star();
      AwardShow? nominated;
      while (GameTime.yearOf(w.week) < 2011 ||
          GameTime.weekOfYear(w.week) <= Awards.ceremonyWeekOfYear) {
        final r = sim.step();
        if (r.awardNominations?.year == 2011) nominated = r.awardNominations;
      }
      final show = Awards.showFor(w, 2011)!;
      expect(identical(show, nominated), isTrue);
      expect(show.held, isTrue);
      expect(show.races.map((r) => r.category),
          containsAll([AwardCategory.record, AwardCategory.song]));
      for (final race in show.races) {
        expect(race.nominees.length, inInclusiveRange(3, 5));
        expect(race.winner, inInclusiveRange(0, race.nominees.length - 1));
        // One nomination per artist in a category.
        expect(race.nominees.map((n) => n.artistId).toSet().length,
            race.nominees.length);
      }
      // Eligible: out from October 2009 to September 2010, and a hit.
      final (from, to) = Awards.window(2011);
      for (final n in show.races.first.nominees) {
        final song = w.songs[n.id];
        final out = song.isSingle ? song.singleWeek : song.releasedWeek;
        expect(out, inInclusiveRange(from, to - 1));
        expect(song.peakOn(Charts.usSongs) + song.peakOn(Charts.globalSongs),
            greaterThan(0));
      }
      // Saved and loaded as is.
      final back = AwardShow.decode(AwardShow.encode(w.awardShows))
          .firstWhere((x) => x.year == 2011);
      expect(back.held, isTrue);
      expect([for (final r in back.races) r.winner],
          [for (final r in show.races) r.winner]);
      expect([for (final r in back.races) r.nominees.map((n) => n.id)],
          [for (final r in show.races) r.nominees.map((n) => n.id)]);
    });

    test('a nominated player is invited, performs and hears the results', () {
      final (:w, :sim, :p) = star();
      while (w.week < GameTime.firstWeekOf(2011)) {
        sim.step();
      }
      final s = Actions.writeSong(w, p, producerSkill: 95, aiMode: true);
      final race = Awards.showFor(w, 2011)!
          .races
          .firstWhere((r) => r.category == AwardCategory.record);
      race.nominees[0] = AwardNominee(s.id, p.id);
      AwardNight? night;
      var invited = false;
      while (GameTime.weekOfYear(w.week) <= Awards.ceremonyWeekOfYear) {
        final r = sim.step();
        night ??= r.awardNight;
        if (r.newOpportunity?.kind == OpportunityKind.award) {
          invited = true;
          Opportunities.answer(w, p, OpportunityChoice.perform);
        }
      }
      expect(invited, isTrue);
      expect(night, isNotNull);
      expect(night!.show.attendance, AwardAttendance.perform);
      expect(night.nominations, [race]);
      expect(night.fans, greaterThan(0));
      expect(night.wins.length, race.won!.artistId == p.id ? 1 : 0);
    });

    test('a player who never answers stays home', () {
      final (:w, :sim, :p) = star();
      while (w.week < GameTime.firstWeekOf(2011)) {
        sim.step();
      }
      final s = Actions.writeSong(w, p, producerSkill: 95, aiMode: true);
      Awards.showFor(w, 2011)!.races.first.nominees[0] =
          AwardNominee(s.id, p.id);
      AwardNight? night;
      while (GameTime.weekOfYear(w.week) <= Awards.ceremonyWeekOfYear) {
        night ??= sim.step().awardNight;
      }
      expect(night!.show.attendance, AwardAttendance.none);
      expect(night.fans, 0);
      expect(p.opportunity, isNull);
    });
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
  int seed = 77,
}) {
  final w =
      WorldGen.create(seed: seed, startYear: year, difficulty: difficulty);
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
    // Averaged over a few worlds: one album's critic score and noise move
    // a single week by ±15%.
    const maxMoves = [0, 0, 0, 0, 0, 0, 1, 2];
    double us(Difficulty d, int seed) {
      final r = _debut(
          year: 2025,
          devotion: 1.0,
          hype: 0.8,
          variants: maxMoves,
          campaign: Campaign.global,
          difficulty: d,
          seed: seed);
      return r.world.albumFirstWeekIn(r.album, ChartMarket.us);
    }

    const seeds = [77, 78, 79];
    final legend = [for (final s in seeds) us(Difficulty.legend, s)];
    final real = [for (final s in seeds) us(Difficulty.normal, s)];
    double mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    printOnFailure('legend $legend, realistic $real');
    // Same artist, same moves: Legend opens above the real record (~4M)
    // on average; the 1.5–2× gap over a career comes from faster growth
    // (docs K58).
    expect(mean(legend), greaterThan(4.2e6));
    expect(mean(legend), greaterThan(1.1 * mean(real)));
    // The rest of the world (rivals' awards, editions) moves the mean by a
    // few percent; seeds alone span 4.5–5.1M.
    expect(mean(real), lessThan(5.0e6));
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
    // About +25–45% for 4× the tracks (longer tracklist + streaming
    // equivalents of the extra tracks, which fans play in release week
    // since docs F25), never anything like 4×.
    print('40 vs 10 tracks: ${(forty / ten).toStringAsFixed(3)}');
    expect(forty / ten, inInclusiveRange(1.18, 1.5));
    expect(forty, lessThan(1.8 * ten));
  });
}

/// Short-video virality (docs/game-design.md §7.3): old catalog songs can go
/// viral and climb the charts in the short-video era, but not before it.
void noviceTests() {
  test('a beginner gets a lift that fades as skills grow (T13)', () {
    expect(Actions.noviceBonus(33), closeTo(7.65, 1e-9));
    expect(Actions.noviceBonus(45), closeTo(2.25, 1e-9));
    expect(Actions.noviceBonus(50), 0);
    expect(Actions.noviceBonus(80), 0);
  });
}

void viralTests() {
  test('unknown artists rarely go viral; known ones as before (T12)', () {
    final c = SimConfig();
    expect(c.viralReach(4e3, 2e4), lessThan(0.15));
    expect(c.viralReach(2e4, 2e5), lessThan(0.3));
    expect(c.viralReach(4e5, 4e6), greaterThanOrEqualTo(1.0));
    expect(c.viralReach(1e7, 1e8), 1.3);
  });

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

  test('campaigns cost more for big audiences (K57)', () {
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
    expect(a.campaignCostCents, Campaign.global.costCents);
    // Back-to-back campaigns cost the same and work at full strength (the
    // fatigue was removed on the player's request).
    final b = Actions.writeSong(w, p, producerSkill: 80, aiMode: true);
    Actions.releaseSingle(w, p, b, campaign: Campaign.global);
    expect(b.campaignCostCents, Campaign.global.costCents);
    expect(b.campaignPower, 1);
    // Weeks later the campaign's income has been counted.
    for (var i = 0; i < 16; i++) {
      sim.step();
    }
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

  test('streaming-era fans buy in week one, then the album streams (K79)', () {
    final c = SimConfig();
    expect(c.albumTail(2009), 1.0);
    expect(c.albumTail(2010), closeTo(0.75, 1e-9));
    expect(c.albumTail(2012), closeTo(0.62, 1e-9));
    expect(c.albumTail(2013), closeTo(0.55, 1e-9));
    expect(c.albumTail(2020), 0.28);
    double secondWeek(int year) {
      final w = WorldGen.create(seed: 7, startYear: year);
      final sim = Simulator(w);
      while (w.week < GameTime.firstWeekOf(year)) {
        sim.step();
      }
      final p = WorldGen.addPlayer(w,
          name: 'Star',
          genre: 0,
          tier: StartTier.superstar,
          money: StartMoney.millionaire);
      final songs = [
        for (var i = 0; i < 10; i++)
          Actions.writeSong(w, p, producerSkill: 90, aiMode: true).id,
      ];
      final al = Actions.releaseAlbum(w, p, 'LP', songs);
      sim.step();
      final first = al.weekPure;
      sim.step();
      return al.weekPure / first;
    }

    // A sixth or more in the download era; about a tenth from 2016.
    expect(secondWeek(2010), greaterThan(0.15));
    expect(secondWeek(2018), lessThan(0.15));
  });

  test('kinds: strengths, group life and the comeback (K87)', () {
    final w = WorldGen.create(seed: 87, startYear: 2016);
    final sim = Simulator(w);
    while (w.week < GameTime.firstWeekOf(2016)) {
      sim.step();
    }
    Artist add(ArtistKind kind, String name) => WorldGen.addPlayer(w,
        name: name,
        genre: 0,
        kind: kind,
        members: kind.isGroup ? const ['Ava', 'Bo', 'Cy', 'Dee'] : const [],
        tier: StartTier.risingStar,
        money: StartMoney.millionaire);
    final solo = add(ArtistKind.solo, 'S');
    final band = add(ArtistKind.band, 'B');
    // Same audience and stage: the band's tour draws 35% more.
    band
      ..coreFans = solo.coreFans
      ..casual = solo.casual
      ..hype = solo.hype
      ..popularity = solo.popularity
      ..skills.performance = solo.skills.performance;
    band.regionShare.setAll(0, solo.regionShare);
    double demand(Artist a) =>
        Tours.marketDemand(w, a, TourMarket.usa, 1, null);
    expect(demand(band) / demand(solo), closeTo(1.35, 1e-9));
    expect(ArtistKind.solo.viral, greaterThan(ArtistKind.band.viral));
    expect(ArtistKind.vocalGroup.collector,
        greaterThan(ArtistKind.band.collector));

    // A member's solo record: new listeners, less creativity.
    final group = add(ArtistKind.vocalGroup, 'G');
    group
      ..creativeEnergy = 100
      ..opportunity = Opportunity(
          kind: OpportunityKind.memberSolo, week: w.week, member: 1);
    final casual = group.casual;
    final out = Opportunities.answer(w, group, OpportunityChoice.accept);
    expect(group.casual, greaterThan(casual));
    expect(out.energy, -Opportunities.memberSoloEnergy);
    // A feud left alone lapses into "let it pass".
    group.opportunity =
        Opportunity(kind: OpportunityKind.memberRift, week: w.week, member: 2);
    expect(group.opportunity!.lapse, OpportunityChoice.ignore);
    expect(group.opportunity!.choices, contains(OpportunityChoice.leanIn));
    group.opportunity = null;

    // Back after two years: a reunion is an event.
    group
      ..lastReleaseWeek = w.week - Actions.comebackWeeks
      ..hype = 0;
    final song = Actions.writeSong(w, group, producerSkill: 80, aiMode: true);
    Actions.releaseSingle(w, group, song);
    expect(group.hype, closeTo(0.35 * (0.5 + group.fame), 1e-9));
  });
}

/// A superstar's single four weeks out, in a fresh 2024 world; then
/// [extra] runs and the next [weeks] weeks are played (docs K92).
({World w, Artist p, Song s, List<double> streams, List<double> physical})
    _singleRun(void Function(World, Artist, Song)? extra, {int weeks = 2}) {
  final w = WorldGen.create(seed: 92, startYear: 2024);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(2024)) {
    sim.step();
  }
  final p = WorldGen.addPlayer(w,
      name: 'Star',
      genre: 0,
      tier: StartTier.superstar,
      money: StartMoney.millionaire);
  final s = Actions.writeSong(w, p, producerSkill: 80, aiMode: true);
  Actions.releaseSingle(w, p, s);
  for (var i = 0; i < 4; i++) {
    sim.step();
  }
  extra?.call(w, p, s);
  final streams = <double>[], physical = <double>[];
  for (var i = 0; i < weeks; i++) {
    sim.step();
    streams.add(s.weekStreams);
    physical.add(s.weekPhysical);
  }
  return (w: w, p: p, s: s, streams: streams, physical: physical);
}

void versionTests() {
  test('a new version brings a wave of listening, once per kind (K92)', () {
    final base = _singleRun(null);
    final remix = _singleRun((w, p, s) {
      final money = p.moneyCents;
      Actions.releaseVersion(w, p, s, SongVersion.remix);
      expect(money - p.moneyCents, SongVersion.remix.costCents);
      expect(() => Actions.releaseVersion(w, p, s, SongVersion.remix),
          throwsA(isA<ActionException>()));
    });
    printOnFailure('${base.streams} vs ${remix.streams}');
    expect(remix.streams[0], greaterThan(base.streams[0] * 1.1));
    expect(remix.s.versions.single.$1, SongVersion.remix);
    // A second version within weeks adds less than the first.
    final two = _singleRun((w, p, s) {
      Actions.releaseVersion(w, p, s, SongVersion.remix);
      final first = s.versionBoost;
      Actions.releaseVersion(w, p, s, SongVersion.spedUp);
      expect(s.versionBoost - first, lessThan(SongVersion.spedUp.boost(2024)));
    });
    expect(two.streams[0], greaterThan(remix.streams[0]));
  });

  test('a physical single edition sells to fans in its week (K92)', () {
    final base = _singleRun(null);
    final cd = _singleRun((w, p, s) {
      Actions.releaseVariant(w, p, s, SingleFormat.cd);
      expect(() => Actions.releaseVariant(w, p, s, SingleFormat.cd),
          throwsA(isA<ActionException>()));
    }, weeks: 3);
    final extra = [
      for (var i = 0; i < 2; i++) cd.physical[i] - base.physical[i]
    ];
    printOnFailure('extra copies $extra');
    // A superstar's CD single: tens of thousands, mostly in week one.
    expect(extra[0], inInclusiveRange(1e4, 2e5));
    expect(extra[1], lessThan(extra[0] * 0.5));
    expect(cd.s.statsOrNull(Charts.usSongs)?.peak ?? 999,
        lessThanOrEqualTo(base.s.statsOrNull(Charts.usSongs)?.peak ?? 999));
    // Only singles.
    final w = cd.w, p = cd.p;
    final track = Actions.writeSong(w, p, producerSkill: 50, aiMode: true);
    expect(() => Actions.releaseVariant(w, p, track, SingleFormat.vinyl),
        throwsA(isA<ActionException>()));
  });
}

/// A newcomer's single in 2021, played for [weeks] after [extra].
({World w, Simulator sim, Artist p, Song s}) _newcomerSingle(int seed,
    {void Function(World, Artist, Song)? extra, int weeks = 0}) {
  final w = WorldGen.create(seed: seed, startYear: 2021);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(2021)) {
    sim.step();
  }
  final p = WorldGen.addPlayer(w,
      name: 'New', genre: 0, money: StartMoney.millionaire);
  final s = Actions.writeSong(w, p, producerSkill: 60, aiMode: true);
  Actions.releaseSingle(w, p, s);
  extra?.call(w, p, s);
  for (var i = 0; i < weeks; i++) {
    sim.step();
  }
  return (w: w, sim: sim, p: p, s: s);
}

void streamingToolTests() {
  test('bought streams count, and a caught song loses them (K95)', () {
    final base = _newcomerSingle(95, weeks: 1);
    final bought = _newcomerSingle(95, extra: (w, p, s) {
      final money = p.moneyCents;
      StreamingTools.buyBots(w, p, s, BotPackage.medium);
      expect(money - p.moneyCents, BotPackage.medium.costCents);
      expect(() => StreamingTools.buyBots(w, p, s, BotPackage.small),
          throwsA(isA<ActionException>()));
    }, weeks: 1);
    // 40% of the package in week one, a quarter filtered out.
    expect(bought.s.weekStreams - base.s.weekStreams,
        closeTo(5e6 * 0.4 * 0.75, 2e5));
    // A big package on a small song gets caught sooner or later.
    var caught = 0;
    for (final seed in [1, 2, 3, 4, 5, 6]) {
      final r = _newcomerSingle(seed,
          extra: (w, p, s) =>
              StreamingTools.buyBots(w, p, s, BotPackage.large));
      var wasCaught = false;
      for (var i = 0; i < 4 && !wasCaught; i++) {
        final before = r.s.lifetimeStreams;
        final week = r.sim.step();
        if (week.botsCaught.contains(r.s.id)) {
          wasCaught = true;
          expect(r.s.botStatus, BotStatus.caught);
          // Everything bought that counted is gone again.
          expect(r.s.lifetimeStreams,
              lessThan(before + r.s.weekStreams - r.s.botDelivered * 0.99));
          expect(r.w.week < r.s.chartFilterUntil, isTrue);
        }
      }
      if (wasCaught) caught++;
    }
    printOnFailure('caught $caught of 6');
    expect(caught, greaterThanOrEqualTo(3));
  });

  test('autoplay: more listening, less royalty per stream (K96)', () {
    final off = _newcomerSingle(96, weeks: 3);
    final on = _newcomerSingle(96,
        extra: (w, p, s) => StreamingTools.setAutoplay(w, s, true), weeks: 3);
    expect(on.s.weekStreams, greaterThan(off.s.weekStreams * 1.1));
    final perStreamOff = off.s.revenueCents / off.s.lifetimeStreams;
    final perStreamOn = on.s.revenueCents / on.s.lifetimeStreams;
    expect(perStreamOn, lessThan(perStreamOff * 0.85));
  });

  test('a pitch can land an editorial playlist, once per song (K97)', () {
    var landed = 0;
    for (var seed = 11; seed < 23; seed++) {
      final r = _newcomerSingle(seed, extra: (w, p, s) {
        // A campaign may already have landed a playlist: no pitch then.
        if (!StreamingTools.canPitch(w, s)) return;
        StreamingTools.pitch(w, s);
        expect(StreamingTools.canPitch(w, s), isFalse);
      }, weeks: 1);
      if (r.s.pitchWeek >= 0 && r.s.playlistWeek == r.s.pitchWeek) landed++;
    }
    printOnFailure('landed $landed of 12');
    expect(landed, inInclusiveRange(1, 10));
  });
}

void audienceLimitTests() {
  test('gains outside listening saturate near the fan cap', () {
    final w = WorldGen.create(seed: 105, startYear: 2015);
    final p = WorldGen.addPlayer(w, name: 'Cap', genre: 0);
    final cap = Audience.fanCap(w);
    p.coreFans = cap / 2;
    expect(Audience.addFans(w, p, 1000), closeTo(500, 1e-6));
    p.coreFans = cap;
    expect(Audience.addFans(w, p, 1e6), 0);
    expect(Audience.addFans(w, p, -1e6), -1e6);
    p.casual = w.config.publicPool;
    expect(Audience.addCasual(w, p, 1e6), 0);
  });

  test('no artist reaches more than a few per cent of a market', () {
    final w = WorldGen.create(seed: 105, startYear: 2020);
    final sim = Simulator(w);
    while (w.week < GameTime.firstWeekOf(2020)) {
      sim.step();
    }
    final p = WorldGen.addPlayer(w,
        name: 'Giant',
        genre: 0,
        tier: StartTier.superstar,
        money: StartMoney.millionaire);
    // Far more listeners than anyone could have (fans flooding a new
    // record are not capped; few fans here).
    p.coreFans = 1e4;
    p.casual = 3e8;
    p.hype = 2;
    for (var i = 0; i < 4; i++) {
      final s = Actions.writeSong(w, p, producerSkill: 90, aiMode: true);
      Actions.releaseSingle(w, p, s);
    }
    final eras = w.regionalEra.forWeek(w.week);
    for (var i = 0; i < 3; i++) {
      sim.step();
    }
    for (var k = 0; k < regionCount; k++) {
      var mine = 0.0;
      for (final id in w.playerSongIds) {
        mine += w.songs[id].weekRegion?[k] ?? 0;
      }
      printOnFailure('region $k: ${mine / eras[k].streamsWeekly}');
      expect(mine, lessThan(w.config.marketShareCap * eras[k].streamsWeekly));
      expect(mine, greaterThan(0));
    }
  });

  test('lifts add up with diminishing returns', () {
    final c = SimConfig();
    expect(c.stackedLift(0), 1);
    expect(c.stackedLift(0.3), closeTo(1.28, 0.01));
    // Playlist, autoplay, video and hype together: far less than their
    // product (1.8 × 1.3 × 1.4 × 1.2 ≈ 3.9).
    final all = c.stackedLift(0.8 + 0.3 + 0.4 + 0.2);
    expect(all, lessThan(2.2));
    expect(all, greaterThan(c.stackedLift(0.8)));
    expect(c.stackedLift(100), lessThanOrEqualTo(1 + c.liftCeiling));
  });

  test('posting every week cannot keep hype high', () {
    final w = WorldGen.create(seed: 105, startYear: 2015);
    final sim = Simulator(w);
    final p = WorldGen.addPlayer(w, name: 'Poster', genre: 0);
    while (w.week < GameTime.firstWeekOf(2015)) {
      sim.step();
    }
    Actions.writeSong(w, p, aiMode: true);
    var top = 0.0;
    for (var i = 0; i < 20; i++) {
      for (var j = 0; j < Social.postsPerWeek; j++) {
        Social.post(w, p, PostKind.teaser);
      }
      top = math.max(top, p.hype);
      sim.step();
    }
    expect(top, lessThan(Social.postHypeCeiling));
  });

  test('records sell more in the holidays, less in January', () {
    final c = SimConfig();
    expect(c.holidaySales(51, 2005), greaterThan(1.8));
    expect(c.holidaySales(51, 2020), lessThan(c.holidaySales(51, 2005)));
    expect(c.holidaySales(51, 2020), greaterThan(1.3));
    expect(c.holidaySales(2, 2005), lessThan(1));
    expect(c.holidaySales(20, 2005), 1);
  });
}

void recordDealTests() {
  test('deal shapes trade money now for the split; fans give leverage', () {
    final w = WorldGen.create(seed: 107, startYear: 2015);
    final p = WorldGen.addPlayer(w, name: 'Deal', genre: 0);
    p.coreFans = Label.major.minFans.toDouble();
    expect(Contracts.leverage(w, p, Label.major), 0);
    final std = Contracts.terms(w, p, Label.major, ContractDeal.standard);
    final big = Contracts.terms(w, p, Label.major, ContractDeal.bigAdvance);
    final split = Contracts.terms(w, p, Label.major, ContractDeal.betterSplit);
    expect(std.advanceCents, Label.major.advanceCents);
    expect(std.artistShare, Label.major.artistShare);
    expect(big.advanceCents, 2 * std.advanceCents);
    expect(big.artistShare, lessThan(std.artistShare));
    expect(big.albums, std.albums + 1);
    expect(split.advanceCents, lessThan(std.advanceCents));
    expect(split.artistShare, greaterThan(std.artistShare));
    // Four times what the label asks for: the best terms it gives.
    p.coreFans = 4.0 * Label.major.minFans;
    expect(Contracts.leverage(w, p, Label.major), 1);
    final proven = Contracts.terms(w, p, Label.major, ContractDeal.standard);
    expect(proven.advanceCents, 2 * std.advanceCents);
    expect(proven.artistShare, greaterThan(std.artistShare));
    // Going independent is no deal at all.
    final own =
        Contracts.terms(w, p, Label.independent, ContractDeal.bigAdvance);
    expect(own.advanceCents, 0);
    expect(own.artistShare, 1);
  });

  test('the advance is paid back from royalties first', () {
    final w = WorldGen.create(seed: 107, startYear: 2015);
    final sim = Simulator(w);
    while (w.week < GameTime.firstWeekOf(2015)) {
      sim.step();
    }
    final p = WorldGen.addPlayer(w,
        name: 'Recoup',
        genre: 0,
        tier: StartTier.superstar,
        money: StartMoney.millionaire);
    final money = p.moneyCents;
    Actions.signLabel(w, p, Label.giant, deal: ContractDeal.bigAdvance);
    final t = Contracts.terms(w, p, Label.giant, ContractDeal.bigAdvance);
    expect(p.moneyCents - money, p.contractAdvanceCents);
    expect(p.unrecoupedCents, p.contractAdvanceCents);
    expect(p.contractAlbumsLeft, Label.giant.contractAlbums + 1);
    expect(p.artistShare, closeTo(t.artistShare, 1e-9));
    // Royalties go to the advance until it is paid back.
    p.unrecoupedCents = 1000;
    expect(Contracts.recoup(p, 600), 0);
    expect(p.unrecoupedCents, 400);
    expect(Contracts.recoup(p, 600), closeTo(200, 1e-9));
    expect(p.unrecoupedCents, 0);
    expect(Contracts.recoup(p, 600), 600);
    // A week of a superstar's songs pays some of a big advance back and
    // nothing into the bank.
    p.unrecoupedCents = 1 << 40;
    for (var i = 0; i < 3; i++) {
      p.creativeEnergy = 100;
      Actions.releaseSingle(
          w, p, Actions.writeSong(w, p, producerSkill: 90, aiMode: true));
    }
    final bank = p.moneyCents;
    sim.step();
    expect(p.unrecoupedCents, lessThan(1 << 40));
    expect(p.moneyCents - bank, lessThanOrEqualTo(p.job.wageCents));
  });
}
