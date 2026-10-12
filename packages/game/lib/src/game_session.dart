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

/// Result of a year skip: the year-summary screen (docs/game-design.md §1.1).
class YearReport {
  YearReport({
    required this.fromWeek,
    required this.weeks,
    required this.stoppedEarly,
    required this.events,
    required this.streamsGained,
    required this.pureGained,
    required this.unitsGained,
    required this.moneyDeltaCents,
    required this.coreFansDelta,
    required this.fameBefore,
    required this.fameAfter,
  });

  final int fromWeek;
  final int weeks;

  /// True when a major event stopped the skip before 52 weeks.
  final bool stoppedEarly;
  final List<GameEvent> events;
  final double streamsGained;
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
            CollaboratorView(c, available: c.minFame <= _p.fame),
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
      throw GameException('weeklyLimit', 'Weekly songwriting limit reached');
    }
    final producer = _collaborator(producerId, CollaboratorRole.producer);
    final cowriter = _collaborator(cowriterId, CollaboratorRole.songwriter);
    for (final c in [producer, cowriter]) {
      if (c != null && c.minFame > p.fame) {
        throw GameException('collaboratorRefused', '${c.name} needs more fame');
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
    final s = _ownSong(songId);
    if (s.isSingle) throw GameException('alreadySingle', 'Already a single');
    _requireMoney(campaign.costCents);
    Actions.releaseSingle(world, _p, s, campaign: campaign);
    _saveNow();
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
    Campaign campaign = Campaign.standard,
  }) {
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
      if (_ownSong(id).albumId >= 0) {
        throw GameException('trackOnOtherRelease', 'Song $id is taken');
      }
    }
    if (variantWeeks.isEmpty ||
        variantWeeks.length > maxVariants ||
        variantWeeks.any((x) => x < 0 || x > maxVariantWeek) ||
        !variantWeeks.contains(0)) {
      throw GameException('invalidVariants', 'Variants must include week 0');
    }
    _requireMoney(campaign.costCents +
        Actions.variantCostCents * (variantWeeks.length - 1));
    final al = Actions.releaseAlbum(world, _p, t, songIds,
        type: type,
        variantWeeks: variantWeeks,
        payForVariants: true,
        campaign: campaign);
    _saveNow();
    return AlbumView.of(world, al);
  }

  /// Takes or quits the day job (it only pays; §20.1).
  void setJob(bool on) {
    Actions.setJob(world, _p, on);
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
  }) {
    final p = _p;
    final from = world.week;
    final streams0 = world.artistLifetimeStreams(p);
    final pure0 = _sum(p, ArtistReg.lifePure);
    final units0 = _sum(p, ArtistReg.lifeUnits);
    final money0 = p.moneyCents, fans0 = p.coreFans, fame0 = p.fame;
    final events = <GameEvent>[];
    var weeks = 0;
    var stopped = false;
    while (weeks < GameTime.weeksPerYear) {
      final r = advanceWeek();
      weeks++;
      events.addAll(r.events);
      onWeek?.call(r);
      if ((stopOnMajor && r.hasMajor) || (cancel?.call() ?? false)) {
        stopped = weeks < GameTime.weeksPerYear;
        break;
      }
    }
    return YearReport(
      fromWeek: from,
      weeks: weeks,
      stoppedEarly: stopped,
      events: events,
      streamsGained: world.artistLifetimeStreams(p) - streams0,
      pureGained: _sum(p, ArtistReg.lifePure) - pure0,
      unitsGained: _sum(p, ArtistReg.lifeUnits) - units0,
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
          events.add(NumberOne(c, kind, id, st.weeksAtNo1));
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

    for (final id in r.viralSongs) {
      if (w.songs[id].primaryArtistId == p.id) events.add(ViralTrend(id));
    }
    for (final id in r.playlistAdds) {
      final s = w.songs[id];
      if (s.primaryArtistId == p.id)
        events.add(PlaylistAdded(id, s.playlistAdd));
    }
    if (before.eraOpen && !p.eraOpen && p.lastEraResult != null) {
      events.add(EraClosed(p.lastEraResult!, p.lastEraUnits, p.eraExpected));
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
    return events;
  }
}

/// Player state before a week, to detect what changed.
class _Snapshot {
  _Snapshot(World w, Artist p)
      : week = w.week,
        money = p.moneyCents,
        eraOpen = p.eraOpen,
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
  final int burnoutUntil;

  /// (kind, id, chart) → (last position, peak) before the week.
  final Map<(EntityKind, int, int), (int, int)> chart = {};
}
