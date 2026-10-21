import 'dart:math' as math;
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
      // Stadiums need a fandom of a few million (K127, F81).
      g.world.player!.coreFans = 3e6;
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
      // A star whose next album is announced, not dropped by surprise
      // (docs K175).
      final rival = w.artists.firstWhere((a) =>
          a.tier == ArtistTier.a &&
          !a.isRetired &&
          a.plan.isEmpty &&
          !RivalMoves.surprise(w, a, w.week + 3));
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
      expect([
        for (final r in songs)
          if (r.isPlayer) (r.rank, r.entityId)
      ], news.songs);
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
      final runs = g
          .chartRun(EntityKind.song, no1.entityId)
          .where((w) => w.entries[Charts.usSongs]?.position == 1);
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
        expect(
            s.releasedWeek == w.week - 1 || s.singleWeek == w.week - 1, isTrue);
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

    test('the artist page shows listeners over time and top cities (K130)', () {
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
      s.reg[SongReg.lifeStreams] +=
          Platforms.playMilestones.first / Streamify.share -
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
        expect(
            radio.rows[i].points, lessThanOrEqualTo(radio.rows[i - 1].points));
      }
      // The audience it counts is the song's US radio.
      final top = g.world.songs[radio.rows.first.entityId];
      expect(top.weekRadio, greaterThan(0));
      g.close();
    });

    test('an independent picks a distributor (K157)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2012, money: StartMoney.millionaire, premium: true));
      final p = g.world.player!;
      expect(p.label, Label.independent);
      final v = g.distribution;
      expect(v.current, Distributor.selfRelease);
      expect(v.available, contains(Distributor.percent));
      // A deal needs an audience.
      expect(v.available, isNot(contains(Distributor.deal)));
      expect(
          () => g.chooseDistributor(Distributor.deal), _code('noDistributor'));
      final reach = p.labelReach;
      g.chooseDistributor(Distributor.percent);
      expect(p.artistShare, Distributor.percent.share);
      expect(p.labelReach, greaterThan(reach));
      // With fans, a deal: an advance and bigger campaigns.
      p.coreFans = 100000;
      final money = p.moneyCents;
      final advance = Distribution.advanceCents(p);
      g.chooseDistributor(Distributor.deal);
      expect(p.moneyCents - money, advance);
      expect(p.unrecoupedCents, advance);
      expect(g.player.maxCampaign, Campaign.intensive);
      // Not leaving before the advance is paid back.
      expect(g.distribution.available, isEmpty);
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.world.player!.distributor, Distributor.deal);
      expect(g.world.player!.labelReach, Distribution.reachOf(g.world.player!));
      // Signing a label ends it.
      Actions.signLabel(g.world, g.world.player!, Label.small);
      expect(g.world.player!.distributor, Distributor.selfRelease);
      g.close();
    });

    test('US streaming and download charts (K166)', () {
      var g = GameSession.start(slots, _setup(startYear: 2010));
      final ids = [for (final c in g.activeCharts) c.id];
      expect(ids, contains(Charts.usDigital));
      expect(ids, isNot(contains(Charts.usStreaming)));
      g.close();
      g = GameSession.start(
          slots,
          _setup(
              startYear: 2015,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      p.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(id);
      g.advanceWeeks(2, stop: SkipStop.never);
      final streaming = g.chart(Charts.usStreaming).rows;
      final digital = g.chart(Charts.usDigital).rows;
      expect(streaming, hasLength(50));
      expect(digital, hasLength(50));
      // Ranked by US streams alone.
      for (var i = 1; i < streaming.length; i++) {
        expect(streaming[i].points, lessThanOrEqualTo(streaming[i - 1].points));
      }
      // Its points are its US streams.
      final top = streaming.first;
      expect(top.points, closeTo(top.streams, top.streams * 0.01));
      g.close();
    });

    test('US album sales and streaming albums charts (K168)', () {
      var g = GameSession.start(slots, _setup(startYear: 2012));
      final ids = [for (final c in g.activeCharts) c.id];
      expect(ids, isNot(contains(Charts.usAlbumSales)));
      g.close();
      g = GameSession.start(
          slots,
          _setup(
              startYear: 2017,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final songs = <int>[];
      for (var i = 0; i < 10; i++) {
        p.creativeEnergy = 100;
        songs.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final al = g.releaseAlbum('Two Charts', songs);
      g.advanceWeek();
      final sales = g.chart(Charts.usAlbumSales).rows;
      final streaming = g.chart(Charts.usStreamingAlbums).rows;
      expect(sales, hasLength(50));
      expect(streaming, hasLength(50));
      // Ranked by US copies sold alone.
      for (final r in sales) {
        expect(r.points, closeTo(r.pure, r.pure * 0.01 + 1));
      }
      expect(sales.any((r) => r.entityId == al.id), isTrue);
      g.close();
    });

    test('the player\'s own label (K169)', () {
      var g = GameSession.start(slots, _setup(startYear: 2016));
      expect(g.imprint.canFound, isFalse);
      expect(() => g.foundImprint('Nope'), _code('noImprint'));
      g.close();
      g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      expect(g.imprintCandidates, isEmpty);
      final money = p.moneyCents;
      g.foundImprint('Night Shift Records');
      expect(money - p.moneyCents, Imprints.foundCents);
      expect(() => g.foundImprint('Again'), _code('noImprint'));
      final list = g.imprintCandidates;
      expect(list.length, greaterThanOrEqualTo(2));
      for (final c in list) {
        expect(c.fame, lessThanOrEqualTo(Imprints.maxSigneeFame));
      }
      final before = p.moneyCents;
      g.signToImprint(list[0].artistId);
      g.signToImprint(list[1].artistId);
      expect(before - p.moneyCents, list[0].advanceCents + list[1].advanceCents);
      expect(() => g.signToImprint(list[0].artistId), _code('notSignable'));
      g.advanceWeeks(16, stop: SkipStop.never);
      final v = g.imprint;
      expect(v.roster, hasLength(2));
      expect(v.earnedCents, greaterThan(0));
      g.dropFromImprint(list[1].artistId);
      expect(g.imprint.roster, hasLength(1));
      final slot = g.slotId;
      final earned = g.imprint.earnedCents;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.imprint.name, 'Night Shift Records');
      expect(g.imprint.roster.single.artistId, list[0].artistId);
      expect(g.imprint.earnedCents, closeTo(earned, 1));
      g.close();
    });

    test('label mates feature free and singles get the label push (K170)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      g.foundImprint('Mate Records');
      final mate = g.imprintCandidates.first;
      g.signToImprint(mate.artistId);
      p.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      final list = g.featureCandidates(id);
      expect(list.first.artistId, mate.artistId);
      expect(list.first.labelMate, isTrue);
      expect(list.first.feeCents, 0);
      final money = p.moneyCents;
      g.requestFeature(id, mate.artistId);
      expect(p.moneyCents, money);
      expect(g.world.songs[id].featuredArtistIds, contains(mate.artistId));
      // The label pushes the signee's newest single once it is out.
      expect(() => g.pushSignee(mate.artistId), _code('noPush'));
      for (var i = 0; i < 20 && g.imprint.roster.single.pushTitle == null; i++) {
        g.advanceWeek();
      }
      final v = g.imprint.roster.single;
      expect(v.pushTitle, isNotNull);
      final before = p.moneyCents;
      expect(g.pushSignee(mate.artistId), v.pushCostCents);
      expect(before - p.moneyCents, v.pushCostCents);
      expect(g.imprint.roster.single.pushTitle, isNull);
      expect(() => g.pushSignee(mate.artistId), _code('noPush'));
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.imprint.roster.single.pushTitle, isNull);
      g.close();
    });

    test('an awards campaign (K171)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      // Hits out in the eligibility window.
      for (var i = 0; i < 4; i++) {
        p.creativeEnergy = 100;
        final id = g.writeSong(budget: BudgetTier.high).id;
        g.releaseSingle(id);
        g.advanceWeeks(6, stop: SkipStop.never);
      }
      while (g.fyc.phase != FycPhase.nominations) {
        expect(() => g.runFyc(FycTier.small), _code('noFyc'));
        g.advanceWeek();
      }
      final money = p.moneyCents;
      g.runFyc(FycTier.allOut);
      expect(money - p.moneyCents, FycTier.allOut.costCents);
      expect(g.fyc.running, FycTier.allOut);
      expect(() => g.runFyc(FycTier.small), _code('noFyc'));
      expect(
          AwardCampaigns.nominationLift(g.world, g.fyc.year, p.id),
          FycTier.allOut.nominationLift);
      // Through the nominations to the voting.
      for (var i = 0; i < 12 && g.fyc.phase != FycPhase.voting; i++) {
        g.advanceWeek();
      }
      expect(g.fyc.phase, FycPhase.voting);
      expect(g.fyc.nomination, FycTier.allOut);
      g.runFyc(FycTier.big);
      expect(AwardCampaigns.voteFactor(g.world, g.fyc.year, p.id),
          FycTier.big.voteFactor);
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.fyc.vote, FycTier.big);
      g.close();
    });

    test('a member\'s solo album (K173)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2018,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true,
              kind: ArtistKind.vocalGroup,
              members: ['Ari', 'Bo', 'Cy']));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      expect(
          () => g.releaseMemberAlbum(0, 'Solo', ids, type: AlbumType.mixtape),
          _code('invalidType'));
      final money = p.moneyCents;
      final v = g.releaseMemberAlbum(2, 'Cy Alone', ids);
      expect(money - p.moneyCents,
          Credits.soloCostCents(g.world, p, 2, Campaign.standard));
      expect(v.artistName, 'Cy');
      expect(v.trackIds, hasLength(8));
      for (final id in ids) {
        expect(g.world.songs[id].status, SongStatus.scrapped);
      }
      final before = p.moneyCents;
      g.advanceWeeks(2, stop: SkipStop.never);
      final m = g.members[2];
      expect(m.albums.single.title, 'Cy Alone');
      expect(m.albums.single.firstWeek, greaterThan(0));
      expect(m.songs, hasLength(8));
      // The group earns from it.
      expect(p.moneyCents, greaterThan(before));
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.members[2].albums.single.id, v.id);
      g.close();
    });

    test('a documentary (K172)', () {
      var g = GameSession.start(slots, _setup(startYear: 2012));
      expect(g.documentary.block, DocBlock.tooEarly);
      g.close();
      g = GameSession.start(
          slots,
          _setup(
              startYear: 2017,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 3; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
        g.releaseSingle(ids.last);
        g.advanceWeeks(3, stop: SkipStop.never);
      }
      expect(g.documentary.block, isNull);
      final fee = g.documentary.originalFeeCents;
      final money = p.moneyCents;
      g.startDocumentary(DocDeal.original, 'Behind the Lights');
      expect(p.moneyCents - money, fee);
      expect(g.documentary.block, DocBlock.filming);
      expect(() => g.startDocumentary(DocDeal.selfFunded, 'Again'),
          _code('noDoc'));
      var premiere = <DocumentaryPremiere>[];
      var fans = 0.0;
      for (var i = 0; i <= Documentaries.productionWeeks && premiere.isEmpty;
          i++) {
        fans = p.coreFans;
        premiere = g.advanceWeek().events.whereType<DocumentaryPremiere>()
            .toList();
      }
      expect(premiere.single.title, 'Behind the Lights');
      // People who watched become fans.
      expect(p.coreFans, greaterThan(fans));
      expect(g.documentary.docs.single.premiered, isTrue);
      expect(g.documentary.block, DocBlock.tooSoon);
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.documentary.docs.single.title, 'Behind the Lights');
      expect(g.documentary.docs.single.premiered, isTrue);
      g.close();
    });

    test('an album rollout (K165)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2020,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      List<int> songs(int n) {
        final ids = <int>[];
        for (var i = 0; i < n; i++) {
          p.creativeEnergy = 100;
          ids.add(g.writeSong(budget: BudgetTier.high).id);
        }
        return ids;
      }

      // A record dropped with nothing ahead of it.
      final bare = g.releaseAlbum('Out of Nowhere', songs(8));
      expect(bare.rollout.count, greaterThanOrEqualTo(5));
      expect(bare.rollout.doneCount, 0);
      g.advanceWeeks(30, stop: SkipStop.never);
      // A full rollout.
      final ids = songs(10);
      g.releaseSingle(ids[0]);
      g.shootVideo(ids[0], VideoBudget.values.first);
      g.pitchSong(ids[1]);
      g.teaseSnippet(ids[2]);
      g.advanceWeek();
      final now = g.world.week;
      final sv = g.scheduleAlbum('The Era', ids,
          releaseWeek: now + 8, announceWeek: now);
      expect(sv.rollout!.has(RolloutStep.leadSingle), isTrue);
      expect(sv.rollout!.has(RolloutStep.secondSingle), isFalse);
      expect(sv.rollout!.has(RolloutStep.announced), isTrue);
      g.advanceWeeks(4, stop: SkipStop.never);
      g.releaseSingle(ids[1]);
      final view = g.scheduled.firstWhere((s) => s.id == sv.id);
      expect(view.rollout!.has(RolloutStep.secondSingle), isTrue);
      g.advanceWeeks(5, stop: SkipStop.never);
      final al = g.world.albums.lastWhere((a) => a.artistId == p.id);
      expect(al.title, 'The Era');
      final r = g.album(al.id).rollout;
      expect(r.doneCount, r.count);
      expect(r.share, 1.0);
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.album(al.id).rollout.share, 1.0);
      g.close();
    });

    test('a paid fan club (K164)', () {
      var g = GameSession.start(slots, _setup(startYear: 2016));
      expect(g.fanClub.canOpen, isFalse);
      expect(() => g.openFanClub(ClubPrice.mid), _code('noFanClub'));
      g.close();
      g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final v = g.fanClub;
      expect(v.canOpen, isTrue);
      expect(v.estimates[ClubPrice.low]!,
          greaterThan(v.estimates[ClubPrice.high]!));
      final money = p.moneyCents;
      g.openFanClub(ClubPrice.mid);
      expect(money - p.moneyCents, FanClubs.setupCents);
      expect(() => g.openFanClub(ClubPrice.mid), _code('noFanClub'));
      final events = <GameEvent>[];
      for (var i = 0; i < 12; i++) {
        events.addAll(g.advanceWeek().events);
      }
      final club = g.fanClub;
      expect(club.members, greaterThan(1000));
      expect(club.revenueCents, greaterThan(0));
      expect(events.whereType<ClubMilestone>(), isNotEmpty);
      // Members keep the fandom warm.
      final warm = p.devotion;
      FanClubs.weekly(g.world, p);
      expect(p.devotion, greaterThan(warm));
      // Members order the next album ahead.
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final members = g.world.fanClub!.members;
      final al = g.releaseAlbum('For the Club', ids);
      expect(g.world.albums[al.id].preOrders,
          closeTo(members * FanClubs.albumBuy, 1));
      g.setClubPrice(ClubPrice.high);
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.fanClub.open, isTrue);
      expect(g.fanClub.price, ClubPrice.high);
      expect(g.fanClub.members, closeTo(members, 1));
      g.close();
    });

    test('a download price cut (K163)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2012,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 10; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final id = g.releaseAlbum('Cheap Thrills', ids).id;
      // Not before it is out, and $0.99 does not count in its first weeks.
      expect(() => g.cutAlbumPrice(id, PriceCut.deep), _code('noPriceCut'));
      g.advanceWeek();
      expect(g.album(id).priceCutBlocks[PriceCut.ninetyNine],
          PriceCutBlock.chartRule);
      expect(() => g.cutAlbumPrice(id, PriceCut.ninetyNine),
          _code('noPriceCut'));
      g.advanceWeeks(4, stop: SkipStop.never);
      final al = g.world.albums[id];
      final before = al.weekPure;
      final revenue = al.revenueCents;
      g.advanceWeek();
      final usual = al.weekPure;
      final usualMoney = al.revenueCents - revenue;
      g.cutAlbumPrice(id, PriceCut.ninetyNine);
      expect(g.album(id).priceCutBlocks[PriceCut.sale], PriceCutBlock.tooSoon);
      final r2 = al.revenueCents;
      g.advanceWeek();
      // Many more copies, each paying little.
      expect(al.weekPure, greaterThan(usual * 3));
      expect(al.weekPure, greaterThan(before));
      expect((al.revenueCents - r2) / al.weekPure,
          lessThan(usualMoney / usual));
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.album(id).priceCut, PriceCut.ninetyNine);
      expect(g.album(id).priceCutWeek, greaterThan(0));
      g.close();
    });

    test('buying masters back from the label (K162)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      Actions.signLabel(g.world, p, Label.major);
      expect(p.artistShare, lessThan(1));
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final albumId = g.releaseAlbum('Under Contract', ids).id;
      g.advanceWeeks(10, stop: SkipStop.never);
      final v = g.album(albumId);
      expect(v.masterShare, lessThan(1));
      final price = v.masterBuyCents!;
      expect(price, greaterThanOrEqualTo(MasterBuyback.minCents));
      expect(price, greaterThan(v.masterOwnerYearCents * 10));
      final money = p.moneyCents;
      expect(g.buyAlbumMasters(albumId), price);
      expect(money - p.moneyCents, price);
      final after = g.album(albumId);
      expect(after.masterShare, 1.0);
      expect(after.masterBuyCents, isNull);
      for (final id in ids) {
        expect(g.song(id).masterShare, 1.0);
      }
      expect(() => g.buyAlbumMasters(albumId), _code('noMasters'));
      // A single on its own.
      p.creativeEnergy = 100;
      final single = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(single);
      g.advanceWeeks(2, stop: SkipStop.never);
      expect(g.song(single).masterBuyCents, isNotNull);
      g.buySongMaster(single);
      expect(g.song(single).masterShare, 1.0);
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.album(albumId).masterShare, 1.0);
      expect(g.song(single).masterShare, 1.0);
      g.close();
    });

    test('a greatest hits album (K161)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2000,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      expect(g.compilationBlock, CompilationBlock.tooEarly);
      final ids = <int>[];
      for (var i = 0; i < 10; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      for (final id in ids.take(4)) {
        g.releaseSingle(id);
        g.advanceWeeks(6, stop: SkipStop.never);
      }
      g.releaseAlbum('First Light', ids);
      g.advanceWeeks(52 * Compilations.minYears, stop: SkipStop.never);
      expect(g.compilationBlock, isNull);
      final hits = g.compilationCandidates;
      expect(hits.length, greaterThanOrEqualTo(10));
      expect(hits.first.weight, greaterThanOrEqualTo(hits.last.weight));
      p.creativeEnergy = 100;
      final fresh = g.writeSong(budget: BudgetTier.high).id;
      expect(
          () => g.releaseGreatestHits(
              'Best Of', [for (final h in hits.take(5)) h.songId], [fresh]),
          _code('trackCount'));
      expect(
          () => g.releaseGreatestHits('Best Of',
              [for (final h in hits.take(8)) h.songId], [hits.last.songId]),
          _code('notInVault'));
      final picked = [for (final h in hits.take(10)) h.songId];
      final era = p.eraAlbumId;
      final contract = p.contractAlbumsLeft;
      final v = g.releaseGreatestHits('The Hits', picked, [fresh]);
      expect(v.isCompilation, isTrue);
      expect(v.trackIds, [fresh]);
      expect(v.hitTrackIds, picked);
      // No new era, not an album the label is owed.
      expect(p.eraAlbumId, era);
      expect(p.contractAlbumsLeft, contract);
      // The old songs stay on their albums.
      expect(g.world.songs[picked.first].albumId, isNot(v.id));
      expect(g.compilationBlock, CompilationBlock.tooSoon);
      g.advanceWeeks(8, stop: SkipStop.never);
      final al = g.world.albums[v.id];
      expect(al.firstWeekPure, greaterThan(0));
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.album(v.id).hitTrackIds, picked);
      g.close();
    });

    test('songs sent to independent curators (K160)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2017, money: StartMoney.millionaire, premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      p.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      // Only released songs.
      expect(g.song(id).canCurators, isFalse);
      expect(
          () => g.submitToCurators(id, CuratorPack.small), _code('noCurators'));
      g.releaseSingle(id);
      g.advanceWeek();
      expect(g.song(id).canCurators, isTrue);
      final money = p.moneyCents;
      final casual = p.casual;
      g.submitToCurators(id, CuratorPack.large);
      expect(money - p.moneyCents, g.curatorCosts[CuratorPack.large]);
      expect(g.song(id).canCurators, isFalse);
      expect(
          () => g.submitToCurators(id, CuratorPack.small), _code('noCurators'));
      expect(g.curatorAnswers(id), isEmpty);
      final report = g.advanceWeek();
      final news = report.events.whereType<CuratorsAnswered>().single;
      expect(news.sent, CuratorPack.large.curators);
      final answers = g.curatorAnswers(id);
      expect(answers, hasLength(CuratorPack.large.curators));
      expect(answers.where((a) => a.added).length, news.adds);
      expect(news.adds, greaterThan(0));
      final s = g.world.songs[id];
      expect(s.curatorReach, greaterThan(0));
      expect(p.casual, greaterThan(casual));
      g.advanceWeek();
      final v = g.song(id);
      expect(v.curatorAnswered, isTrue);
      expect(v.curatorStreams, greaterThan(0));
      // The same answers every time.
      expect(
          g.curatorAnswers(id).map((a) => a.name), answers.map((a) => a.name));
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      final back = g.world.songs[id];
      expect(back.curatorWeek, s.curatorWeek);
      expect(back.curatorPack, CuratorPack.large);
      expect(back.curatorAdds, news.adds);
      expect(back.curatorReach, s.curatorReach);
      g.close();
    });

    test('the player\'s own playlist (K159)', () {
      var g = GameSession.start(slots, _setup(startYear: 2008));
      expect(g.ownPlaylistOpen, isFalse);
      expect(() => g.createPlaylist('Mine'), _code('noPlaylists'));
      g.close();
      g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      // A song of their own out first.
      p.creativeEnergy = 100;
      final own = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(own);
      g.advanceWeek();
      expect(g.ownPlaylist, isNull);
      expect(() => g.createPlaylist('  '), _code('invalidName'));
      g.createPlaylist('Late Night Drive');
      expect(() => g.createPlaylist('Again'), _code('hasPlaylist'));
      final list = g.playlistCandidates;
      expect(list.length, greaterThan(20));
      p.creativeEnergy = 100;
      final unreleased = g.writeSong(budget: BudgetTier.low).id;
      expect(() => g.addToPlaylist(unreleased), _code('notReleased'));
      g.addToPlaylist(own);
      expect(g.ownPlaylist!.tooShort, isTrue);
      final rivals = list.where((t) => !t.isPlayer).take(15).toList();
      for (final t in rivals) {
        g.addToPlaylist(t.songId);
      }
      expect(() => g.addToPlaylist(own), _code('onPlaylist'));
      final v = g.ownPlaylist!;
      expect(v.tracks, hasLength(16));
      expect(v.tooMuchSelf, isFalse);
      expect(v.appeal, greaterThan(0));
      expect(g.song(own).onOwnPlaylist, isTrue);
      g.advanceWeeks(12, stop: SkipStop.never);
      final grown = g.ownPlaylist!;
      expect(grown.followers, greaterThan(0));
      expect(grown.lift, greaterThan(0));
      // A rival on it is a little easier to get.
      final favoured = g.world.artists[rivals.first.artistId];
      expect(OwnPlaylists.favours(g.world, favoured), isTrue);
      // Filling it with the player's own songs puts people off.
      final selfOnly = grown.appeal;
      for (final t in rivals) {
        g.removeFromPlaylist(t.songId);
      }
      for (var i = 0; i < 6; i++) {
        p.creativeEnergy = 100;
        final id = g.writeSong(budget: BudgetTier.low).id;
        g.releaseSingle(id, campaign: Campaign.none);
        g.addToPlaylist(id);
      }
      expect(g.ownPlaylist!.tooMuchSelf, isTrue);
      expect(g.ownPlaylist!.appeal, lessThan(selfOnly));
      expect(() => g.removeFromPlaylist(rivals.first.songId),
          _code('notOnPlaylist'));
      final slot = g.slotId;
      final followers = g.ownPlaylist!.followers;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.ownPlaylist!.name, 'Late Night Drive');
      expect(g.ownPlaylist!.followers, followers);
      expect(g.ownPlaylist!.tracks, hasLength(7));
      g.close();
    });

    test('a member\'s solo single and the player\'s verses (K158)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true,
              kind: ArtistKind.vocalGroup,
              members: ['Ari', 'Bo', 'Cy']));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      expect(g.members.map((m) => m.name), ['Ari', 'Bo', 'Cy']);
      expect(g.members.first.artistId, -1);
      p.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      expect(() => g.releaseMemberSolo(5, id), _code('noMember'));
      final cost = g.memberSoloCost(1, Campaign.standard);
      final money = p.moneyCents;
      g.releaseMemberSolo(1, id);
      expect(money - p.moneyCents, cost);
      expect(g.vault.map((s) => s.id), isNot(contains(id)));
      final bo = g.members[1];
      expect(bo.artistId, greaterThanOrEqualTo(0));
      final member = g.world.artists[bo.artistId];
      expect(member.managedBy, p.id);
      expect(member.coreFans, lessThan(p.coreFans));
      final solo = bo.songs.single;
      expect(g.world.activeSongIds, contains(solo.songId));
      // The member makes no plans of their own and is not a rival.
      g.advanceWeeks(6, stop: SkipStop.never);
      expect(g.world.songs.where((s) => s.primaryArtistId == member.id),
          hasLength(1));
      expect(member.isRetired, isFalse);
      expect(g.members[1].songs.single.earnedCents, greaterThan(0));
      expect(g.song(solo.songId).credit, ChartCredit.member);
      // A rival puts the player on their song: on the charts as theirs,
      // with the featured share paid to the player.
      final rival = g.world.artists.firstWhere(
          (a) => a.tier == ArtistTier.a && !a.isRetired && a.managedBy < 0);
      final song = Credits.guestOn(g.world, rival, p, producerSkill: 85);
      expect(g.guestSongs.single.songId, song.id);
      expect(g.guestSongs.single.released, isFalse);
      g.advanceWeeks(Credits.guestReleaseAfter + 3, stop: SkipStop.never);
      expect(song.releasedWeek, greaterThanOrEqualTo(0));
      expect(song.primaryArtistId, rival.id);
      expect(song.featuredArtistIds, contains(p.id));
      expect(song.guestCents, greaterThan(0));
      final row = g
          .chart(Charts.globalSongs)
          .rows
          .where((r) => r.entityId == song.id)
          .firstOrNull;
      if (row != null) {
        expect(row.credit, ChartCredit.guest);
        expect(row.isOurs, isTrue);
        expect(row.featuring, contains(p.name));
      }
      final slot = g.slotId;
      final guest = song.guestCents;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.guestSongs.single.earnedCents, guest);
      expect(g.members[1].artistId, bo.artistId);
      expect(g.world.artists[bo.artistId].managedBy, g.world.playerArtistId);
      expect(g.members[1].songs.single.songId, solo.songId);
      g.advanceWeek();
      expect(g.world.songs[song.id].guestCents, greaterThan(guest));
      g.close();
    });

    test('monthly listener and album stream milestones (K156)', () {
      var g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final al = g.releaseAlbum('Billions', ids);
      final events = <GameEvent>[];
      for (var i = 0; i < 20; i++) {
        events.addAll(g.advanceWeek().events);
      }
      final listeners = events
          .whereType<ListenersMilestone>()
          .map((e) => e.listeners)
          .toList();
      expect(listeners, isNotEmpty);
      // Each milestone once, in order.
      expect(listeners.toSet().length, listeners.length);
      expect(g.world.playerPeakListeners, greaterThanOrEqualTo(listeners.last));
      final albums = events.whereType<AlbumStreamMilestone>().toList();
      expect(albums.map((e) => e.albumId), everyElement(al.id));
      expect(albums.map((e) => e.streams), contains(1e9));
      expect(g.artistPage(p.id).peakListeners, g.world.playerPeakListeners);
      // An old save learns its peak quietly.
      g.world.playerPeakListeners = -1;
      expect(g.advanceWeek().events.whereType<ListenersMilestone>(), isEmpty);
      expect(g.world.playerPeakListeners, greaterThan(0));
      final peak = g.world.playerPeakListeners;
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.world.playerPeakListeners, peak);
      g.close();
    });

    test('a version in another language opens a market (K155)', () {
      var g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      p.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      expect(g.song(id).languageOptions, isEmpty);
      g.releaseSingle(id);
      // At home in North America: Spanish, not English.
      expect(p.homeCountry.region, Region.northAmerica);
      expect(g.song(id).languageOptions, [LanguageVersion.spanish]);
      expect(() => g.releaseLanguageVersion(id, LanguageVersion.english),
          _code('noLanguage'));
      final other = p.regionShare[Region.other.index];
      final boost = g.world.songs[id].versionBoost;
      g.releaseLanguageVersion(id, LanguageVersion.spanish);
      expect(p.regionShare[Region.other.index], greaterThan(other));
      expect(g.world.songs[id].versionBoost, greaterThan(boost));
      expect(g.song(id).languageVersions, [LanguageVersion.spanish]);
      expect(g.song(id).languageOptions, isEmpty);
      // The market stays won, week after week.
      g.advanceWeeks(3, stop: SkipStop.never);
      expect(p.marketBonus[Region.other.index], Languages.marketStep);
      final share = p.regionShare[Region.other.index];
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.world.player!.marketBonus[Region.other.index],
          Languages.marketStep);
      expect(g.world.player!.regionShare[Region.other.index],
          closeTo(share, 1e-9));
      expect(g.song(id).languageVersions, [LanguageVersion.spanish]);
      g.close();
    });

    test('a visual album films every track (K154)', () {
      (GameSession, AlbumView) start() {
        final g = GameSession.start(
            slots,
            _setup(
                tier: StartTier.superstar,
                money: StartMoney.millionaire,
                premium: true));
        final p = g.world.player!;
        p.moneyCents = 1 << 40;
        final ids = <int>[];
        for (var i = 0; i < 8; i++) {
          p.creativeEnergy = 100;
          ids.add(g.writeSong(budget: BudgetTier.high).id);
        }
        return (g, g.releaseAlbum('Lemonade', ids));
      }

      final (plain, pAl) = start();
      var (g, al) = start();
      final cost = g.album(al.id).visualCostCents!;
      expect(cost, VisualAlbums.trackCostCents() * al.trackIds.length);
      final money = g.player.moneyCents;
      final hype = g.player.hype;
      g.makeVisualAlbum(al.id);
      expect(money - g.player.moneyCents, cost);
      expect(g.player.hype, closeTo(hype + VisualAlbums.hype, 1e-9));
      expect(g.album(al.id).visual, isTrue);
      expect(g.album(al.id).visualCostCents, isNull);
      for (final id in al.trackIds) {
        expect(g.world.songs[id].videoPower, greaterThan(0));
      }
      expect(() => g.makeVisualAlbum(al.id), _code('noVisual'));
      expect(g.channel.videos.length, greaterThanOrEqualTo(al.trackIds.length));
      plain.advanceWeeks(3, stop: SkipStop.never);
      g.advanceWeeks(3, stop: SkipStop.never);
      double streams(GameSession s, AlbumView a) => a.trackIds.fold(
          0.0, (t, id) => t + s.world.songLifetimeStreams(s.world.songs[id]));
      expect(streams(g, al), greaterThan(streams(plain, pAl)));
      // Too late after a month.
      plain.advanceWeek();
      expect(plain.album(pAl.id).visualCostCents, isNull);
      plain.close();
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.album(al.id).visual, isTrue);
      g.close();
    });

    test('selling the catalog: money now, the songs pay the fund (K153)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2018,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final al = g.releaseAlbum('Old', ids);
      expect(g.catalogOffer.songs, 0);
      expect(() => g.sellCatalog(), _code('noOffer'));
      g.advanceWeeks(CatalogSale.ageWeeks, stop: SkipStop.never);
      final offer = g.catalogOffer;
      expect(offer.open, isTrue);
      expect(offer.songs, ids.length);
      expect(offer.multiple, CatalogSale.multiple(g.year));
      expect(offer.offerCents, greaterThan(0));
      final money = g.player.moneyCents;
      final price = g.sellCatalog();
      expect(price, offer.offerCents);
      expect(g.player.moneyCents - money, price);
      expect(g.song(ids.first).masterShare, 0);
      expect(g.album(al.id).masterShare, 0);
      // Sold: no more offers, and nothing more from those songs.
      expect(g.catalogOffer.offerCents, 0);
      final revenue = g.world.songs[ids.first].revenueCents;
      g.advanceWeek();
      expect(g.world.songs[ids.first].revenueCents, revenue);
      // A sold album can be recorded again.
      expect(g.album(al.id).canRerecord, isTrue);
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.song(ids.first).masterShare, 0);
      g.close();
    });

    test('a snippet test shows the reaction and builds a wait (K152)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2020,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 3; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      expect(g.song(ids.first).canSnippet, isTrue);
      expect(g.song(ids.first).snippetReaction, isNull);
      final energy = g.player.creativeEnergy;
      g.teaseSnippet(ids.first);
      expect(g.player.creativeEnergy, energy - Snippets.energy);
      final v = g.song(ids.first);
      expect(v.snippetReaction, isNotNull);
      expect(v.snippetReaction, Snippets.reaction(v.snippetScore.toDouble()));
      // One a week, once a song.
      expect(() => g.teaseSnippet(ids[1]), _code('noSnippet'));
      expect(() => g.teaseSnippet(ids.first), _code('noSnippet'));
      // A teased song leaks more easily.
      final s = g.world.songs[ids.first];
      final other = g.world.songs[ids[2]];
      expect(
          Leaks.chance(g.world, p, s),
          closeTo(
              Leaks.chance(g.world, p, other) * Snippets.leakFactor, 1e-12));
      g.advanceWeek();
      g.teaseSnippet(ids[1]);
      // Out while awaited: its wave.
      final boost = s.versionBoost;
      g.releaseSingle(ids.first);
      expect(s.versionBoost, greaterThan(boost));
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.song(ids.first).snippetWeek, greaterThanOrEqualTo(0));
      expect(g.song(ids.first).snippetScore, v.snippetScore);
      g.close();
      // Before 2019 there are no snippets.
      final old = GameSession.start(slots, _setup(startYear: 2017));
      old.world.player!.creativeEnergy = 100;
      final id = old.writeSong(budget: BudgetTier.low).id;
      expect(old.song(id).canSnippet, isFalse);
      old.close();
    });

    test('a joint album with a rival sells to both fan bases (K150)', () {
      (GameSession, List<int>) start() {
        final g = GameSession.start(
            slots,
            _setup(
                tier: StartTier.superstar,
                money: StartMoney.millionaire,
                premium: true));
        final p = g.world.player!;
        p.moneyCents = 1 << 40;
        final ids = <int>[];
        for (var i = 0; i < 8; i++) {
          p.creativeEnergy = 100;
          ids.add(g.writeSong(budget: BudgetTier.high).id);
        }
        return (g, ids);
      }

      final (solo, sIds) = start();
      final soloAl = solo.releaseAlbum('Alone', sIds);
      var (g, ids) = start();
      final partner = g.jointPartners.first;
      expect(partner.feeCents,
          JointAlbums.feeCents(g.world.artists[partner.artistId]));
      final money = g.player.moneyCents;
      final al = g.releaseAlbum('Together', ids, partnerId: partner.artistId);
      expect(
          money - g.player.moneyCents,
          partner.feeCents +
              Actions.campaignCostFor(g.world.player!, Campaign.standard));
      expect(g.album(al.id).partnerName, partner.name);
      for (final id in ids) {
        expect(g.world.songs[id].featuredArtistIds, contains(partner.artistId));
      }
      expect(() => g.releaseAlbum('X', ids, partnerId: g.world.playerArtistId),
          throwsA(isA<GameException>()));
      solo.advanceWeek();
      g.advanceWeek();
      expect(g.album(al.id).firstWeekUnits,
          greaterThan(solo.album(soloAl.id).firstWeekUnits));
      solo.close();
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.album(al.id).partnerId, partner.artistId);
      g.close();
    });

    test('an anniversary reissue: remastered, with a vinyl (K149)', () {
      final g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final w = g.world;
      final p = w.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final fresh = g.releaseAlbum('New', ids);
      expect(g.album(fresh.id).anniversaryDue, 0);
      expect(() => g.reissueAnniversary(fresh.id), _code('noAnniversary'));
      // An album from ten years ago, long in the catalog.
      final old = Album(
          id: w.albums.length,
          title: 'Classic',
          artistId: p.id,
          type: AlbumType.album,
          releaseWeek: g.week - 10 * GameTime.weeksPerYear,
          songIds: ids,
          quality: 70)
        ..status = AlbumStatus.dormant;
      w.albums.add(old);
      expect(g.album(old.id).anniversaryDue, 10);
      final money = g.player.moneyCents;
      final boost = w.songs[ids.first].versionBoost;
      g.reissueAnniversary(old.id);
      expect(money - g.player.moneyCents, Anniversaries.costCents());
      expect(old.status, AlbumStatus.active);
      expect(w.songs[ids.first].versionBoost - boost,
          closeTo(Anniversaries.remasterBoost, 1e-9));
      expect(old.variantFormats.last, EditionFormat.vinyl.index);
      expect(g.album(old.id).anniversariesMarked, [10]);
      expect(g.album(old.id).anniversaryDue, 0);
      expect(() => g.reissueAnniversary(old.id), _code('noAnniversary'));
      g.advanceWeek();
      expect(g.world.albums[old.id].weekPure, greaterThan(0));
      g.close();
    });

    test('a free upload to the audio site, then out for real (K148)', () {
      (GameSession, int) start(int year) {
        final g = GameSession.start(
            slots,
            _setup(
                startYear: year, money: StartMoney.millionaire, premium: true));
        final p = g.world.player!;
        p.moneyCents = 1 << 40;
        p.creativeEnergy = 100;
        return (g, g.writeSong(budget: BudgetTier.high).id);
      }

      var (g, id) = start(2007);
      expect(g.song(id).canCloud, isFalse);
      expect(() => g.uploadToCloud(id), _code('cannotCloud'));
      g.close();
      final (plain, _) = start(2016);
      (g, id) = start(2016);
      expect(g.song(id).canCloud, isTrue);
      g.uploadToCloud(id);
      expect(g.song(id).cloudOnly, isTrue);
      expect(g.vault.map((s) => s.id), isNot(contains(id)));
      g.advanceWeeks(6, stop: SkipStop.never);
      plain.advanceWeeks(6, stop: SkipStop.never);
      final s = g.world.songs[id];
      expect(g.song(id).cloudPlays, greaterThan(0));
      // It never charts while it is only there.
      for (final ch in Charts.mainSongCharts) {
        expect(s.statsOrNull(ch)?.weeksOn ?? 0, 0);
      }
      // Its listeners became fans: an unknown is found there.
      expect(g.player.coreFans, greaterThan(plain.player.coreFans));
      plain.close();
      final plays = g.song(id).cloudPlays;
      final boost = s.versionBoost;
      g.releaseSingle(id, campaign: Campaign.none);
      expect(s.cloudOnly, isFalse);
      expect(s.releasedWeek, g.week);
      expect(s.cloudPlays, closeTo(plays, plays * 0.01));
      expect(s.versionBoost - boost,
          closeTo(Cloud.officialBoost(s.cloudPlays), 1e-9));
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.song(id).cloudWeek, greaterThanOrEqualTo(0));
      expect(g.song(id).cloudOnly, isFalse);
      g.close();
    });

    test('the streaming app\'s Marquee and Showcase (K147)', () {
      (GameSession, List<int>) start(int year) {
        final g = GameSession.start(
            slots,
            _setup(
                startYear: year,
                tier: StartTier.superstar,
                money: StartMoney.millionaire,
                premium: true));
        final p = g.world.player!;
        p.moneyCents = 1 << 40;
        final ids = <int>[];
        for (var i = 0; i < 9; i++) {
          p.creativeEnergy = 100;
          ids.add(g.writeSong(budget: BudgetTier.high).id);
        }
        g.releaseSingle(ids.first);
        return (g, ids);
      }

      // Before 2020 there is no Marquee.
      var (g, ids) = start(2019);
      expect(g.song(ids.first).marqueeCostCents, isNull);
      expect(() => g.runMarquee(ids.first), _code('noMarquee'));
      g.close();
      final (plain, pIds) = start(2022);
      (g, ids) = start(2022);
      final cost = g.song(ids.first).marqueeCostCents!;
      final money = g.player.moneyCents;
      g.runMarquee(ids.first);
      expect(money - g.player.moneyCents, cost);
      expect(g.song(ids.first).marqueeCostCents, isNull);
      expect(() => g.runMarquee(ids.first), _code('noMarquee'));
      plain.advanceWeek();
      g.advanceWeek();
      // More of the artist's listeners played it.
      expect(g.world.songs[ids.first].weekStreams,
          greaterThan(plain.world.songs[pIds.first].weekStreams));
      plain.close();
      // A whole album on the Marquee.
      final al = g.releaseAlbum('Marquee', ids.skip(1).toList());
      expect(g.album(al.id).marqueeCostCents, isNotNull);
      g.runAlbumMarquee(al.id);
      expect(g.album(al.id).onMarquee, isTrue);
      for (final id in al.trackIds) {
        expect(g.world.songs[id].marqueeWeek, g.week);
      }
      // A catalog song gets a Showcase, once a year.
      expect(g.song(ids.first).showcaseCostCents, isNull);
      g.advanceWeeks(StreamingTools.showcaseAge, stop: SkipStop.never);
      expect(g.song(ids.first).showcaseCostCents, isNotNull);
      final boost = g.world.songs[ids.first].versionBoost;
      g.runShowcase(ids.first);
      expect(g.world.songs[ids.first].versionBoost, greaterThan(boost));
      expect(g.world.songs[ids.first].status, SongStatus.active);
      expect(() => g.runShowcase(ids.first), _code('noShowcase'));
      final slot = g.slotId;
      final week = g.song(ids.first).showcaseWeek;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.song(ids.first).showcaseWeek, week);
      g.close();
    });

    test('a live album from the tour, for the fans (K146)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final studio = g.releaseAlbum('Studio', ids);
      expect(g.liveAlbumTours, isEmpty);
      g.startTour(TourRequest(
          name: 'Arenas', legs: [TourLeg(TourMarket.usa, TourKind.arena, 12)]));
      while (g.player.tour != null) {
        g.advanceWeek();
      }
      g.advanceWeek();
      final tours = g.liveAlbumTours;
      expect(tours.single.shows, greaterThanOrEqualTo(LiveAlbums.minShows));
      expect(
          () => g.releaseLiveAlbum(
              tours.single.startWeek, 'Live', ids.take(3).toList()),
          _code('trackCount'));
      p.creativeEnergy = 100;
      final owed = p.contractAlbumsLeft;
      final money = g.player.moneyCents;
      final live =
          g.releaseLiveAlbum(tours.single.startWeek, 'Live at the Arenas', ids);
      expect(money - g.player.moneyCents, LiveAlbums.costCents(ids.length));
      expect(live.isLive, isTrue);
      expect(g.player.contractAlbumsLeft, owed);
      for (final (i, id) in live.trackIds.indexed) {
        expect(g.song(id).liveOf, ids[i]);
      }
      expect(g.liveAlbumTours, isEmpty);
      g.advanceWeek();
      final first = g.album(live.id);
      expect(first.firstWeekUnits, greaterThan(0));
      // Fans buy it; it is no new studio record.
      expect(first.firstWeekUnits, lessThan(g.album(studio.id).firstWeekUnits));
      g.close();
    });

    test('record money by source: the services pay differently (K145)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2018,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      g.releaseSingle(ids.first);
      g.advanceWeeks(4, stop: SkipStop.never);
      g.releaseAlbum('Paid', ids);
      g.advanceWeeks(6, stop: SkipStop.never);
      // Per play: the second service pays most, the video site least,
      // and on average what the simulation pays.
      final y = g.year;
      double rate(MusicPlatform m) => Income.perStreamCents(m, y);
      expect(rate(MusicPlatform.fruitMusic),
          greaterThan(rate(MusicPlatform.streamify)));
      expect(rate(MusicPlatform.streamify),
          greaterThan(rate(MusicPlatform.viewTube)));
      var plays = 0.0, money = 0.0;
      for (final m in Income.rate.keys) {
        plays += m.streamShare(y);
        money += m.streamShare(y) * rate(m);
      }
      expect(money / plays, closeTo(Income.averageCents, 1e-9));
      // A song's sources add up to what it earned.
      final song = g.songIncome(ids.first);
      expect(song.cents.keys,
          containsAll([IncomeSource.streamify, IncomeSource.viewTube]));
      expect(
          song.total,
          closeTo(g.world.songs[ids.first].revenueCents,
              g.world.songs[ids.first].revenueCents * 0.1));
      final career = g.careerIncome;
      expect(career.cents[IncomeSource.albumSales], greaterThan(0));
      expect(career.total, greaterThan(song.total));
      g.close();
    });

    test('album bundles count merch and tickets, until 2020 (K144)', () {
      (GameSession, List<int>) start(int year) {
        final g = GameSession.start(
            slots,
            _setup(
                startYear: year,
                tier: StartTier.superstar,
                money: StartMoney.millionaire,
                premium: true));
        final p = g.world.player!;
        p.moneyCents = 1 << 40;
        final ids = <int>[];
        for (var i = 0; i < 8; i++) {
          p.creativeEnergy = 100;
          ids.add(g.writeSong(budget: BudgetTier.high).id);
        }
        return (g, ids);
      }

      var (g, ids) = start(2018);
      // No tour ahead: no ticket bundle.
      expect(g.bundleOptions.keys, [AlbumBundle.merch]);
      expect(() => g.releaseAlbum('X', ids, bundle: AlbumBundle.tickets),
          _code('cannotBundle'));
      g.startTour(TourRequest(
          name: 'Big', legs: [TourLeg(TourMarket.usa, TourKind.arena, 20)]));
      expect(g.bundleOptions.keys,
          containsAll([AlbumBundle.merch, AlbumBundle.tickets]));
      final tickets = g.bundleOptions[AlbumBundle.tickets]!;
      expect(tickets, greaterThan(0));
      final money = g.player.moneyCents;
      final al = g.releaseAlbum('Merch', ids, bundle: AlbumBundle.merch);
      final units = g.world.albums[al.id].bundleUnits;
      expect(units, greaterThan(0));
      expect(
          g.player.moneyCents - money,
          greaterThanOrEqualTo((units * Bundles.merchMarginCents).round() -
              Actions.campaignCostFor(g.world.player!, Campaign.standard)));
      g.advanceWeek();
      expect(g.album(al.id).bundle, AlbumBundle.merch);
      expect(g.album(al.id).firstWeekPure, greaterThan(units));
      g.close();
      // The charts stopped counting bundles after 2020.
      (g, ids) = start(2021);
      expect(g.bundleOptions, isEmpty);
      expect(() => g.releaseAlbum('X', ids, bundle: AlbumBundle.merch),
          _code('cannotBundle'));
      g.close();
    });

    test('a song sold to another artist pays its writer (K143)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      // A song someone wants.
      late int id;
      late SongBuyerView buyer;
      for (var i = 0;; i++) {
        p.creativeEnergy = 100;
        id = g.writeSong(budget: BudgetTier.high).id;
        final list = g.songBuyers(id);
        if (list.isNotEmpty && list.first.wants) {
          buyer = list.first;
          final refused = list.where((b) => !b.wants).firstOrNull;
          if (refused != null) {
            expect(
                () => g.sellSong(id, refused.artistId), _code('songRefused'));
          }
          break;
        }
        expect(i, lessThan(30));
      }
      final money = g.player.moneyCents;
      g.sellSong(id, buyer.artistId);
      expect(g.player.moneyCents - money, buyer.feeCents);
      expect(g.vault.map((s) => s.id), isNot(contains(id)));
      final sold = g.writtenForOthers.single;
      expect(sold.artistId, buyer.artistId);
      expect(sold.released, isFalse);
      g.advanceWeeks(Songwriting.releaseAfter + 1, stop: SkipStop.never);
      final s = g.world.songs[sold.songId];
      expect(s.releasedWeek, greaterThanOrEqualTo(0));
      expect(s.primaryArtistId, buyer.artistId);
      expect(g.song(s.id).writtenByPlayer, isTrue);
      g.advanceWeeks(4, stop: SkipStop.never);
      expect(g.writtenForOthers.single.earnedCents, greaterThan(0));
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.writtenForOthers.single.songId, sold.songId);
      expect(g.writtenForOthers.single.earnedCents, greaterThan(0));
      g.close();
    });

    test('the channel: upload videos for songs and about the artist (K142)',
        () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      p.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      // Only released songs get videos.
      expect(() => g.uploadVideo(VideoKind.lyric, songId: id),
          _code('cannotUpload'));
      g.releaseSingle(id);
      g.advanceWeeks(2, stop: SkipStop.never);
      expect(g.channel.kinds, VideoKind.values);
      p.creativeEnergy = 100;
      final money = g.player.moneyCents;
      final boost = g.world.songs[id].versionBoost;
      g.uploadVideo(VideoKind.lyric, songId: id);
      expect(money - g.player.moneyCents, VideoKind.lyric.costCents);
      expect(g.player.creativeEnergy, 100 - VideoKind.lyric.energy);
      expect(g.world.songs[id].versionBoost, greaterThan(boost));
      expect(g.channel.made[id], {VideoKind.lyric});
      expect(() => g.uploadVideo(VideoKind.lyric, songId: id),
          _code('cannotUpload'));
      g.uploadVideo(VideoKind.acoustic, songId: id);
      // Videos about the artist win fans; one a week.
      final fans = g.player.coreFans;
      g.uploadVideo(VideoKind.vlog);
      expect(g.player.coreFans, greaterThan(fans));
      expect(
          () => g.uploadVideo(VideoKind.behindScenes), _code('cannotUpload'));
      g.advanceWeek();
      final first = g.channel;
      expect(first.videos.length, 3);
      expect(first.totalViews, greaterThan(0));
      g.advanceWeeks(4, stop: SkipStop.never);
      final later = g.channel;
      expect(later.totalViews, greaterThan(first.totalViews));
      final lyric = later.videos.firstWhere((v) => v.kind == VideoKind.lyric);
      expect(lyric.views, greaterThan(0));
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.channel.videos.length, 3);
      expect(g.channel.made[id], {VideoKind.lyric, VideoKind.acoustic});
      g.close();
      // Before the video site opened there is no channel.
      final old = GameSession.start(slots, _setup(startYear: 2003));
      expect(old.channel.open, isFalse);
      expect(() => old.uploadVideo(VideoKind.vlog), _code('cannotUpload'));
      old.close();
    });

    test('best sellers: all time, by year and each year\'s best (K141)', () {
      final g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      g.releaseAlbum('Gold', ids);
      final events = <GameEvent>[];
      while (g.yearEndYears.isEmpty) {
        events.addAll(g.advanceWeek().events);
      }
      // A superstar album sells a million in no time.
      final sold = BestSellers.playerSales(g.world);
      expect(sold, greaterThan(1e6));
      expect(events.whereType<SalesMilestone>().map((e) => e.copies),
          contains(1e6));
      for (final kind in BestSellerKind.values) {
        for (final m in SalesMeasure.values) {
          final rows = g.bestSellers(kind, measure: m);
          expect(rows.length, BestSellers.size);
          for (var i = 1; i < rows.length; i++) {
            expect(rows[i].value, lessThanOrEqualTo(rows[i - 1].value));
          }
        }
      }
      final artists = g.bestSellers(BestSellerKind.artists);
      final rank = g.bestSellerRank();
      expect(rank, greaterThan(0));
      if (rank <= BestSellers.size) {
        expect(artists[rank - 1].isPlayer, isTrue);
      }
      final copies = g.bestSellerRank(measure: SalesMeasure.sales);
      expect(copies, greaterThan(0));
      final y = g.yearEndYears.first;
      final year = g.yearEndArtists(y);
      expect(year, isNotEmpty);
      final wins = g.yearWinners;
      expect(wins.first.year, y);
      expect(wins.first.artist!.artistId, year.first.artistId);
      expect(wins.first.album!.entityId,
          g.yearEnd(Charts.globalAlbums, y).first.entityId);
      g.close();
    });

    test('a leaked song is answered by putting it out (K140)', () {
      final g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      for (var i = 0; i < 60; i++) {
        p.creativeEnergy = 100;
        g.writeSong(budget: BudgetTier.low);
      }
      // Unknowns' songs do not leak, nor anything before file sharing.
      final s0 = g.world.songs[g.vault.first.id];
      final fame = p.fame;
      p.fame = 0;
      expect(Leaks.chance(g.world, p, s0), 0);
      p.fame = fame;
      // A big vault leaks now and then, not every week (F83).
      final leaks = <SongLeaked>[];
      for (var i = 0; i < 156; i++) {
        p.fame = 1;
        leaks.addAll(g.advanceWeek().events.whereType<SongLeaked>());
      }
      expect(leaks, isNotEmpty);
      expect(leaks.length, lessThanOrEqualTo(156 ~/ Leaks.quietWeeks));
      expect(Leaks.weeklyOdds(10), closeTo(Leaks.maxWeekly, 1e-9));
      expect(Leaks.weeklyOdds(0.001), closeTo(0.001, 0.0001));
      final leak = leaks.last;
      // The next one waits.
      final w = g.world;
      for (final l in leaks.skip(1)) {
        final before = leaks[leaks.indexOf(l) - 1];
        expect(w.songs[l.songId].leakedWeek - w.songs[before.songId].leakedWeek,
            greaterThanOrEqualTo(Leaks.quietWeeks));
      }
      SongLeaked? fresh;
      for (var i = 0; i < 104 && fresh == null; i++) {
        p.fame = 1;
        fresh = g.advanceWeek().events.whereType<SongLeaked>().firstOrNull;
      }
      expect(leak, isNotNull);
      expect(fresh, isNotNull);
      final id = fresh!.songId;
      expect(g.song(id).leakedWeek, g.week - 1);
      expect(g.song(id).canAnswerLeak, isTrue);
      g.releaseSingle(id);
      expect(g.world.songs[id].versionBoost,
          greaterThanOrEqualTo(Leaks.answerBoost));
      expect(g.song(id).leakHurts, isFalse);
      // Left too long, a leak costs fans' plays and album sales.
      final late = g.world.songs[g.vault.first.id]
        ..leakedWeek = g.week - Leaks.answerWeeks - 1;
      expect(g.song(late.id).canAnswerLeak, isFalse);
      final tracks = [for (final v in g.vault.take(8)) v.id];
      final al = g.releaseAlbum('Leaked', tracks);
      expect(g.song(late.id).leakHurts, isTrue);
      expect(Leaks.fanFactor(late), Leaks.fanKeep);
      final hurt = tracks.where((t) => Leaks.hurts(g.world.songs[t])).length;
      expect(hurt, greaterThanOrEqualTo(1));
      expect(Leaks.albumKeep(g.world, g.world.albums[al.id]),
          closeTo(1 - Leaks.albumCutStreamingEra * hurt, 1e-9));
      g.close();
    });

    test('a re-recording wins the masters back from the label (K139)', () {
      var g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      final p = g.world.player!;
      Actions.signLabel(g.world, p, Label.major);
      final labelShare = p.artistShare;
      expect(labelShare, lessThan(1));
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 8; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final album = g.releaseAlbum('Fearless', ids);
      g.advanceWeek();
      expect(g.album(album.id).masterShare, labelShare);
      expect(g.album(album.id).rerecordBlock, RerecordBlock.tooSoon);
      while (g.week < album.releaseWeek + Rerecords.waitWeeks) {
        g.advanceWeeks(26, stop: SkipStop.never);
      }
      // Free of the label: the old album still pays the label's way.
      Actions.signLabel(g.world, p, Label.independent);
      g.advanceWeek();
      expect(g.album(album.id).masterShare, labelShare);
      expect(g.song(ids.first).masterShare, labelShare);
      expect(g.album(album.id).canRerecord, isTrue);
      p.creativeEnergy = 0;
      expect(() => g.rerecordAlbum(album.id, 'X'), _code('noEnergy'));
      p.creativeEnergy = 100;
      final money = g.player.moneyCents;
      final draft = g.rerecordAlbum(album.id, "Fearless (Nova's Version)");
      expect(g.player.creativeEnergy,
          100 - Rerecords.energyCost(g.world.albums[album.id]));
      expect(money - g.player.moneyCents,
          Rerecords.costCents(g.world.albums[album.id]));
      expect(draft.isDraft, isTrue);
      expect(draft.songIds.length, ids.length);
      expect(g.album(album.id).rerecordBlock, RerecordBlock.done);
      final copy = g.song(draft.songIds.first);
      expect(copy.rerecordOf, ids.first);
      expect(copy.title, g.song(ids.first).title);
      double oldStreams() => ids.fold(
          0.0, (x, id) => x + g.world.songLifetimeStreams(g.world.songs[id]));
      g.advanceWeek();
      final before = oldStreams();
      g.advanceWeek();
      final weekBefore = oldStreams() - before;
      final out = g.releaseDraft(draft.id);
      expect(out.isRerecord, isTrue);
      expect(out.originalAlbumId, album.id);
      expect(g.song(ids.first).replacedWeek, g.week);
      g.advanceWeek();
      final at = oldStreams();
      g.advanceWeek();
      // Most listeners moved to the new versions, which pay in full.
      expect(oldStreams() - at, lessThan(weekBefore * 0.6));
      final newIds = out.trackIds;
      final newStreams =
          newIds.fold(0.0, (x, id) => x + g.world.songs[id].weekStreams);
      expect(newStreams, greaterThan(oldStreams() - at));
      expect(g.song(newIds.first).masterShare, 1.0);
      expect(g.album(out.id).masterShare, 1.0);
      expect(g.album(out.id).rerecordBlock, RerecordBlock.isRerecord);
      expect(() => g.rerecordAlbum(album.id, 'Again'), _code('cannotRerecord'));
      // A long album can be re-recorded too (F81).
      final long = <int>[];
      for (var i = 0; i < 16; i++) {
        p.creativeEnergy = 100;
        long.add(g.writeSong(budget: BudgetTier.high).id);
      }
      Actions.signLabel(g.world, p, Label.major);
      final big = g.releaseAlbum('Long', long);
      while (g.week < big.releaseWeek + Rerecords.waitWeeks) {
        g.advanceWeeks(26, stop: SkipStop.never);
      }
      p.creativeEnergy = 100;
      expect(Rerecords.energyCost(g.world.albums[big.id]),
          lessThanOrEqualTo(Rerecords.maxEnergy));
      expect(g.rerecordAlbum(big.id, "Long (Nova's Version)").songIds.length,
          16);
      final slot = g.slotId;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.song(ids.first).replacedWeek, greaterThanOrEqualTo(0));
      expect(g.song(newIds.first).rerecordOf, ids.first);
      expect(g.album(album.id).masterShare, labelShare);
      g.close();
    });

    test('a remix with a star brings a released song back (K138)', () {
      (GameSession, int) run() {
        final g = GameSession.start(
            slots,
            _setup(
                tier: StartTier.superstar,
                money: StartMoney.millionaire,
                premium: true));
        g.world.player!.moneyCents = 1 << 40;
        g.world.player!.creativeEnergy = 100;
        final id = g.writeSong(budget: BudgetTier.high).id;
        g.releaseSingle(id);
        g.advanceWeeks(10, stop: SkipStop.never);
        return (g, id);
      }

      final (plain, pid) = run();
      final (g, id) = run();
      final rival = g.featureCandidates(id).first;
      final star = g.world.artists[rival.artistId];
      expect(rival.feeCents,
          (Features.feeCents(star) * Features.remixFeeFactor).round());
      final money = g.player.moneyCents;
      g.requestFeature(id, rival.artistId);
      expect(money - g.player.moneyCents, rival.feeCents);
      expect(g.world.songs[id].featuredArtistIds, contains(rival.artistId));
      expect(g.world.songs[id].versionBoost, greaterThan(0));
      expect(() => g.requestFeature(id, rival.artistId), throwsA(anything));
      plain.advanceWeeks(2, stop: SkipStop.never);
      g.advanceWeeks(2, stop: SkipStop.never);
      expect(g.world.songs[id].weekStreams,
          greaterThan(plain.world.songs[pid].weekStreams * 1.2));
      plain.close();
      final slot = g.slotId;
      g.close();
      final again = GameSession.resume(slots, slot);
      expect(again.world.songs[id].featuredArtistIds, contains(rival.artistId));
      again.close();
    });

    test('the songs of the summer come out in September (K137)', () {
      final g = GameSession.start(slots, _setup());
      expect(g.summerYears, isEmpty);
      SongOfSummer? news;
      while (GameTime.weekOfYear(g.week) != YearEnd.summerToWeekOfYear + 2) {
        for (final e in g.advanceWeek().events) {
          if (e is SongOfSummer) news = e;
        }
      }
      expect(news, isNotNull);
      expect(g.summerYears, [news!.year]);
      final rows = g.yearEnd(YearEnd.summer, news.year);
      expect(rows, isNotEmpty);
      expect(rows.first.entityId, news.topSongId);
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].points, lessThanOrEqualTo(rows[i - 1].points));
      }
      // Only summer weeks count: fewer weeks on than a whole year allows.
      expect(
          rows.first.weeksOn,
          lessThanOrEqualTo(
              YearEnd.summerToWeekOfYear - YearEnd.summerFromWeekOfYear + 1));
      g.close();
    });

    test('a holiday song sleeps all year and comes back in December (K136)',
        () {
      final g = GameSession.start(
          slots,
          _setup(
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              premium: true));
      g.world.player!.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high, holiday: true).id;
      expect(g.song(id).holiday, isTrue);
      g.releaseSingle(id);
      double streamsAt(int weekOfYear) {
        while (GameTime.weekOfYear(g.week - 1) != weekOfYear) {
          g.advanceWeek();
        }
        return g.world.songs[id].weekStreams;
      }

      final summer = streamsAt(30);
      final christmas = streamsAt(51);
      expect(christmas, greaterThan(summer * 2));
      // Next year it is back, with news.
      final events = <GameEvent>[];
      while (GameTime.weekOfYear(g.week - 1) != Holidays.returnWeek + 1) {
        events.addAll(g.advanceWeek().events);
      }
      expect(
          events.whereType<HolidayReturn>().map((e) => e.songId), contains(id));
      expect(g.world.songs[id].status, SongStatus.active);
      g.close();
    });

    test('a streaming exclusive pays now and streams less at first (K135)', () {
      (AlbumView, int, double) run(bool exclusive) {
        final g = GameSession.start(
            slots,
            _setup(
                startYear: 2016,
                tier: StartTier.superstar,
                money: StartMoney.millionaire,
                premium: true));
        g.world.player!.moneyCents = 1 << 40;
        final fee = g.exclusiveOffer!;
        final songs = <int>[];
        for (var i = 0; i < 8; i++) {
          g.world.player!.creativeEnergy = 100;
          songs.add(g.writeSong(budget: BudgetTier.high).id);
        }
        final money = g.player.moneyCents;
        final al = g.releaseAlbum('X', songs, exclusive: exclusive);
        final paid = g.player.moneyCents - money;
        g.advanceWeek();
        final sea = g.world.albums[al.id].weekSea;
        final view = g.albums.firstWhere((a) => a.id == al.id);
        g.close();
        expect(paid, exclusive ? greaterThan(fee ~/ 2) : lessThan(0));
        return (view, paid, sea);
      }

      final (open, _, openSea) = run(false);
      final (only, _, onlySea) = run(true);
      expect(open.exclusiveFeeCents, 0);
      expect(only.exclusiveFeeCents, greaterThan(0));
      expect(only.exclusiveUntil, greaterThan(0));
      expect(onlySea, lessThan(openSea * 0.6));
    });

    test('an album kept off streaming sells more, streams later (K174)',
        () {
      ({double pure, double sea, double after, int until}) run(int window) {
        var g = GameSession.start(
            slots,
            _setup(
                startYear: 2016,
                tier: StartTier.superstar,
                money: StartMoney.millionaire,
                premium: true));
        final slot = g.slotId;
        g.world.player!.moneyCents = 1 << 40;
        final songs = <int>[];
        for (var i = 0; i < 8; i++) {
          g.world.player!.creativeEnergy = 100;
          songs.add(g.writeSong(budget: BudgetTier.high).id);
        }
        expect(g.canWindow(AlbumType.album), isTrue);
        expect(g.canWindow(AlbumType.mixtape), isFalse);
        expect(
            () => g.releaseAlbum('X', songs, windowWeeks: 5),
            throwsA(isA<GameException>()
                .having((e) => e.code, 'code', 'invalidWindow')));
        expect(
            () => g.releaseAlbum('X', songs, windowWeeks: 4, exclusive: true),
            throwsA(isA<GameException>()));
        final al = g.releaseAlbum('X', songs, windowWeeks: window);
        var pure = 0.0, sea = 0.0;
        for (var i = 0; i < 4; i++) {
          g.advanceWeek();
          pure += g.world.albums[al.id].weekPure;
          sea += g.world.albums[al.id].weekSea;
          if (window > 0) {
            for (final id in songs) {
              expect(g.world.songs[id].weekStreams, 0);
            }
          }
        }
        // A save keeps it.
        g.close();
        g = GameSession.resume(slots, slot);
        final until = g.albums.firstWhere((a) => a.id == al.id).windowUntil;
        g.advanceWeek();
        final after = songs.fold(
            0.0, (sum, id) => sum + g.world.songs[id].weekStreams);
        g.close();
        return (pure: pure, sea: sea, after: after, until: until);
      }

      final open = run(0);
      final held = run(4);
      expect(open.until, -1);
      expect(held.until, greaterThan(0));
      expect(held.sea, lessThan(open.sea * 0.2));
      expect(held.pure, greaterThan(open.pure * 1.2));
      // Out on the apps once the window ends.
      expect(held.after, greaterThan(0));
    });

    test('rival stars surprise-drop and go exclusive (K175)', () {
      final g = GameSession.start(slots, _setup(startYear: 2016));
      final seen = <(int, int)>{};
      final moves = <RivalAlbumMove>[];
      bool both() =>
          moves.any((m) => m.move == RivalMove.surprise) &&
          moves.any((m) => m.move == RivalMove.exclusive);
      // The exclusive years (2015–2019): a few eligible albums a year.
      for (var i = 0; i < 4 * 52 && !both(); i++) {
        for (final u in g.upcomingRivalAlbums) {
          seen.add((u.artistId, u.week));
        }
        final now = g.advanceWeek().events.whereType<RivalAlbumMove>();
        // Stars make the moves (ranks change every year, so check now).
        for (final m in now) {
          expect(g.world.artists[m.artistId].tier, ArtistTier.a);
        }
        moves.addAll(now);
      }
      expect(moves.map((m) => m.move),
          containsAll([RivalMove.surprise, RivalMove.exclusive]));
      for (final m in moves) {
        final al = g.world.albums[m.albumId];
        if (m.move == RivalMove.surprise) {
          // Nobody saw it coming.
          expect(seen, isNot(contains((al.artistId, al.releaseWeek))));
        } else if (m.move == RivalMove.exclusive) {
          expect(al.exclusiveUntil, al.releaseWeek + m.weeks);
        }
      }
      g.close();
    });

    test('the release calendar shows the dates ahead (K177)', () {
      final g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final w0 = g.week;
      g.world.player!.creativeEnergy = 100;
      final song = g.writeSong(budget: BudgetTier.low).id;
      g.scheduleSingle(song,
          campaign: Campaign.standard,
          releaseWeek: w0 + 6,
          announceWeek: w0 + 4);
      g.startTour(const TourRequest(
          name: 'Run', legs: [TourLeg(TourMarket.usa, TourKind.club, 6)]));
      final cal = g.calendar;
      List<CalendarEntry> at(int week) =>
          cal.where((c) => c.week == week).expand((c) => c.entries).toList();
      expect(at(w0 + 6).map((e) => e.kind), contains(CalendarKind.release));
      expect(at(w0 + 6).first.title, g.song(song).title);
      expect(at(w0 + 4).map((e) => e.kind), contains(CalendarKind.announce));
      final tourWeeks = [
        for (final c in cal)
          if (c.entries.any((e) => e.kind == CalendarKind.tour)) c.week
      ];
      expect(tourWeeks, isNotEmpty);
      // Half a year always holds some of the year's dates, in order.
      expect(cal.expand((c) => c.entries).where((e) => e.isSeason),
          isNotEmpty);
      for (var i = 1; i < cal.length; i++) {
        expect(cal[i].week, greaterThan(cal[i - 1].week));
      }
      for (final c in cal) {
        expect(c.week, inInclusiveRange(w0, w0 + ReleaseCalendar.weeks - 1));
      }
      // Big rivals' announced albums are on it.
      for (final r in g.upcomingRivalAlbums) {
        expect(
            at(r.week).any((e) =>
                e.kind == CalendarKind.rivalAlbum && e.artistId == r.artistId),
            isTrue);
      }
      g.close();
    });

    test('a Streamify Session: own song stripped back and a cover (K178)',
        () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2019,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final slot = g.slotId;
      final p = g.world.player!;
      p.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(id);
      for (var i = 0; i < 6; i++) {
        g.advanceWeek();
      }
      final v = g.sessions;
      expect(v.listeners, greaterThan(StreamifySessions.minListeners));
      expect(v.block, isNull);
      expect(v.songs.map((s) => s.id), contains(id));
      expect(v.covers, isNotEmpty);
      expect(() => g.releaseVersion(id, SongVersion.session),
          _code('noSession'));
      final cover = v.covers.first;
      final casual = p.casual;
      final original = g.world.songs[cover.id].versionBoost;
      p.creativeEnergy = 100;
      g.recordSession(id, cover.id);
      expect(g.world.songs[id].versions.map((x) => x.$1),
          contains(SongVersion.session));
      expect(g.world.songs[id].playlistBoost,
          greaterThanOrEqualTo(g.world.config.playlistMidBoost));
      expect(p.casual, greaterThan(casual));
      expect(g.world.songs[cover.id].versionBoost, greaterThan(original));
      // One a year.
      expect(g.sessions.block, SessionBlock.tooSoon);
      expect(() => g.recordSession(id, cover.id), _code('noSession'));
      g.close();
      g = GameSession.resume(slots, slot);
      final after = g.sessions;
      expect(after.sessions.single.title, g.song(id).title);
      expect(after.sessions.single.coverTitle, cover.title);
      expect(after.songs.map((s) => s.id), isNot(contains(id)));
      g.close();
    });

    test('tour legs sized to what the fans fill (K181)', () {
      final g = GameSession.start(
          slots,
          _setup(
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      g.world.player!.coreFans = 4e6;
      for (final kind in [TourKind.arena, TourKind.stadium]) {
        const m = TourMarket.usa;
        final n = g.suggestTourShows(
            TourRequest(legs: [TourLeg(m, kind, 1)]), m);
        expect(n, inInclusiveRange(1, Tours.maxShows(m, kind)));
        double fill(int shows) => g
            .tourPreview(TourRequest(legs: [TourLeg(m, kind, shows)]))
            .legs
            .single
            .fill;
        expect(fill(n), greaterThanOrEqualTo(GameSession.suggestedFill));
        if (n < Tours.maxShows(m, kind)) {
          expect(fill(Tours.maxShows(m, kind)),
              lessThan(GameSession.suggestedFill));
        }
      }
      // Pricier tickets: fewer nights.
      final cheap = g.suggestTourShows(
          const TourRequest(
              legs: [TourLeg(TourMarket.usa, TourKind.stadium, 1)]),
          TourMarket.usa);
      final dear = g.suggestTourShows(
          const TourRequest(
              legs: [TourLeg(TourMarket.usa, TourKind.stadium, 1)],
              priceFactor: 1.8),
          TourMarket.usa);
      expect(dear, lessThanOrEqualTo(cheap));
      g.close();
    });

    test('the next single picked from what listeners do (K182)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2020,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 10; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final al = g.releaseAlbum('Picks', ids);
      for (var i = 0; i < 3; i++) {
        g.advanceWeek();
      }
      final picks = g.singlePicks(al.id);
      expect(picks.length, GameSession.singlePickCount);
      for (var i = 1; i < picks.length; i++) {
        expect(picks[i].score, lessThanOrEqualTo(picks[i - 1].score));
      }
      expect(picks.every((x) => ids.contains(x.songId)), isTrue);
      // The most played track is flagged wherever it ranks.
      final top = ids
          .map((id) => g.world.songs[id])
          .reduce((a, b) => a.lastAttention >= b.lastAttention ? a : b);
      for (final x in picks) {
        expect(x.reasons.contains(SinglePickReason.mostPlayed),
            x.songId == top.id);
      }
      g.releaseSingle(picks.first.songId);
      expect(g.singlePicks(al.id).map((x) => x.songId),
          isNot(contains(picks.first.songId)));
      // Only the player's own albums.
      final rival = g.world.albums.firstWhere((a) => a.artistId != p.id);
      expect(g.singlePicks(rival.id), isEmpty);
      g.close();
    });

    test('ringtones sell in their years and chart (K183)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2006,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final slot = g.slotId;
      g.world.player!.creativeEnergy = 100;
      final id = g.writeSong(budget: BudgetTier.high, genres: [1]).id;
      g.releaseSingle(id);
      for (var i = 0; i < 3; i++) {
        g.advanceWeek();
      }
      final s = g.world.songs[id];
      expect(s.weekRingtones, greaterThan(0));
      expect(s.weekRingtones, lessThan(s.weekDownloads * 2));
      expect(s.lifetimeRingtones, greaterThan(s.weekRingtones));
      expect(g.songIncome(id).cents[IncomeSource.ringtones], greaterThan(0));
      final chart = g.chart(Charts.usRingtones);
      expect(chart.rows, isNotEmpty);
      for (var i = 1; i < chart.rows.length; i++) {
        expect(chart.rows[i].weekValue,
            lessThanOrEqualTo(chart.rows[i - 1].weekValue));
      }
      final total = s.lifetimeRingtones;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.world.songs[id].lifetimeRingtones, closeTo(total, 1e-6));
      g.close();
      // Gone by the streaming years.
      expect(Charts.all[Charts.usRingtones].activeIn(GameTime.firstWeekOf(2011)),
          isFalse);
      expect(Ringtones.eraFactor(2015), 0);
    });

    test('the Artist Pick and a countdown page (K185)', () {
      (double, GameSession) run(bool pin) {
        final g = GameSession.start(
            slots,
            _setup(
                startYear: 2022,
                premium: true,
                tier: StartTier.superstar,
                money: StartMoney.millionaire));
        final p = g.world.player!;
        p.moneyCents = 1 << 40;
        final ids = <int>[];
        for (var i = 0; i < 9; i++) {
          p.creativeEnergy = 100;
          ids.add(g.writeSong(budget: BudgetTier.high).id);
        }
        final sr = g.scheduleAlbum('Soon', ids.take(8).toList(),
            releaseWeek: g.week + 6, announceWeek: g.week);
        if (pin) g.setArtistPick(PickKind.upcoming, sr.id);
        for (var i = 0; i < 4; i++) {
          g.advanceWeek();
        }
        final saves = g.scheduled.firstWhere((x) => x.id == sr.id).preSaves;
        return (saves, g);
      }

      final (plain, g0) = run(false);
      g0.close();
      final (pinned, g) = run(true);
      expect(pinned, greaterThan(plain * 1.2));
      expect(g.artistPick.current!.kind, PickKind.upcoming);
      expect(g.artistPick.title, 'Soon');
      // Once out, the countdown is the album.
      for (var i = 0; i < 3; i++) {
        g.advanceWeek();
      }
      final now = g.artistPick.current!;
      expect(now.kind, PickKind.album);
      expect(g.world.albums[now.id].title, 'Soon');
      expect(ArtistPicks.lifts(g.world).keys,
          containsAll(g.world.albums[now.id].songIds));
      // A song; unreleased songs cannot be pinned.
      final vault = g.world.playerSongIds
          .firstWhere((id) => g.world.songs[id].releasedWeek < 0);
      expect(() => g.setArtistPick(PickKind.song, vault), _code('noPick'));
      final out = g.world.albums[now.id].songIds.first;
      g.setArtistPick(PickKind.song, out);
      expect(ArtistPicks.lifts(g.world)[out],
          closeTo(ArtistPicks.songLift, 1e-9));
      final slot = g.slotId;
      g.close();
      final again = GameSession.resume(slots, slot);
      expect(again.artistPick.current!.id, out);
      // Stale pins fade.
      for (var i = 0; i < 26; i++) {
        again.advanceWeek();
      }
      expect(again.artistPick.freshness, lessThan(0.4));
      again.close();
    });

    test('mood playlists keep a catalog song going (K186)', () {
      (double, GameSession, int) run({bool pitch = false, bool force = false}) {
        final g = GameSession.start(
            slots,
            _setup(
                startYear: 2016,
                premium: true,
                tier: StartTier.superstar,
                money: StartMoney.millionaire));
        g.world.player!.creativeEnergy = 100;
        final id = g.writeSong(budget: BudgetTier.high, genres: [0]).id;
        g.releaseSingle(id);
        for (var i = 0; i < MoodPlaylists.minAgeWeeks; i++) {
          g.advanceWeek();
        }
        expect(g.song(id).canMood, isTrue);
        if (pitch) {
          final best = g.moodOptions(id).reduce((a, b) =>
              a.chance >= b.chance ? a : b);
          expect(best.fit, inInclusiveRange(0.0, 1.0));
          expect(best.chance, inInclusiveRange(0.1, 0.7));
          final inList = g.pitchMood(id, best.mood);
          expect(g.song(id).moodIn, inList);
          expect(g.song(id).mood, best.mood);
          expect(g.song(id).canMood, isFalse);
          expect(() => g.pitchMood(id, Mood.chill), _code('noMood'));
        }
        if (force) {
          g.world.songs[id]
            ..moodWeek = g.week
            ..mood = Mood.sad.index
            ..moodIn = true;
        }
        var streams = 0.0;
        for (var i = 0; i < 4; i++) {
          g.advanceWeek();
          streams += g.world.songs[id].weekStreams;
        }
        return (streams, g, id);
      }

      final (_, g1, id1) = run(pitch: true);
      final slot = g1.slotId;
      final mood = g1.song(id1).mood;
      g1.close();
      final again = GameSession.resume(slots, slot);
      expect(again.song(id1).mood, mood);
      again.close();
      final (plain, g2, _) = run();
      g2.close();
      final (listed, g3, id3) = run(force: true);
      expect(MoodPlaylists.lifts(g3.world)[id3], greaterThan(0));
      g3.close();
      expect(listed, greaterThan(plain * 1.05));
    });

    test('the critics\' albums of the year (K187)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2015,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      final ids = <int>[];
      for (var i = 0; i < 10; i++) {
        p.creativeEnergy = 100;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      final al = g.releaseAlbum('Reviewed', ids);
      final events = <GameEvent>[];
      while (GameTime.weekOfYear(g.week - 1) != YearEnd.publishWeekOfYear) {
        events.addAll(g.advanceWeek().events);
      }
      final year = GameTime.yearOf(g.week - 1);
      final list = g.yearEnd(YearEnd.critics, year);
      expect(list, isNotEmpty);
      expect(list.length, lessThanOrEqualTo(YearEnd.criticsSize));
      for (var i = 1; i < list.length; i++) {
        expect(list[i].points, lessThanOrEqualTo(list[i - 1].points));
      }
      final mine = list.where((r) => r.entityId == al.id).firstOrNull;
      final news = events.whereType<CriticsList>().toList();
      if (mine != null) {
        expect(news.single.rank, mine.rank);
        expect(news.single.metascore,
            Critics.metascore(g.world, g.world.albums[al.id]));
      } else {
        expect(news, isEmpty);
      }
      g.close();
    });

    test('a member leaves the group and the player goes solo (K191)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2015,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              kind: ArtistKind.vocalGroup,
              members: const ['Yuna', 'Mira', 'Jin', 'Sora']));
      final slot = g.slotId;
      final group = g.world.player!;
      group.moneyCents = 1 << 36;
      final released = <int>[];
      for (var i = 0; i < 3; i++) {
        group.creativeEnergy = 100;
        final id = g.writeSong(budget: BudgetTier.high).id;
        g.releaseSingle(id);
        released.add(id);
        g.advanceWeeks(3, stop: SkipStop.never);
      }
      final vault = <int>[];
      for (var i = 0; i < 3; i++) {
        group.creativeEnergy = 100;
        vault.add(g.writeSong(budget: BudgetTier.high).id);
      }
      // A single set for later: called off, its money back.
      final sr = g.scheduleSingle(vault.last,
          releaseWeek: g.week + 6, announceWeek: g.week);
      g.openFanClub(ClubPrice.mid);
      g.advanceWeek();
      expect(g.members, hasLength(4));

      final preview = g.goSoloPreview(1);
      expect(preview.name, 'Mira');
      expect(preview.block, isNull);
      expect(preview.groupBreaksUp, isFalse);
      expect(preview.scheduled, 1);
      expect(preview.fanClub, isTrue);
      final money = group.moneyCents + sr.paidCents;
      final fans = group.coreFans, fame = group.fame;
      final skills = group.skills.songwriting;
      final energy = group.creativeEnergy;
      final streamsBefore = g.world.playerCareerStreams;
      final k = Lineups.importance(g.world, group, 1);
      expect(preview.importance, closeTo(k, 1e-9));

      g.goSolo(1);
      final w = g.world;
      final solo = w.player!;
      expect(solo.id, isNot(group.id));
      expect(solo.name, 'Mira');
      expect(solo.kind, ArtistKind.solo);
      expect(solo.tier, ArtistTier.player);
      expect(solo.managedBy, -1);
      expect(solo.moneyCents, money);
      expect(solo.skills.songwriting, skills);
      expect(solo.creativeEnergy, energy);
      expect(solo.coreFans, closeTo(fans * GoSolo.fansTaken(k), 1));
      expect(solo.fame, closeTo(fame * GoSolo.fameTaken(k), 1e-9));
      expect(preview.fans, closeTo(solo.coreFans, 1));
      expect(w.playerCareerStreams, closeTo(streamsBefore, 1));
      expect(w.formerGroupId, group.id);
      // The group goes on without her, as a rival after a break.
      expect(group.tier, isNot(ArtistTier.player));
      expect(group.members, ['Yuna', 'Jin', 'Sora']);
      expect(group.coreFans, closeTo(fans * GoSolo.fansKept(k), 1));
      expect(group.moneyCents, 0);
      expect(group.isRetired, isFalse);
      expect(group.nextEraWeek, w.week + GoSolo.groupBreakWeeks);
      // Unreleased songs go with her; the group's records stay its own.
      expect(w.playerSongIds.toSet(), vault.toSet());
      for (final id in released) {
        expect(w.songs[id].primaryArtistId, group.id);
      }
      expect(solo.scheduled, isEmpty);
      expect(w.fanClub, isNull);
      expect(g.members, isEmpty);
      expect(() => g.goSolo(0), _code('notGroup'));
      expect(() => g.goSoloPreview(0), _code('noMember'));

      // Her first single, and the group back after its break.
      solo.creativeEnergy = 100;
      g.releaseSingle(vault.first);
      final mid = solo.moneyCents;
      g.advanceWeeks(GoSolo.groupBreakWeeks + 8, stop: SkipStop.never);
      expect(solo.moneyCents, isNot(mid));
      expect(w.songs[vault.first].lifetimeStreams, greaterThan(0));
      expect(
          w.albums.any((al) =>
              al.artistId == group.id && al.releaseWeek > w.week - 20) ||
              w.songs.any((s) =>
                  s.primaryArtistId == group.id &&
                  s.releasedWeek > w.week - 20),
          isTrue);
      for (final y in g.careerByYear()) {
        expect(y.streams, greaterThanOrEqualTo(0));
      }
      final listeners = g.artistPage(solo.id).listenerStreams;
      expect(listeners, greaterThan(0));
      final ids = w.playerSongIds.toList();

      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.world.playerArtistId, solo.id);
      expect(g.world.formerGroupId, group.id);
      expect(g.world.playerSongIds, ids);
      expect(g.world.managedSongIds, isEmpty);
      expect(g.world.playerCareerStreams,
          closeTo(w.playerCareerStreams, 1));
      expect(g.artistPage(solo.id).listenerStreams, closeTo(listeners, 1));
      g.advanceWeek();
      g.close();
    });

    test('members have roles and their own popularity (K192)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2018,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              kind: ArtistKind.vocalGroup,
              members: const ['Yuna', 'Mira', 'Jin', 'Sora']));
      final slot = g.slotId;
      var ms = g.members;
      expect(ms, hasLength(4));
      int holders(MemberRole r) => ms.where((m) => m.roles.contains(r)).length;
      for (final r in [
        MemberRole.leader,
        MemberRole.mainVocal,
        MemberRole.visual,
        MemberRole.maknae
      ]) {
        expect(holders(r), 1, reason: r.name);
      }
      expect(ms.last.roles, contains(MemberRole.maknae));
      for (final m in ms) {
        expect(m.popularity, inInclusiveRange(0.0, 100.0));
        expect(m.roles.every(MemberRole.forKind(ArtistKind.vocalGroup).contains),
            isTrue);
      }
      expect(ms.fold(0.0, (t, m) => t + m.share), closeTo(1, 1e-9));

      // A role only one can hold moves; a band's role is not theirs.
      g.setMemberRoles(0, {MemberRole.visual, MemberRole.leadVocal});
      ms = g.members;
      expect(holders(MemberRole.visual), 1);
      expect(ms[0].roles, contains(MemberRole.visual));
      expect(() => g.setMemberRoles(0, {MemberRole.drums}), _code('noRole'));
      expect(() => g.setMemberFocus(4), _code('noMember'));

      // The label pushes its least popular member for a year.
      final before = [for (final m in ms) m.popularity];
      final low = ms.reduce((a, b) => a.popularity <= b.popularity ? a : b).index;
      g.setMemberFocus(low);
      g.advanceWeeks(52, stop: SkipStop.never);
      ms = g.members;
      expect(ms[low].focused, isTrue);
      expect(ms[low].focusWeeks, 52);
      expect(ms[low].popularity, greaterThan(before[low] + 15));
      for (final m in ms) {
        if (m.index != low) expect(m.popularity, lessThan(before[m.index]));
      }
      expect(ms.reduce((a, b) => a.share >= b.share ? a : b).index, low);
      expect(g.goSoloPreview(low).ace, isTrue);
      final other = (low + 1) % 4;
      expect(g.goSoloPreview(low).importance,
          greaterThan(g.goSoloPreview(other).importance));

      // A solo single gets a member noticed.
      final p = g.world.player!..creativeEnergy = 100;
      final song = g.writeSong(budget: BudgetTier.high).id;
      final pop3 = p.memberPop[3];
      g.releaseMemberSolo(3, song);
      expect(p.memberPop[3], closeTo(pop3 + Lineups.soloGain, 1e-9));

      g.close();
      g = GameSession.resume(slots, slot);
      ms = g.members;
      expect(ms[low].focused, isTrue);
      expect(ms[0].roles, contains(MemberRole.visual));
      expect(ms[3].popularity, closeTo(pop3 + Lineups.soloGain, 0.01));
      g.setMemberFocus(-1);
      expect(g.members.any((m) => m.focused), isFalse);
      g.close();
    });

    test('the ace leaving sinks the group; a quiet member does not (K192)',
        () {
      // -1: the least popular member when they leave.
      (double, double) split(int leaving) {
        final g = GameSession.start(
            slots,
            _setup(
                startYear: 2018,
                premium: true,
                tier: StartTier.superstar,
                money: StartMoney.millionaire,
                kind: ArtistKind.vocalGroup,
                members: const ['Yuna', 'Mira', 'Jin', 'Sora']));
        g.setMemberFocus(1);
        g.advanceWeeks(40, stop: SkipStop.never);
        final group = g.world.player!;
        final fans = group.coreFans;
        if (leaving < 0) {
          final ms = g.members;
          leaving =
              ms.reduce((a, b) => a.popularity <= b.popularity ? a : b).index;
        }
        g.goSolo(leaving);
        final out = (group.coreFans / fans, g.world.player!.coreFans / fans);
        g.close();
        return out;
      }

      final (aceKept, aceTook) = split(1);
      final quiet = split(-1);
      expect(aceKept, lessThan(GoSolo.keepFans));
      expect(aceTook, greaterThan(GoSolo.takeFans));
      expect(quiet.$1, greaterThan(aceKept + 0.1));
      expect(quiet.$2, lessThan(aceTook));
    });

    test('the star leaves and the group never comes back (K192)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2000,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              kind: ArtistKind.vocalGroup,
              members: const ['Justin', 'JC', 'Chris', 'Joey', 'Lance']));
      final group = g.world.player!;
      // The label makes him the face of the group for years.
      g.setMemberRoles(0, {
        MemberRole.leader,
        MemberRole.mainVocal,
        MemberRole.mainDancer,
        MemberRole.visual
      });
      g.setMemberFocus(0);
      g.advanceWeeks(104, stop: SkipStop.never);
      final v = g.goSoloPreview(0);
      expect(v.ace, isTrue);
      expect(v.importance, greaterThanOrEqualTo(GoSolo.hiatusAt));
      expect(v.hiatus, isTrue);
      expect(v.groupBreaksUp, isTrue);
      final fans = group.coreFans;
      g.goSolo(0);
      expect(group.isRetired, isTrue);
      expect(g.world.player!.coreFans, greaterThan(fans * 0.5));
      g.advanceWeeks(30, stop: SkipStop.never);
      expect(
          g.world.songs.any((s) =>
              s.primaryArtistId == group.id && s.releasedWeek > g.week - 30),
          isFalse);
      g.close();
    });

    GameSession newGroup(
            {int year = 2016, StartTier tier = StartTier.superstar}) =>
        GameSession.start(
            slots,
            _setup(
                startYear: year,
                premium: true,
                tier: tier,
                money: StartMoney.millionaire,
                kind: ArtistKind.vocalGroup,
                members: const ['Yuna', 'Mira', 'Jin', 'Sora']));

    test('a song built around its center plays more (K193)', () {
      (double, GameSession, int) run(LineSplit split) {
        final g = newGroup();
        g.setLineSplit(split);
        g.world.player!.creativeEnergy = 100;
        final id = g.writeSong(budget: BudgetTier.high).id;
        g.releaseSingle(id);
        var streams = 0.0;
        for (var i = 0; i < 8; i++) {
          g.advanceWeek();
          streams += g.world.songs[id].weekStreams;
        }
        return (streams, g, id);
      }

      final (even, g1, _) = run(LineSplit.even);
      expect(g1.lineup!.split, LineSplit.even);
      expect(g1.lineup!.lift, 0);
      final devotionEven = g1.world.player!.devotion;
      g1.close();
      final (center, g2, _) = run(LineSplit.center);
      final v = g2.lineup!;
      expect(v.split, LineSplit.center);
      expect(v.lift, greaterThan(0));
      final ms = g2.members;
      expect(ms[v.center].center, isTrue);
      // The center rises; the others sing less and like it less.
      for (final m in ms) {
        if (m.index == v.center) continue;
        expect(m.morale, lessThan(ms[v.center].morale));
      }
      expect(g2.world.player!.devotion, lessThan(devotionEven));
      g2.close();
      expect(center, greaterThan(even * 1.005));
    });

    test('unhappy members talk, get a bonus, or walk out (K195)', () {
      final g = newGroup(tier: StartTier.risingStar);
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      var ms = g.members;
      for (final m in ms) {
        expect(m.morale, Lineups.moraleRest);
      }
      // A bonus lifts one member, then not again for a while.
      p.memberMorale[2] = 40;
      final money = p.moneyCents;
      final cost = g.lineup!.cheerCents;
      g.cheerMember(2);
      expect(p.memberMorale[2], 40 + Lineups.cheerMorale);
      expect(p.moneyCents, money - cost);
      expect(g.lineup!.canCheer, isFalse);
      expect(() => g.cheerMember(1), _code('cheerSoon'));

      // Pushing one member and building every song around them.
      g.setMemberFocus(0);
      g.setLineSplit(LineSplit.center);
      final events = <GameEvent>[];
      for (var i = 0; i < 160 && events.whereType<MemberQuit>().isEmpty; i++) {
        events.addAll(g.advanceWeek().events);
      }
      expect(events.whereType<MemberUnhappy>(), isNotEmpty);
      final quit = events.whereType<MemberQuit>().single;
      expect(quit.name, isNot('Yuna'));
      expect(quit.fansLost, greaterThan(0));
      expect(p.members, hasLength(3));
      expect(p.members, isNot(contains(quit.name)));
      expect(p.memberMorale, hasLength(3));
      final gone = g.world.artists.firstWhere((a) => a.name == quit.name);
      expect(gone.managedBy, -1);
      expect(gone.tier, ArtistTier.b);
      expect(gone.isRetired, isFalse);
      g.close();
    });

    test('the contracts come up every seven years (K195)', () {
      final g = newGroup(year: 2005, tier: StartTier.unknown);
      final p = g.world.player!;
      final at = g.lineup!.renewalWeek;
      expect(at, p.debutWeek + MemberMorale.renewalWeeks);
      g.advanceWeeks(at - MemberMorale.warnWeeks - 1 - g.week,
          stop: SkipStop.never);
      // Sora is fed up just before.
      p.memberMorale[3] = 5;
      final events = <GameEvent>[];
      while (g.week <= at) {
        events.addAll(g.advanceWeek().events);
        if (p.memberMorale.length > 3) {
          p.memberMorale[3] = math.min(p.memberMorale[3], 20);
        }
      }
      final soon = events.whereType<RenewalSoon>().single;
      expect(soon.atRisk, contains('Sora'));
      final done = events.whereType<RenewalDone>().single;
      expect(done.left, ['Sora']);
      expect(done.stayed, 3);
      expect(p.members, ['Yuna', 'Mira', 'Jin']);
      expect(g.lineup!.renewalWeek, at + MemberMorale.renewalWeeks);
      g.close();
    });

    test('a reunion with the group, years later (K194)', () {
      var g = newGroup();
      final slot = g.slotId;
      final band = g.world.player!..creativeEnergy = 100;
      final hit = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(hit);
      g.advanceWeek();
      g.goSolo(1);
      final w = g.world;
      final solo = w.player!;
      var v = g.reunion!;
      expect(v.groupName, band.name);
      expect(v.block, ReunionBlock.tooSoon);
      expect(v.openWeek, w.playerSinceWeek + Reunions.gapWeeks);
      expect(() => g.startReunion(), _code('reunionSoon'));
      // Years apart.
      w.playerSinceWeek -= Reunions.gapWeeks + 5 * 52;
      v = g.reunion!;
      expect(v.block, isNull);
      expect(v.audience.fans, greaterThan(band.coreFans));
      final fans = v.audience.fans;
      g.startReunion();
      expect(band.managedBy, solo.id);
      expect(band.members.last, 'Mira');
      expect(band.coreFans, closeTo(fans, 1));
      expect(g.reunion!.active, isTrue);
      expect(() => g.startReunion(), _code('reunionOn'));
      expect(w.managedSongIds, isNotEmpty);

      // A single under the group's name, paid by the player.
      solo
        ..creativeEnergy = 100
        ..moneyCents = 1 << 40;
      final id = g.writeSong(budget: BudgetTier.high).id;
      final money = solo.moneyCents;
      final cost = g.reunionCosts[Campaign.standard.index];
      g.releaseReunionSingle(id);
      expect(solo.moneyCents, money - cost);
      final song = w.songs.last;
      expect(song.primaryArtistId, band.id);
      expect(song.releasedWeek, greaterThanOrEqualTo(0));
      expect(w.managedSongIds, contains(song.id));
      g.advanceWeeks(4, stop: SkipStop.never);
      expect(w.songs[song.id].lifetimeStreams, greaterThan(0));
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.reunion!.active, isTrue);
      expect(g.world.artists[band.id].managedBy, solo.id);

      final events = <GameEvent>[];
      while (g.reunion!.active) {
        events.addAll(g.advanceWeek().events);
      }
      final over = events.whereType<ReunionOver>().single;
      expect(over.groupId, band.id);
      expect(over.ended, isFalse);
      final b = g.world.artists[band.id];
      expect(b.managedBy, -1);
      expect(b.members, isNot(contains('Mira')));
      expect(g.world.managedSongIds, isEmpty);
      expect(g.reunion!.block, ReunionBlock.tooSoon);
      g.close();
    });

    test('the reunion tour sells on the old group\'s fans (K196)', () {
      final g = newGroup();
      final band = g.world.player!;
      g.goSolo(1);
      final w = g.world;
      final solo = w.player!;
      const legs = [TourLeg(TourMarket.usa, TourKind.arena, 12)];
      final own = g.tourPreview(const TourRequest(legs: legs));
      // Not without a reunion on.
      expect(g.tourPreview(const TourRequest(legs: legs, reunion: true))
          .problems, contains('noReunion'));
      w.playerSinceWeek -= Reunions.gapWeeks + 5 * 52;
      g.startReunion();
      final reunion =
          g.tourPreview(const TourRequest(legs: legs, reunion: true));
      expect(reunion.problems, isEmpty);
      expect(reunion.estimate.tickets, greaterThan(own.estimate.tickets));
      // It has to fit in the reunion's year.
      expect(
          g.tourPreview(TourRequest(legs: [
            for (final m in TourMarket.values)
              TourLeg(m, TourKind.arena, Tours.maxShows(m, TourKind.arena))
          ], reunion: true)).problems,
          contains('reunionTourLong'));

      final money = solo.moneyCents;
      final groupFans = band.coreFans;
      g.startTour(const TourRequest(legs: legs, reunion: true));
      expect(solo.tour!.reunionOf, band.id);
      expect(solo.tour!.name, '${band.name} Reunion Tour');
      while (solo.tour != null) {
        g.advanceWeek();
      }
      expect(solo.moneyCents, greaterThan(money));
      expect(band.coreFans, greaterThan(groupFans * 0.98));
      final record = w.tourRecords.last;
      expect(record.artistId, band.id);
      expect(record.tickets, greaterThan(0));
      g.close();
    });

    test('a group that ended comes back for the reunion only (K194)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2014,
              kind: ArtistKind.band,
              members: const ['Ana', 'Leo']));
      final duo = g.world.player!;
      g.goSolo(0);
      expect(duo.isRetired, isTrue);
      g.world.playerSinceWeek -= Reunions.gapWeeks;
      g.startReunion();
      expect(duo.isRetired, isFalse);
      expect(g.world.activeArtistIds, contains(duo.id));
      g.advanceWeeks(Reunions.weeks + 1, stop: SkipStop.never);
      expect(duo.isRetired, isTrue);
      expect(duo.managedBy, -1);
      g.close();
    });

    test('rival groups lose members to solo careers (K199)', () {
      var g = GameSession.start(slots, _setup(startYear: 2005));
      final slot = g.slotId;
      final events = <GameEvent>[];
      for (var y = 0; y < 8; y++) {
        events.addAll(g.advanceWeeks(52, stop: SkipStop.never).events);
      }
      final w = g.world;
      expect(w.rivalSplits, isNotEmpty);
      // A few a year at most.
      expect(w.rivalSplits.length, lessThanOrEqualTo(8 * RivalSplits.maxPerYear));
      for (final x in w.rivalSplits) {
        final group = w.artists[x.groupId];
        final solo = w.artists[x.soloId];
        expect(solo.managedBy, -1);
        expect(solo.tier, isNot(ArtistTier.player));
        expect(solo.kind, ArtistKind.solo);
        if (x.ended) expect(group.isRetired, isTrue);
        expect(w.week - group.debutWeek,
            greaterThanOrEqualTo(RivalSplits.minYears * 52));
      }
      final news = events.whereType<RivalGroupSplit>().toList();
      for (final e in news) {
        expect(w.rivalSplits.any((x) => x.soloId == e.soloId), isTrue);
      }
      // Some of the new solo artists have put records out by now.
      final early = [
        for (final x in w.rivalSplits)
          if (w.week - x.week > 52) x.soloId
      ];
      if (early.isNotEmpty) {
        expect(
            w.songs.any((s) =>
                early.contains(s.primaryArtistId) && s.releasedWeek >= 0),
            isTrue);
      }
      final n = w.rivalSplits.length;
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.world.rivalSplits, hasLength(n));
      g.close();
    });

    test('a band has band roles (K192)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2005,
              kind: ArtistKind.band,
              members: const ['Ana', 'Leo', 'Max']));
      final ms = g.members;
      expect(ms[0].roles, contains(MemberRole.frontman));
      expect(ms[1].roles, contains(MemberRole.guitar));
      expect(ms[2].roles, contains(MemberRole.bass));
      // The singer is the face of a band.
      expect(Lineups.target(MemberRole.frontman.bit),
          greaterThan(Lineups.target(MemberRole.bass.bit)));
      g.close();
    });

    test('a duo breaks up when one goes solo (K191)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2012,
              kind: ArtistKind.band,
              members: const ['Ana', 'Leo']));
      final duo = g.world.player!;
      expect(g.goSoloPreview(0).groupBreaksUp, isTrue);
      g.goSolo(0);
      expect(g.world.player!.name, 'Ana');
      expect(duo.isRetired, isTrue);
      expect(g.world.activeArtistIds, isNot(contains(duo.id)));
      g.advanceWeeks(4, stop: SkipStop.never);
      g.close();
    });

    test('nobody leaves a solo career (K191)', () {
      final g = GameSession.start(slots, _setup());
      expect(() => g.goSolo(0), _code('notGroup'));
      expect(() => g.goSoloPreview(0), _code('noMember'));
      g.close();
    });

    test('the editors\' This Is list (K189)', () {
      var g = GameSession.start(
          slots,
          _setup(
              startYear: 2016,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final slot = g.slotId;
      final p = g.world.player!;
      p.moneyCents = 1 << 40;
      expect(g.thisIs(p.id).made, isFalse);
      final ids = <int>[];
      final events = <GameEvent>[];
      for (var i = 0; i < ThisIs.minSongs; i++) {
        p.creativeEnergy = 100;
        final id = g.writeSong(budget: BudgetTier.high).id;
        ids.add(id);
        g.releaseSingle(id);
        events.addAll(g.advanceWeek().events);
      }
      for (var i = 0; i < 4 && g.world.thisIsWeek < 0; i++) {
        events.addAll(g.advanceWeek().events);
      }
      final v = g.thisIs(p.id);
      expect(v.listeners, greaterThan(ThisIs.minListeners));
      expect(v.made, isTrue);
      expect(events.whereType<ThisIsMade>().single.songs, ThisIs.minSongs);
      expect(v.songs.map((s) => s.id).toSet(), ids.toSet());
      // The biggest song first, then the newest ones, the rest by streams.
      final k = v.newIds.length < ThisIs.newSlots
          ? v.newIds.length
          : ThisIs.newSlots;
      final top = v.songs.sublist(1, 1 + k);
      for (var i = 0; i < k; i++) {
        expect(v.newIds, contains(top[i].id));
        if (i > 0) {
          expect(top[i].releasedWeek, lessThanOrEqualTo(top[i - 1].releasedWeek));
        }
      }
      final rest = [v.songs.first, ...v.songs.skip(1 + k)];
      for (var i = 1; i < rest.length; i++) {
        expect(rest[i].lifetimeStreams.total,
            lessThanOrEqualTo(rest[i - 1].lifetimeStreams.total));
      }
      final lifts = ThisIs.lifts(g.world);
      expect(lifts.keys.toSet(), ids.toSet());
      // A new single goes in near the top.
      p.creativeEnergy = 100;
      final fresh = g.writeSong(budget: BudgetTier.high).id;
      g.releaseSingle(fresh);
      g.advanceWeek();
      expect(g.thisIs(p.id).songs[1].id, fresh);
      expect(ThisIs.lifts(g.world)[fresh], ThisIs.newLift);
      g.close();
      g = GameSession.resume(slots, slot);
      expect(g.world.thisIsWeek, greaterThanOrEqualTo(0));
      expect(g.thisIs(p.id).made, isTrue);
      // Rivals have theirs on their pages.
      for (final id in g.world.activeArtistIds.take(30)) {
        if (id == p.id) continue;
        final r = g.thisIs(id);
        expect(r.made,
            r.eligible >= ThisIs.minSongs && r.listeners >= ThisIs.minListeners);
        expect(r.lifts, isEmpty);
      }
      g.close();
    });

    test('This Is waits for 2016 (K189)', () {
      final g = GameSession.start(
          slots,
          _setup(
              startYear: 2012,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire));
      final p = g.world.player!;
      for (var i = 0; i < ThisIs.minSongs + 2; i++) {
        p.creativeEnergy = 100;
        g.releaseSingle(g.writeSong(budget: BudgetTier.high).id);
        g.advanceWeek();
      }
      expect(g.world.thisIsWeek, -1);
      expect(g.thisIs(p.id).open, isFalse);
      expect(ThisIs.lifts(g.world), isEmpty);
      g.close();
    });

    test('a Canvas makes a song skipped less and played more (K190)', () {
      (double, GameSession, int) run({bool canvas = false}) {
        final g = GameSession.start(
            slots,
            _setup(
                startYear: 2020,
                premium: true,
                tier: StartTier.risingStar,
                money: StartMoney.millionaire));
        g.world.player!.creativeEnergy = 100;
        final id = g.writeSong(budget: BudgetTier.high, genres: [0]).id;
        final skip = g.song(id).skipRate;
        expect(g.song(id).canCanvas, isTrue);
        if (canvas) {
          final money = g.world.player!.moneyCents;
          g.addCanvas(id);
          expect(g.world.player!.moneyCents, money - SongCanvas.costCents);
          expect(g.song(id).canvas, isTrue);
          expect(g.song(id).canCanvas, isFalse);
          expect(g.song(id).skipRate, closeTo(skip - SongCanvas.skipCut, 1e-9));
          expect(() => g.addCanvas(id), _code('noCanvas'));
        }
        g.setAutoplayLevel(id, AutoplayLevel.standard);
        g.releaseSingle(id);
        var streams = 0.0;
        for (var i = 0; i < 8; i++) {
          g.advanceWeek();
          streams += g.world.songs[id].weekStreams;
        }
        return (streams, g, id);
      }

      final (plain, g1, _) = run();
      g1.close();
      final (withCanvas, g2, id) = run(canvas: true);
      final slot = g2.slotId;
      g2.close();
      expect(withCanvas, greaterThan(plain * 1.015));
      final again = GameSession.resume(slots, slot);
      expect(again.song(id).canvas, isTrue);
      again.close();
      // Not before the app had them.
      final old = GameSession.start(slots, _setup(startYear: 2017));
      old.world.player!.creativeEnergy = 100;
      final o = old.writeSong(budget: BudgetTier.low).id;
      expect(old.song(o).canvasOpen, isFalse);
      expect(() => old.addCanvas(o), _code('noCanvas'));
      old.close();
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
      expect(
          () => g.setRadioFormat(id, RadioFormat.top40), _code('radioLocked'));
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
      expect(
          p.hype - hype,
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
      expect(
          wr.topSongs.fold(0.0, (t, s) => t + s.plays), closeTo(wr.plays, 1));
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

    test('video views: audio first, the official video pulls more (K118)', () {
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
