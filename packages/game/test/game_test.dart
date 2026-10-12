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
      // Refusals did not use up the weekly songwriting slots.
      expect(g.player.songsLeftThisWeek, 3);
      final ids = [
        for (var i = 0; i < 3; i++)
          g.writeSong(budget: BudgetTier.low, genres: [0, 6]).id,
      ];
      expect(g.writeSong, _code('weeklyLimit'));
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
        if (g.player.songsLeftThisWeek == 0 || g.player.creativeEnergy < 30) {
          g.advanceWeek();
          continue;
        }
        songs.add(g.writeSong(budget: BudgetTier.high).id);
      }
      expect(g.player.everCharted, isFalse);
      g.releaseSingle(songs.first, campaign: Campaign.global);
      final weekEvents = <GameEvent>[];
      for (var i = 0; i < 3; i++) {
        weekEvents.addAll(g.advanceWeek().events);
      }
      expect(weekEvents.whereType<ChartDebut>(), isNotEmpty);
      // The app celebrates the first ever chart entry once.
      expect(g.player.everCharted, isTrue);

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
