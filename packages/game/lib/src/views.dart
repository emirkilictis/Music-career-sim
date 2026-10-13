import 'dart:math' as math;

import 'package:simulation_core/simulation_core.dart';

import 'events.dart';
import 'milestones.dart';

/// Read-only screen data built from the world on demand. Views never expose
/// hidden values (a song's true quality stays hidden; the team's estimate is
/// shown instead).

/// Numbers per region (North America, Europe, Other) plus their total.
class RegionalNumbers {
  RegionalNumbers(this.byRegion) : total = byRegion.fold(0.0, (a, x) => a + x);
  final List<double> byRegion;
  final double total;
  double operator [](Region r) => byRegion[r.index];
}

/// Chart record of a song or album on one chart.
class ChartRecord {
  ChartRecord(this.chartId, ChartStats s)
      : lastPos = s.lastPos,
        peak = s.peak,
        weeksOn = s.weeksOn,
        weeksAtNo1 = s.weeksAtNo1,
        debutPos = s.debutPos;
  final int chartId;
  final int lastPos;
  final int peak;
  final int weeksOn;
  final int weeksAtNo1;
  final int debutPos;
}

List<ChartRecord> _records(Charted e) => [
      for (var c = 0; c < Charts.count; c++)
        if (e.statsOrNull(c) case final s? when s.weeksOn > 0)
          ChartRecord(c, s),
    ];

RegionalNumbers _regional(double Function(int r) f) =>
    RegionalNumbers([for (var r = 0; r < regionCount; r++) f(r)]);

class ArtistView {
  ArtistView._(World w, Artist a)
      : id = a.id,
        name = a.name,
        kind = a.kind,
        members = List.unmodifiable(a.members),
        genre = a.genre,
        home = a.homeCountry,
        isPlayer = a.tier == ArtistTier.player,
        fame = a.fame,
        popularity = a.popularity,
        coreFans = a.coreFans,
        casualListeners = a.casual,
        devotion = a.devotion,
        hype = a.hype,
        anticipation = a.anticipation,
        moneyCents = a.moneyCents,
        lifetimeStreams = _regional((r) => w.artistLifetimeStreams(a, r)),
        lifetimePure =
            _regional((r) => a.reg[ArtistReg.lifePure + r].toDouble()),
        lifetimeUnits = _regional((r) => w.artistLifetimeUnits(a, r)),
        lifetimeSingleSales = a.tier == ArtistTier.player
            ? w.playerSongIds.fold(
                0.0,
                (t, id) =>
                    t +
                    w.songLifetimeDownloads(w.songs[id]) +
                    w.songs[id].lifetimePhysical)
            : a.lifetimeDownloads,
        lifetimeRadio = a.tier == ArtistTier.player
            ? w.playerSongIds
                .fold(0.0, (t, id) => t + w.songs[id].lifetimeRadio)
            : 0,
        numberOneSingles = List.unmodifiable(a.no1Singles),
        numberOneAlbums = List.unmodifiable(a.no1Albums),
        eraOpen = a.eraOpen,
        eraAlbumId = a.eraOpen ? a.eraAlbumId : -1,
        eraAlbumSinglesLeft = a.eraOpen && a.eraAlbumId >= 0
            ? w.albums[a.eraAlbumId].songIds
                .where((id) =>
                    !w.songs[id].isSingle &&
                    !a.scheduled.any((sr) => sr.songIds.contains(id)))
                .length
            : 0,
        lastEraResult = a.lastEraResult,
        comebackSupport = a.flopSupport,
        creativeEnergy = a.creativeEnergy,
        burnoutWeeksLeft =
            a.burnoutUntilWeek > w.week ? a.burnoutUntilWeek - w.week : 0,
        canWrite = Actions.canWrite(w, a),
        songsWrittenThisWeek =
            a.lastWriteWeek == w.week ? a.songsWrittenThisWeek : 0,
        creativityPenalty = Actions.creativityPenalty(a.creativeEnergy),
        adsLeftThisWeek = Actions.adsLeftThisWeek(w, a),
        job = a.job,
        skillPoints = a.skillPoints,
        label = a.label,
        contractAlbumsLeft = a.contractAlbumsLeft,
        campaignCosts = [
          for (final k in Campaign.values) Actions.campaignCostFor(a, k)
        ],
        opportunity = a.opportunity == null
            ? null
            : OpportunityView.of(w, a.opportunity!),
        tour = a.tour == null ? null : TourView.of(w, a.tour!),
        manager = a.manager,
        skills = {for (final k in SkillKind.values) k: a.skills[k]},
        lastReleaseWeek = a.lastReleaseWeek,
        everCharted = a.tier == ArtistTier.player &&
            (w.playerSongIds.any((id) => _charted(w.songs[id])) ||
                w.albums.any((al) => al.artistId == a.id && _charted(al))),
        vaultCount = a.tier == ArtistTier.player
            ? w.playerSongIds
                .where((id) =>
                    w.songs[id].status == SongStatus.vault &&
                    !a.scheduled.any((sr) => sr.songIds.contains(id)))
                .length
            : 0,
        restingThisWeek = a.restWeek == w.week,
        energyNextWeek = Actions.weeklyEnergy(w, a),
        isRetired = a.isRetired;

  factory ArtistView.of(World w, Artist a) => ArtistView._(w, a);

  final int id;
  final String name;
  final ArtistKind kind;
  final List<String> members;
  final int genre;
  final HomeCountry home;
  final bool isPlayer;
  final double fame;
  final double popularity;
  final double coreFans;
  final double casualListeners;
  final double devotion;
  final double hype;
  final double anticipation;
  final int moneyCents;
  final RegionalNumbers lifetimeStreams;
  final RegionalNumbers lifetimePure;
  final RegionalNumbers lifetimeUnits;

  /// Downloads + CD singles (CD singles counted for the player only).
  final double lifetimeSingleSales;

  /// Radio audience of the player's songs (0 for rivals).
  final double lifetimeRadio;

  /// #1 counts per chart id.
  final List<int> numberOneSingles;
  final List<int> numberOneAlbums;
  final bool eraOpen;

  /// The album of the open era, and how many of its tracks could still be
  /// singles (not singles yet, not scheduled).
  final int eraAlbumId;
  final int eraAlbumSinglesLeft;
  final EraResult? lastEraResult;

  /// Comeback support after a flop (0..1), docs/game-design.md §6.
  final double comebackSupport;
  final double creativeEnergy;
  final int burnoutWeeksLeft;

  /// Not burnt out and not resting: no weekly limit (docs K46).
  final bool canWrite;
  final int songsWrittenThisWeek;

  /// Share of quality the next song loses to low creativity (0 = full
  /// strength, 0.5 at creativity 0).
  final double creativityPenalty;
  final int adsLeftThisWeek;
  final Job job;
  bool get hasJob => job != Job.none;

  /// The player's record label and albums still owed to it (docs K54).
  final Label label;
  final int contractAlbumsLeft;

  /// What each campaign costs the artist now (by [Campaign.index]): the
  /// price grows with the audience, the label pays part (docs K57).
  final List<int> campaignCosts;

  /// An offer waiting for the player's answer (docs K59).
  final OpportunityView? opportunity;

  /// The tour on the road (docs K63).
  final TourView? tour;

  /// The player's manager (docs K68).
  final Manager manager;

  /// Unspent skill points and the current skills (0–100).
  final int skillPoints;
  final Map<SkillKind, double> skills;

  /// Week of the last single or album (-1 = never released anything).
  final int lastReleaseWeek;

  /// The player's unreleased songs.
  final int vaultCount;

  /// Any of the player's releases has been on a chart.
  final bool everCharted;

  /// The player took this week off.
  final bool restingThisWeek;

  /// Energy change at the end of this week if nothing else changes.
  final double energyNextWeek;
  final bool isRetired;
}

/// The album whose cover a song shows when it has none of its own: its
/// album's, unless it came out as a single before that album (a lead
/// single keeps its own look), else -1.
int coverAlbumOf(World w, Song s) {
  if (s.albumId < 0) return -1;
  if (s.isSingle && s.singleWeek < w.albums[s.albumId].releaseWeek) return -1;
  return s.albumId;
}

class SongView {
  SongView._(World w, Song s)
      : id = s.id,
        title = s.title,
        artistId = s.primaryArtistId,
        artistName = w.artists[s.primaryArtistId].name,
        featuredArtistIds = List.unmodifiable(s.featuredArtistIds),
        genres = s.genres,
        status = s.status,
        isSingle = s.isSingle,
        writtenWeek = s.writtenWeek,
        releasedWeek = s.releasedWeek,
        singleWeek = s.singleWeek,
        albumId = s.albumId,
        coverAlbumId = coverAlbumOf(w, s),
        estimatedGrade = s.estimatedGrade,
        gradeLow = math.max(1, s.estimatedGrade - s.gradeSpread),
        gradeHigh = math.min(100, s.estimatedGrade + s.gradeSpread),
        grade = s.status == SongStatus.vault ? -1 : s.quality.round(),
        campaign = s.campaign,
        playlistAdd = s.playlistAdd,
        charts = _records(s),
        weekStreamsUs =
            s.releasedWeek < 0 ? 0 : w.songWeekStreamsIn(s, ChartMarket.us),
        weekStreams =
            s.releasedWeek < 0 ? 0 : w.songWeekStreamsIn(s, ChartMarket.global),
        lifetimeStreams = _regional((r) => w.songLifetimeStreams(s, r)),
        lifetimeDownloads = w.songLifetimeDownloads(s),
        lifetimePhysical = s.lifetimePhysical,
        lifetimeRadio = s.lifetimeRadio,
        isPlayer = s.primaryArtistId == w.playerArtistId,
        video = s.videoBudget < 0 ? null : VideoBudget.values[s.videoBudget],
        campaignCostCents = s.campaignCostCents,
        campaignReturnCents = s.campaignReturnCents.round(),
        revenueCents = s.revenueCents.round(),
        costsCents = _songCosts(s),
        featuredNames = [
          for (final id in s.featuredArtistIds) w.artists[id].name
        ],
        usSingleUnits = _usSingleUnits(w, s),
        scheduledSingleWeek = _scheduledWeek(w, s, album: false),
        scheduledAlbumWeek = _scheduledWeek(w, s, album: true);

  factory SongView.of(World w, Song s) => SongView._(w, s);

  static int _scheduledWeek(World w, Song s, {required bool album}) {
    for (final sr in w.artists[s.primaryArtistId].scheduled) {
      if (sr.isAlbum == album && sr.songIds.contains(s.id)) {
        return sr.releaseWeek;
      }
    }
    return -1;
  }

  final bool isPlayer;

  /// The song's music video budget, if it has one (docs K52).
  final VideoBudget? video;

  /// The song's campaign, what the player paid and the income it brought
  /// in (estimated; docs K57). Album tracks share the album's campaign
  /// (see [AlbumView]).
  final int campaignCostCents;
  final int campaignReturnCents;

  /// The player's income from the song and what it cost them: writing,
  /// its own campaign, its video (docs K60).
  final int revenueCents;
  final int costsCents;

  /// Featured artists' names, in credit order.
  final List<String> featuredNames;

  /// Single units in the US, for certifications (docs K60).
  final double usSingleUnits;

  /// Week a scheduled single / album with this song comes out, or -1
  /// (docs K45).
  final int scheduledSingleWeek;
  final int scheduledAlbumWeek;

  final int id;
  final String title;
  final int artistId;
  final String artistName;
  final List<int> featuredArtistIds;
  final List<int> genres;
  final SongStatus status;
  final bool isSingle;
  final int writtenWeek;
  final int releasedWeek;
  final int singleWeek;
  final int albumId;

  /// Album whose cover this song shows (see [coverAlbumOf]).
  final int coverAlbumId;

  /// The team's estimate of the song's quality (1–100), not the true value.
  final int estimatedGrade;

  /// The range the team is fairly sure of (docs F36): what the player sees
  /// before the song comes out.
  final int gradeLow;
  final int gradeHigh;

  /// The song's real grade once it is out (-1 while in the vault).
  final int grade;
  final Campaign campaign;
  final PlaylistAdd playlistAdd;
  final List<ChartRecord> charts;
  final double weekStreamsUs;
  final double weekStreams;
  final RegionalNumbers lifetimeStreams;
  final double lifetimeDownloads;

  /// CD singles sold.
  final double lifetimePhysical;

  /// Radio audience (listener impressions).
  final double lifetimeRadio;

  /// Single sales: downloads + CD singles.
  double get singleSales => lifetimeDownloads + lifetimePhysical;

  /// Single units as certifications count them: sales + streams / 150.
  double get singleUnits =>
      singleSales + lifetimeStreams.total / streamsPerSingleUnit;

  static const streamsPerSingleUnit = 150;

  bool get inVault => status == SongStatus.vault;
}

class AlbumView {
  AlbumView._(World w, Album al)
      : id = al.id,
        title = al.title,
        artistId = al.artistId,
        artistName = w.artists[al.artistId].name,
        type = al.type,
        releaseWeek = al.releaseWeek,
        trackIds = List.unmodifiable(al.songIds),
        variantWeeks = List.unmodifiable(al.variantWeeks),
        variantFormats = [
          for (var k = 0; k < al.variantWeeks.length; k++)
            k < al.variantFormats.length && al.variantFormats[k] >= 0
                ? EditionFormat.values[al.variantFormats[k]]
                : null,
        ],
        campaign = al.campaign,
        charts = _records(al),
        firstWeekUsUnits = w.albumFirstWeekIn(al, ChartMarket.us),
        firstWeekUsPure = w.albumFirstWeekIn(al, ChartMarket.us, pure: true),
        firstWeekUkUnits = w.albumFirstWeekIn(al, ChartMarket.uk),
        firstWeekUnits = al.firstWeekUnits,
        firstWeekPure = al.firstWeekPure,
        weekUnits = al.status == AlbumStatus.active ? al.weekUnits : 0,
        weekPure = al.status == AlbumStatus.active ? al.weekPure : 0,
        weekUsUnits = al.status == AlbumStatus.active
            ? albumWeekUnitsIn(w, al, ChartMarket.us)
            : 0,
        isPlayer = al.artistId == w.playerArtistId,
        scheduleId = al.scheduleId,
        criticScore = al.criticScore,
        preSingleUnits = al.preSingleUnits,
        campaignCostCents = al.campaignCostCents,
        campaignReturnCents = al.campaignReturnCents.round(),
        revenueCents = (al.revenueCents +
                al.songIds.fold(0.0, (x, id) => x + w.songs[id].revenueCents))
            .round(),
        costsCents = al.campaignCostCents +
            (al.artistId == w.playerArtistId
                ? Actions.editionsCostCents(
                    al.variantWeeks.length, al.variantFormats)
                : 0) +
            al.songIds.fold(0, (x, id) => x + _songCosts(w.songs[id])),
        usLifetimeUnits =
            CountryShares.usOfNorthAmerica(w.artists[al.artistId].homeCountry) *
                w.albumLifetimeUnits(al, Region.northAmerica.index),
        trackStreams = al.songIds
            .fold(0.0, (sum, id) => sum + w.songLifetimeStreams(w.songs[id])),
        lifetimePure =
            _regional((r) => al.reg[AlbumReg.lifePure + r].toDouble()),
        lifetimeUnits = _regional((r) => w.albumLifetimeUnits(al, r));

  factory AlbumView.of(World w, Album al) => AlbumView._(w, al);

  final int id;
  final String title;
  final int artistId;
  final String artistName;
  final AlbumType type;
  final int releaseWeek;
  final List<int> trackIds;
  final List<int> variantWeeks;

  /// Format of each edition (null = standard / classic), parallel to
  /// [variantWeeks].
  final List<EditionFormat?> variantFormats;
  final Campaign campaign;
  final List<ChartRecord> charts;
  final double firstWeekUsUnits;
  final double firstWeekUsPure;
  final double firstWeekUkUnits;
  final double firstWeekUnits;
  final double firstWeekPure;

  /// Last played week (0 once the album is in the catalog).
  final double weekUnits;
  final double weekPure;
  final double weekUsUnits;
  final bool isPlayer;

  /// The schedule it came out of, or -1.
  final int scheduleId;

  /// Pitchwork's review (1.0–10.0), or -1 for albums from before reviews.
  final double criticScore;

  /// Lifetime units from singles out before the album (part of
  /// [lifetimeUnits], never of a week's sales; docs K56).
  final double preSingleUnits;

  /// What the player paid for the album campaign and the income it brought
  /// in through the album's own tracks and sales (estimated; docs K57).
  final int campaignCostCents;
  final int campaignReturnCents;

  /// The player's income from the album and its tracks, and everything it
  /// cost them: songs, campaigns, videos, editions (docs K60).
  final int revenueCents;
  final int costsCents;
  int get profitCents => revenueCents - costsCents;

  /// Album units in the US, for certifications (docs K60).
  final double usLifetimeUnits;

  /// All streams of the album's tracks (singles included).
  final double trackStreams;
  final RegionalNumbers lifetimePure;
  final RegionalNumbers lifetimeUnits;
}

/// One line of a published chart.
class ChartRow {
  ChartRow({
    required this.albumId,
    required this.weekValue,
    required this.position,
    required this.lastPos,
    required this.peak,
    required this.weeksOn,
    required this.entityId,
    required this.title,
    required this.artistId,
    required this.artistName,
    required this.isPlayer,
  });
  final int position;

  /// Album the entry belongs to (for its cover); -1 for a loose single.
  final int albumId;

  /// This week's streams (song charts) or units (album charts) in the
  /// chart's market.
  final double weekValue;

  /// 0 = new or re-entry this week.
  final int lastPos;
  final int peak;
  final int weeksOn;
  final int entityId;
  final String title;
  final int artistId;
  final String artistName;
  final bool isPlayer;
  bool get isNew => lastPos == 0 && weeksOn == 1;
  bool get isReentry => lastPos == 0 && weeksOn > 1;
}

class ChartView {
  ChartView._(this.def, this.week, this.rows);

  /// The latest published chart (the week just simulated).
  factory ChartView.latest(World w, int chartId) {
    final def = Charts.all[chartId];
    final kind =
        def.kind == ChartKind.songs ? EntityKind.song : EntityKind.album;
    final rows = [
      for (final e in w.charts[chartId])
        _row(w, def.market, kind, e.position, e.lastPos, e.peak, e.weeksOn,
            e.entityId, e.points),
    ];
    return ChartView._(def, w.week - 1, rows);
  }

  static ChartRow _row(World w, ChartMarket market, EntityKind kind,
      int position, int lastPos, int peak, int weeksOn, int id, double points) {
    final title =
        kind == EntityKind.song ? w.songs[id].title : w.albums[id].title;
    final artistId = kind == EntityKind.song
        ? w.songs[id].primaryArtistId
        : w.albums[id].artistId;
    return ChartRow(
      albumId: kind == EntityKind.song ? coverAlbumOf(w, w.songs[id]) : id,
      weekValue: kind == EntityKind.song
          ? w.songWeekStreamsIn(w.songs[id], market)
          // What the album chart ranked: pure sales before 2015, units
          // after (docs K49).
          : points,
      position: position,
      lastPos: lastPos,
      peak: peak,
      weeksOn: weeksOn,
      entityId: id,
      title: title,
      artistId: artistId,
      artistName: w.artists[artistId].name,
      isPlayer: artistId == w.playerArtistId,
    );
  }

  final ChartDef def;
  final int week;
  final List<ChartRow> rows;
}

/// One collaborator the player can hire (fame permitting).
class CollaboratorView {
  CollaboratorView(Collaborator c,
      {required this.available, this.requiredFans = 0})
      : id = c.id,
        name = c.name,
        role = c.role,
        skill = c.skill,
        genre = c.genre,
        feeCents = c.feeCents;
  final int id;
  final String name;
  final CollaboratorRole role;
  final double skill;
  final int genre;
  final int feeCents;

  /// False when the collaborator still refuses the player (too few fans).
  final bool available;

  /// Core fans this collaborator wants (0 = works with anyone).
  final int requiredFans;
}

/// This week's units of an album in a chart market (US/UK are shares of
/// their region, like [World.albumFirstWeekIn]).
double albumWeekUnitsIn(World w, Album al, ChartMarket market) {
  if (al.status != AlbumStatus.active) return 0;
  final home = w.artists[al.artistId].homeCountry;
  double units(Region r) => al.weekRegion[regionCount + r.index];
  return switch (market) {
    ChartMarket.us =>
      CountryShares.usOfNorthAmerica(home) * units(Region.northAmerica),
    ChartMarket.uk => CountryShares.ukOfEurope(home) * units(Region.europe),
    _ => al.weekUnits,
  };
}

/// The fictional streaming platform's view of an artist (Streamify artist
/// page): its share of all streams, monthly listeners, popular tracks.
abstract final class Streamify {
  /// Share of all on-demand streams that happen on the platform.
  static const share = 0.45;

  /// Monthly listeners from weekly streams (about 12 plays per listener a
  /// month on the platform).
  static double monthlyListeners(double weeklyStreams) =>
      weeklyStreams * share * 4.3 / 12;
}

class ArtistPageView {
  ArtistPageView({
    required this.artist,
    required this.weeklyStreams,
    double? listenerStreams,
    required this.popular,
    required this.albums,
    required this.singles,
  }) : listenerStreams = listenerStreams ?? weeklyStreams;

  final ArtistView artist;

  /// All platforms; use [Streamify] for the platform's numbers.
  final double weeklyStreams;

  /// Most played songs right now (up to 10).
  final List<SongView> popular;

  /// Albums and EPs, newest first.
  final List<AlbumView> albums;

  /// Singles not on an album, newest first.
  final List<SongView> singles;

  /// Weekly streams averaged over the last month where known (the player);
  /// monthly listeners follow it rather than a single week.
  final double listenerStreams;

  double get monthlyListeners => Streamify.monthlyListeners(listenerStreams);
}

/// Which number best tells a song's success in a given year (docs K38):
/// CD singles and radio in the early 2000s, then downloads, then streams.
/// A player release set for a later week (docs K45).
class ScheduledView {
  ScheduledView.of(World w, ScheduledRelease sr)
      : id = sr.id,
        type = sr.type,
        title = sr.isAlbum ? sr.title : w.songs[sr.songIds.single].title,
        songIds = List.unmodifiable(sr.songIds),
        releaseWeek = sr.releaseWeek,
        announceWeek = sr.announceWeek,
        announced = sr.announcedBy(w.week),
        isSurprise = sr.isSurprise,
        isDraft = sr.isDraft,
        createdWeek = sr.createdWeek,
        editionsCostCents = Actions.editionsCostCents(
            sr.variantWeeks.length, sr.variantFormats),
        campaign = sr.campaign,
        paidCents = sr.paidCents,
        buzz = sr.buzz,
        buzzCap = w.config.announceBuzzCap(sr.type, w.player!.fame);

  final int id;
  final AlbumType type;

  /// The album title, or the single's song title.
  final String title;
  final List<int> songIds;
  final int releaseWeek;

  /// Equal to [releaseWeek] for a surprise release.
  final int announceWeek;
  final bool announced;
  final bool isSurprise;

  /// Kept in the vault with no date (docs F31); [releaseWeek] means nothing.
  final bool isDraft;

  /// When it was scheduled or saved as a draft.
  final int createdWeek;

  /// What its extra editions cost (paid when a draft is released or dated).
  final int editionsCostCents;
  final Campaign campaign;
  final int paidCents;

  /// Excitement built since the announcement, and its ceiling.
  final double buzz;
  final double buzzCap;
  bool get isAlbum => type != AlbumType.single;
}

/// A record label's terms for the player (docs K54).
class LabelView {
  LabelView.of(World w, Artist p, this.label, this.missing)
      : isCurrent = p.label == label,
        contractAlbumsLeft = p.contractAlbumsLeft,
        buyoutCents = Actions.buyoutCents(w, p),
        moneyCents = p.moneyCents,
        legend = w.difficulty == Difficulty.legend;

  final Label label;

  /// What the player still lacks for this label to sign them.
  final List<LabelRequirement> missing;
  final bool isCurrent;
  final int contractAlbumsLeft;

  /// What leaving the current label costs now (0: free to go; docs K78).
  final int buyoutCents;
  final int moneyCents;
  final bool legend;

  bool get wouldSign => missing.isEmpty;

  /// Money in hand after signing: the advance less the buyout.
  int get netCents => label.advanceCents - buyoutCents;
  bool get canAfford => moneyCents + netCents >= 0;
  bool get canSign => wouldSign && !isCurrent && canAfford;

  /// Requirements as they apply in this game mode.
  double get minFans => label.minFans * (legend ? 0.4 : 1.0);
  double get minFame => label.minFame * (legend ? 0.4 : 1.0);
  EraResult? get minResult => legend ? null : label.minResult;
}

enum SalesEra {
  /// 2000–2004: single sales (mostly CD) first, radio second.
  physical,

  /// 2005–2011: single sales (mostly downloads) first, streams second.
  downloads,

  /// 2012 on: streams first, single sales second.
  streaming;

  static SalesEra of(int year) => year < 2005
      ? physical
      : year < 2012
          ? downloads
          : streaming;
}

bool _charted(Charted e) {
  for (var c = 0; c < Charts.count; c++) {
    if ((e.statsOrNull(c)?.weeksOn ?? 0) > 0) return true;
  }
  return false;
}

/// An offer waiting for the player's answer (docs K59).
class OpportunityView {
  OpportunityView.of(World w, Opportunity o)
      : kind = o.kind,
        week = o.week,
        weeksLeft = o.week + Opportunities.answerWeeks + 1 - w.week,
        partnerArtistId = o.partnerArtistId,
        partnerName =
            o.partnerArtistId >= 0 ? w.artists[o.partnerArtistId].name : '',
        feeCents = o.feeCents,
        choices = o.choices;

  final OpportunityKind kind;
  final int week;

  /// Weeks still played before it lapses (1 = answer before next week).
  final int weeksLeft;
  final int partnerArtistId;
  final String partnerName;
  final int feeCents;
  final List<OpportunityChoice> choices;
}

/// What a song cost the player: writing it, its own campaign, its video.
int _songCosts(Song s) =>
    s.productionCostCents +
    s.campaignCostCents +
    (s.videoBudget >= 0 ? VideoBudget.values[s.videoBudget].costCents : 0);

/// A song's single units in the US (certifications; docs K60).
double usSingleUnits(World w, Song s) => _usSingleUnits(w, s);

/// An album's units in the US (certifications; docs K60).
double usAlbumUnits(World w, Album al) =>
    CountryShares.usOfNorthAmerica(w.artists[al.artistId].homeCountry) *
    w.albumLifetimeUnits(al, Region.northAmerica.index);

double _usSingleUnits(World w, Song s) {
  final a = w.primaryOf(s);
  final na = Region.northAmerica.index;
  return CountryShares.usOfNorthAmerica(a.homeCountry) *
      (w.songLifetimeDownloads(s, na) +
          s.lifetimePhysical * a.regionShare[na] +
          w.songLifetimeStreams(s, na) / SongView.streamsPerSingleUnit);
}

/// US certification levels, RIAA-style (docs K60): units sold in the US.
enum Certification {
  gold(5e5),
  platinum(1e6),
  diamond(1e7);

  const Certification(this.units);
  final double units;

  /// The level reached with [units] and how many times over (platinum
  /// counts multiples: 3× platinum), or null below gold.
  static (Certification, int)? of(double units) {
    if (units >= diamond.units) {
      return (diamond, (units / diamond.units).floor());
    }
    if (units >= platinum.units) {
      return (platinum, (units / platinum.units).floor());
    }
    if (units >= gold.units) return (gold, 1);
    return null;
  }
}

/// A career milestone and how far the player is (docs K61).
class MilestoneView {
  MilestoneView(
      {required this.milestone, required this.reachedWeek, this.progress});
  final Milestone milestone;

  /// Week it was reached, or null.
  final int? reachedWeek;

  /// (have, need) for count goals.
  final (double, double)? progress;

  bool get reached => reachedWeek != null;
}

/// A tour on the road (docs K63).
class TourView {
  TourView.of(World w, Tour t)
      : name = t.name,
        kind = t.kind,
        legs = List.unmodifiable(t.legs),
        production = t.production,
        priceFactor = t.priceFactor,
        openerName = t.openerId >= 0 ? w.artists[t.openerId].name : null,
        weeks = t.weeks,
        weekOfTour = (w.week - t.startWeek + 1).clamp(1, t.weeks),
        shows = [for (final s in t.shows) TourShowView.of(t, s)],
        thisWeek = [for (final s in t.showsIn(w.week)) TourShowView.of(t, s)],
        tickets = t.tickets,
        grossCents = t.grossCents.round(),
        merchCents = t.merchCents.round(),
        costCents = t.costCents.round(),
        netCents = t.netCents.round(),
        fans = t.fans,
        soldOut = t.soldOut;

  /// The player's name for it ('' = named after its biggest venues).
  final String name;

  /// The biggest venues on the tour.
  final TourKind kind;
  final List<TourLeg> legs;
  final TourProduction production;
  final double priceFactor;
  final String? openerName;
  final int weeks;

  /// The week of the tour about to be played (1-based).
  final int weekOfTour;

  /// Every night, played ones with their numbers.
  final List<TourShowView> shows;

  /// Nights this coming week.
  final List<TourShowView> thisWeek;
  final double tickets;
  final int grossCents;
  final int merchCents;
  final int costCents;
  final int netCents;
  final double fans;
  final int soldOut;

  int get played => shows.where((s) => s.played).length;
}

/// One night of a tour (docs K76): where, when, how big, and its tickets
/// (sold once played, else expected when planning).
class TourShowView {
  TourShowView({
    required this.weekOfTour,
    required this.market,
    required this.city,
    required this.venue,
    required this.kind,
    required this.capacity,
    required this.priceCents,
    required this.played,
    required this.tickets,
    required this.grossCents,
  });

  TourShowView.of(Tour t, TourShow s, [ShowResult? expected])
      : weekOfTour = s.week - t.startWeek + 1,
        market = s.market,
        city = s.cityName,
        venue = s.venue,
        kind = t.legs[s.leg].kind,
        capacity = s.capacity,
        priceCents = s.priceCents,
        played = s.played,
        tickets = s.played ? s.sold : (expected?.sold ?? 0),
        grossCents =
            (s.played ? s.grossCents : (expected?.grossCents ?? 0)).round();

  final int weekOfTour;
  final TourMarket market;
  final String city;
  final String venue;
  final TourKind kind;
  final int capacity;
  final int priceCents;
  final bool played;
  final double tickets;
  final int grossCents;

  bool get soldOut => tickets >= capacity * Tours.soldOutShare;
}

/// What the player asks for when planning a tour (docs K76).
class TourRequest {
  const TourRequest({
    required this.legs,
    this.name = '',
    this.priceFactor = 1.0,
    this.production = TourProduction.standard,
    this.openerId = -1,
  });
  final List<TourLeg> legs;
  final String name;
  final double priceFactor;
  final TourProduction production;
  final int openerId;
}

/// One leg as planned: its expected turnout.
class TourLegView {
  TourLegView(
      {required this.leg,
      required this.tickets,
      required this.fill,
      required this.grossCents,
      required this.maxShows,
      required this.priceCents});
  final TourLeg leg;
  final double tickets;
  final double fill;
  final int grossCents;

  /// Most shows this market can take at this size.
  final int maxShows;
  final int priceCents;
}

/// A rival who could open the tour, and their fee a night.
class OpenerView {
  OpenerView(
      {required this.artistId,
      required this.name,
      required this.genre,
      required this.fame,
      required this.coreFans,
      required this.feeCents});
  final int artistId;
  final String name;
  final int genre;
  final double fame;
  final double coreFans;
  final int feeCents;
}

/// A tour as planned now: what it would do, night by night, and what
/// stops it (docs K76).
class TourPlanView {
  TourPlanView({
    required this.request,
    required this.problems,
    required this.estimate,
    required this.netCents,
    required this.weeks,
    required this.legs,
    required this.schedule,
    required this.openerName,
    required this.openerFeeCents,
  });
  final TourRequest request;

  /// Why it cannot start: 'onTour', 'tourMarkets', 'tourTooBig',
  /// 'tourShows' (empty = ready).
  final List<String> problems;
  final TourWeek estimate;

  /// What the player would keep (their manager's cut taken; K68).
  final int netCents;
  final int weeks;
  final List<TourLegView> legs;
  final List<TourShowView> schedule;
  final String? openerName;
  final int openerFeeCents;

  bool get available => problems.isEmpty;
}

/// A big rival's album due soon (docs K69): release dates are known about
/// two months ahead, so the player can pick their week around it.
class UpcomingRelease {
  UpcomingRelease(
      {required this.artistId,
      required this.artistName,
      required this.title,
      required this.week,
      required this.fame});
  final int artistId;
  final String artistName;
  final String title;
  final int week;
  final double fame;
}

/// A festival's next edition as the player sees it (docs K77).
class FestivalView {
  FestivalView({
    required this.index,
    required this.festival,
    required this.year,
    required this.week,
    required this.slot,
    required this.booked,
    required this.feeCents,
    required this.watched,
    required this.fans,
    required this.fitsGenre,
  });
  final int index;
  final Festival festival;
  final int year;

  /// Its week in the game calendar.
  final int week;

  /// The slot the player would get now (null: too small).
  final FestivalSlot? slot;

  /// The slot already booked (null: not booked).
  final FestivalSlot? booked;

  /// Fee, people watching and fans won for the slot shown.
  final int feeCents;
  final double watched;
  final double fans;

  /// The festival books the player's genre.
  final bool fitsGenre;

  bool get canBook => booked == null && slot != null && fitsGenre;
}

/// One act on a festival bill.
class FestivalAct {
  FestivalAct(this.artistId, this.name, this.isPlayer);
  final int artistId;
  final String name;
  final bool isPlayer;
}

/// A line in the box-office rankings (docs K77).
class TourRankView {
  TourRankView({
    required this.rank,
    required this.artistId,
    required this.artistName,
    required this.tourName,
    required this.grossCents,
    required this.tickets,
    required this.shows,
    required this.isPlayer,
    required this.onGoing,
  });
  final int rank;
  final int artistId;
  final String artistName;

  /// '' when the player left it unnamed.
  final String tourName;
  final double grossCents;
  final double tickets;
  final int shows;
  final bool isPlayer;

  /// Still on the road: numbers so far.
  final bool onGoing;
}
