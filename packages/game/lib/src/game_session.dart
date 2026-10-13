import 'dart:math' as math;

import 'package:persistence/persistence.dart';
import 'package:simulation_core/simulation_core.dart';

import 'career_setup.dart';
import 'events.dart';
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
        seed: seed, startYear: setup.startYear, difficulty: setup.difficulty);
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
    return GameSession._(slots, slotId, store, store.load());
  }

  /// Saves search tables and closes the save file. Call when the app goes to
  /// the background or the player leaves the career.
  void close() {
    if (_closed) return;
    _store.flushActive(world);
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
    return ArtistPageView(
      artist: ArtistView.of(w, a),
      weeklyStreams: weekly.values.fold(0.0, (x, y) => x + y),
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

  /// Releases a vault song as a single, or pushes an album track as a single.
  void releaseSingle(int songId, {Campaign campaign = Campaign.standard}) {
    final s = _checkSingle(songId);
    _requireMoney(_campaignCost(campaign));
    Actions.releaseSingle(world, _p, s, campaign: campaign);
    _saveNow();
  }

  /// What the player pays for [campaign] with their label, after checking
  /// the label can run it at all (docs K54).
  int _campaignCost(Campaign campaign) {
    if (campaign.index > _p.label.maxCampaign.index) {
      throw GameException('campaignLocked', 'The label cannot run this');
    }
    return Actions.campaignCostFor(_p, campaign);
  }

  // ------------------------------------------------------------- labels

  /// Every label, with its terms and whether it would sign the player.
  List<LabelView> get labels => [
        for (final l in Label.values)
          LabelView.of(world, _p, l, Actions.labelMissing(world, _p, l)),
      ];

  /// Signs with [label] (or goes independent with [Label.independent]).
  /// Not possible while albums are still owed to the current label.
  void signLabel(Label label) {
    if (label == _p.label) {
      throw GameException('sameLabel', 'Already with this label');
    }
    if (_p.contractAlbumsLeft > 0) {
      throw GameException('underContract', 'Albums still owed to the label');
    }
    if (Actions.labelMissing(world, _p, label).isNotEmpty) {
      throw GameException('labelRefused', 'The label turned you down');
    }
    Actions.signLabel(world, _p, label);
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
      required int releaseWeek,
      required int announceWeek}) {
    final s = _checkSingle(songId);
    _checkDates(releaseWeek, announceWeek);
    _requireMoney(_campaignCost(campaign));
    return _schedule(ScheduledRelease(
      id: _nextScheduleId(),
      type: AlbumType.single,
      songIds: [s.id],
      releaseWeek: releaseWeek,
      announceWeek: announceWeek,
      createdWeek: world.week,
      campaign: campaign,
      paidCents: _campaignCost(campaign),
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

  /// Moves a scheduled release. Once announced, the announcement stays;
  /// pushing an announced release back costs part of its buzz.
  void reschedule(int id, {required int releaseWeek, int? announceWeek}) {
    final sr = _scheduledById(id);
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
    final (lo, hi) = type == AlbumType.ep
        ? (minEpTracks, maxEpTracks)
        : (minAlbumTracks, maxAlbumTracks);
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
    _store.commitWeek(world, r);
    slots.writeSummary(slotId, world);
    return WeekReport(
      week: r.week,
      events: _events(r, before),
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
    if (before.eraOpen && !p.eraOpen && p.lastEraResult != null) {
      events.add(EraClosed(p.lastEraResult!, p.lastEraUnits, p.eraExpected));
      if (before.label != Label.independent && p.label == Label.independent) {
        events.add(LabelDropped(before.label));
      } else if (p.contractAlbumsLeft == 0 &&
          p.lastEraResult!.index >= EraResult.normal.index) {
        // A good era: the biggest label that would sign the player calls.
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
