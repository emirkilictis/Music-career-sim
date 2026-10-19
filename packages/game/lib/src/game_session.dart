import 'dart:math' as math;

import 'package:persistence/persistence.dart';
import 'package:simulation_core/simulation_core.dart';

import 'career_setup.dart';
import 'events.dart';
import 'social_feed.dart';
import 'milestones.dart';
import 'platforms.dart';
import 'views.dart';

/// Result of one played week.
class WeekReport {
  WeekReport({
    required this.week,
    required this.events,
    required this.moneyDeltaCents,
  });

  /// The week that was simulated (charts and numbers are for this week).
  final int week;
  final List<GameEvent> events;
  final int moneyDeltaCents;

  int get year => GameTime.yearOf(week);
  int get weekOfYear => GameTime.weekOfYear(week);
  bool get hasMajor => events.any((e) => e.isMajor);
}

/// When a multi-week skip stops early.
enum SkipStop {
  /// Play every requested week.
  never,

  /// After a week with a major event (top-10 debut, #1, viral, ...).
  major,

  /// After any week with news about the player.
  anyNews;

  bool stopsOn(GameEvent e) => switch (this) {
        never => false,
        major => e.isMajor,
        anyNews => !e.isIndustry,
      };
}

/// Result of a skip (a few weeks or a year): the summary screen
/// (docs/game-design.md §1.1).
class YearReport {
  YearReport({
    required this.fromWeek,
    required this.weeks,
    this.requestedWeeks = GameTime.weeksPerYear,
    required this.stoppedEarly,
    required this.events,
    required this.streamsGained,
    this.singleSalesGained = 0,
    required this.pureGained,
    required this.unitsGained,
    required this.moneyDeltaCents,
    required this.coreFansDelta,
    required this.fameBefore,
    required this.fameAfter,
  });

  final int fromWeek;
  final int weeks;

  /// Weeks asked for (52 for a year skip).
  final int requestedWeeks;

  /// True when an event stopped the skip before [requestedWeeks].
  final bool stoppedEarly;

  bool get isYear => requestedWeeks == GameTime.weeksPerYear;
  final List<GameEvent> events;
  final double streamsGained;

  /// Downloads + CD singles.
  final double singleSalesGained;
  final double pureGained;
  final double unitsGained;
  final int moneyDeltaCents;
  final double coreFansDelta;
  final double fameBefore;
  final double fameAfter;

  List<NumberOne> get numberOnes => events.whereType<NumberOne>().toList();
}

/// One weekly point of a release's history graph.
class HistoryPoint {
  HistoryPoint(this.week, this.value, this.positions, {this.sales = 0});
  final int week;

  /// Streams (songs) or units (albums) that week.
  final double value;

  /// Songs: single sales (downloads + CD singles) that week.
  final double sales;

  /// Chart position by chart id that week (only charts it was on).
  final Map<int, int> positions;
}

/// One week of an album's sales (docs K47). The player's albums have the
/// full breakdown; a rival's has only what its chart entries show (units
/// in the chart's market), the rest is null.
class AlbumSalesWeek {
  AlbumSalesWeek({
    required this.week,
    required this.positions,
    this.units,
    this.pure,
    this.tea,
    this.sea,
    this.usUnits,
  });
  final int week;

  /// Chart position by chart id that week (only charts it was on).
  final Map<int, int> positions;

  /// Global units, pure sales, track and stream equivalents.
  final double? units, pure, tea, sea;

  /// US units (from the US album chart, when it charted there).
  final double? usUnits;
}

/// One week of a release's chart run: position and chart points (album
/// charts: units in the chart's market) per chart it was on.
class ChartWeek {
  ChartWeek(this.week, this.entries);
  final int week;
  final Map<int, ({int position, double points})> entries;
}

/// One row of the career summary, per year.
class CareerYear {
  CareerYear({
    required this.year,
    required this.streams,
    required this.singleSales,
    required this.pure,
    required this.units,
    required this.fame,
    required this.coreFans,
    required this.moneyCents,
  });
  final int year;
  final double streams;

  /// Downloads + CD singles of the player's songs.
  final double singleSales;
  final double pure;
  final double units;
  final double fame;
  final double coreFans;
  final int moneyCents;
}

/// A playable career: the world, its save slot and the player's actions.
/// The UI talks only to this class (docs/architecture.md).
///
/// Weekly play autosaves every week; actions between weeks (writing,
/// releasing, money) are saved immediately, so closing the app never loses
/// them.
class GameSession {
  GameSession._(this.slots, this.slotId, this._store, this.world)
      : _sim = Simulator(world);

  final SaveSlots slots;
  final String slotId;
  final World world;
  final SaveStore _store;
  final Simulator _sim;
  bool _closed = false;

  // --------------------------------------------------------------- lifecycle

  /// Creates a new career: builds the world, simulates the years before the
  /// start year (so charts are full), adds the player and saves the slot.
  static GameSession start(
    SaveSlots slots,
    CareerSetup setup, {
    String? slotId,
    void Function(double progress)? onProgress,
  }) {
    setup.validate();
    final seed =
        setup.seed ?? DateTime.now().microsecondsSinceEpoch & 0x7fffffffffff;
    final w = WorldGen.create(
        seed: seed,
        startYear: setup.startYear,
        difficulty: setup.difficulty,
        realNames: setup.realNames);
    final sim = Simulator(w);
    final start = GameTime.firstWeekOf(setup.startYear);
    final total = start - w.week;
    var done = 0;
    while (w.week < start) {
      sim.step();
      onProgress?.call(++done / total);
    }
    WorldGen.addPlayer(
      w,
      name: setup.name.trim(),
      genre: setup.genre,
      tier: setup.tier,
      money: setup.money,
      path: setup.path,
      home: setup.home,
      kind: setup.kind,
      members: [for (final m in setup.members) m.trim()],
      skills: setup.resolvedSkills,
    );
    final id = slotId ?? 'career_${DateTime.now().microsecondsSinceEpoch}';
    final store = slots.create(id, w);
    return GameSession._(slots, id, store, w);
  }

  /// Opens a saved career exactly where it was left.
  static GameSession resume(SaveSlots slots, String slotId) {
    final store = slots.open(slotId);
    final world = store.load();
    // The player's reach always follows their label: older saves get the
    // independent reach raised in docs K70.
    final p = world.player;
    if (p != null && p.labelReach != p.label.reach) {
      p.labelReach = p.label.reach;
      world.dirtyArtists.add(p.id);
    }
    // Points piled up before docs F34 shrink to what the skills can use.
    if (p != null && p.skillPoints > Actions.skillRoom(p)) {
      p.skillPoints = Actions.skillRoom(p);
      world.dirtyArtists.add(p.id);
    }
    return GameSession._(slots, slotId, store, world);
  }

  /// Saves search tables and closes the save file. Call when the app goes to
  /// the background or the player leaves the career.
  void close() {
    if (_closed) return;
    _store.flushActive(world);
    // The career list shows what changed since the last week (money, a new
    // album).
    slots.writeSummary(slotId, world);
    _store.close();
    _closed = true;
  }

  // ------------------------------------------------------------------ state

  Artist get _p => world.player!;
  int get week => world.week;
  int get year => GameTime.yearOf(world.week);
  int get weekOfYear => GameTime.weekOfYear(world.week);
  Difficulty get difficulty => world.difficulty;

  ArtistView get player => ArtistView.of(world, _p);
  ArtistView artist(int id) => ArtistView.of(world, world.artists[id]);
  SongView song(int id) => SongView.of(world, world.songs[id]);
  AlbumView album(int id) => AlbumView.of(world, world.albums[id]);
  ChartView chart(int chartId) => ChartView.latest(world, chartId);

  /// Charts that exist in the current year.
  List<ChartDef> get activeCharts => [
        for (final c in Charts.all)
          if (c.activeIn(world.week - 1)) c
      ];

  /// The player's songs, newest first.
  List<SongView> get songs => [
        for (final id in world.playerSongIds.reversed)
          if (world.songs[id].status != SongStatus.scrapped)
            SongView.of(world, world.songs[id]),
      ];

  /// Unreleased songs, best estimate first.
  List<SongView> get vault => songs.where((s) => s.inVault).toList()
    ..sort((a, b) => b.estimatedGrade.compareTo(a.estimatedGrade));

  /// The player's albums and EPs, newest first.
  List<AlbumView> get albums => [
        for (final al in world.albums.reversed)
          if (al.artistId == _p.id) AlbumView.of(world, al),
      ];

  /// The player's average weekly streams over the last four weeks (monthly
  /// listeners count a 28-day window, so a release week does not make them
  /// jump; docs F20).
  double _fourWeekStreams() {
    final now = world.artistLifetimeStreams(_p);
    final rows = _store.db.select(
        'SELECT week, lifetimeStreams FROM playerWeek WHERE week <= ? '
        'ORDER BY week DESC LIMIT 1',
        [world.week - 5]);
    if (rows.isEmpty) {
      final first = _store.db.select(
          'SELECT week, lifetimeStreams FROM playerWeek ORDER BY week LIMIT 1');
      if (first.isEmpty) return 0;
      final weeks = world.week - 1 - (first.first['week'] as int);
      if (weeks <= 0) return 0;
      return (now - (first.first['lifetimeStreams'] as num).toDouble()) / weeks;
    }
    final weeks = world.week - 1 - (rows.first['week'] as int);
    return (now - (rows.first['lifetimeStreams'] as num).toDouble()) / weeks;
  }

  /// Streamify artist page for any artist (player or rival).
  ArtistPageView artistPage(int artistId) {
    final w = world;
    final a = w.artists[artistId];
    final songs = [
      for (final s in w.songs)
        if (s.primaryArtistId == artistId && s.releasedWeek >= 0) s,
    ];
    final weekly = {
      for (final s in songs) s.id: w.songWeekStreamsIn(s, ChartMarket.global),
    };
    final popular = [...songs]..sort((x, y) {
        final d = weekly[y.id]!.compareTo(weekly[x.id]!);
        return d != 0 ? d : y.lifetimeStreams.compareTo(x.lifetimeStreams);
      });
    final total = weekly.values.fold(0.0, (x, y) => x + y);
    return ArtistPageView(
      artist: ArtistView.of(w, a),
      weeklyStreams: total,
      listenerStreams: artistId == _p.id ? _fourWeekStreams() : total,
      followers: Platforms.followers(
              w, a, MusicPlatform.streamify, GameTime.yearOf(w.week)) ??
          0,
      worldRank: Platforms.worldRank(w, a),
      popular: [for (final s in popular.take(10)) SongView.of(w, s)],
      albums: [
        for (final al in w.albums.reversed)
          if (al.artistId == artistId) AlbumView.of(w, al),
      ],
      singles: [
        for (final s in songs.reversed)
          if (s.isSingle && s.albumId < 0) SongView.of(w, s),
      ],
    );
  }

  List<CollaboratorView> collaborators(CollaboratorRole role) => [
        for (final c in world.collaborators)
          if (c.role == role)
            CollaboratorView(c,
                available: Actions.collaboratorAvailable(c, _p),
                requiredFans: Actions.requiredFans(c)),
      ]..sort((a, b) => b.skill.compareTo(a.skill));

  // ---------------------------------------------------------------- actions

  /// Writes and records a song (docs/game-design.md §4).
  SongView writeSong({
    int? producerId,
    int? cowriterId,
    BudgetTier budget = BudgetTier.medium,
    List<int>? genres,
    String? title,
  }) {
    final p = _p;
    if (world.week < p.burnoutUntilWeek) {
      throw GameException('burnout', 'Burnout until ${p.burnoutUntilWeek}');
    }
    if (!Actions.canWrite(world, p)) {
      throw GameException('resting', 'Resting this week');
    }
    final producer = _collaborator(producerId, CollaboratorRole.producer);
    final cowriter = _collaborator(cowriterId, CollaboratorRole.songwriter);
    for (final c in [producer, cowriter]) {
      if (c != null && !Actions.collaboratorAvailable(c, p)) {
        throw GameException('collaboratorRefused', '${c.name} needs more fans');
      }
    }
    final g = genres ?? [p.genre];
    if (g.isEmpty ||
        g.length > maxSongGenres ||
        g.toSet().length != g.length ||
        g.any((x) => x < 0 || x >= genreNames.length)) {
      throw GameException('invalidGenres', 'A song has 1–3 distinct genres');
    }
    final t = title?.trim();
    if (t != null && (t.isEmpty || t.length > 60)) {
      throw GameException('invalidTitle', 'Title must be 1–60 chars');
    }
    final cost = Actions.budgetCostCents(budget) +
        (producer?.feeCents ?? 0) +
        (cowriter?.feeCents ?? 0);
    if (cost > p.moneyCents) {
      throw GameException('notEnoughMoney', 'Song costs $cost cents');
    }
    final s = Actions.writeSong(world, p,
        producer: producer,
        cowriter: cowriter,
        budget: budget,
        genres: g,
        title: t);
    _saveNow();
    return SongView.of(world, s);
  }

  /// Releases a vault song as a single, or pushes an album track as a single,
  /// with a [radio] push bought on top of the campaign (docs K84).
  void releaseSingle(int songId,
      {Campaign campaign = Campaign.standard,
      RadioPush radio = RadioPush.none}) {
    final s = _checkSingle(songId);
    _requireMoney(_campaignCost(campaign) + _radioCost(radio));
    Actions.releaseSingle(world, _p, s, campaign: campaign, radio: radio);
    _saveNow();
  }

  /// What the player pays for a radio push, after checking the label can
  /// arrange it (heavy rotation needs a mid-size label or bigger).
  int _radioCost(RadioPush radio) {
    if (radio.index > Actions.maxRadioPush(_p.label).index) {
      throw GameException('radioLocked', 'The label cannot arrange this');
    }
    return Actions.radioPushCostFor(_p, radio);
  }

  /// The radio push prices for the player now (docs K84).
  Map<RadioPush, int> get radioPushCosts => {
        for (final r in RadioPush.values) r: Actions.radioPushCostFor(_p, r),
      };

  /// The biggest radio push the player's label can arrange.
  RadioPush get maxRadioPush => Actions.maxRadioPush(_p.label);

  /// What the player pays for [campaign] with their label, after checking
  /// the label can run it at all (docs K54).
  int _campaignCost(Campaign campaign) {
    if (campaign.index > _p.label.maxCampaign.index) {
      throw GameException('campaignLocked', 'The label cannot run this');
    }
    return Actions.campaignCostFor(_p, campaign);
  }

  // -------------------------------------------------------- opportunities

  /// The offer waiting for an answer, if any (docs K59).
  OpportunityView? get opportunity => _p.opportunity == null
      ? null
      : OpportunityView.of(world, _p.opportunity!);

  // ------------------------------------------------------------ platforms

  /// A platform last week: its Top 50 and the player's numbers (docs K67).
  PlatformView platform(MusicPlatform p) => Platforms.view(world, p);

  /// The platforms open now with the player's numbers there last week.
  List<PlatformView> get platforms => [
        for (final p
            in Platforms.openIn(GameTime.yearOf(math.max(0, world.week - 1))))
          Platforms.view(world, p),
      ];

  // ---------------------------------------------------------------- tours

  /// What a tour of each size would do over [regions], as planned now
  /// (docs K63).
  /// A tour as it would go if it started this week (docs K76): each
  /// night's expected turnout, the money, and what stops it.
  TourPlanView tourPreview(TourRequest r) {
    final legs = [
      for (final l in r.legs)
        TourLeg(l.market, l.kind,
            l.shows.clamp(1, Tours.maxShows(l.market, l.kind)).toInt())
    ];
    final opener = r.openerId >= 0 ? world.artists[r.openerId] : null;
    final t = Tours.plan(world, _p,
        legs: legs,
        name: r.name,
        priceFactor: r.priceFactor,
        production: r.production,
        openerId: opener?.id ?? -1);
    final (e, each) = Tours.estimate(world, _p, t);
    final legViews = <TourLegView>[];
    for (var i = 0; i < legs.length; i++) {
      var tickets = 0.0, seats = 0.0, gross = 0.0;
      for (var k = 0; k < t.shows.length; k++) {
        if (t.shows[k].leg != i) continue;
        tickets += each[k].sold;
        seats += t.shows[k].capacity;
        gross += each[k].grossCents;
      }
      legViews.add(TourLegView(
          leg: legs[i],
          tickets: tickets,
          fill: seats == 0 ? 0 : tickets / seats,
          grossCents: gross.round(),
          maxShows: Tours.maxShows(legs[i].market, legs[i].kind),
          priceCents: Tours.priceFor(legs[i].kind, year, t.priceFactor)));
    }
    return TourPlanView(
      request: r,
      problems: _tourProblems(r),
      estimate: e,
      netCents: Tours.netFor(_p, e).round(),
      weeks: legs.isEmpty ? 0 : t.weeks,
      legs: legViews,
      schedule: [
        for (var k = 0; k < t.shows.length; k++)
          TourShowView.of(t, t.shows[k], each[k])
      ],
      openerName: opener?.name,
      openerFeeCents: opener == null ? 0 : Tours.openerFeeCents(opener),
    );
  }

  List<String> _tourProblems(TourRequest r) => [
        if (_p.tour != null) 'onTour',
        if (r.legs.isEmpty ||
            r.legs.map((l) => l.market).toSet().length != r.legs.length)
          'tourMarkets',
        if (r.legs.any((l) => _p.coreFans < l.kind.minFans)) 'tourTooBig',
        if (r.legs.any(
            (l) => l.shows < 1 || l.shows > Tours.maxShows(l.market, l.kind)))
          'tourShows',
      ];

  // ------------------------------------------------------------ festivals

  /// Every festival's next edition, soonest first (docs K77).
  List<FestivalView> get festivals {
    final p = _p;
    final slot = Festivals.slotFor(p);
    final out = <FestivalView>[];
    for (var i = 0; i < Festivals.all.length; i++) {
      final f = Festivals.all[i];
      final year = Festivals.nextYear(world, f);
      final booked = world.festivalBookings
          .where((b) => b.festival == i && b.year == year)
          .firstOrNull
          ?.slot;
      final shown = booked ?? slot;
      final watched = shown == null ? 0.0 : Festivals.watched(f, shown, p);
      out.add(FestivalView(
        index: i,
        festival: f,
        year: year,
        week: GameTime.firstWeekOf(year) + f.weekOfYear - 1,
        slot: slot,
        booked: booked,
        feeCents: shown == null ? 0 : Festivals.feeCents(f, shown, year),
        watched: watched,
        fans: watched * (0.03 + 0.05 * p.skills.charisma / 100),
        fitsGenre: f.books(p.genre),
      ));
    }
    out.sort((a, b) => a.week.compareTo(b.week));
    return out;
  }

  /// Takes the slot the player gets now at [festival]'s next edition.
  void bookFestival(int festival) {
    final f = Festivals.all[festival];
    if (Festivals.slotFor(_p) == null) {
      throw GameException('festivalTooSmall', 'Not big enough yet');
    }
    if (!f.books(_p.genre)) {
      throw GameException('festivalGenre', 'Not this festival\'s genre');
    }
    final year = Festivals.nextYear(world, f);
    if (world.festivalBookings
        .any((b) => b.festival == festival && b.year == year)) {
      throw GameException('festivalBooked', 'Already booked');
    }
    Festivals.book(world, _p, festival);
    _saveNow();
  }

  /// Calls off a festival slot.
  void cancelFestival(int festival, int year) {
    Festivals.cancel(world, festival, year);
    _saveNow();
  }

  /// [festival]'s bill for [year], headliners first.
  Map<FestivalSlot, List<FestivalAct>> festivalLineup(int festival, int year) =>
      {
        for (final e in Festivals.lineup(world, festival, year).entries)
          e.key: [
            for (final id in e.value)
              FestivalAct(
                  id, world.artists[id].name, id == world.playerArtistId)
          ],
      };

  // ----------------------------------------------------------- brand deals

  /// The player's brand deals, newest first (docs K102).
  List<BrandDealView> get brandDeals => [
        for (var i = world.brandDeals.length - 1; i >= 0; i--)
          BrandDealView.of(world, _p, i, world.brandDeals[i])
      ];

  /// Does a task of a deal; returns what the last task paid (0 before).
  int doDealTask(int deal, int task) {
    if (deal < 0 || deal >= world.brandDeals.length) {
      throw GameException('dealOver', 'No such deal');
    }
    final d = world.brandDeals[deal];
    if (d.status != DealStatus.active) {
      throw GameException('dealOver', 'The deal is over');
    }
    final (kind, _, done) = d.tasks[task];
    if (done >= 0) throw GameException('taskDone', 'Already done');
    if (_p.creativeEnergy < kind.energy) {
      throw GameException('noEnergy', 'Not enough energy');
    }
    if (kind == DealTask.sponsoredPost &&
        world.social.postsIn(world.week) >= Social.postsPerWeek) {
      throw GameException('postLimit', 'Posted enough this week');
    }
    final out = Brands.doTask(world, _p, deal, task);
    _saveNow();
    return out?.cents ?? 0;
  }

  // --------------------------------------------------------- social media

  /// The player's social media: the feed, followers, posts left (docs K93).
  SocialView get social => SocialView.of(world, _p);

  /// Posts; fans answer in the feed.
  PostOutcome post(PostKind kind, {int songId = -1}) {
    final year = GameTime.yearOf(world.week);
    if (!Social.canPostIn(year)) {
      throw GameException('socialLocked', 'No social media yet');
    }
    if (world.social.postsIn(world.week) >= Social.postsPerWeek) {
      throw GameException('postLimit', 'Posted enough this week');
    }
    if (kind == PostKind.teaser && !Social.hasTeaser(world, _p)) {
      throw GameException('nothingToTease', 'Nothing unreleased');
    }
    if (kind == PostKind.promote) _ownSong(songId);
    final out = Social.post(world, _p, kind, songId: songId);
    _saveNow();
    return out;
  }

  // --------------------------------------------------------------- awards

  /// Years with a Golden Record Awards show, newest first (docs K91).
  List<int> get awardYears =>
      [for (final s in world.awardShows.reversed) s.year];

  AwardShowView? awardShow(int year) {
    final s = Awards.showFor(world, year);
    return s == null ? null : AwardShowView.of(world, s);
  }

  // ----------------------------------------------------------- box office

  /// The year's top-grossing tours so far (docs K77): rivals' tours by
  /// what they have played, the player's own included.
  List<TourRankView> topTours(int year, {int limit = 25}) {
    final now = world.week;
    final rows = <(TourRecord, double, bool)>[];
    for (final r in world.tourRecords) {
      // What it has earned in [year] up to now (evenly over its weeks).
      final until = math.min(now, GameTime.firstWeekOf(year + 1));
      final from = GameTime.firstWeekOf(year);
      final overlap =
          math.max(0, math.min(r.endWeek, until) - math.max(r.startWeek, from));
      final gross = r.grossCents * overlap / r.weeks;
      if (gross > 0) rows.add((r, gross, r.endWeek > now));
    }
    final t = _p.tour;
    if (t != null) {
      var gross = 0.0;
      for (final s in t.shows) {
        if (s.played && GameTime.yearOf(s.week) == year) gross += s.grossCents;
      }
      if (gross > 0) {
        rows.add((
          TourRecord(
              artistId: _p.id,
              name: t.name,
              startWeek: t.startWeek,
              endWeek: t.endWeek,
              shows: t.shows.where((s) => s.played).length,
              tickets: t.tickets,
              grossCents: t.grossCents),
          gross,
          true
        ));
      }
    }
    return _rank(rows, limit);
  }

  /// The biggest tours ever played in this world.
  List<TourRankView> allTimeTours({int limit = 25}) {
    final rows = <(TourRecord, double, bool)>[
      for (final r in world.tourRecords)
        if (r.startWeek < world.week)
          (r, r.grossCents * r.playedBy(world.week), r.endWeek > world.week),
    ];
    final t = _p.tour;
    if (t != null && t.grossCents > 0) {
      rows.add((
        TourRecord(
            artistId: _p.id,
            name: t.name,
            startWeek: t.startWeek,
            endWeek: t.endWeek,
            shows: t.shows.where((s) => s.played).length,
            tickets: t.tickets,
            grossCents: t.grossCents),
        t.grossCents,
        true
      ));
    }
    return _rank(rows, limit);
  }

  /// First year with tours on the books.
  int get firstTourYear => world.tourRecords.isEmpty
      ? year
      : GameTime.yearOf(
          world.tourRecords.map((r) => r.startWeek).reduce(math.min));

  /// The top [limit], plus the player's own tours further down with their
  /// real rank (the player always sees where they stand).
  List<TourRankView> _rank(List<(TourRecord, double, bool)> rows, int limit) {
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    final me = world.playerArtistId;
    return [
      for (final (i, (r, gross, live)) in rows.indexed)
        if (i < limit || r.artistId == me)
          TourRankView(
            rank: i + 1,
            artistId: r.artistId,
            artistName: world.artists[r.artistId].name,
            tourName: r.name,
            grossCents: gross,
            tickets: r.grossCents > 0 ? r.tickets * gross / r.grossCents : 0,
            shows: r.shows,
            isPlayer: r.artistId == world.playerArtistId,
            onGoing: live,
          ),
    ];
  }

  /// Rivals who could open the tour, with their fee a night.
  List<OpenerView> get tourOpeners => [
        for (final o in Tours.openerCandidates(world, _p))
          OpenerView(
              artistId: o.id,
              name: o.name,
              genre: o.genre,
              fame: o.fame,
              coreFans: o.coreFans,
              feeCents: Tours.openerFeeCents(o)),
      ];

  // ---------------------------------------------------------------- rivals

  /// How far ahead big rival albums are known (docs K69).
  static const rivalLookaheadWeeks = 8;

  /// Big rivals' albums due in the next [rivalLookaheadWeeks] weeks, soonest
  /// first.
  List<UpcomingRelease> get upcomingRivalAlbums {
    final w = world;
    final out = <UpcomingRelease>[];
    for (final a in w.artists) {
      if (a.tier == ArtistTier.player || a.isRetired || !_bigRival(a)) {
        continue;
      }
      for (final pr in a.plan) {
        if (pr.kind == PlannedKind.album &&
            pr.week >= w.week &&
            pr.week < w.week + rivalLookaheadWeeks) {
          out.add(UpcomingRelease(
              artistId: a.id,
              artistName: a.name,
              title: a.pendingAlbumTitle,
              week: pr.week,
              fame: a.fame));
        }
      }
    }
    out.sort((x, y) {
      final d = x.week.compareTo(y.week);
      return d != 0 ? d : y.fame.compareTo(x.fame);
    });
    return out;
  }

  /// Rivals whose releases make news: the top tier or well known.
  static bool _bigRival(Artist a) => a.tier == ArtistTier.a || a.fame >= 0.35;

  // ------------------------------------------------------------- managers

  /// Hires [m] (or lets the manager go with [Manager.none]; docs K68).
  void hireManager(Manager m) {
    if (m == _p.manager) {
      throw GameException('sameManager', 'Already your manager');
    }
    if (_p.coreFans < m.minFans) {
      throw GameException('managerRefused', 'Needs more fans');
    }
    _p.manager = m;
    world.dirtyArtists.add(_p.id);
    _saveNow();
  }

  /// Goes on tour from this week (docs K76).
  void startTour(TourRequest r) {
    final problems = _tourProblems(r);
    if (problems.isNotEmpty) {
      throw GameException(problems.first, 'Cannot start this tour');
    }
    if (r.openerId >= 0 &&
        !Tours.openerCandidates(world, _p).any((o) => o.id == r.openerId)) {
      throw GameException('tourOpener', 'That act cannot open for you');
    }
    final t = Tours.plan(world, _p,
        legs: r.legs,
        name: r.name,
        priceFactor: r.priceFactor,
        production: r.production,
        openerId: r.openerId);
    Tours.start(world, _p, t);
    Milestone.firstTour.mark(world, _p);
    if (t.kind == TourKind.stadium) Milestone.stadiumTour.mark(world, _p);
    _saveNow();
  }

  /// Every milestone with the week it was reached (null = not yet), and
  /// progress for count goals (docs K61).
  List<MilestoneView> get milestones => [
        for (final m in Milestone.values)
          MilestoneView(
            milestone: m,
            reachedWeek: _p.milestones[m.index],
            progress: m.progress(world, _p),
          ),
      ];

  /// Answers the waiting offer.
  OpportunityOutcome answerOpportunity(OpportunityChoice choice) {
    final o = _p.opportunity;
    if (o == null) throw GameException('noOffer', 'Nothing to answer');
    if (!o.choices.contains(choice)) {
      throw GameException('invalidChoice', 'Not an answer to this offer');
    }
    final out = Opportunities.answer(world, _p, choice);
    if (out.kind == OpportunityKind.festival &&
        out.choice == OpportunityChoice.accept) {
      Milestone.firstFestival.mark(world, _p);
    }
    _saveNow();
    return out;
  }

  // ------------------------------------------------------------- labels

  /// Every label, with its terms and whether it would sign the player.
  List<LabelView> get labels => [
        for (final l in Label.values)
          LabelView.of(world, _p, l, Actions.labelMissing(world, _p, l)),
      ];

  /// Signs with [label] (or goes independent with [Label.independent]) on
  /// [deal]'s terms (docs K107). While albums are still owed, the contract
  /// is bought out (docs K78): the new advance goes towards it, the player
  /// pays the rest.
  void signLabel(Label label, {ContractDeal deal = ContractDeal.standard}) {
    if (label == _p.label) {
      throw GameException('sameLabel', 'Already with this label');
    }
    if (Actions.labelMissing(world, _p, label).isNotEmpty) {
      throw GameException('labelRefused', 'The label turned you down');
    }
    final buyout = Actions.buyoutCents(world, _p);
    final advance = Contracts.terms(world, _p, label, deal).advanceCents;
    if (buyout > _p.moneyCents + advance) {
      throw GameException('buyoutMoney', 'Not enough money for the buyout');
    }
    Actions.signLabel(world, _p, label, buyout: buyout > 0, deal: deal);
    _saveNow();
  }

  Song _checkSingle(int songId) {
    final s = _ownSong(songId);
    if (s.isSingle) throw GameException('alreadySingle', 'Already a single');
    if (_p.scheduled.any((sr) => !sr.isAlbum && sr.songIds.contains(s.id))) {
      throw GameException('alreadyScheduled', 'Already scheduled as a single');
    }
    return s;
  }

  // ---------------------------------------------------- scheduled releases

  /// The player's releases set for later weeks, soonest first (docs K45).
  List<ScheduledView> get scheduled => [
        for (final sr in [
          ..._p.scheduled
        ]..sort((a, b) => a.releaseWeek.compareTo(b.releaseWeek)))
          ScheduledView.of(world, sr),
      ];

  /// Sets a single to come out at [releaseWeek] (1–26 weeks ahead),
  /// announced at [announceWeek] (this week up to the release week; the
  /// release week itself = a surprise drop). The campaign is paid now.
  ScheduledView scheduleSingle(int songId,
      {Campaign campaign = Campaign.standard,
      RadioPush radio = RadioPush.none,
      required int releaseWeek,
      required int announceWeek}) {
    final s = _checkSingle(songId);
    _checkDates(releaseWeek, announceWeek);
    final cost = _campaignCost(campaign) + _radioCost(radio);
    _requireMoney(cost);
    return _schedule(ScheduledRelease(
      id: _nextScheduleId(),
      type: AlbumType.single,
      songIds: [s.id],
      releaseWeek: releaseWeek,
      announceWeek: announceWeek,
      createdWeek: world.week,
      campaign: campaign,
      radioPush: radio,
      paidCents: cost,
    ));
  }

  /// Sets an album or EP to come out later (see [scheduleSingle]). Its
  /// songs can still come out as singles before it.
  ScheduledView scheduleAlbum(
    String title,
    List<int> songIds, {
    AlbumType type = AlbumType.album,
    List<int> variantWeeks = const [0],
    List<EditionFormat?> variantFormats = const [],
    Campaign campaign = Campaign.standard,
    required int releaseWeek,
    required int announceWeek,
  }) {
    final t = _checkAlbum(title, songIds, type, variantWeeks, variantFormats);
    _checkDates(releaseWeek, announceWeek);
    final formats = _formats(variantFormats);
    final cost = _campaignCost(campaign) +
        Actions.editionsCostCents(variantWeeks.length, formats);
    _requireMoney(cost);
    return _schedule(ScheduledRelease(
      id: _nextScheduleId(),
      type: type,
      songIds: List.of(songIds),
      title: t,
      variantWeeks: List.of(variantWeeks),
      variantFormats: formats,
      releaseWeek: releaseWeek,
      announceWeek: announceWeek,
      createdWeek: world.week,
      campaign: campaign,
      paidCents: cost,
    ));
  }

  /// Keeps an album, EP or mixtape in the vault with no date (docs F31):
  /// its songs, title and editions are set and its cover can be chosen;
  /// nothing is paid until it is released ([releaseDraft]) or dated
  /// ([scheduleDraft]). It can wait for years.
  ScheduledView saveDraft(
    String title,
    List<int> songIds, {
    AlbumType type = AlbumType.album,
    List<int> variantWeeks = const [0],
    List<EditionFormat?> variantFormats = const [],
  }) {
    final t = _checkAlbum(title, songIds, type, variantWeeks, variantFormats);
    return _schedule(ScheduledRelease(
      id: _nextScheduleId(),
      type: type,
      songIds: List.of(songIds),
      title: t,
      variantWeeks: List.of(variantWeeks),
      variantFormats: _formats(variantFormats),
      releaseWeek: ScheduledRelease.draftWeek,
      announceWeek: ScheduledRelease.draftWeek,
      createdWeek: world.week,
      campaign: Campaign.none,
    ));
  }

  /// Releases a draft this week with [campaign]. Its schedule id stays on
  /// the album, so a cover chosen for the draft follows it.
  AlbumView releaseDraft(int id, {Campaign campaign = Campaign.standard}) {
    final sr = _draftById(id);
    _p.scheduled.remove(sr);
    try {
      _checkAlbum(sr.title, sr.songIds, sr.type, sr.variantWeeks,
          _editionFormats(sr.variantFormats));
      _requireMoney(_campaignCost(campaign) +
          Actions.editionsCostCents(sr.variantWeeks.length, sr.variantFormats));
    } on GameException {
      _p.scheduled.add(sr);
      rethrow;
    }
    final al = Actions.releaseAlbum(world, _p, sr.title, sr.songIds,
        type: sr.type,
        variantWeeks: sr.variantWeeks,
        variantFormats: sr.variantFormats,
        scheduleId: sr.id,
        payForVariants: true,
        campaign: campaign);
    _saveNow();
    return AlbumView.of(world, al);
  }

  /// Gives a draft a date like [scheduleAlbum]; the campaign and editions
  /// are paid now.
  ScheduledView scheduleDraft(int id,
      {Campaign campaign = Campaign.standard,
      required int releaseWeek,
      required int announceWeek}) {
    final sr = _draftById(id);
    _checkDates(releaseWeek, announceWeek);
    final cost = _campaignCost(campaign) +
        Actions.editionsCostCents(sr.variantWeeks.length, sr.variantFormats);
    _requireMoney(cost);
    _p.scheduled.remove(sr);
    return _schedule(ScheduledRelease(
      id: sr.id,
      type: sr.type,
      songIds: sr.songIds,
      title: sr.title,
      variantWeeks: sr.variantWeeks,
      variantFormats: sr.variantFormats,
      releaseWeek: releaseWeek,
      announceWeek: announceWeek,
      createdWeek: sr.createdWeek,
      campaign: campaign,
      paidCents: cost,
    ));
  }

  ScheduledRelease _draftById(int id) {
    final sr = _scheduledById(id);
    if (!sr.isDraft) throw GameException('notDraft', 'Already has a date');
    return sr;
  }

  static List<EditionFormat?> _editionFormats(List<int> f) =>
      [for (final x in f) x < 0 ? null : EditionFormat.values[x]];

  /// Moves a scheduled release. Once announced, the announcement stays;
  /// pushing an announced release back costs part of its buzz.
  void reschedule(int id, {required int releaseWeek, int? announceWeek}) {
    final sr = _scheduledById(id);
    if (sr.isDraft) throw GameException('isDraft', 'Use scheduleDraft');
    final announced = sr.announcedBy(world.week);
    final announce = announced ? sr.announceWeek : announceWeek ?? releaseWeek;
    if (releaseWeek <= world.week ||
        releaseWeek > world.week + Actions.maxScheduleWeeks ||
        announce > releaseWeek ||
        (!announced && announce < world.week)) {
      throw GameException('invalidDate', 'Pick a later week');
    }
    if (announced && releaseWeek > sr.releaseWeek) sr.buzz *= delayBuzzKept;
    sr.releaseWeek = releaseWeek;
    sr.announceWeek = announce;
    _saveNow();
  }

  /// First year of short-video apps (docs K38); earlier virality happens
  /// on video sites.
  static const shortVideoYear = 2017;

  /// Share of the buzz kept when an announced release is pushed back.
  static const delayBuzzKept = 0.7;

  /// Calls off a scheduled release: its songs are free again and what was
  /// paid for it comes back (any announcement buzz is lost).
  void cancelScheduled(int id) {
    final sr = _scheduledById(id);
    _p.scheduled.remove(sr);
    _p.moneyCents += sr.paidCents;
    _saveNow();
  }

  ScheduledRelease _scheduledById(int id) =>
      _p.scheduled.where((sr) => sr.id == id).firstOrNull ??
      (throw GameException('notScheduled', 'No such scheduled release'));

  /// Unique in the career (a pending album cover is stored under it).
  int _nextScheduleId() => _p.scheduled
      .where((sr) => sr.createdWeek == world.week)
      .fold(world.week * 64, (m, sr) => math.max(m, sr.id + 1));

  void _checkDates(int releaseWeek, int announceWeek) {
    if (releaseWeek <= world.week ||
        releaseWeek > world.week + Actions.maxScheduleWeeks ||
        announceWeek < world.week ||
        announceWeek > releaseWeek) {
      throw GameException('invalidDate', 'Pick a later week');
    }
  }

  ScheduledView _schedule(ScheduledRelease sr) {
    _p.moneyCents -= sr.paidCents;
    _p.scheduled.add(sr);
    _saveNow();
    return ScheduledView.of(world, sr);
  }

  /// How many tracks each release type takes (a mixtape: 5–30; K62).
  static (int, int) trackRange(AlbumType type) => switch (type) {
        AlbumType.ep => (minEpTracks, maxEpTracks),
        AlbumType.mixtape => (minMixtapeTracks, maxMixtapeTracks),
        _ => (minAlbumTracks, maxAlbumTracks),
      };
  static const minMixtapeTracks = 5, maxMixtapeTracks = 30;

  static const minEpTracks = 3, maxEpTracks = 7;
  static const minAlbumTracks = 8, maxAlbumTracks = 40;
  static const maxVariants = 8, maxVariantWeek = 12;

  /// Releases an album or EP of the player's songs: vault songs and earlier
  /// singles that are not on another release yet. [variantWeeks] lists each
  /// edition's release week offset (index 0 is the standard edition at 0).
  AlbumView releaseAlbum(
    String title,
    List<int> songIds, {
    AlbumType type = AlbumType.album,
    List<int> variantWeeks = const [0],
    List<EditionFormat?> variantFormats = const [],
    Campaign campaign = Campaign.standard,
  }) {
    final t = _checkAlbum(title, songIds, type, variantWeeks, variantFormats);
    final formats = _formats(variantFormats);
    _requireMoney(_campaignCost(campaign) +
        Actions.editionsCostCents(variantWeeks.length, formats));
    final al = Actions.releaseAlbum(world, _p, t, songIds,
        type: type,
        variantWeeks: variantWeeks,
        variantFormats: formats,
        payForVariants: true,
        campaign: campaign);
    _saveNow();
    return AlbumView.of(world, al);
  }

  static List<int> _formats(List<EditionFormat?> f) =>
      [for (final x in f) x?.index ?? -1];

  String _checkAlbum(
      String title, List<int> songIds, AlbumType type, List<int> variantWeeks,
      [List<EditionFormat?> variantFormats = const []]) {
    final t = title.trim();
    if (t.isEmpty || t.length > 60) {
      throw GameException('invalidTitle', 'Title must be 1–60 chars');
    }
    if (type == AlbumType.single) {
      throw GameException('invalidType', 'Use releaseSingle for singles');
    }
    final (lo, hi) = trackRange(type);
    if (type == AlbumType.mixtape && variantWeeks.length > 1) {
      throw GameException('mixtapeEditions', 'A free mixtape has no editions');
    }
    if (songIds.length < lo || songIds.length > hi) {
      throw GameException('trackCount', 'Needs $lo–$hi tracks');
    }
    if (songIds.toSet().length != songIds.length) {
      throw GameException('duplicateTracks', 'A song is listed twice');
    }
    for (final id in songIds) {
      if (_ownSong(id).albumId >= 0 ||
          _p.scheduled.any((sr) => sr.isAlbum && sr.songIds.contains(id))) {
        throw GameException('trackOnOtherRelease', 'Song $id is taken');
      }
    }
    if (variantWeeks.isEmpty ||
        variantWeeks.length > maxVariants ||
        variantWeeks.any((x) => x < 0 || x > maxVariantWeek) ||
        !variantWeeks.contains(0)) {
      throw GameException('invalidVariants', 'Variants must include week 0');
    }
    if (variantFormats.length > variantWeeks.length ||
        (variantFormats.isNotEmpty && variantFormats.first != null)) {
      throw GameException(
          'invalidVariants', 'One format per extra edition (not the first)');
    }
    return t;
  }

  /// Takes a day job, or quits with [Job.none] (docs K36).
  void setJob(Job job) {
    Actions.setJob(world, _p, job);
    _saveNow();
  }

  /// Spends one skill point on [kind] (docs K43).
  void spendSkillPoint(SkillKind kind) {
    if (_p.skillPoints <= 0) {
      throw GameException('noSkillPoints', 'No skill points left');
    }
    if (_p.skills[kind] >= Actions.maxSkill) {
      throw GameException('skillMaxed', 'This skill is maxed');
    }
    Actions.spendSkillPoint(_p, kind);
    _saveNow();
  }

  /// Spends up to [count] points on [kind] at once (docs F34); returns how
  /// many were spent.
  int spendSkillPoints(SkillKind kind, int count) {
    if (_p.skillPoints <= 0) {
      throw GameException('noSkillPoints', 'No skill points left');
    }
    if (_p.skills[kind] >= Actions.maxSkill) {
      throw GameException('skillMaxed', 'This skill is maxed');
    }
    final n = Actions.spendSkillPoints(_p, kind, count);
    _saveNow();
    return n;
  }

  /// Spends every point, lowest skill first (docs F34).
  int spreadSkillPoints() {
    final n = Actions.spreadSkillPoints(_p);
    _saveNow();
    return n;
  }

  /// Shoots a music video for one of the player's songs (docs K52); it
  /// promotes the song from its release on.
  void shootVideo(int songId, VideoBudget budget) {
    final s = _ownSong(songId);
    if (s.videoBudget >= 0) {
      throw GameException('hasVideo', 'This song already has a video');
    }
    _requireMoney(budget.costCents);
    Actions.shootVideo(world, _p, s, budget);
    _saveNow();
  }

  /// Buys streams for a released song (docs K95). Risky: the platform may
  /// catch and remove them.
  void buyBots(int songId, BotPackage pkg) {
    final s = _ownSong(songId);
    if (!StreamingTools.streamingOpen(world)) {
      throw GameException('noStreaming', 'No streaming platform yet');
    }
    if (s.releasedWeek < 0) {
      throw GameException('notReleased', 'Only released songs');
    }
    if (s.botStatus == BotStatus.caught || s.botWeeksLeft > 0) {
      throw GameException('botsBusy', 'Not on this song');
    }
    _requireMoney(pkg.costCents);
    StreamingTools.buyBots(world, _p, s, pkg);
    _saveNow();
  }

  /// Puts a released song in or out of the autoplay programme (docs K96).
  void setAutoplay(int songId, bool on) {
    final s = _ownSong(songId);
    if (on && !StreamingTools.autoplayOpen(world)) {
      throw GameException('noStreaming', 'No autoplay yet');
    }
    StreamingTools.setAutoplay(world, s, on);
    _saveNow();
  }

  /// Pitches a fresh release to the playlist editors (docs K97).
  void pitchSong(int songId) {
    final s = _ownSong(songId);
    if (!StreamingTools.canPitch(world, s)) {
      throw GameException('cannotPitch', 'Cannot pitch this song');
    }
    StreamingTools.pitch(world, s);
    _saveNow();
  }

  /// Puts out another version of a released song (docs K92, F26).
  void releaseVersion(int songId, SongVersion v) {
    final s = _ownSong(songId);
    if (s.releasedWeek < 0) {
      throw GameException('notReleased', 'Only released songs');
    }
    if (s.versions.any((x) => x.$1 == v)) {
      throw GameException('versionOut', 'That version is already out');
    }
    _requireMoney(v.costCents);
    Actions.releaseVersion(world, _p, s, v);
    _saveNow();
  }

  /// Puts out a physical edition of a released single (docs K92, F26).
  void releaseVariant(int songId, SingleFormat f) {
    final s = _ownSong(songId);
    if (!s.isSingle || s.releasedWeek < 0) {
      throw GameException('notSingle', 'Only released singles');
    }
    if (s.variants.any((x) => x.$1 == f)) {
      throw GameException('variantOut', 'That edition is already out');
    }
    _requireMoney(f.costCents);
    Actions.releaseVariant(world, _p, s, f);
    _saveNow();
  }

  /// Rivals the player could ask to feature on vault song [songId]
  /// (docs K117).
  List<FeatureCandidateView> featureCandidates(int songId) {
    final s = _ownSong(songId);
    return [
      for (final a in Features.candidates(world, _p, s))
        FeatureCandidateView.of(world, a, _p)
    ];
  }

  /// Gets rival [artistId] on vault song [songId] for their fee.
  void requestFeature(int songId, int artistId) {
    final s = _ownSong(songId);
    if (s.status != SongStatus.vault) {
      throw GameException('notInVault', 'Only unreleased songs');
    }
    if (s.featuredArtistIds.length >= Features.maxPerSong) {
      throw GameException('featuresFull', 'Two features at most');
    }
    if (artistId < 0 || artistId >= world.artists.length) {
      throw GameException('noArtist', 'No such artist');
    }
    final rival = world.artists[artistId];
    if (!Features.willing(rival, _p)) {
      throw GameException('featureRefused', 'Out of your league');
    }
    _requireMoney(Features.feeCents(rival));
    Features.request(world, _p, s, rival);
    _saveNow();
  }

  /// Re-releases album [albumId] as a deluxe edition with unreleased
  /// [songIds] as bonus tracks (docs K115).
  void releaseDeluxe(int albumId, List<int> songIds) {
    if (albumId < 0 || albumId >= world.albums.length) {
      throw GameException('noAlbum', 'No such album');
    }
    final al = world.albums[albumId];
    if (al.artistId != _p.id) throw GameException('notYours', 'Not yours');
    if (Actions.hasDeluxe(al)) {
      throw GameException('deluxeOut', 'Already re-released');
    }
    if (songIds.isEmpty || songIds.length > Actions.maxDeluxeTracks) {
      throw GameException('deluxeTracks', 'Pick 1–6 bonus tracks');
    }
    for (final id in songIds) {
      final s = _ownSong(id);
      if (s.status != SongStatus.vault) {
        throw GameException('notInVault', 'Only unreleased songs');
      }
      if (_p.scheduled.any((sr) => sr.songIds.contains(id))) {
        throw GameException('songScheduled', 'Song is on a scheduled release');
      }
    }
    _requireMoney(EditionFormat.deluxe.costCents);
    Actions.releaseDeluxe(world, _p, al, songIds);
    _saveNow();
  }

  /// Throws away an unreleased song from the vault (docs K48).
  void scrapSong(int songId) {
    final s = _ownSong(songId);
    if (s.status != SongStatus.vault) {
      throw GameException('notInVault', 'Only unreleased songs');
    }
    if (_p.scheduled.any((sr) => sr.songIds.contains(s.id))) {
      throw GameException('songScheduled', 'Song is on a scheduled release');
    }
    Actions.scrapSong(world, s);
    _saveNow();
  }

  /// Takes this week off: no writing, more energy at the end of the week.
  void rest() {
    if (_p.lastWriteWeek == world.week && _p.songsWrittenThisWeek > 0) {
      throw GameException('alreadyWrote', 'Already wrote this week');
    }
    Actions.rest(world, _p);
    _saveNow();
  }

  /// Call after a rewarded ad finished playing.
  void rewardAd() {
    if (Actions.adsLeftThisWeek(world, _p) <= 0) {
      throw GameException('adLimit', 'Ad limit reached for this week');
    }
    Actions.claimAdReward(world, _p);
    _saveNow();
  }

  /// Premium daily login bonus; true when it was granted now (§20.2).
  bool claimDailyBonus({required bool premium, DateTime? now}) {
    if (!premium || !slots.claimDailyBonus(now ?? DateTime.now())) {
      return false;
    }
    Actions.grantDailyBonus(world, _p);
    _saveNow();
    return true;
  }

  // ----------------------------------------------------------------- weeks

  /// Plays one week, autosaves it and reports what happened.
  WeekReport advanceWeek() {
    final p = _p;
    final before = _Snapshot(world, p);
    final r = _sim.step();
    final milestones = Milestone.check(world, p);
    final events = [
      ..._events(r, before),
      for (final m in milestones) MilestoneReached(m),
    ];
    // Fans talk about the week (docs K93).
    SocialFeed.react(world, p, events, r.week);
    _store.commitWeek(world, r);
    slots.writeSummary(slotId, world);
    return WeekReport(
      week: r.week,
      events: events,
      moneyDeltaCents: p.moneyCents - before.money,
    );
  }

  /// Year skip: plays up to 52 weeks, stopping after a week with a major
  /// event when [stopOnMajor] is set. [onWeek] reports progress after each
  /// week; returning true from [cancel] stops after the current week.
  YearReport advanceYear({
    bool stopOnMajor = true,
    void Function(WeekReport week)? onWeek,
    bool Function()? cancel,
  }) =>
      advanceWeeks(GameTime.weeksPerYear,
          stop: stopOnMajor ? SkipStop.major : SkipStop.never,
          onWeek: onWeek,
          cancel: cancel);

  /// Plays up to [count] weeks, stopping after a week whose news matches
  /// [stop]. [onWeek] reports progress after each week; returning true from
  /// [cancel] stops after the current week.
  YearReport advanceWeeks(
    int count, {
    SkipStop stop = SkipStop.major,
    void Function(WeekReport week)? onWeek,
    bool Function()? cancel,
  }) {
    final p = _p;
    final from = world.week;
    final streams0 = world.artistLifetimeStreams(p);
    final pure0 = _sum(p, ArtistReg.lifePure);
    final units0 = world.artistLifetimeUnits(p);
    final money0 = p.moneyCents, fans0 = p.coreFans, fame0 = p.fame;
    final singles0 = _singleSales();
    final events = <GameEvent>[];
    var weeks = 0;
    var stopped = false;
    while (weeks < count) {
      final r = advanceWeek();
      weeks++;
      events.addAll(r.events);
      onWeek?.call(r);
      if (r.events.any(stop.stopsOn) || (cancel?.call() ?? false)) {
        stopped = weeks < count;
        break;
      }
    }
    return YearReport(
      fromWeek: from,
      weeks: weeks,
      requestedWeeks: count,
      stoppedEarly: stopped,
      events: events,
      streamsGained: world.artistLifetimeStreams(p) - streams0,
      singleSalesGained: _singleSales() - singles0,
      pureGained: _sum(p, ArtistReg.lifePure) - pure0,
      unitsGained: world.artistLifetimeUnits(p) - units0,
      moneyDeltaCents: p.moneyCents - money0,
      coreFansDelta: p.coreFans - fans0,
      fameBefore: fame0,
      fameAfter: p.fame,
    );
  }

  // --------------------------------------------------------------- history

  /// Weekly streams and chart positions of one of the player's songs.
  List<HistoryPoint> songHistory(int songId) => _history(
        'SELECT week, streams AS v, downloads + physical AS s FROM songWeek '
        'WHERE songId = ? '
        'ORDER BY week',
        songId,
        Charts.all
            .where((c) => c.kind == ChartKind.songs)
            .map((c) => c.id)
            .toList(),
      );

  /// Weekly units and chart positions of one of the player's albums.
  List<HistoryPoint> albumHistory(int albumId) => _history(
        'SELECT week, units AS v FROM albumWeek WHERE albumId = ? '
        'ORDER BY week',
        albumId,
        Charts.all
            .where((c) => c.kind == ChartKind.albums)
            .map((c) => c.id)
            .toList(),
      );

  List<HistoryPoint> _history(String sql, int id, List<int> chartIds) {
    final pos = <int, Map<int, int>>{};
    for (final r in _store.db.select(
        'SELECT week, chartId, position FROM chartEntry '
        'WHERE entityId = ? AND chartId IN (${chartIds.join(',')})',
        [id])) {
      (pos[r['week'] as int] ??= {})[r['chartId'] as int] =
          r['position'] as int;
    }
    return [
      for (final r in _store.db.select(sql, [id]))
        HistoryPoint(r['week'] as int, (r['v'] as num).toDouble(),
            pos[r['week'] as int] ?? const {},
            sales: (r['s'] as num?)?.toDouble() ?? 0),
    ];
  }

  /// [year]'s year-end chart of [chartId] (docs K110): points over the
  /// tracking year, best position and weeks on.
  List<YearEndRow> yearEnd(int chartId, int year, {int limit = YearEnd.size}) {
    final def = Charts.all[chartId];
    final (from, to) = YearEnd.tracking(year);
    final kind =
        def.kind == ChartKind.songs ? EntityKind.song : EntityKind.album;
    var rank = 0;
    return [
      for (final r in _store.db.select(
          'SELECT entityId, SUM(? - position) AS pts, MIN(position) AS peak, '
          'COUNT(*) AS weeks FROM chartEntry '
          'WHERE chartId = ? AND week BETWEEN ? AND ? '
          'GROUP BY entityId ORDER BY pts DESC, peak ASC, entityId ASC '
          'LIMIT ?',
          [def.size + 1, chartId, from, to, limit]))
        YearEndRow.of(world, kind,
            rank: ++rank,
            entityId: r['entityId'] as int,
            points: r['pts'] as int,
            peak: r['peak'] as int,
            weeksOn: r['weeks'] as int),
    ];
  }

  /// All-time records the player set this week (docs K111). The history
  /// holds the weeks before this one; after two years of it, so a record
  /// means something.
  List<RecordBroken> _recordsBroken(WeekResult r) {
    final w = world;
    final start = historyStartWeek;
    if (r.week - start < 2 * GameTime.weeksPerYear) return const [];
    double scalar(String sql, List<Object> args) {
      final rows = _store.db.select(sql, args);
      return rows.isEmpty ? 0 : ((rows.first['v'] as num?) ?? 0).toDouble();
    }

    bool mine(EntityKind k, int id) =>
        (k == EntityKind.song
            ? w.songs[id].primaryArtistId
            : w.albums[id].artistId) ==
        w.playerArtistId;
    final out = <RecordBroken>[];
    // Weeks at #1: the week the player's #1 passes everyone's best.
    for (final (chart, kind, record) in const [
      (Charts.usSongs, EntityKind.song, RecordKind.weeksAtNo1Song),
      (Charts.usAlbums, EntityKind.album, RecordKind.weeksAtNo1Album),
    ]) {
      final c = r.charts[chart];
      if (c.isEmpty || !mine(kind, c.first.entityId)) continue;
      final id = c.first.entityId;
      final weeks = scalar(
              'SELECT COUNT(*) AS v FROM chartEntry '
              'WHERE chartId = ? AND position = 1 AND entityId = ?',
              [chart, id]) +
          1;
      final best = scalar(
          'SELECT MAX(n) AS v FROM (SELECT COUNT(*) AS n FROM chartEntry '
          'WHERE chartId = ? AND position = 1 AND entityId <> ? '
          'GROUP BY entityId)',
          [chart, id]);
      if (best >= 4 && weeks == best + 1)
        out.add(RecordBroken(record, id, weeks));
    }
    // The biggest streaming week ever, the first time a song passes it.
    final st = r.charts[Charts.platformGlobal];
    if (st.isNotEmpty && mine(EntityKind.song, st.first.entityId)) {
      final id = st.first.entityId;
      final best = scalar(
          'SELECT MAX(points) AS v FROM chartEntry '
          'WHERE chartId = ? AND entityId <> ?',
          [Charts.platformGlobal, id]);
      final own = scalar(
          'SELECT MAX(points) AS v FROM chartEntry '
          'WHERE chartId = ? AND entityId = ?',
          [Charts.platformGlobal, id]);
      if (best > 0 && st.first.points > best && own <= best) {
        out.add(RecordBroken(RecordKind.streamWeek, id, st.first.points));
      }
    }
    // The biggest US album debut.
    for (final id in r.albumDebuts) {
      final al = w.albums[id];
      if (al.artistId != w.playerArtistId) continue;
      final units = w.albumFirstWeekIn(al, ChartMarket.us);
      var best = 0.0;
      for (final x in w.albums) {
        if (x.id == id || x.releaseWeek < start || x.releaseWeek >= r.week) {
          continue;
        }
        final u = w.albumFirstWeekIn(x, ChartMarket.us);
        if (u > best) best = u;
      }
      if (best > 0 && units > best) {
        out.add(RecordBroken(RecordKind.albumDebut, id, units));
      }
    }
    return out;
  }

  /// The player's honours beyond awards (docs K116).
  HonorsView get honors {
    final w = world;
    final me = w.playerArtistId;
    (int, int, String)? best(int chart) {
      (int, int, String)? out;
      for (final y in yearEndYears) {
        for (final r in yearEnd(chart, y)) {
          if (!r.isPlayer) continue;
          if (out == null || r.rank < out.$1) out = (r.rank, y, r.title);
          break;
        }
      }
      return out;
    }

    var wins = 0, crowns = 0;
    w.musicShow.wins.forEach((id, n) {
      if (w.songs[id].primaryArtistId == me) wins += n;
    });
    for (final id in w.musicShow.crowned) {
      if (w.songs[id].primaryArtistId == me) crowns++;
    }
    final boards = records;
    return HonorsView(
      recordsHeld: [
        for (final k in RecordKind.values)
          if (boards[k]!.isNotEmpty && boards[k]!.first.isPlayer) k
      ],
      bestYearEndSong: best(Charts.usSongs),
      bestYearEndAlbum: best(Charts.usAlbums),
      musicShowWins: wins,
      tripleCrowns: crowns,
      bestArtistRank: w.playerBestArtistRank,
      weeksTopArtist: w.playerWeeksTopArtist,
    );
  }

  /// The K-pop music show's recent weeks, newest first (docs K114).
  List<MusicShowRow> get musicShow => [
        for (final x in world.musicShow.weeks.reversed)
          MusicShowRow.of(world, x)
      ];

  /// This week's top artists (docs K113).
  List<ArtistChartRow> get artistChart {
    final streams = Platforms.weekStreamsByArtist(world);
    return [
      for (final (i, id) in world.artistChart.indexed)
        ArtistChartRow.of(world, i + 1, id, streams[id] ?? 0)
    ];
  }

  /// First week of this save's chart history (records count from it).
  int get historyStartWeek {
    final r = _store.db.select('SELECT MIN(week) AS w FROM chartEntry');
    return r.isEmpty ? world.week : (r.first['w'] as int?) ?? world.week;
  }

  /// The top 10 of every record (docs K111).
  Map<RecordKind, List<RecordEntry>> get records => {
        for (final k in RecordKind.values) k: recordBoard(k),
      };

  /// The top [limit] holders of record [kind] since the history began.
  List<RecordEntry> recordBoard(RecordKind kind, {int limit = 10}) {
    final w = world;
    RecordEntry song(int rank, int id, double v) {
      final s = w.songs[id];
      return RecordEntry(
          rank: rank,
          entityId: id,
          title: s.title,
          artistName: w.artists[s.primaryArtistId].name,
          albumId: coverAlbumOf(w, s),
          isPlayer: s.primaryArtistId == w.playerArtistId,
          value: v);
    }

    RecordEntry album(int rank, int id, double v) {
      final al = w.albums[id];
      return RecordEntry(
          rank: rank,
          entityId: id,
          title: al.title,
          artistName: w.artists[al.artistId].name,
          albumId: id,
          isPlayer: al.artistId == w.playerArtistId,
          value: v);
    }

    List<(int, double)> top(String sql, List<Object> args) => [
          for (final r in _store.db.select(sql, args))
            (r['id'] as int, (r['v'] as num).toDouble())
        ];
    var rank = 0;
    switch (kind) {
      case RecordKind.weeksAtNo1Song || RecordKind.weeksAtNo1Album:
        final chart = kind == RecordKind.weeksAtNo1Song
            ? Charts.usSongs
            : Charts.usAlbums;
        return [
          for (final (id, v) in top(
              'SELECT entityId AS id, COUNT(*) AS v FROM chartEntry '
              'WHERE chartId = ? AND position = 1 GROUP BY entityId '
              'ORDER BY v DESC, MIN(week) ASC LIMIT ?',
              [chart, limit]))
            kind == RecordKind.weeksAtNo1Song
                ? song(++rank, id, v)
                : album(++rank, id, v)
        ];
      case RecordKind.weeksOnChart:
        return [
          for (final (id, v) in top(
              'SELECT entityId AS id, COUNT(*) AS v FROM chartEntry '
              'WHERE chartId = ? GROUP BY entityId '
              'ORDER BY v DESC, MIN(week) ASC LIMIT ?',
              [Charts.usSongs, limit]))
            song(++rank, id, v)
        ];
      case RecordKind.streamWeek:
        return [
          for (final (id, v) in top(
              'SELECT entityId AS id, MAX(points) AS v FROM chartEntry '
              'WHERE chartId = ? GROUP BY entityId '
              'ORDER BY v DESC, MIN(week) ASC LIMIT ?',
              [Charts.platformGlobal, limit]))
            song(++rank, id, v)
        ];
      case RecordKind.albumDebut:
        final start = historyStartWeek;
        final debuts = [
          for (final al in w.albums)
            if (al.releaseWeek >= start && al.releaseWeek < w.week)
              (al.id, w.albumFirstWeekIn(al, ChartMarket.us))
        ]..sort((a, b) => b.$2.compareTo(a.$2));
        return [for (final (id, v) in debuts.take(limit)) album(++rank, id, v)];
      case RecordKind.mostNo1s:
        final count = <int, int>{};
        for (final r in _store.db.select(
            'SELECT DISTINCT entityId AS id FROM chartEntry '
            'WHERE chartId = ? AND position = 1',
            [Charts.usSongs])) {
          final a = w.songs[r['id'] as int].primaryArtistId;
          count[a] = (count[a] ?? 0) + 1;
        }
        final artists = count.entries.toList()
          ..sort((a, b) {
            final c = b.value.compareTo(a.value);
            return c != 0 ? c : a.key.compareTo(b.key);
          });
        return [
          for (final e in artists.take(limit))
            RecordEntry(
                rank: ++rank,
                entityId: e.key,
                title: '',
                artistName: w.artists[e.key].name,
                albumId: -1,
                isPlayer: e.key == w.playerArtistId,
                value: e.value.toDouble())
        ];
    }
  }

  /// Years with year-end charts, newest first: out already, and with at
  /// least half of their tracking year in this save's history.
  List<int> get yearEndYears {
    final first = _store.db.select('SELECT MIN(week) AS w FROM chartEntry');
    final start = first.isEmpty ? null : first.first['w'] as int?;
    if (start == null) return const [];
    return [
      for (var y = year; y >= GameTime.yearOf(start); y--)
        if (YearEnd.publishedBy(y, world.week - 1) &&
            YearEnd.tracking(y).$2 - start >= 26)
          y
    ];
  }

  /// Every chart week of a song or album, any artist's (docs K47).
  List<ChartWeek> chartRun(EntityKind kind, int id) {
    final ids = [
      for (final c in Charts.all)
        if ((c.kind == ChartKind.songs) == (kind == EntityKind.song)) c.id
    ];
    final weeks = <int, Map<int, ({int position, double points})>>{};
    for (final r in _store.db.select(
        'SELECT week, chartId, position, points FROM chartEntry '
        'WHERE entityId = ? AND chartId IN (${ids.join(',')}) ORDER BY week',
        [id])) {
      (weeks[r['week'] as int] ??= {})[r['chartId'] as int] = (
        position: r['position'] as int,
        points: (r['points'] as num).toDouble(),
      );
    }
    return [
      for (final e in weeks.entries) ChartWeek(e.key, e.value),
    ];
  }

  /// Week-by-week sales of an album, newest last (docs K47).
  List<AlbumSalesWeek> albumSales(int albumId) {
    final run = {
      for (final c in chartRun(EntityKind.album, albumId)) c.week: c.entries
    };
    Map<int, int> pos(int week) => {
          for (final e in (run[week] ?? const {}).entries)
            e.key: e.value.position
        };
    double? us(int week) => run[week]?[Charts.usAlbums]?.points;
    final al = world.albums[albumId];
    if (al.artistId == _p.id) {
      return [
        for (final r in _store.db.select(
            'SELECT week, pure, tea, sea, units FROM albumWeek '
            'WHERE albumId = ? ORDER BY week',
            [albumId]))
          AlbumSalesWeek(
            week: r['week'] as int,
            positions: pos(r['week'] as int),
            units: (r['units'] as num?)?.toDouble(),
            pure: (r['pure'] as num?)?.toDouble(),
            tea: (r['tea'] as num?)?.toDouble(),
            sea: (r['sea'] as num?)?.toDouble(),
            usUnits: us(r['week'] as int),
          ),
      ];
    }
    return [
      for (final week in run.keys)
        AlbumSalesWeek(
          week: week,
          positions: pos(week),
          units: run[week]?[Charts.globalAlbums]?.points,
          usUnits: us(week),
        ),
    ];
  }

  /// Career summary by year (streams, sales, fame at year end, money).
  List<CareerYear> careerByYear() {
    final sales = <int, (double, double)>{};
    for (final r in _store.db.select(
        'SELECT ${GameTime.baseYear} + week / ${GameTime.weeksPerYear} AS y, '
        'SUM(pure) AS pure, SUM(units) AS units FROM albumWeek GROUP BY y')) {
      sales[r['y'] as int] = (
        (r['pure'] as num?)?.toDouble() ?? 0,
        (r['units'] as num?)?.toDouble() ?? 0,
      );
    }
    final singles = <int, double>{
      for (final r in _store.db.select(
          'SELECT ${GameTime.baseYear} + week / ${GameTime.weeksPerYear} AS y, '
          'SUM(downloads + physical) AS n FROM songWeek GROUP BY y'))
        r['y'] as int: (r['n'] as num?)?.toDouble() ?? 0,
    };
    final out = <CareerYear>[];
    var lastStreams = 0.0;
    for (final r in _store.db.select(
        'SELECT ${GameTime.baseYear} + week / ${GameTime.weeksPerYear} AS y, '
        'fame, coreFans, moneyCents, lifetimeStreams FROM playerWeek p '
        'WHERE week = (SELECT MAX(week) FROM playerWeek q '
        'WHERE q.week / ${GameTime.weeksPerYear} = '
        'p.week / ${GameTime.weeksPerYear}) ORDER BY week')) {
      final y = r['y'] as int;
      final life = (r['lifetimeStreams'] as num).toDouble();
      out.add(CareerYear(
        year: y,
        streams: life - lastStreams,
        singleSales: singles[y] ?? 0,
        pure: sales[y]?.$1 ?? 0,
        units: sales[y]?.$2 ?? 0,
        fame: (r['fame'] as num).toDouble(),
        coreFans: (r['coreFans'] as num).toDouble(),
        moneyCents: r['moneyCents'] as int,
      ));
      lastStreams = life;
    }
    return out;
  }

  // ---------------------------------------------------------------- helpers

  void _saveNow() => _store.saveState(world);

  double _singleSales() => world.playerSongIds.fold(
      0.0,
      (t, id) =>
          t +
          world.songLifetimeDownloads(world.songs[id]) +
          world.songs[id].lifetimePhysical);

  void _requireMoney(int cents) {
    if (cents > _p.moneyCents) {
      throw GameException('notEnoughMoney', 'Needs $cents cents');
    }
  }

  Song _ownSong(int id) {
    if (id < 0 || id >= world.songs.length) {
      throw GameException('unknownSong', 'No song $id');
    }
    final s = world.songs[id];
    if (s.status == SongStatus.scrapped) {
      throw GameException('unknownSong', 'Song $id was scrapped');
    }
    if (s.primaryArtistId != _p.id) {
      throw GameException('notYourSong', 'Song $id is not yours');
    }
    return s;
  }

  Collaborator? _collaborator(int? id, CollaboratorRole role) {
    if (id == null) return null;
    if (id < 0 || id >= world.collaborators.length) {
      throw GameException('unknownCollaborator', 'No collaborator $id');
    }
    final c = world.collaborators[id];
    if (c.role != role) {
      throw GameException('wrongRole', '${c.name} is not a ${role.name}');
    }
    return c;
  }

  static double _sum(Artist a, int offset) {
    var s = 0.0;
    for (var r = 0; r < regionCount; r++) {
      s += a.reg[offset + r];
    }
    return s;
  }

  static const _songCharts = [
    Charts.usSongs,
    Charts.ukSongs,
    Charts.globalSongs
  ];
  static const _albumCharts = [
    Charts.usAlbums,
    Charts.ukAlbums,
    Charts.globalAlbums
  ];

  List<GameEvent> _events(WeekResult r, _Snapshot before) {
    final w = world;
    final p = _p;
    final events = <GameEvent>[];
    final debutAlbums = {
      for (final id in r.albumDebuts)
        if (w.albums[id].artistId == p.id) id,
    };

    if (r.lapsedOpportunity case final o?) events.add(OpportunityLapsed(o));
    if (r.tourFinished case final t?) {
      events.add(TourFinished(
          kind: t.kind,
          name: t.name,
          shows: t.shows.where((s) => s.played).length,
          soldOut: t.soldOut,
          grossCents: t.grossCents.round(),
          tickets: t.tickets,
          netCents: t.netCents.round(),
          fans: t.fans));
    }
    if (r.festivalSet case final f?) {
      events.add(FestivalPlayed(
          festival: f.booking.info.name,
          slot: f.booking.slot,
          watched: f.watched,
          feeCents: f.feeCents,
          fans: f.fans));
    }
    if (r.newOpportunity case final o?) events.add(OpportunityCame(o.kind));
    // The Golden Record Awards (docs K91).
    if (r.awardNominations case final show?) {
      final mine = show.racesOf(p.id).toList();
      if (mine.isNotEmpty) {
        events
            .add(AwardNominated(show.year, [for (final x in mine) x.category]));
      }
    }
    if (r.awardNight case final n?) {
      events.add(AwardResults(
          year: n.show.year,
          nominations: n.nominations.length,
          won: [for (final x in n.wins) x.category],
          attendance: n.show.attendance,
          fans: n.fans));
      if (n.wins.isNotEmpty) Milestone.awardWin.mark(w, p);
    }
    if (GameTime.weekOfYear(r.week) == Awards.ceremonyWeekOfYear) {
      final show = Awards.showFor(w, GameTime.yearOf(r.week));
      if (show != null && show.held) {
        AwardNominee? winner(AwardCategory c) {
          for (final x in show.races) {
            if (x.category == c) return x.won;
          }
          return null;
        }

        final album = winner(AwardCategory.album);
        final record = winner(AwardCategory.record);
        events.add(AwardWinners(
            year: show.year,
            albumArtistId: album?.artistId ?? -1,
            albumId: album?.id ?? -1,
            recordArtistId: record?.artistId ?? -1,
            songId: record?.id ?? -1));
      }
    }
    for (final al in w.albums.reversed) {
      if (al.releaseWeek < r.week) break;
      if (al.artistId == p.id &&
          al.releaseWeek == r.week &&
          al.criticScore >= 0) {
        events.add(CriticReview(al.id, al.criticScore,
            metascore: Critics.metascore(w, al)));
      }
    }
    for (final id in debutAlbums) {
      final al = w.albums[id];
      events.add(AlbumFirstWeek(
        albumId: id,
        usUnits: w.albumFirstWeekIn(al, ChartMarket.us),
        usPure: w.albumFirstWeekIn(al, ChartMarket.us, pure: true),
        globalUnits: al.firstWeekUnits,
        usPosition: al.lastPosOn(Charts.usAlbums),
      ));
    }

    void check(Charted e, EntityKind kind, int id, List<int> charts) {
      // Celebrated once per release: its first #1 on any chart.
      var hadNumberOne =
          charts.any((c) => (before.chart[(kind, id, c)]?.$2 ?? 0) == 1);
      for (final c in charts) {
        final st = e.statsOrNull(c);
        if (st == null || st.lastPos == 0) continue;
        final prev = before.chart[(kind, id, c)];
        final prevPos = prev?.$1 ?? 0, prevPeak = prev?.$2 ?? 0;
        final isDebut = st.weeksOn == 1;
        if (isDebut &&
            !(kind == EntityKind.album && debutAlbums.contains(id))) {
          events.add(ChartDebut(c, kind, id, st.lastPos));
        }
        if (st.lastPos == 1 && prevPos != 1) {
          events.add(NumberOne(c, kind, id, st.weeksAtNo1,
              firstForRelease: !hadNumberOne));
          hadNumberOne = true;
        } else if (st.lastPos == 1 &&
            (c == Charts.usSongs || c == Charts.usAlbums)) {
          events.add(StillNumberOne(c, kind, id, st.weeksAtNo1));
        } else if (kind == EntityKind.song &&
            !isDebut &&
            c != Charts.ukSongs &&
            st.lastPos <= 40 &&
            (prevPeak == 0 || st.lastPos < prevPeak)) {
          events.add(NewPeak(c, id, st.lastPos));
        }
      }
    }

    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.status == SongStatus.active) {
        check(s, EntityKind.song, id, _songCharts);
      }
    }
    for (final id in w.activeAlbumIds) {
      final al = w.albums[id];
      if (al.artistId == p.id) check(al, EntityKind.album, id, _albumCharts);
    }

    for (final o in r.scheduledOut) {
      events.add(ReleaseOut(
          o.isAlbum ? EntityKind.album : EntityKind.song, o.id, o.scheduleId));
    }
    for (final sr in p.scheduled) {
      if (sr.announceWeek == r.week &&
          !sr.isSurprise &&
          sr.announceWeek > sr.createdWeek) {
        events.add(ReleaseAnnounced(
            isAlbum: sr.isAlbum,
            songId: sr.isAlbum ? -1 : sr.songIds.single,
            title: sr.isAlbum ? sr.title : w.songs[sr.songIds.single].title,
            releaseWeek: sr.releaseWeek));
      }
    }
    for (final id in r.viralSongs) {
      if (w.songs[id].primaryArtistId == p.id) {
        events.add(ViralTrend(id,
            shortVideo: GameTime.yearOf(r.week) >= shortVideoYear));
      }
    }
    for (final id in r.playlistAdds) {
      final s = w.songs[id];
      if (s.primaryArtistId == p.id)
        events.add(PlaylistAdded(id, s.playlistAdd));
    }
    // A sleeper hit in the making (docs K108).
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.status != SongStatus.active || s.releasedWeek < 0) continue;
      final age = r.week - (s.isSingle ? s.singleWeek : s.releasedWeek);
      if (WordOfMouth.catchingOn(w, s, age)) events.add(CatchingOn(id));
    }
    for (final d in r.brandDealsBroken) {
      events.add(BrandDealBroken(d.deal.info, d.cents));
    }
    for (final c in r.rivalClashes) {
      events.add(RivalAlbumClash(c));
    }
    events.addAll(_recordsBroken(r));
    // Views milestones on the video site (docs K118).
    if (MusicPlatform.viewTube.openIn(GameTime.yearOf(r.week))) {
      for (final id in w.playerSongIds) {
        final s = w.songs[id];
        if (s.status != SongStatus.active) continue;
        final now = Platforms.videoViews(w, s);
        final before = Platforms.videoViews(w, s,
            streamsAgo: w.songWeekStreamsIn(s, ChartMarket.global));
        for (final m in Platforms.videoMilestones) {
          if (before < m && now >= m) events.add(VideoMilestone(id, m));
        }
      }
    }
    // The K-pop music show (docs K114).
    if (r.musicShow case final show?) {
      if (w.songs[show.songId].primaryArtistId == p.id) {
        events.add(MusicShowResult(show.songId,
            won: true,
            wins: w.musicShow.wins[show.songId] ?? 1,
            tripleCrown: show.tripleCrown,
            otherSongId: show.runnerUpId));
      } else if (show.runnerUpId >= 0 &&
          w.songs[show.runnerUpId].primaryArtistId == p.id) {
        events.add(MusicShowResult(show.runnerUpId,
            won: false,
            wins: w.musicShow.wins[show.runnerUpId] ?? 0,
            otherSongId: show.songId));
      }
    }
    // The top artists chart (docs K113): into the top 10, or to #1.
    final rankNow = w.artistChart.indexOf(p.id) + 1;
    final rankBefore = w.artistChartPrev.indexOf(p.id) + 1;
    if (rankNow == 1 && rankBefore != 1) {
      events.add(const TopArtist(1));
    } else if (rankNow >= 1 &&
        rankNow <= 10 &&
        (rankBefore == 0 || rankBefore > 10)) {
      events.add(TopArtist(rankNow));
    }
    // The year-end charts come out in early December (docs K110).
    if (GameTime.weekOfYear(r.week) == YearEnd.publishWeekOfYear) {
      final y = GameTime.yearOf(r.week);
      if (yearEndYears.contains(y)) {
        final songs = yearEnd(Charts.usSongs, y);
        events.add(YearEndCharts(y,
            songs: [
              for (final e in songs)
                if (e.isPlayer) (e.rank, e.entityId)
            ],
            albums: [
              for (final e in yearEnd(Charts.usAlbums, y))
                if (e.isPlayer) (e.rank, e.entityId)
            ],
            topSongId: songs.isEmpty ? -1 : songs.first.entityId));
      }
    }
    // Bought streams caught, and pitches the editors passed on (K95, K97).
    for (final id in r.botsCaught) {
      final s = w.songs[id];
      events.add(s.primaryArtistId == p.id
          ? BotsCaught(id, s.botDelivered,
              refundCents: (s.botDelivered * 0.35 * p.artistShare).round())
          : RivalBotsCaught(id, s.primaryArtistId, s.botDelivered));
    }
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (StreamingTools.pitchAnswerWeek(s) == r.week &&
          s.playlistWeek != r.week) {
        events.add(PitchDeclined(id));
      }
    }
    if (before.eraOpen && !p.eraOpen && p.lastEraResult != null) {
      events.add(EraClosed(p.lastEraResult!, p.lastEraUnits, p.eraExpected));
      if (before.label != Label.independent && p.label == Label.independent) {
        events.add(LabelDropped(before.label));
      } else if (p.lastEraResult!.index >= EraResult.normal.index) {
        // A good era: the biggest label that would sign the player calls
        // (under contract too: it can buy the player out, docs K78).
        final offer = Label.values.reversed.firstWhere(
            (l) => Actions.labelMissing(w, p, l).isEmpty,
            orElse: () => p.label);
        if (offer.index > p.label.index) events.add(LabelOffer(offer));
      }
    }
    if (before.burnoutUntil > before.week && w.week >= p.burnoutUntilWeek) {
      events.add(const BurnoutOver());
    }
    for (final c in [Charts.usSongs, Charts.usAlbums]) {
      for (final id in r.newNumberOnes[c]) {
        final kind = c == Charts.usSongs ? EntityKind.song : EntityKind.album;
        final artistId = kind == EntityKind.song
            ? w.songs[id].primaryArtistId
            : w.albums[id].artistId;
        if (artistId != p.id) {
          events.add(RivalNumberOne(c, kind, id, artistId));
        }
      }
    }
    // Chart battles: the player's release against the biggest rival one out
    // the same week (docs K69).
    for (final id in debutAlbums) {
      Album? rival;
      for (final al in w.albums.reversed) {
        if (al.releaseWeek < r.week) break;
        if (al.releaseWeek != r.week ||
            al.artistId == p.id ||
            !al.chartsOnAlbumChart ||
            !_bigRival(w.artists[al.artistId])) {
          continue;
        }
        if (rival == null || al.firstWeekUnits > rival.firstWeekUnits) {
          rival = al;
        }
      }
      if (rival != null) {
        events.add(ChartBattle(
          kind: EntityKind.album,
          playerEntityId: id,
          rivalEntityId: rival.id,
          rivalArtistId: rival.artistId,
          playerPosition: w.albums[id].lastPosOn(Charts.usAlbums),
          rivalPosition: rival.lastPosOn(Charts.usAlbums),
        ));
      }
    }
    for (final id in w.playerSongIds) {
      final mine = w.songs[id];
      if (!mine.isSingle || mine.singleWeek != r.week) continue;
      Song? rival;
      for (final sid in w.activeSongIds) {
        final s = w.songs[sid];
        if (!s.isSingle ||
            s.singleWeek != r.week ||
            s.primaryArtistId == p.id ||
            !_bigRival(w.artists[s.primaryArtistId])) {
          continue;
        }
        if (rival == null || s.weekPoints > rival.weekPoints) rival = s;
      }
      if (rival != null) {
        final battle = ChartBattle(
          kind: EntityKind.song,
          playerEntityId: id,
          rivalEntityId: rival.id,
          rivalArtistId: rival.primaryArtistId,
          playerPosition: mine.lastPosOn(Charts.usSongs),
          rivalPosition: rival.lastPosOn(Charts.usSongs),
        );
        // Two songs nowhere near the chart are no battle.
        if (battle.playerPosition > 0 || battle.rivalPosition > 0) {
          events.add(battle);
        }
      }
    }

    // Platforms opening this year (Streamify by its charts below).
    if (GameTime.weekOfYear(r.week) == 1) {
      for (final p in MusicPlatform.values) {
        if (p != MusicPlatform.streamify &&
            p.launchYear == GameTime.yearOf(r.week)) {
          events.add(PlatformOpened(p));
        }
      }
    }
    if (GameTime.weekOfYear(r.week) == 46) events.add(const HolidaySeason());
    for (final c in const [
      Charts.platformGlobal,
      Charts.platformNorthAmerica,
    ]) {
      final def = Charts.all[c];
      if (def.activeIn(r.week) && !def.activeIn(r.week - 1)) {
        events.add(PlatformLaunched(c));
      }
    }
    return events;
  }
}

/// Player state before a week, to detect what changed.
class _Snapshot {
  _Snapshot(World w, Artist p)
      : week = w.week,
        money = p.moneyCents,
        eraOpen = p.eraOpen,
        label = p.label,
        burnoutUntil = p.burnoutUntilWeek {
    void take(Charted e, EntityKind kind, int id) {
      for (var c = 0; c < Charts.count; c++) {
        final st = e.statsOrNull(c);
        if (st != null) chart[(kind, id, c)] = (st.lastPos, st.peak);
      }
    }

    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.status == SongStatus.active) take(s, EntityKind.song, id);
    }
    for (final id in w.activeAlbumIds) {
      final al = w.albums[id];
      if (al.artistId == p.id) take(al, EntityKind.album, id);
    }
  }

  final int week;
  final int money;
  final bool eraOpen;
  final Label label;
  final int burnoutUntil;

  /// (kind, id, chart) → (last position, peak) before the week.
  final Map<(EntityKind, int, int), (int, int)> chart = {};
}
