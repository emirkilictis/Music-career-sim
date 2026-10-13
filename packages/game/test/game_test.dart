import 'dart:io';

import 'package:game/game.dart';
import 'package:test/test.dart';

late Directory tmp;
late SaveSlots slots;

CareerSetup _setup({
  String name = 'Nova',
  int startYear = 2018,
  bool premium = false,
  StartTier tier = StartTier.unknown,
  StartMoney money = StartMoney.basic,
  ArtistKind kind = ArtistKind.solo,
  List<String> members = const [],
  Skills? skills,
  CareerPath path = CareerPath.independent,
}) =>
    CareerSetup(
      name: name,
      genre: 0,
      startYear: startYear,
      premium: premium,
      tier: tier,
      money: money,
      kind: kind,
      members: members,
      skills: skills,
      path: path,
      seed: 4242,
    );

Matcher _code(String code) =>
    throwsA(isA<GameException>().having((e) => e.code, 'code', code));

void main() {
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mcs_game_');
    slots = SaveSlots(Directory('${tmp.path}/slots'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('career setup', () {
    test('free players cannot pick Premium starts', () {
      expect(() => _setup(tier: StartTier.superstar).validate(),
          _code('premiumRequired'));
      expect(() => _setup(money: StartMoney.millionaire).validate(),
          _code('premiumRequired'));
      _setup(premium: true, tier: StartTier.superstar).validate();
    });

    test('names, members, years and stats are checked', () {
      expect(() => _setup(name: '  ').validate(), _code('invalidName'));
      expect(
          () => _setup(startYear: 1995).validate(), _code('invalidStartYear'));
      expect(() => _setup(kind: ArtistKind.band, members: ['A']).validate(),
          _code('invalidMembers'));
      expect(() => _setup(members: ['A', 'B']).validate(),
          _code('invalidMembers'));
      final premiumBuild =
          StartingStats.auto(premium: true, kind: ArtistKind.solo);
      expect(() => _setup(skills: premiumBuild).validate(),
          _code('invalidSkills'));
      _setup(premium: true, skills: premiumBuild).validate();
    });
  });

  group('session', () {
    test('a new career starts at the chosen year with full charts', () {
      final progress = <double>[];
      final g = GameSession.start(slots, _setup(), onProgress: progress.add);
      expect(g.year, 2018);
      expect(g.weekOfYear, 1);
      expect(progress.last, 1.0);
      expect(g.player.moneyCents, 500000);
      expect(g.player.isPlayer, isTrue);
      final us = g.chart(Charts.usSongs);
      expect(us.rows.length, 100);
      expect(us.rows.first.position, 1);
      expect(slots.list().single['artistName'], 'Nova');
      g.close();
    });

    test('actions follow the rules and report clear error codes', () {
      final g = GameSession.start(slots, _setup());
      expect(
          () => g.writeSong(budget: BudgetTier.high), _code('notEnoughMoney'));
      final star = g
          .collaborators(CollaboratorRole.producer)
          .firstWhere((c) => !c.available);
      expect(() => g.writeSong(producerId: star.id, budget: BudgetTier.low),
          _code('collaboratorRefused'));
      expect(() => g.writeSong(budget: BudgetTier.low, genres: [0, 0]),
          _code('invalidGenres'));
      // Refusals did not use up any creativity.
      final creativity = g.player.creativeEnergy;
      expect(g.player.songsWrittenThisWeek, 0);
      final ids = [
        for (var i = 0; i < 3; i++)
          g.writeSong(budget: BudgetTier.low, genres: [0, 6]).id,
      ];
      expect(
          g.player.creativeEnergy, creativity - 3 * Actions.energyCostPerSong);
      expect(g.vault.length, 3);
      expect(g.song(ids.first).genres, [0, 6]);

      g.releaseSingle(ids.first, campaign: Campaign.none);
      expect(() => g.releaseSingle(ids.first), _code('alreadySingle'));
      // An earlier single can go on the EP; then the songs are taken.
      final ep = g.releaseAlbum('EP', ids, type: AlbumType.ep);
      expect(g.song(ids.first).albumId, ep.id);
      expect(() => g.releaseAlbum('Again', ids, type: AlbumType.ep),
          _code('trackOnOtherRelease'));
      expect(() => g.releaseAlbum('Short', ids.sublist(1), type: AlbumType.ep),
          _code('trackCount'));

      for (var i = 0; i < 3; i++) {
        g.rewardAd();
      }
      expect(g.rewardAd, _code('adLimit'));

      // No weekly limit (K46): low creativity weakens songs, and writing
      // on until it runs out means burnout.
      expect(g.player.creativityPenalty, greaterThan(0));
      while (g.player.canWrite) {
        g.writeSong(budget: BudgetTier.low);
      }
      expect(g.player.burnoutWeeksLeft, greaterThan(0));
      expect(g.writeSong, _code('burnout'));
      g.close();
    });

    test('an offer waits across reopening; answers are checked (K59)', () {
      var g = GameSession.start(slots, _setup());
      final id = g.slotId;
      expect(() => g.answerOpportunity(OpportunityChoice.accept),
          throwsA(isA<GameException>()));
      final p = g.world.player!;
      p.opportunity = Opportunity(
          kind: OpportunityKind.festival, week: g.world.week, feeCents: 1000);
      g.world.dirtyArtists.add(p.id);
      g.writeSong(budget: BudgetTier.low); // any action saves
      expect(g.player.opportunity?.kind, OpportunityKind.festival);
      expect(g.player.opportunity?.weeksLeft, 3);
      g.close();

      g = GameSession.resume(slots, id);
      expect(g.opportunity?.feeCents, 1000);
      expect(() => g.answerOpportunity(OpportunityChoice.perform),
          throwsA(isA<GameException>()));
      final money = g.player.moneyCents;
      final out = g.answerOpportunity(OpportunityChoice.accept);
      expect(out.moneyCents, 1000);
      expect(g.player.moneyCents, money + 1000);
      expect(g.opportunity, isNull);
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.opportunity, isNull);
      g.close();
    });

    test('weeks autosave; resuming continues exactly where it was', () {
      var g = GameSession.start(slots, _setup());
      final id = g.slotId;
      g.setJob(Job.cafe);
      final song = g.writeSong(budget: BudgetTier.low).id;
      g.releaseSingle(song);
      for (var i = 0; i < 5; i++) {
        final r = g.advanceWeek();
        expect(r.moneyDeltaCents, greaterThanOrEqualTo(Job.cafe.wageCents));
      }
      // An action between weeks is saved at once, without playing a week.
      g.writeSong(budget: BudgetTier.low);
      final hash = worldHash(g.world);
      final weekStreams = g.song(song).weekStreams;
      final no1 = g.chart(Charts.usSongs).rows.first;
      final rivalWeekly = g.artistPage(no1.artistId).weeklyStreams;
      expect(weekStreams, greaterThan(0));
      g.close();

      g = GameSession.resume(slots, id);
      expect(worldHash(g.world), hash);
      expect(g.player.hasJob, isTrue);
      expect(g.songs.length, 2);
      // "This week" numbers survive reopening (they used to read 0).
      expect(g.song(song).weekStreams, weekStreams);
      expect(g.artistPage(no1.artistId).weeklyStreams, rivalWeekly);
      g.close();
    });

    test('skill points every week, spent up to 100, kept on reopening', () {
      var g = GameSession.start(slots, _setup());
      final id = g.slotId;
      final vocals = g.player.skills[SkillKind.vocals]!;
      expect(g.player.skillPoints, 0);
      expect(() => g.spendSkillPoint(SkillKind.vocals), _code('noSkillPoints'));
      final fame = <double>[];
      for (var i = 0; i < 4; i++) {
        g.advanceWeek();
        fame.add(g.player.fame);
      }
      expect(g.player.skillPoints, 4 * Actions.skillPointsPerWeek);
      // Near the cap (as after years of practice): the last point fills it.
      g.world.artists[g.player.id].skills.songwriting = 99.5;
      g.spendSkillPoint(SkillKind.songwriting);
      expect(g.player.skills[SkillKind.songwriting], 100);
      expect(
          () => g.spendSkillPoint(SkillKind.songwriting), _code('skillMaxed'));
      g.spendSkillPoint(SkillKind.vocals);
      expect(g.player.skillPoints, 4 * Actions.skillPointsPerWeek - 2);
      g.close();

      g = GameSession.resume(slots, id);
      expect(g.player.skillPoints, 4 * Actions.skillPointsPerWeek - 2);
      expect(g.player.skills[SkillKind.vocals], vocals + 1);
      // Fame never goes down (docs K44).
      for (var i = 1; i < fame.length; i++) {
        expect(fame[i], greaterThanOrEqualTo(fame[i - 1]));
      }
      g.close();
    });

    test('releases scheduled ahead, announced when the player chooses', () {
      var g = GameSession.start(
          slots, _setup(premium: true, money: StartMoney.millionaire));
      final id = g.slotId;
      final w0 = g.week;
      final songs = [
        for (var i = 0; i < 3; i++) g.writeSong(budget: BudgetTier.low).id,
      ];
      final money0 = g.player.moneyCents;

      // A single in 6 weeks, announced 2 weeks before it comes out.
      final single = g.scheduleSingle(songs[0],
          campaign: Campaign.standard,
          releaseWeek: w0 + 6,
          announceWeek: w0 + 4);
      expect(g.player.moneyCents, money0 - Campaign.standard.costCents);
      expect(single.announced, isFalse);
      expect(g.song(songs[0]).scheduledSingleWeek, w0 + 6);
      expect(() => g.releaseSingle(songs[0]), _code('alreadyScheduled'));
      expect(
          () => g.scheduleSingle(songs[1],
              releaseWeek: w0 + 30, announceWeek: w0),
          _code('invalidDate'));
      expect(
          () => g.scheduleSingle(songs[1],
              releaseWeek: w0 + 3, announceWeek: w0 + 4),
          _code('invalidDate'));

      // An EP in 10 weeks, never announced (surprise); its songs are taken.
      final ep = g.scheduleAlbum('Later', songs,
          type: AlbumType.ep,
          campaign: Campaign.none,
          releaseWeek: w0 + 10,
          announceWeek: w0 + 10);
      expect(ep.isSurprise, isTrue);
      expect(() => g.releaseAlbum('Now', songs, type: AlbumType.ep),
          _code('trackOnOtherRelease'));
      expect(g.scheduled.map((s) => s.id), [single.id, ep.id]);

      for (var i = 0; i < 3; i++) {
        g.advanceWeek();
      }
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.scheduled.length, 2);

      final events = <(int, GameEvent)>[];
      final buzz = <double>[];
      while (g.week < w0 + 10) {
        final r = g.advanceWeek();
        events.addAll([for (final e in r.events) (r.week, e)]);
        if (g.scheduled.isNotEmpty && !g.scheduled.first.isAlbum) {
          buzz.add(g.scheduled.first.buzz);
        }
      }
      final announced = events.where((e) => e.$2 is ReleaseAnnounced).toList();
      expect(announced.length, 1);
      expect(announced.single.$1, w0 + 4);
      // Buzz built only after the announcement (weeks w0+4 and w0+5).
      expect(buzz.where((b) => b > 0).length, 2);
      final out = events.where((e) => e.$2 is ReleaseOut).toList();
      expect(out.first.$1, w0 + 6);
      expect(g.song(songs[0]).isSingle, isTrue);
      expect(g.song(songs[0]).singleWeek, w0 + 6);
      expect(g.scheduled.length, 1);

      // Cancelling gives the money back and frees the songs.
      final before = g.player.moneyCents;
      g.cancelScheduled(ep.id);
      expect(g.scheduled, isEmpty);
      expect(g.player.moneyCents, before + ep.paidCents);
      g.releaseAlbum('Now', songs, type: AlbumType.ep, campaign: Campaign.none);
      g.close();
    });

    test('an announced album opens bigger than a surprise drop', () {
      double firstWeek(bool announce) {
        final g = GameSession.start(
            slots,
            _setup(
                premium: true,
                tier: StartTier.superstar,
                money: StartMoney.millionaire));
        g.world.player!.moneyCents = 1 << 40;
        final songs = <int>[];
        while (songs.length < 8) {
          if (!g.player.canWrite || g.player.creativeEnergy < 30) {
            g.advanceWeek();
            continue;
          }
          songs.add(g.writeSong(budget: BudgetTier.high).id);
        }
        final release = g.week + 6;
        g.scheduleAlbum('Big', songs,
            releaseWeek: release, announceWeek: announce ? g.week : release);
        AlbumFirstWeek? fw;
        while (fw == null) {
          fw = g.advanceWeek().events.whereType<AlbumFirstWeek>().firstOrNull;
        }
        g.close();
        return fw.globalUnits;
      }

      final surprise = firstWeek(false);
      final announced = firstWeek(true);
      expect(announced, greaterThan(surprise * 1.1));
    });

    test('edition formats: vinyl beats cassette in the 2020s, costs differ',
        () {
      (double, int) firstWeek(EditionFormat f) {
        final g = GameSession.start(
            slots,
            _setup(
                startYear: 2021,
                premium: true,
                tier: StartTier.superstar,
                money: StartMoney.millionaire));
        g.world.player!.moneyCents = 1 << 40;
        final songs = <int>[];
        while (songs.length < 8) {
          if (!g.player.canWrite || g.player.creativeEnergy < 30) {
            g.advanceWeek();
            continue;
          }
          songs.add(g.writeSong(budget: BudgetTier.high).id);
        }
        final money = g.player.moneyCents;
        g.releaseAlbum('Big', songs,
            variantWeeks: const [0, 0, 0],
            variantFormats: [null, f, f],
            campaign: Campaign.none);
        final paid = money - g.player.moneyCents;
        expect(g.albums.first.variantFormats, [null, f, f]);
        final fw = g.advanceWeek().events.whereType<AlbumFirstWeek>().first;
        g.close();
        return (fw.globalUnits, paid);
      }

      final (vinyl, vinylPaid) = firstWeek(EditionFormat.vinyl);
      final (cassette, cassettePaid) = firstWeek(EditionFormat.cassette);
      expect(vinyl, greaterThan(cassette));
      expect(vinylPaid, 2 * EditionFormat.vinyl.costCents);
      expect(cassettePaid, 2 * EditionFormat.cassette.costCents);
    });

    test('album week-by-week sales and chart runs, also for rivals', () {
      final g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      g.world.player!.moneyCents = 1 << 40;
      final songs = <int>[];
      while (songs.length < 8) {
        if (!g.player.canWrite || g.player.creativeEnergy < 30) {
          g.advanceWeek();
          continue;
        }
        songs.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final al = g.releaseAlbum('Big', songs);
      for (var i = 0; i < 3; i++) {
        g.advanceWeek();
      }
      final weeks = g.albumSales(al.id);
      expect(weeks.length, 3);
      expect(weeks.first.week, al.releaseWeek);
      expect(weeks.first.units, closeTo(g.album(al.id).firstWeekUnits, 1));
      expect(weeks.first.pure, greaterThan(0));
      expect(weeks.first.positions[Charts.usAlbums], isNotNull);
      expect(g.album(al.id).weekUnits, closeTo(weeks.last.units!, 1));
      final run = g.chartRun(EntityKind.album, al.id);
      expect(run.first.entries[Charts.usAlbums]!.position,
          weeks.first.positions[Charts.usAlbums]);

      // A rival's album: chart weeks with units, no private breakdown.
      final rival = g
          .chart(Charts.usAlbums)
          .rows
          .firstWhere((r) => !r.isPlayer && r.weeksOn > 2);
      final rw = g.albumSales(rival.entityId);
      // Only weeks played since the career started are saved.
      expect(rw, isNotEmpty);
      expect(rw.length, lessThanOrEqualTo(rival.weeksOn));
      expect(rw.last.usUnits, greaterThan(0));
      expect(rw.last.pure, isNull);
      expect(g.album(rival.entityId).isPlayer, isFalse);
      g.close();
    });

    test('one celebration per release; later weeks at #1 are plain news', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2002,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      g.world.player!.moneyCents = 1 << 40;
      final songs = <int>[];
      while (songs.length < 10) {
        if (!g.player.canWrite || g.player.creativeEnergy < 40) {
          g.advanceWeek();
          continue;
        }
        songs.add(g.writeSong(budget: BudgetTier.high).id);
      }
      // A devoted superstar fanbase, so the album reaches #1.
      g.world.player!
        ..devotion = 1.0
        ..coreFans *= 4;
      // Big campaigns need a label that can run them (K54).
      if (g.player.label != Label.giant) g.signLabel(Label.giant);
      final al = g.releaseAlbum('Big', songs, campaign: Campaign.global);
      final events = <(int, GameEvent)>[];
      for (var i = 0; i < 8; i++) {
        final r = g.advanceWeek();
        events.addAll([for (final e in r.events) (r.week, e)]);
      }
      final albumNo1 = [
        for (final (_, e) in events)
          if (e is NumberOne &&
              e.kind == EntityKind.album &&
              e.entityId == al.id)
            e
      ];
      expect(albumNo1, isNotEmpty);
      expect(albumNo1.where((e) => e.firstForRelease).length, 1);
      expect(albumNo1.first.firstForRelease, isTrue);
      // Every further week at #1 in the US is a plain "still #1" line.
      final run = g.chartRun(EntityKind.album, al.id);
      for (var i = 1; i < run.length; i++) {
        final now = run[i].entries[Charts.usAlbums]?.position;
        final prev = run[i - 1].entries[Charts.usAlbums]?.position;
        final still = events.any((x) =>
            x.$1 == run[i].week &&
            x.$2 is StillNumberOne &&
            (x.$2 as StillNumberOne).entityId == al.id);
        expect(still, now == 1 && prev == 1);
      }
      g.close();
    });

    test('vault songs can be scrapped; released or scheduled ones not', () {
      var g = GameSession.start(slots, _setup());
      final id = g.slotId;
      final a = g.writeSong(budget: BudgetTier.low).id;
      final b = g.writeSong(budget: BudgetTier.low).id;
      final c = g.writeSong(budget: BudgetTier.low).id;
      g.releaseSingle(b, campaign: Campaign.none);
      g.scheduleSingle(c,
          campaign: Campaign.none,
          releaseWeek: g.week + 3,
          announceWeek: g.week + 3);
      expect(() => g.scrapSong(b), _code('notInVault'));
      expect(() => g.scrapSong(c), _code('songScheduled'));
      g.scrapSong(a);
      expect(g.songs.map((s) => s.id), isNot(contains(a)));
      expect(() => g.releaseSingle(a), _code('unknownSong'));
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.songs.map((s) => s.id), isNot(contains(a)));
      expect(g.player.vaultCount, 0);
      g.close();
    });

    test('a lead single keeps its own cover; album tracks use the album\'s',
        () {
      final g = GameSession.start(slots, _setup());
      final songs = [
        for (var i = 0; i < 3; i++) g.writeSong(budget: BudgetTier.low).id,
      ];
      g.releaseSingle(songs[0], campaign: Campaign.none);
      g.advanceWeek();
      final ep = g.releaseAlbum('EP', songs,
          type: AlbumType.ep, campaign: Campaign.none);
      expect(g.song(songs[0]).albumId, ep.id);
      expect(g.song(songs[0]).coverAlbumId, -1);
      expect(g.song(songs[1]).coverAlbumId, ep.id);
      g.close();
    });

    test('a music video promotes its song; one per song, saved', () {
      double streams(bool video) {
        var g = GameSession.start(
            slots, _setup(premium: true, money: StartMoney.millionaire));
        final id = g.slotId;
        g.world.player!.moneyCents = 1 << 40;
        final song = g.writeSong(budget: BudgetTier.high).id;
        if (video) {
          final money = g.player.moneyCents;
          g.shootVideo(song, VideoBudget.high);
          expect(g.player.moneyCents, money - VideoBudget.high.costCents);
          expect(() => g.shootVideo(song, VideoBudget.low), _code('hasVideo'));
        }
        g.releaseSingle(song, campaign: Campaign.standard);
        for (var i = 0; i < 8; i++) {
          g.advanceWeek();
        }
        g.close();
        g = GameSession.resume(slots, id);
        expect(g.song(song).video, video ? VideoBudget.high : null);
        final total = g.song(song).lifetimeStreams.total;
        g.close();
        return total;
      }

      final without = streams(false);
      final withVideo = streams(true);
      expect(withVideo, greaterThan(without * 1.15));
    });

    test('labels: what they ask for, contracts, campaigns, drops', () {
      final g = GameSession.start(slots, _setup(path: CareerPath.smallLabel));
      expect(g.player.label, Label.small);
      expect(g.player.contractAlbumsLeft, 2);
      // A small label cannot run big campaigns.
      final song = g.writeSong(budget: BudgetTier.low).id;
      expect(() => g.releaseSingle(song, campaign: Campaign.intensive),
          _code('campaignLocked'));
      // Bound by the contract, and the big labels want fans first.
      expect(() => g.signLabel(Label.giant), _code('underContract'));
      final giant = g.labels.firstWhere((v) => v.label == Label.giant);
      expect(giant.missing, contains(LabelRequirement.fans));
      // With the albums delivered and fans, a major signs the player.
      g.world.player!
        ..contractAlbumsLeft = 0
        ..coreFans = 1e6
        ..fame = 0.4;
      final money = g.player.moneyCents;
      g.signLabel(Label.major);
      expect(g.player.label, Label.major);
      expect(g.player.contractAlbumsLeft, 3);
      expect(g.player.moneyCents, money + Label.major.advanceCents);
      // The label pays most of a campaign.
      final before = g.player.moneyCents;
      g.releaseSingle(song, campaign: Campaign.global);
      expect(before - g.player.moneyCents,
          (Campaign.global.costCents * Label.major.campaignShare).round());
      // After a flop, a major ends the contract.
      final p = g.world.player!
        ..eraOpen = true
        ..eraUnits = 1
        ..eraExpected = 1e6;
      Eras.close(g.world, p);
      expect(g.player.label, Label.independent);
      g.close();
    });

    test('Pitchwork reviews every album; better albums score higher', () {
      var g = GameSession.start(
          slots, _setup(premium: true, money: StartMoney.millionaire));
      final id = g.slotId;
      g.world.player!.moneyCents = 1 << 40;
      final good = [
        for (var i = 0; i < 3; i++) g.writeSong(budget: BudgetTier.high).id,
      ];
      // Written exhausted: half the quality (K46).
      final weak = <int>[];
      for (var i = 0; i < 3; i++) {
        g.world.player!
          ..creativeEnergy = 1
          ..burnoutUntilWeek = 0;
        weak.add(g.writeSong(budget: BudgetTier.low).id);
      }
      final a = g.releaseAlbum('Great', good, type: AlbumType.ep);
      final b = g.releaseAlbum('Poor', weak, type: AlbumType.ep);
      final r = g.advanceWeek();
      final reviews = r.events.whereType<CriticReview>().toList();
      expect(reviews.map((e) => e.albumId), containsAll([a.id, b.id]));
      expect(g.album(a.id).criticScore,
          greaterThan(g.album(b.id).criticScore + 1));
      final score = g.album(a.id).criticScore;
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.album(a.id).criticScore, score);
      g.close();
    });

    test('an early-2000s single sells CDs, not streams', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2002,
              premium: true,
              tier: StartTier.risingStar,
              money: StartMoney.comfortable));
      final song = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(song);
      for (var i = 0; i < 6; i++) {
        g.advanceWeek();
      }
      final s = g.song(song);
      expect(s.lifetimeStreams.total, 0);
      expect(s.lifetimePhysical, greaterThan(0));
      expect(s.singleSales, s.lifetimePhysical + s.lifetimeDownloads);
      expect(g.player.lifetimeSingleSales, closeTo(s.singleSales, 1e-6));
      expect(g.songHistory(song).map((h) => h.sales).reduce((a, b) => a + b),
          closeTo(s.lifetimePhysical + s.lifetimeDownloads, 1));
      expect(g.careerByYear().single.singleSales, greaterThan(0));
      expect(SalesEra.of(2002), SalesEra.physical);
      g.close();
    });

    test('the premium daily bonus is paid once a day', () {
      final g = GameSession.start(slots, _setup());
      final day = DateTime(2026, 5, 4, 10);
      expect(g.claimDailyBonus(premium: false, now: day), isFalse);
      expect(g.claimDailyBonus(premium: true, now: day), isTrue);
      expect(g.claimDailyBonus(premium: true, now: day), isFalse);
      expect(g.player.moneyCents, 500000 + Actions.dailyBonusCents);
      g.close();
    });
  });

  group('notifications and history', () {
    test('a superstar album debuts with first-week numbers and chart events',
        () {
      final g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      g.world.player!.moneyCents = 1 << 40;
      final songs = <int>[];
      while (songs.length < 12) {
        if (!g.player.canWrite || g.player.creativeEnergy < 30) {
          g.advanceWeek();
          continue;
        }
        songs.add(g.writeSong(budget: BudgetTier.high).id);
      }
      expect(g.player.everCharted, isFalse);
      // Big campaigns need a label that can run them (K54).
      if (g.player.label != Label.giant) g.signLabel(Label.giant);
      g.releaseSingle(songs.first, campaign: Campaign.global);
      final weekEvents = <GameEvent>[];
      for (var i = 0; i < 3; i++) {
        weekEvents.addAll(g.advanceWeek().events);
      }
      expect(weekEvents.whereType<ChartDebut>(), isNotEmpty);
      // The app celebrates the first ever chart entry once.
      expect(g.player.everCharted, isTrue);

      // Big campaigns need a label that can run them (K54).
      if (g.player.label != Label.giant) g.signLabel(Label.giant);
      g.releaseAlbum('Supernova', songs,
          variantWeeks: const [0, 0, 1], campaign: Campaign.intensive);
      final r = g.advanceWeek();
      final fw = r.events.whereType<AlbumFirstWeek>().single;
      expect(fw.usUnits, greaterThan(50000));
      expect(fw.usPosition, inInclusiveRange(1, 10));
      expect(r.hasMajor, isTrue);
      // Album chart debuts are folded into the first-week event.
      expect(
          r.events
              .whereType<ChartDebut>()
              .where((e) => e.kind == EntityKind.album),
          isEmpty);

      final view = g.album(fw.albumId);
      expect(view.firstWeekUsUnits, fw.usUnits);
      expect(view.trackIds.length, 12);

      final history = g.songHistory(songs.first);
      expect(history.length, 4);
      expect(
          history.any((h) => h.positions.containsKey(Charts.usSongs)), isTrue);
      expect(g.albumHistory(fw.albumId).single.value, view.weekUnits);

      // Streamify artist page: popular tracks, discography, listeners.
      final page = g.artistPage(g.player.id);
      expect(page.popular, isNotEmpty);
      expect(page.popular.length, lessThanOrEqualTo(10));
      expect(page.albums.single.title, 'Supernova');
      expect(page.monthlyListeners, greaterThan(0));
      // Monthly listeners follow the last weeks' average, not this week.
      expect(page.listenerStreams, greaterThan(0));
      expect(page.listenerStreams, isNot(page.weeklyStreams));
      final us = g.chart(Charts.usSongs);
      expect(us.rows.first.weekValue, greaterThan(us.rows.last.weekValue));
      final rival = g.artistPage(us.rows.first.artistId);
      expect(rival.popular, isNotEmpty);
      g.close();
    });

    test('year skip stops at a major event and sums up the year', () {
      final g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.risingStar,
              money: StartMoney.millionaire));
      final songs = [
        for (var i = 0; i < 3; i++) g.writeSong(budget: BudgetTier.high).id,
      ];
      // A rising star gets a mid-size label, which runs intensive campaigns.
      g.signLabel(Label.mid);
      g.releaseSingle(songs.first, campaign: Campaign.intensive);
      final y = g.advanceYear();
      expect(y.weeks, inInclusiveRange(1, 52));
      if (y.stoppedEarly) expect(y.events.any((e) => e.isMajor), isTrue);
      expect(y.streamsGained, greaterThan(0));

      final full = g.advanceYear(stopOnMajor: false);
      expect(full.weeks, 52);
      expect(full.stoppedEarly, isFalse);

      final career = g.careerByYear();
      expect(career.map((c) => c.year), containsAllInOrder([2018, 2019]));
      expect(career.first.streams, greaterThan(0));
      g.close();
    });

    test('a few weeks can be skipped, stopping at the first news', () {
      final g = GameSession.start(slots, _setup());
      final four = g.advanceWeeks(4, stop: SkipStop.never);
      expect(four.weeks, 4);
      expect(four.requestedWeeks, 4);
      expect(four.isYear, isFalse);
      expect(four.stoppedEarly, isFalse);

      // A released single makes news (a chart debut, a playlist or a peak)
      // sooner or later; the skip stops right after that week.
      final song = g.writeSong(budget: BudgetTier.low).id;
      g.releaseSingle(song);
      final until = g.advanceWeeks(52, stop: SkipStop.anyNews);
      final news = until.events.where((e) => !e.isIndustry);
      if (until.stoppedEarly) expect(news, isNotEmpty);
      expect(until.weeks, lessThanOrEqualTo(52));
      g.close();
    });

    test('the streaming platform launches in its real year with news', () {
      final g = GameSession.start(slots, _setup(startYear: 2008));
      final y = g.advanceWeeks(GameTime.weeksPerYear + 1, stop: SkipStop.never);
      final launches = y.events.whereType<PlatformLaunched>().toList();
      expect(launches.map((e) => e.chartId), [Charts.platformGlobal]);
      expect(GameTime.yearOf(g.week), 2009);
      g.close();
    });
  });
}
