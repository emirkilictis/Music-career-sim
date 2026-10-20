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

    test('a draft album waits in the vault, then comes out (F31)', () {
      var g = GameSession.start(
          slots, _setup(premium: true, money: StartMoney.millionaire));
      final id = g.slotId;
      List<int> write(int n) => [
            for (var i = 0; i < n; i++)
              (() {
                g.world.player!.creativeEnergy = 100;
                g.world.player!.burnoutUntilWeek = -1;
                return g.writeSong(budget: BudgetTier.low).id;
              })(),
          ];
      final songs = write(8);
      final money = g.player.moneyCents;
      final draft = g.saveDraft('Later', songs,
          variantWeeks: [0, 1], variantFormats: [null, EditionFormat.cd]);
      expect(draft.isDraft, isTrue);
      expect(draft.editionsCostCents, EditionFormat.cd.costCents);
      // Nothing paid yet; its songs are taken.
      expect(g.player.moneyCents, money);
      expect(
          () => g.releaseAlbum('Other', songs), _code('trackOnOtherRelease'));
      expect(() => g.reschedule(draft.id, releaseWeek: g.week + 2),
          _code('isDraft'));
      // A single from it may still come out first.
      g.releaseSingle(songs.first, campaign: Campaign.none);
      for (var i = 0; i < 30; i++) {
        g.advanceWeek();
      }
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.scheduled.single.isDraft, isTrue);
      expect(g.albums, isEmpty);
      final before = g.player.moneyCents;
      final album = g.releaseDraft(draft.id, campaign: Campaign.none);
      expect(album.scheduleId, draft.id);
      expect(album.trackIds, songs);
      expect(before - g.player.moneyCents, EditionFormat.cd.costCents);
      expect(g.scheduled, isEmpty);

      // Another draft, dated later: it comes out on its week.
      final second = g.saveDraft('Even later', write(3), type: AlbumType.ep);
      expect(() => g.releaseDraft(-5), _code('notScheduled'));
      final dated = g.scheduleDraft(second.id,
          campaign: Campaign.none,
          releaseWeek: g.week + 2,
          announceWeek: g.week + 2);
      expect(dated.isDraft, isFalse);
      expect(dated.id, second.id);
      final outs = [
        for (var i = 0; i < 3; i++)
          ...g.advanceWeek().events.whereType<ReleaseOut>()
      ];
      expect(outs.single.scheduleId, second.id);
      // A draft can also just be thrown away.
      final third = g.saveDraft('Never', write(3), type: AlbumType.ep);
      g.cancelScheduled(third.id);
      expect(g.scheduled, isEmpty);
      g.close();
    });

    test('a range before release, the real grade after (F36)', () {
      var g = GameSession.start(slots, _setup());
      final id = g.slotId;
      final song = g.writeSong(budget: BudgetTier.low);
      final spread = g.world.songs[song.id].gradeSpread;
      expect(spread, greaterThan(0));
      expect(song.grade, -1);
      expect(song.gradeLow, lessThan(song.estimatedGrade));
      expect(song.gradeHigh, greaterThan(song.estimatedGrade));
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.world.songs[song.id].gradeSpread, spread);
      g.releaseSingle(song.id, campaign: Campaign.none);
      expect(g.song(song.id).grade, g.world.songs[song.id].quality.round());
      g.close();
    });

    test('the career list shows the latest album (E9)', () {
      final g = GameSession.start(slots, _setup());
      final ids = [
        for (var i = 0; i < 3; i++)
          (() {
            g.world.player!.creativeEnergy = 100;
            return g.writeSong(budget: BudgetTier.low).id;
          })(),
      ];
      g.releaseAlbum('First Steps', ids,
          type: AlbumType.ep, campaign: Campaign.none);
      g.close();
      final summary = slots.list().single;
      expect(summary['lastAlbumTitle'], 'First Steps');
      expect(summary['lastAlbumId'], isNonNegative);
    });

    test('piled-up skill points shrink to what is usable (F34)', () {
      var g = GameSession.start(slots, _setup());
      final id = g.slotId;
      final p = g.world.player!;
      final room = Actions.skillRoom(p);
      p.skillPoints = 5000; // as saved before F34
      g.world.dirtyArtists.add(p.id);
      g.writeSong(budget: BudgetTier.low); // any action saves
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.player.skillPoints, room);
      final before = g.player.skills[SkillKind.vocals]!;
      expect(g.spendSkillPoints(SkillKind.vocals, 10), 10);
      expect(g.player.skills[SkillKind.vocals], before + 10);
      expect(g.spreadSkillPoints(), room - 10);
      expect(g.player.skillPoints, 0);
      g.close();
    });

    test('older saves get the independent reach of docs K70', () {
      var g = GameSession.start(slots, _setup());
      final id = g.slotId;
      final p = g.world.player!;
      expect(p.labelReach, Label.independent.reach);
      p.labelReach = 0.7; // as saved before K70
      g.world.dirtyArtists.add(p.id);
      g.writeSong(budget: BudgetTier.low); // any action saves
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.world.player!.labelReach, 0.85);
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

    test('a tour is planned, survives reopening and is reported (K63)', () {
      var g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final id = g.slotId;
      const request = TourRequest(
          name: 'Neon Nights',
          legs: [TourLeg(TourMarket.usa, TourKind.club, 6)]);
      final plan = g.tourPreview(request);
      expect(plan.available, isTrue);
      expect(plan.schedule.length, 6);
      expect(plan.weeks, 2);
      expect(plan.legs.single.tickets, greaterThan(0));
      expect(g.tourPreview(const TourRequest(legs: [])).problems,
          contains('tourMarkets'));
      expect(
          () => g.startTour(const TourRequest(legs: [])), _code('tourMarkets'));
      final opener = g.tourOpeners.first;
      g.startTour(TourRequest(
          name: request.name, legs: request.legs, openerId: opener.artistId));
      expect(g.player.tour?.weeks, 2);
      expect(g.player.tour?.name, 'Neon Nights');
      expect(g.player.tour?.openerName, opener.name);
      expect(() => g.startTour(request), _code('onTour'));
      expect(
          g.milestones
              .firstWhere((m) => m.milestone == Milestone.firstTour)
              .reached,
          isTrue);
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.player.tour?.kind, TourKind.club);
      expect(g.player.tour?.thisWeek.length, 3);
      final events = <GameEvent>[];
      for (var i = 0; i < 2; i++) {
        events.addAll(g.advanceWeek().events);
      }
      final done = events.whereType<TourFinished>().single;
      expect(done.name, 'Neon Nights');
      expect(done.shows, 6);
      expect(g.player.tour, isNull);
      g.close();
    });

    test('songs on no album count in the career units (K99)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2017,
              premium: true,
              tier: StartTier.risingStar,
              money: StartMoney.millionaire));
      final song = g.writeSong(budget: BudgetTier.high);
      g.releaseSingle(song.id);
      for (var i = 0; i < 3; i++) {
        g.advanceWeek();
      }
      final p = g.player;
      expect(p.lifetimeUnits.total, 0);
      final s = g.song(song.id);
      final expected = s.lifetimeStreams.total / 1500 +
          (s.lifetimeDownloads + s.lifetimePhysical) / 10;
      expect(p.lifetimeTotalUnits.total, closeTo(expected, expected * 0.01));
      expect(p.lifetimeTotalUnits.total, greaterThan(0));
      g.close();
    });

    test('streaming tools: pitch, autoplay, bought streams (K95-K97)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2021,
              premium: true,
              tier: StartTier.risingStar,
              money: StartMoney.millionaire));
      // Pitched and in autoplay before it comes out (docs K101).
      final song = g.writeSong(budget: BudgetTier.high);
      expect(g.song(song.id).canPitch, isTrue);
      g.pitchSong(song.id);
      expect(g.song(song.id).canPitch, isFalse);
      expect(() => g.pitchSong(song.id), _code('cannotPitch'));
      g.setAutoplay(song.id, true);
      expect(g.song(song.id).autoplay, isTrue);
      expect(g.song(song.id).pitchAnswerWeek, -1);
      g.advanceWeek();
      g.releaseSingle(song.id);
      expect(g.song(song.id).pitchAnswerWeek, g.week);
      final events = g.advanceWeek().events;
      expect(
          events.any((e) =>
              (e is PlaylistAdded && e.songId == song.id) ||
              (e is PitchDeclined && e.songId == song.id)),
          isTrue);
      g.buyBots(song.id, BotPackage.large);
      expect(() => g.buyBots(song.id, BotPackage.small), _code('botsBusy'));
      expect(g.song(song.id).botStatus, BotStatus.running);
      final later = <GameEvent>[];
      for (var i = 0; i < 4; i++) {
        later.addAll(g.advanceWeek().events);
      }
      final view = g.song(song.id);
      final caught = later.whereType<BotsCaught>().toList();
      expect(view.botWeeksLeft, 0);
      if (caught.isNotEmpty) {
        expect(view.botStatus, BotStatus.caught);
        expect(view.botRemoved, greaterThan(0));
      } else {
        expect(view.botStatus, BotStatus.running);
      }
      g.close();

      final old = GameSession.start(slots, _setup(startYear: 2005));
      final s2 = old.writeSong(budget: BudgetTier.low);
      old.releaseSingle(s2.id);
      expect(() => old.buyBots(s2.id, BotPackage.small), _code('noStreaming'));
      expect(() => old.setAutoplay(s2.id, true), _code('noStreaming'));
      old.close();
    });

    test('social media: posts, fan replies and reactions (K93)', () {
      var g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final id = g.slotId;
      expect(g.social.network, SocialNetwork.chirper);
      expect(g.social.items, isEmpty);
      expect(() => g.post(PostKind.teaser), _code('nothingToTease'));
      final song = g.writeSong(budget: BudgetTier.high);
      final hype = g.player.hype;
      g.post(PostKind.teaser);
      expect(g.player.hype, greaterThan(hype));
      final feed = g.social.items;
      // The post first, the replies under it.
      expect(feed.first.isPlayer, isTrue);
      expect(feed.first.topic, FanTopic.postTeaser);
      expect(feed[1].topic, FanTopic.replyTeaser);
      expect(feed.first.likes, greaterThan(0));
      g.post(PostKind.fans);
      g.post(PostKind.studio);
      expect(g.social.postsLeft, 0);
      expect(() => g.post(PostKind.studio), _code('postLimit'));
      // Fans react to a release the week it comes out.
      g.releaseSingle(song.id);
      g.advanceWeek();
      final reactions = g.social.items.where((i) =>
          i.topic == FanTopic.releaseLove ||
          i.topic == FanTopic.releaseMixed ||
          i.topic == FanTopic.releaseHate);
      expect(reactions, hasLength(2));
      expect(reactions.first.title, song.title);
      expect(g.social.postsLeft, Social.postsPerWeek);
      g.post(PostKind.promote, songId: song.id);
      final count = g.social.items.length;
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.social.items.length, count);
      g.close();

      // Before social media there is only the fan forum.
      final old = GameSession.start(slots, _setup(startYear: 2002));
      expect(old.social.network, SocialNetwork.forum);
      expect(() => old.post(PostKind.fans), _code('socialLocked'));
      old.close();
    });

    test('award shows: invitation, the night and the results (K91)', () {
      var g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final id = g.slotId;
      expect(g.awardYears.first, 2018);
      final song = g.writeSong(budget: BudgetTier.high);
      // Put the player on the 2018 ballot (nominated in November 2017).
      final race = Awards.showFor(g.world, 2018)!.races.first;
      race.nominees[1] = AwardNominee(song.id, g.world.playerArtistId);
      expect(g.awardShow(2018)!.playerNominations, 1);
      final events = <GameEvent>[];
      while (GameTime.weekOfYear(g.week) <= Awards.ceremonyWeekOfYear) {
        final week = g.advanceWeek().events;
        events.addAll(week);
        if (week.any(
            (e) => e is OpportunityCame && e.kind == OpportunityKind.award)) {
          expect(g.player.opportunity!.nominations, 1);
          expect(g.player.opportunity!.weeksLeft, 1);
          g.answerOpportunity(OpportunityChoice.perform);
        }
      }
      final results = events.whereType<AwardResults>().single;
      expect(results.year, 2018);
      expect(results.nominations, 1);
      expect(results.attendance, AwardAttendance.perform);
      expect(results.fans, greaterThan(0));
      expect(events.whereType<AwardWinners>(), hasLength(1));
      final show = g.awardShow(2018)!;
      expect(show.held, isTrue);
      final mine = show.races.first.nominees.firstWhere((n) => n.isPlayer);
      expect(mine.title, song.title);
      expect(results.won.length, mine.isWinner ? 1 : 0);
      expect(g.player.awardNominations, 1);
      expect(g.player.awardWins, results.won.length);
      // Kept across reopening.
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.awardShow(2018)!.held, isTrue);
      expect(g.player.awardNominations, 1);
      g.close();
    });

    test('festivals are booked, played and kept across reopening (K77)', () {
      var g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final id = g.slotId;
      final list = g.festivals;
      expect(list.length, Festivals.all.length);
      expect(list.first.week, lessThanOrEqualTo(list.last.week));
      final pick = list.firstWhere((f) => f.canBook);
      expect(pick.slot, FestivalSlot.headliner);
      expect(pick.feeCents, greaterThan(0));
      g.bookFestival(pick.index);
      expect(() => g.bookFestival(pick.index), _code('festivalBooked'));
      final bill = g.festivalLineup(pick.index, pick.year);
      expect(bill[FestivalSlot.headliner]!.any((a) => a.isPlayer), isTrue);
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.festivals.firstWhere((f) => f.index == pick.index).booked,
          FestivalSlot.headliner);
      final events = <GameEvent>[];
      while (g.week <= pick.week) {
        events.addAll(g.advanceWeek().events);
      }
      final played = events.whereType<FestivalPlayed>().single;
      expect(played.festival, pick.festival.name);
      expect(played.feeCents, pick.feeCents);
      g.close();
    });

    test('the box office ranks rivals and the player (K77)', () {
      final g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      for (var i = 0; i < 30; i++) {
        g.advanceWeek();
      }
      final year = g.year;
      final top = g.topTours(year);
      expect(top, isNotEmpty);
      expect(top.first.rank, 1);
      expect(top.first.grossCents, greaterThanOrEqualTo(top.last.grossCents));
      // Stadiums need a fandom the superstar start has to grow into (K127).
      g.world.player!.coreFans = 6e6;
      g.startTour(const TourRequest(
          name: 'Big Night',
          legs: [TourLeg(TourMarket.usa, TourKind.stadium, 6)]));
      g.advanceWeek();
      final mine = g.topTours(year).where((r) => r.isPlayer).single;
      expect(mine.tourName, 'Big Night');
      expect(mine.onGoing, isTrue);
      expect(g.allTimeTours(), isNotEmpty);
      expect(g.firstTourYear, lessThanOrEqualTo(year));
      g.close();
    });

    test('platforms open in their years and split real numbers (K67)', () {
      expect([for (final p in Platforms.openIn(2002)) p], isEmpty);
      expect(Platforms.openIn(2006),
          [MusicPlatform.fruitTunes, MusicPlatform.viewTube]);
      for (var y = 2005; y <= 2030; y++) {
        final total =
            MusicPlatform.values.fold(0.0, (t, p) => t + p.streamShare(y));
        expect(total, closeTo(1.0, 1e-9), reason: '$y');
      }
      final g = GameSession.start(slots, _setup(startYear: 2018));
      final song = g.writeSong(budget: BudgetTier.low).id;
      g.releaseSingle(song);
      for (var i = 0; i < 3; i++) {
        g.advanceWeek();
      }
      final open = g.platforms;
      expect([for (final v in open) v.platform], MusicPlatform.values);
      final streamify =
          open.firstWhere((v) => v.platform == MusicPlatform.streamify);
      expect(streamify.playerWeek, greaterThan(0));
      expect(streamify.rows.length, Platforms.chartSize);
      for (var i = 1; i < streamify.rows.length; i++) {
        expect(streamify.rows[i].value,
            lessThanOrEqualTo(streamify.rows[i - 1].value));
      }
      // Streamify's share of the song's streams is the familiar 45%.
      expect(streamify.playerWeek,
          closeTo(g.song(song).weekStreams * Streamify.share, 1));
      g.close();
    });

    test('managers want fans and stay hired across reopening (K68)', () {
      var g = GameSession.start(slots, _setup());
      final id = g.slotId;
      expect(() => g.hireManager(Manager.star), throwsA(isA<GameException>()));
      g.hireManager(Manager.local);
      expect(g.player.manager, Manager.local);
      expect(() => g.hireManager(Manager.local), throwsA(isA<GameException>()));
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.player.manager, Manager.local);
      g.hireManager(Manager.none);
      expect(g.player.manager, Manager.none);
      g.close();
    });

    test(
        'same-week releases make a chart battle; rival albums show ahead '
        '(K69)', () {
      final g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final w = g.world;
      final rival = w.artists.firstWhere(
          (a) => a.tier == ArtistTier.a && !a.isRetired && a.plan.isEmpty);
      // Known two months ahead.
      rival.plan.add(PlannedRelease(week: w.week + 3, kind: PlannedKind.album));
      rival.pendingAlbumTitle = 'Big Return';
      expect(
          g.upcomingRivalAlbums
              .any((u) => u.artistId == rival.id && u.title == 'Big Return'),
          isTrue);
      rival.plan.clear();
      // Both albums out this week.
      final theirs = [
        for (var i = 0; i < 10; i++)
          Actions.writeSong(w, rival, producerSkill: 80, aiMode: true).id,
      ];
      Actions.releaseAlbum(w, rival, 'Theirs', theirs);
      final mine = <int>[];
      for (var i = 0; i < 8; i++) {
        w.player!.creativeEnergy = 100;
        w.player!.burnoutUntilWeek = -1;
        mine.add(g.writeSong(budget: BudgetTier.high).id);
      }
      g.releaseAlbum('Mine', mine);
      final events = g.advanceWeek().events;
      final battle = events.whereType<ChartBattle>().single;
      expect(battle.kind, EntityKind.album);
      // The biggest rival album out this week (ours or another star's).
      final week = g.world.week - 1;
      final rivalAlbums = [
        for (final al in w.albums)
          if (al.releaseWeek == week && al.artistId != w.playerArtistId) al
      ];
      final theirsOut = rivalAlbums.firstWhere((al) => al.title == 'Theirs');
      final battled =
          rivalAlbums.firstWhere((al) => al.id == battle.rivalEntityId);
      expect(battled.artistId, battle.rivalArtistId);
      expect(battled.firstWeekUnits,
          greaterThanOrEqualTo(theirsOut.firstWeekUnits));
      expect(
          battle.won,
          battle.playerPosition > 0 &&
              (battle.rivalPosition == 0 ||
                  battle.playerPosition < battle.rivalPosition));
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
      // The first release is a milestone, paid in skill points (K61).
      final first =
          g.milestones.firstWhere((m) => m.milestone == Milestone.firstRelease);
      expect(first.reached, isTrue);
      // Income and costs per release (docs K60).
      expect(g.song(song).revenueCents, greaterThan(0));
      expect(g.song(song).costsCents, greaterThan(0));
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

    test('a long campaign takes pre-orders that ship in week one (K126)', () {
      (double, double, AlbumView) run(int leadWeeks) {
        var g = GameSession.start(
            slots,
            _setup(
                premium: true,
                tier: StartTier.superstar,
                money: StartMoney.millionaire));
        final slot = g.slotId;
        g.world.player!.moneyCents = 1 << 40;
        final songs = <int>[];
        for (var i = 0; i < 8; i++) {
          g.world.player!.creativeEnergy = 100;
          songs.add(g.writeSong(budget: BudgetTier.high).id);
        }
        final release = g.week + 24;
        g.scheduleAlbum('Big', songs,
            releaseWeek: release, announceWeek: release - leadWeeks);
        g.advanceWeeks(20, stop: SkipStop.never);
        final ordered = g.scheduled.single.preOrders;
        // Kept through a save.
        g.close();
        g = GameSession.resume(slots, slot);
        expect(g.scheduled.single.preOrders, ordered);
        AlbumFirstWeek? fw;
        while (fw == null) {
          fw = g.advanceWeek().events.whereType<AlbumFirstWeek>().firstOrNull;
        }
        final al = g.albums.single;
        g.close();
        return (ordered, al.firstWeekPure, al);
      }

      final (shortOrders, shortWeek, short) = run(6);
      final (longOrders, longWeek, long) = run(24);
      expect(longOrders, greaterThan(shortOrders * 1.5));
      expect(long.preOrders, greaterThanOrEqualTo(longOrders));
      expect(long.firstWeekPure, greaterThan(long.preOrders));
      expect(longWeek, greaterThan(shortWeek));
      expect(short.preOrders, greaterThan(0));
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
      // Less than before K127: the lifts saturate sooner.
      expect(withVideo, greaterThan(without * 1.07));
    });

    test('radio push: paid apart, heavy needs a bigger label (K84)', () {
      final g = GameSession.start(slots, _setup(path: CareerPath.smallLabel));
      g.world.player!.moneyCents = 1 << 40;
      final a = g.writeSong(budget: BudgetTier.low).id;
      final b = g.writeSong(budget: BudgetTier.low).id;
      // A small label can't arrange heavy rotation.
      expect(g.maxRadioPush, RadioPush.standard);
      expect(() => g.releaseSingle(a, radio: RadioPush.heavy),
          _code('radioLocked'));
      final before = g.player.moneyCents;
      g.releaseSingle(a, radio: RadioPush.standard);
      expect(before - g.player.moneyCents,
          g.radioPushCosts[RadioPush.standard]! + g.player.campaignCosts[1]);
      expect(g.song(a).radioPush, RadioPush.standard);
      // A scheduled single keeps its push across reopening.
      final now = g.week;
      g.scheduleSingle(b,
          radio: RadioPush.standard, releaseWeek: now + 3, announceWeek: now);
      final id = g.slotId;
      g.close();
      final h = GameSession.resume(slots, id);
      expect(h.scheduled.single.radioPush, RadioPush.standard);
      for (var i = 0; i < 3; i++) {
        h.advanceWeek();
      }
      expect(h.song(b).radioPush, RadioPush.standard);
      expect(h.song(a).radioPush, RadioPush.standard);
      h.close();
    });

    test('a profile with followers on every platform (K82)', () {
      final g = GameSession.start(slots, _setup(path: CareerPath.smallLabel));
      g.world.player!
        ..coreFans = 1e6
        ..casual = 1e7;
      final year = GameTime.yearOf(g.world.week);
      double? f(MusicPlatform p) =>
          Platforms.followers(g.world, g.world.player!, p, year);
      // The download store has no followers; the big app has the most.
      expect(f(MusicPlatform.fruitTunes), isNull);
      for (final p in Platforms.openIn(year)) {
        if (p == MusicPlatform.fruitTunes) continue;
        expect(f(p), greaterThan(0));
        expect(f(p), lessThanOrEqualTo(f(MusicPlatform.streamify)!));
      }
      final view = g.platform(MusicPlatform.streamify);
      expect(view.profile!.name, g.player.name);
      expect(view.profile!.followers, f(MusicPlatform.streamify));
      expect(view.profile!.verified, isTrue);
      expect(g.artistPage(g.player.id).followers, f(MusicPlatform.streamify));
      g.close();
    });

    test('year-end charts come out in December (K110), records (K111)', () {
      final g = GameSession.start(
          slots, _setup(tier: StartTier.superstar, premium: true));
      expect(g.yearEndYears, isEmpty);
      YearEndCharts? news;
      while (GameTime.weekOfYear(g.week) != YearEnd.publishWeekOfYear + 1) {
        for (final e in g.advanceWeek().events) {
          if (e is YearEndCharts) news = e;
        }
      }
      expect(news, isNotNull);
      expect(news!.year, 2018);
      expect(g.yearEndYears, [2018]);
      final songs = g.yearEnd(Charts.usSongs, 2018);
      expect(songs.length, YearEnd.size);
      expect([for (final r in songs) r.rank],
          [for (var i = 1; i <= YearEnd.size; i++) i]);
      for (var i = 1; i < songs.length; i++) {
        expect(songs[i].points, lessThanOrEqualTo(songs[i - 1].points));
      }
      expect(songs.first.entityId, news.topSongId);
      expect(songs.first.peak, lessThanOrEqualTo(10));
      // The player's entries are the ones the news names.
      expect([for (final r in songs) if (r.isPlayer) (r.rank, r.entityId)],
          news.songs);
      expect(g.yearEnd(Charts.usAlbums, 2018), isNotEmpty);

      // All-time records from the same history (K111).
      final records = g.records;
      for (final k in RecordKind.values) {
        final board = records[k]!;
        expect(board, isNotEmpty, reason: k.name);
        expect(board.length, lessThanOrEqualTo(10));
        for (var i = 1; i < board.length; i++) {
          expect(board[i].value, lessThanOrEqualTo(board[i - 1].value));
        }
      }
      // Weeks at #1: the year-end #1 song's run counts.
      final no1 = records[RecordKind.weeksAtNo1Song]!.first;
      final runs = g.chartRun(EntityKind.song, no1.entityId).where((w) =>
          w.entries[Charts.usSongs]?.position == 1);
      expect(no1.value, runs.length);
      // Honours (K116): a player with nothing out holds none.
      final h = g.honors;
      expect(h.recordsHeld, isEmpty);
      expect(h.bestYearEndSong, isNull);
      expect(h.isEmpty, isTrue);
      g.close();
    });

    test('editorial playlists rank last week, editors\' picks first (K125)',
        () {
      final g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final w = g.world;
      w.player!.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(id);
      g.advanceWeek();
      expect(Editorial.playlists(w), EditorialPlaylist.values);
      final hot = Editorial.view(w, EditorialPlaylist.hotRightNow);
      expect(hot.rows.length, Editorial.size);
      expect(hot.followers, greaterThan(0));
      expect([for (final r in hot.rows) r.position],
          [for (var i = 1; i <= Editorial.size; i++) i]);
      // New releases only: out last week.
      final fresh = Editorial.view(w, EditorialPlaylist.freshFriday);
      expect(fresh.rows, isNotEmpty);
      for (final r in fresh.rows) {
        final s = w.songs[r.songId];
        expect(s.releasedWeek == w.week - 1 || s.singleWeek == w.week - 1,
            isTrue);
      }
      expect(fresh.rows.any((r) => r.songId == id), isTrue);
      // Genre playlists play their genres.
      final pop = Editorial.view(w, EditorialPlaylist.popRising);
      for (final r in pop.rows) {
        expect(w.songs[r.songId].genres, contains(0));
      }
      // The song page lists the same places.
      for (final pl in Editorial.placements(w, id)) {
        final rows = Editorial.view(w, pl.playlist).rows;
        expect(rows[pl.position - 1].songId, id);
      }
      expect(
          Editorial.placements(w, id)
              .any((pl) => pl.playlist == EditorialPlaylist.freshFriday),
          isTrue);
      g.close();
    });

    test('the artist page shows listeners over time and top cities (K130)',
        () {
      final g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      g.world.player!.creativeEnergy = 100;
      g.releaseSingle(g.writeSong(budget: BudgetTier.high).id);
      g.advanceWeeks(6, stop: SkipStop.never);
      final page = g.artistPage(g.player.id);
      expect(page.listenerHistory.length, inInclusiveRange(3, 26));
      expect(page.listenerHistory.last, greaterThan(0));
      final cities = page.topCities;
      expect(cities.length, 5);
      for (var i = 1; i < cities.length; i++) {
        expect(cities[i].listeners, lessThanOrEqualTo(cities[i - 1].listeners));
      }
      expect(cities.fold(0.0, (t, c) => t + c.listeners),
          lessThan(page.monthlyListeners));
      // A K-pop act is big in Seoul.
      final kpop = Streamify.topCities(
          const [0.2, 0.2, 0.6], HomeCountry.other, 18, 1e6);
      expect(kpop.map((c) => c.name), contains('Seoul'));
      // Rivals' pages have no history.
      final rival = g.world.artists
          .firstWhere((a) => a.tier == ArtistTier.a && !a.isRetired);
      expect(g.artistPage(rival.id).listenerHistory, isEmpty);
      g.close();
    });

    test('creators paid to use the sound, for four weeks (K131)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2020,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final slot = g.slotId;
      g.world.player!.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      // Not before it is out.
      expect(g.song(id).creatorCosts, isEmpty);
      g.releaseSingle(id);
      final costs = g.song(id).creatorCosts;
      expect(costs.keys, CreatorCampaign.values);
      expect(costs[CreatorCampaign.large]!,
          greaterThan(costs[CreatorCampaign.small]!));
      final money = g.player.moneyCents;
      g.runCreators(id, CreatorCampaign.large);
      expect(g.player.moneyCents, money - costs[CreatorCampaign.large]!);
      final s = g.world.songs[id];
      expect(s.viralBoost, greaterThan(0));
      expect(StreamingTools.creatorChance(s, g.week), 25);
      expect(() => g.runCreators(id, CreatorCampaign.small),
          _code('cannotRunCreators'));
      // Kept through a save.
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.song(id).creatorTier, CreatorCampaign.large);
      final events = <GameEvent>[];
      for (var i = 0; i < CreatorCampaign.weeks; i++) {
        events.addAll(g.advanceWeek().events);
      }
      final result = g.song(id).creatorResult;
      expect(result, isNot(CreatorResult.running));
      expect(events.whereType<CreatorsFlopped>().isNotEmpty,
          result == CreatorResult.flopped);
      expect(StreamingTools.creatorChance(g.world.songs[id], g.week), 1);
      g.close();
    });

    test('play milestones and the Billions Club (K132)', () {
      final g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      g.world.player!.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(id, campaign: Campaign.standard);
      g.advanceWeek();
      // Just short of 100M plays: next week crosses it.
      final s = g.world.songs[id];
      s.reg[SongReg.lifeStreams] += Platforms.playMilestones.first /
              Streamify.share -
          Platforms.streamifyPlays(g.world, s) / Streamify.share -
          1000;
      final hits = g.advanceWeek().events.whereType<StreamMilestone>().toList();
      expect(hits.length, 1);
      expect(hits.first.songId, id);
      expect(hits.first.plays, Platforms.playMilestones.first);
      expect(Platforms.streamifyPlays(g.world, g.world.songs[id]),
          greaterThanOrEqualTo(hits.first.plays));
      // The club: real hits from before, a billion and up, best first.
      final club = g.billionsClub;
      expect(club, isNotEmpty);
      for (var i = 0; i < club.length; i++) {
        expect(club[i].plays, greaterThanOrEqualTo(Platforms.billionsClub));
        if (i > 0) expect(club[i].plays, lessThanOrEqualTo(club[i - 1].plays));
      }
      g.close();
    });

    test('the radio chart ranks US airplay (K129)', () {
      final g = GameSession.start(slots, _setup());
      g.advanceWeeks(3, stop: SkipStop.never);
      final radio = g.chart(Charts.usRadio);
      expect(radio.rows.length, 50);
      for (var i = 1; i < radio.rows.length; i++) {
        expect(radio.rows[i].points, lessThanOrEqualTo(radio.rows[i - 1].points));
      }
      // The audience it counts is the song's US radio.
      final top = g.world.songs[radio.rows.first.entityId];
      expect(top.weekRadio, greaterThan(0));
      g.close();
    });

    test('a single worked to another radio format (K134)', () {
      var g = GameSession.start(slots, _setup());
      final slot = g.slotId;
      g.world.player!.moneyCents = 1 << 40;
      g.world.player!.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.low, genres: [0]).id;
      g.releaseSingle(id, radio: RadioPush.standard);
      expect(g.song(id).radioFormat, RadioFormat.top40);
      expect(g.song(id).radioFormatOptions[RadioFormat.hotAc]!.$2,
          closeTo(1.5, 1e-9));
      g.setRadioFormat(id, RadioFormat.hotAc);
      expect(g.song(id).radioFormat, RadioFormat.hotAc);
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.song(id).radioFormat, RadioFormat.hotAc);
      g.advanceWeeks(Actions.radioUpgradeWeeks, stop: SkipStop.never);
      expect(g.song(id).radioFormatOptions, isEmpty);
      expect(() => g.setRadioFormat(id, RadioFormat.top40), _code('radioLocked'));
      g.close();
    });

    test('autoplay levels and a radio push raised after release (K128)', () {
      var g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final slot = g.slotId;
      g.world.player!.moneyCents = 1 << 40;
      if (g.player.label.index < Label.major.index) g.signLabel(Label.major);
      g.world.player!.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(id, radio: RadioPush.standard);
      g.setAutoplayLevel(id, AutoplayLevel.max);
      expect(g.song(id).autoplayLevel, AutoplayLevel.max);
      expect(g.song(id).autoplay, isTrue);
      // Raise the push while the stations decide.
      final costs = g.song(id).radioUpgradeCosts;
      expect(costs.keys, [RadioPush.heavy, RadioPush.blitz]);
      final money = g.world.player!.moneyCents;
      g.upgradeRadio(id, RadioPush.heavy);
      expect(g.world.player!.moneyCents, money - costs[RadioPush.heavy]!);
      expect(g.song(id).radioPush, RadioPush.heavy);
      expect(() => g.upgradeRadio(id, RadioPush.light), _code('radioLocked'));
      g.advanceWeek();
      expect(g.song(id).radioSpins, greaterThan(0));
      expect(g.song(id).radioStations, greaterThan(0));
      // Kept through a save.
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.song(id).autoplayLevel, AutoplayLevel.max);
      expect(g.song(id).radioPush, RadioPush.heavy);
      // Too late after eight weeks.
      g.advanceWeeks(Actions.radioUpgradeWeeks, stop: SkipStop.never);
      expect(g.song(id).radioUpgradeCosts, isEmpty);
      expect(() => g.upgradeRadio(id, RadioPush.blitz), _code('radioLocked'));
      g.close();
    });

    test('a surprise drop makes headlines for a known name (K124)', () {
      final g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      List<int> songs(int n) => [
            for (var i = 0; i < n; i++)
              (() {
                p.creativeEnergy = 100;
                return g.writeSong(budget: BudgetTier.low).id;
              })(),
          ];
      final first = songs(4);
      final shock = Actions.surpriseShock(g.world, p, AlbumType.ep, first);
      expect(shock, greaterThan(0.3));
      final hype = p.hype;
      final ep = g.releaseAlbum('Out Of Nowhere', first, type: AlbumType.ep);
      expect(p.hype - hype,
          closeTo(g.world.config.announceBuzzCap(AlbumType.ep, p.fame) * shock,
              1e-9));
      expect(p.surpriseWeek, g.week);
      final events = g.advanceWeek().events;
      expect(events.whereType<SurpriseDrop>().single.albumId, ep.id);
      // The trick again soon after: less noise.
      final second = songs(4);
      expect(Actions.surpriseShock(g.world, p, AlbumType.ep, second),
          closeTo(shock * 0.4, 0.05));
      // With a single from it out already, it is no surprise.
      g.releaseSingle(second.first, campaign: Campaign.none);
      expect(Actions.surpriseShock(g.world, p, AlbumType.ep, second), 0);
      // Nobody notices an unknown's.
      p.fame = 0.1;
      expect(Actions.surpriseShock(g.world, p, AlbumType.album, songs(1)), 0);
      g.close();
    });

    test('the year on the streaming app comes out in December (K123)', () {
      final g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      g.world.player!.creativeEnergy = 100;
      final a = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(a);
      g.advanceWeeks(3, stop: SkipStop.never);
      g.world.player!.creativeEnergy = 100;
      final b = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(b);
      expect(g.wrappedYears, isEmpty);
      WrappedOut? news;
      while (GameTime.weekOfYear(g.week) != Wrapped.publishWeekOfYear + 1) {
        for (final e in g.advanceWeek().events) {
          if (e is WrappedOut) news = e;
        }
      }
      expect(news, isNotNull);
      expect(news!.year, g.year);
      expect(g.wrappedYears, [g.year]);
      final wr = g.wrapped(g.year)!;
      expect(wr.plays, closeTo(news.plays, 1));
      expect(wr.minutes, closeTo(wr.plays * Wrapped.minutesPerPlay, 1));
      expect(wr.story, WrappedStory.newcomer);
      expect(wr.growthPct, isNull);
      expect(wr.topSongs.length, 2);
      expect(wr.topSongs.first.songId, news.topSongId);
      expect(wr.topSongs.first.plays,
          greaterThanOrEqualTo(wr.topSongs.last.plays));
      expect(wr.topSongs.fold(0.0, (t, s) => t + s.plays),
          closeTo(wr.plays, 1));
      expect(wr.regionShare.fold(0.0, (t, v) => t + v), closeTo(1, 1e-9));
      expect(wr.peakListeners, greaterThan(0));
      expect(wr.newSongs, 2);
      expect(wr.topFans, greaterThan(0));
      expect(g.wrapped(g.year - 1), isNull);
      g.close();
    });

    test('a deluxe edition adds bonus tracks once and survives a save (K115)',
        () {
      var g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final id = g.slotId;
      final tracks = <int>[];
      for (var i = 0; i < 8; i++) {
        g.world.player!.creativeEnergy = 100;
        tracks.add(g.writeSong(budget: BudgetTier.low).id);
      }
      final album = g.releaseAlbum('Base', tracks).id;
      g.advanceWeeks(3, stop: SkipStop.never);
      final bonus = <int>[];
      for (var i = 0; i < 2; i++) {
        g.world.player!.creativeEnergy = 100;
        bonus.add(g.writeSong(budget: BudgetTier.low).id);
      }
      expect(g.album(album).canDeluxe, isTrue);
      final money = g.player.moneyCents;
      g.releaseDeluxe(album, bonus);
      expect(money - g.player.moneyCents, EditionFormat.deluxe.costCents);
      final v = g.album(album);
      expect(v.trackIds, [...tracks, ...bonus]);
      expect(v.isDeluxe, isTrue);
      expect(v.canDeluxe, isFalse);
      for (final s in bonus) {
        expect(g.song(s).inVault, isFalse);
      }
      expect(() => g.releaseDeluxe(album, bonus), _code('deluxeOut'));
      g.advanceWeek();
      // Fans talk about it (K115).
      expect(g.world.social.feed.any((i) => i.topic == FanTopic.deluxeOut),
          isTrue);
      g.close();
      g = GameSession.resume(slots, id);
      expect(g.album(album).trackIds, [...tracks, ...bonus]);
      expect(g.album(album).isDeluxe, isTrue);
      g.close();
    });

    test('video views: audio first, the official video pulls more (K118)',
        () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      g.world.player!.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(id, campaign: Campaign.none);
      g.advanceWeeks(4, stop: SkipStop.never);
      final s = g.world.songs[id];
      final audio = Platforms.videoViews(g.world, s);
      expect(audio, greaterThan(0));
      g.shootVideo(id, VideoBudget.high);
      // Views so far stay what they were.
      expect(Platforms.videoViews(g.world, s), closeTo(audio, audio * 1e-9));
      var last = audio;
      double gain = 0;
      for (var i = 0; i < 4; i++) {
        final before = Platforms.videoViews(g.world, s);
        g.advanceWeek();
        final now = Platforms.videoViews(g.world, s);
        expect(now, greaterThanOrEqualTo(before));
        gain = now - last;
        last = now;
      }
      // A week of the official video beats a week of audio uploads for
      // the same streams.
      final weekStreams = g.world.songWeekStreamsIn(s, ChartMarket.global);
      final share = MusicPlatform.viewTube.streamShare(2016);
      expect(gain, greaterThan(0.6 * share * weekStreams));
      final mine = Platforms.topVideos(g.world, mine: true);
      expect(mine.first.songId, id);
      expect(mine.first.hasVideo, isTrue);
      g.close();
    });

    test('stream sources add up and survive a save (K120)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2018,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final slot = g.slotId;
      g.world.player!.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      g.setAutoplay(id, true);
      g.releaseSingle(id);
      g.advanceWeeks(3, stop: SkipStop.never);
      final shares = g.song(id).streamSources;
      expect(shares.length, StreamSource.values.length);
      expect(shares.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(shares[StreamSource.fans.index], greaterThan(0));
      expect(shares[StreamSource.algorithm.index], greaterThan(0));
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.song(id).streamSources, hasLength(StreamSource.values.length));
      g.close();
    });

    test('pre-saves build while a release is announced (K121)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2018,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final slot = g.slotId;
      g.world.player!.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      g.scheduleSingle(id, releaseWeek: g.week + 5, announceWeek: g.week);
      g.advanceWeeks(2, stop: SkipStop.never);
      final early = g.scheduled.single.preSaves;
      expect(early, greaterThan(0));
      // Kept through a save.
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.scheduled.single.preSaves, early);
      g.advanceWeeks(2, stop: SkipStop.never);
      final late = g.scheduled.single.preSaves;
      expect(late, greaterThan(early));
      g.advanceWeeks(2, stop: SkipStop.never);
      expect(g.scheduled, isEmpty);
      expect(g.song(id).preSaves, greaterThanOrEqualTo(late));
      final p = g.world.player!;
      expect(
          StreamingTools.preSaveLift(g.world.songs[id], p, 0), greaterThan(0));
      expect(StreamingTools.preSaveLift(g.world.songs[id], p, 2), 0);
      g.close();
    });

    test('labels: what they ask for, contracts, campaigns, drops', () {
      final g = GameSession.start(slots, _setup(path: CareerPath.smallLabel));
      expect(g.player.label, Label.small);
      expect(g.player.contractAlbumsLeft, 2);
      // A small label cannot run big campaigns.
      final song = g.writeSong(budget: BudgetTier.low).id;
      expect(() => g.releaseSingle(song, campaign: Campaign.intensive),
          _code('campaignLocked'));
      // The big labels want fans first.
      expect(() => g.signLabel(Label.giant), _code('labelRefused'));
      final giant = g.labels.firstWhere((v) => v.label == Label.giant);
      expect(giant.missing, contains(LabelRequirement.fans));
      // Leaving early means buying out the contract (K78): per album owed,
      // half the $25K advance back and the label's 40% of 50¢ a fan.
      g.world.player!
        ..coreFans = 1e6
        ..fame = 0.4
        ..moneyCents = 0;
      final major = g.labels.firstWhere((v) => v.label == Label.major);
      expect(major.buyoutCents, 2 * (1250000 + 20000000));
      expect(major.canSign, isTrue);
      // Going independent pays it all, and there is no money for it.
      final own = g.labels.firstWhere((v) => v.label == Label.independent);
      expect(own.canSign, isFalse);
      expect(() => g.signLabel(Label.independent), _code('buyoutMoney'));
      // The major's advance pays for it.
      g.signLabel(Label.major);
      expect(g.player.label, Label.major);
      expect(g.player.contractAlbumsLeft, 3);
      expect(g.player.moneyCents, major.netCents);
      // With the albums delivered, leaving is free.
      g.world.player!.contractAlbumsLeft = 0;
      expect(g.labels.firstWhere((v) => v.label == Label.giant).buyoutCents, 0);
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
