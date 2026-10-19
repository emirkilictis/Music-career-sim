/// In-memory hot world model. These are mutable simulation-internal objects;
/// IDs are list indices in [World] so lookups are O(1) and iteration order is
/// deterministic.
library;

import 'dart:typed_data';

import 'config/charts.dart';
import 'config/regions.dart';
import 'opportunities.dart';
import 'tours.dart';

enum ArtistTier { player, a, b }

/// Solo artist, band, or vocal group (boy band / girl group);
/// docs/game-design.md §2.4, K87. Kinds differ in strengths, never in
/// penalties: a solo star's singles travel (viral, reach), a band lives on
/// albums and the road over a long career, a vocal group's fandom collects,
/// fills arenas and grows fast.
enum ArtistKind {
  solo(
    qualityWeights: (writing: 0.45, production: 0.30, vocals: 0.25, perf: 0.0),
    statWeights: [0.40, 1 / 3, 0.40 / 3, 0.20 / 3, 0.20 / 3],
    devotionGain: 1.0,
    devotionDrift: 1.0,
    fanDecay: 1.0,
    viral: 1.35,
    singleReach: 1.12,
  ),

  /// Plays its own instruments: production and stage performance matter more,
  /// fans play whole albums, the road pays, and the fanbase is loyal over
  /// long careers.
  band(
    qualityWeights: (writing: 0.40, production: 0.30, vocals: 0.15, perf: 0.15),
    statWeights: [0.35, 0.15, 0.25, 0.20, 0.05],
    devotionGain: 1.0,
    devotionDrift: 1.0,
    fanDecay: 0.8,
    albumAffinity: 1.3,
    collector: 1.15,
    tourDemand: 1.35,
    merch: 1.2,
  ),

  /// Boy band / girl group: vocals, choreography and charisma; builds a
  /// devoted, collecting fandom quickly that buys every edition and the
  /// merch.
  vocalGroup(
    qualityWeights: (writing: 0.35, production: 0.25, vocals: 0.30, perf: 0.10),
    statWeights: [0.25, 0.35, 0.10, 0.20, 0.10],
    devotionGain: 1.4,
    devotionDrift: 0.5,
    fanDecay: 1.0,
    albumAffinity: 1.1,
    collector: 1.8,
    fanConversion: 1.25,
    tourDemand: 1.15,
    merch: 1.5,
  );

  const ArtistKind({
    required this.qualityWeights,
    required this.statWeights,
    required this.devotionGain,
    required this.devotionDrift,
    required this.fanDecay,
    this.viral = 1,
    this.singleReach = 1,
    this.albumAffinity = 1,
    this.collector = 1,
    this.fanConversion = 1,
    this.tourDemand = 1,
    this.merch = 1,
  });

  /// Chance a song catches a viral trend.
  final double viral;

  /// New listeners a single reaches.
  final double singleReach;

  /// Fans playing and buying the album (deep cuts, superfan copies).
  final double albumAffinity;

  /// Collector copies of extra editions.
  final double collector;

  /// Listeners turned into core fans.
  final double fanConversion;

  /// Tickets wanted on tour.
  final double tourDemand;

  /// Merch bought per ticket.
  final double merch;

  /// How skills combine into song quality (sums to 1).
  final ({
    double writing,
    double production,
    double vocals,
    double perf
  }) qualityWeights;

  /// "Auto distribute" split of starting points: songwriting, vocals,
  /// production, performance, charisma.
  final List<double> statWeights;

  /// Multiplier on devotion gained from successful eras.
  final double devotionGain;

  /// Multiplier on the slow weekly devotion drift.
  final double devotionDrift;

  /// Multiplier on core-fan decay.
  final double fanDecay;

  bool get isGroup => this != solo;
  static const minMembers = 2;
  static const maxMembers = 7;
}

/// [scrapped]: an unreleased song the player threw away (never released,
/// hidden everywhere; kept so ids stay stable).
enum SongStatus { vault, active, dormant, scrapped }

/// Release types. A mixtape is free (docs K62): streams only, no sales,
/// no album chart, no era.
enum AlbumType { single, ep, album, mixtape }

enum AlbumStatus { active, dormant }

enum CollaboratorRole { producer, songwriter }

enum BudgetTier { low, medium, high }

/// Promotion campaign for a release (docs/game-design.md §9). [standard] is
/// the calibrated baseline (what AI labels do); the strength shifts from
/// radio to streaming playlists over the years ([SimConfig.playlistShare]).
enum Campaign {
  none(costCents: 0, strength: -0.4, playlistOdds: 0.05),
  standard(costCents: 200000, strength: 0, playlistOdds: 0.25),
  intensive(costCents: 6000000, strength: 0.35, playlistOdds: 0.45),
  global(costCents: 25000000, strength: 0.7, playlistOdds: 0.65);

  const Campaign({
    required this.costCents,
    required this.strength,
    required this.playlistOdds,
  });

  /// Base price for an artist of up to ~1.5M listeners; bigger audiences
  /// cost more to reach (docs K57).
  final int costCents;

  /// Effect relative to [standard] (0); negative = less than a label's usual.
  final double strength;

  /// Base chance (before era, quality, single/album track) of a playlist add.
  final double playlistOdds;
}

/// Radio promotion for a single, bought apart from the campaign (docs
/// K84). Without it a star's single gets about half the radio: their
/// airplay comes from the label's promotion machine. A newcomer's few
/// spins are local and earned, so skipping the push costs them little.
enum RadioPush {
  none(costCents: 0, factor: 0.5),
  standard(costCents: 15000000, factor: 1.0),
  heavy(costCents: 60000000, factor: 1.6);

  const RadioPush({required this.costCents, required this.factor});

  /// Price for an artist of ~1.5M listeners; it scales with the audience
  /// (see Actions.radioPushCostFor).
  final int costCents;

  /// Multiplier on a star's single's radio play.
  final double factor;

  /// The multiplier for an artist this famous: no push costs a newcomer
  /// ×0.85, anyone from 50% fame ×0.5.
  double factorFor(double fame) =>
      this == none ? 0.85 - 0.7 * fame.clamp(0.0, 0.5) : factor;
}

/// Extra versions of a released song (docs K92, F26). Streaming services
/// and the charts count them with the song; each brings a wave of
/// listening. Index order is stored in saves: only append.
enum SongVersion {
  remix(1500000),
  spedUp(100000),
  slowed(100000),
  acapella(50000),
  instrumental(50000);

  const SongVersion(this.costCents);
  final int costCents;

  /// Extra exposure it brings the song in [year] (fading week by week).
  /// Sped-up and slowed versions are a short-video thing.
  double boost(int year) => switch (this) {
        remix => 0.35,
        spedUp => year >= 2021
            ? 0.45
            : year >= 2018
                ? 0.15
                : 0.03,
        slowed => year >= 2021
            ? 0.35
            : year >= 2018
                ? 0.12
                : 0.03,
        acapella || instrumental => 0.05,
      };

  /// Can set off a short-video trend.
  bool get trendy => this == spedUp || this == slowed;
}

/// Bought streams for a song (docs K95): how many, and what they cost.
/// Index order is stored in saves: only append.
enum BotPackage {
  small(1000000, 250000),
  medium(5000000, 1100000),
  large(20000000, 4000000);

  const BotPackage(this.streams, this.costCents);
  final double streams;
  final int costCents;

  /// Share of the streams that arrives in each of the next weeks.
  static const schedule = [0.4, 0.3, 0.2, 0.1];
}

/// Where a song's bought streams stand. Index order is stored in saves.
enum BotStatus { none, running, caught }

/// Physical editions of a single (docs K92, F26): collectors buy them in
/// the week they come out, and they count on the charts. Index order is
/// stored in saves: only append.
enum SingleFormat {
  cd(1000000),
  vinyl(1500000),
  cassette(500000),
  signed(2000000);

  const SingleFormat(this.costCents);
  final int costCents;

  /// Collector demand in [year] (1 = a CD single in the CD era).
  double appeal(int year) => switch (this) {
        cd => year < 2008
            ? 1.0
            : year < 2019
                ? 0.35
                : 0.8,
        vinyl => year < 2008
            ? 0.3
            : year < 2015
                ? 0.5
                : 1.0,
        cassette => year < 2003
            ? 0.8
            : year < 2018
                ? 0.1
                : 0.45,
        signed => 1.4,
      };
}

/// Editorial playlist pickup of a release.
enum PlaylistAdd { none, mid, big }

enum EraResult { flop, disappointing, normal, success, smash }

/// Per-chart stats of a song or album. Allocated only once an entity
/// charts, since most songs never do.
class ChartStats {
  int lastPos = 0;
  int peak = 0;
  int weeksOn = 0;
  int weeksAtNo1 = 0;
  int debutPos = 0;
}

/// Lazily allocated chart stats, indexed by chart id.
mixin Charted {
  List<ChartStats?>? charts;

  ChartStats stats(int chart) => ((charts ??=
      List<ChartStats?>.filled(Charts.count, null))[chart] ??= ChartStats());

  ChartStats? statsOrNull(int chart) => charts?[chart];

  int lastPosOn(int chart) => charts?[chart]?.lastPos ?? 0;
  int peakOn(int chart) => charts?[chart]?.peak ?? 0;
  int weeksOnChart(int chart) => charts?[chart]?.weeksOn ?? 0;
}

/// One of the five artist skills (for spending skill points).
enum SkillKind { songwriting, vocals, production, performance, charisma }

class Skills {
  Skills({
    required this.songwriting,
    required this.vocals,
    required this.production,
    required this.performance,
    required this.charisma,
  });

  double songwriting;
  double vocals;
  double production;
  double performance;
  double charisma;

  double operator [](SkillKind k) => switch (k) {
        SkillKind.songwriting => songwriting,
        SkillKind.vocals => vocals,
        SkillKind.production => production,
        SkillKind.performance => performance,
        SkillKind.charisma => charisma,
      };

  void operator []=(SkillKind k, double v) {
    switch (k) {
      case SkillKind.songwriting:
        songwriting = v;
      case SkillKind.vocals:
        vocals = v;
      case SkillKind.production:
        production = v;
      case SkillKind.performance:
        performance = v;
      case SkillKind.charisma:
        charisma = v;
    }
  }
}

class Artist {
  Artist({
    required this.id,
    required this.name,
    required this.tier,
    required this.genre,
    required this.debutWeek,
    required this.skills,
    required this.fame,
    required this.coreFans,
    required this.casual,
    this.homeCountry = HomeCountry.us,
    this.kind = ArtistKind.solo,
    List<String>? members,
    this.labelReach = 1.0,
    this.artistShare = 1.0,
    this.moneyCents = 0,
  })  : members = members ?? [],
        popularity = fame {
    updateRegionShare();
  }

  final int id;

  /// Not final: an AI rival sharing the player's name is renamed (K66).
  String name;
  ArtistTier tier;
  final int genre;
  final HomeCountry homeCountry;
  final ArtistKind kind;

  /// Member names for bands and vocal groups (empty for solo artists).
  /// Mutable for later lineup changes.
  final List<String> members;
  final int debutWeek;
  int retiredWeek = -1;
  final Skills skills;

  // Audience state.
  double fame;
  double popularity;
  double coreFans;
  double casual;
  double buzz = 0;

  /// How devoted the fanbase is (0..1). Grows with successful eras, drops
  /// after flops; drives superfan purchases and collector demand.
  double devotion = 0.2;

  /// Converted anticipation that boosts current releases; decays weekly.
  double hype = 0;

  // Era / anticipation (docs/game-design.md §5–§6).
  double anticipation = 0;
  double anticipationCap = 0;
  bool eraOpen = false;
  int eraAlbumId = -1;
  int eraStartWeek = -1;
  double eraUnits = 0;
  double eraExpected = 0;
  double lastEraUnits = 0;
  EraResult? lastEraResult;
  double flopSupport = 0;
  int lastReleaseWeek = -1;

  // Songwriting.
  double creativeEnergy = 100;
  int burnoutUntilWeek = -1;
  int lastWriteWeek = -1;
  int songsWrittenThisWeek = 0;

  /// Weekly rest chosen by the player: no writing that week, more energy.
  int restWeek = -1;

  /// Unspent skill points (the player earns one a week; docs K43).
  int skillPoints = 0;

  /// The player's record label and the albums still owed to it (docs K54).
  Label label = Label.independent;
  int contractAlbumsLeft = 0;

  /// The deal signed (docs K107): its advance and albums, and the part of
  /// the advance the artist's royalties have not paid back yet.
  int contractAdvanceCents = 0;
  int contractAlbums = 0;
  int unrecoupedCents = 0;

  /// No longer used: campaign fatigue (K57) was removed. Kept so saves keep
  /// their layout.
  double campaignFatigue = 0;

  /// An offer waiting for the player's answer (docs K59).
  Opportunity? opportunity;

  /// The player's tour on the road (docs K63).
  Tour? tour;

  /// The player's manager (docs K68).
  Manager manager = Manager.none;

  /// Career milestones reached: milestone id → week (docs K61).
  final Map<int, int> milestones = {};

  /// The player's releases set for a later week (docs K45).
  final List<ScheduledRelease> scheduled = [];

  // Side income (player only; docs/game-design.md §20.1, K36).
  Job job = Job.none;
  bool get hasJob => job != Job.none;
  int lastAdWeek = -1;
  int adsWatchedThisWeek = 0;

  // Business.
  double labelReach;
  double artistShare;
  int moneyCents;

  // Dormant catalog (lazy accrual, docs/simulation.md §5.3).
  double sumDormantRate = 0;
  final List<int> dormantSongIds = [];

  /// Where this artist's audience is (sums to 1). Derived from home region,
  /// genre and fame (famous artists are more international); recomputed
  /// weekly for active artists, frozen for retired ones.
  final Float64List regionShare = Float64List(regionCount);

  /// Per-region accounting, layout [ArtistReg]. Catalog indices and their
  /// settle markers drive lazy accrual (retired artists settle lazily, so a
  /// long history of retired artists costs nothing per week).
  final Float64List reg = Float64List(ArtistReg.length);

  void updateRegionShare() {
    final home = homeCountry.region.index;
    final breadth = (0.15 + 0.6 * fame).clamp(0.0, 0.8);
    final aff = genreRegionAffinity[genre];
    var sum = 0.0;
    for (final r in Region.values) {
      final i = r.index;
      final base = (i == home ? 1 - breadth : 0.0) +
          breadth * regionConfigs[r]!.globalReach;
      regionShare[i] = base * aff[i];
      sum += regionShare[i];
    }
    for (var i = 0; i < regionCount; i++) {
      regionShare[i] /= sum;
    }
  }

  // AI planning.
  int nextEraWeek = -1;
  final List<PlannedRelease> plan = [];
  final List<int> pendingAlbumSongIds = [];
  String pendingAlbumTitle = '';
  AlbumType pendingAlbumType = AlbumType.album;
  List<int> pendingVariantWeeks = const [0];

  // Chart achievements, per chart id.
  final Int32List no1Singles = Int32List(Charts.count);
  final Int32List no1SinglesFeatured = Int32List(Charts.count);
  final Int32List no1Albums = Int32List(Charts.count);
  final Int32List weeksAtNo1 = Int32List(Charts.count);

  /// Settled lifetime totals (for retired artists, see
  /// World.artistLifetimeStreams for the lazily accrued part).
  double get lifetimeStreams => _sum(ArtistReg.lifeStreams);
  double get lifetimeDownloads => _sum(ArtistReg.lifeDownloads);
  double get lifetimeAlbumPure => _sum(ArtistReg.lifePure);
  double get lifetimeAlbumUnits => _sum(ArtistReg.lifeUnits);

  double _sum(int at) => reg[at] + reg[at + 1] + reg[at + 2];

  // Weekly scratch.
  double weekPoints = 0;
  double weekReach = 0;
  double weekStreams = 0;

  bool get isRetired => retiredWeek >= 0;

  /// Superfan purchase multiplier from devotion. Convex: only the most
  /// devoted fanbases produce mega debuts.
  double get devotionBuyFactor =>
      0.5 + 0.2 * devotion + 2.3 * devotion * devotion * devotion;

  /// Collector multiplier from devotion (also convex).
  double get devotionCollectorFactor => 0.15 + 0.85 * devotion * devotion;

  /// Catalog popularity factor applied to dormant songs.
  double get catalogFactor => 0.3 + 0.7 * popularity;
}

class PlannedRelease {
  PlannedRelease({required this.week, required this.kind, this.songId = -1});

  final int week;
  final PlannedKind kind;
  final int songId;
}

enum PlannedKind { leadSingle, single, album }

class Song with Charted {
  Song({
    required this.id,
    required this.title,
    required this.genre,
    required this.primaryArtistId,
    required this.writtenWeek,
    required this.quality,
    required this.commercial,
    required this.fanAppeal,
    required this.radioAppeal,
    required this.virality,
    required this.longevity,
    required this.estimatedGrade,
    List<int>? featuredArtistIds,
    List<int>? extraGenres,
  })  : featuredArtistIds = featuredArtistIds ?? [],
        extraGenres = extraGenres ?? [];

  final int id;
  final String title;

  /// Primary genre; [extraGenres] are further genres (crossover songs).
  final int genre;
  final List<int> extraGenres;
  List<int> get genres => [genre, ...extraGenres];
  final int primaryArtistId;
  final List<int> featuredArtistIds;
  final int writtenWeek;

  // Hidden traits (0..1 except quality 0..100).
  final double quality;
  final double commercial;
  final double fanAppeal;
  final double radioAppeal;
  final double virality;
  final double longevity;
  final int estimatedGrade;

  /// How unsure the team is: the estimate is shown as [estimatedGrade] ±
  /// this (docs F36). Better producers judge more surely.
  int gradeSpread = 6;

  SongStatus status = SongStatus.vault;
  int releasedWeek = -1;
  int albumId = -1;
  bool isSingle = false;
  int singleWeek = -1;

  // Weekly state (global totals; regional splits live in world scratch).
  double lastAttention = 0;
  double lastReach = 0;
  double weekStreams = 0;
  double weekDownloads = 0;
  double weekPhysical = 0;
  double weekRadio = 0;

  /// US song chart points from radio and in all this week (not saved;
  /// for chart breakdowns and probes).
  double weekRadioPtsUs = 0;
  double weekPtsUs = 0;

  /// Global chart points this week.
  double weekPoints = 0;
  double viralBoost = 0;

  /// Weeks a viral trend keeps growing before it starts to fade.
  int viralRamp = 0;

  /// Promotion campaign it was released (or pushed as a single) with.
  Campaign campaign = Campaign.standard;

  /// Radio promotion bought for it as a single (docs K84).
  RadioPush radioPush = RadioPush.standard;

  /// Versions out, and physical editions of the single, with their weeks
  /// (docs K92, F26).
  final List<(SongVersion, int)> versions = [];
  final List<(SingleFormat, int)> variants = [];

  /// Extra exposure from new versions; fades week by week.
  double versionBoost = 0;

  /// Bought streams (docs K95): the package bought, weeks left,
  /// streams delivered so far and [BotStatus]; while [chartFilterUntil]
  /// is ahead the charts count the song at half weight.
  double botTotal = 0;
  int botWeeksLeft = 0;
  double botDelivered = 0;
  BotStatus botStatus = BotStatus.none;
  int chartFilterUntil = -1;

  /// In the streaming apps' autoplay programme (docs K96): more listening
  /// from the algorithm for a smaller royalty.
  bool autoplay = false;

  /// Week the player pitched it to the playlist editors (docs K97), -1.
  int pitchWeek = -1;

  /// Editorial playlist pickup: extra exposure that fades week by week.
  PlaylistAdd playlistAdd = PlaylistAdd.none;
  int playlistWeek = -1;
  double playlistBoost = 0;
  int weeksBelowCutoff = 0;

  double lifetimeRadio = 0;

  /// Physical (CD) singles sold, all regions.
  double lifetimePhysical = 0;

  /// Music video (docs K52): its budget (-1 = none) and strength (0..~0.6),
  /// fixed when it is shot.
  int videoBudget = -1;
  double videoPower = 0;

  /// No longer used (campaign fatigue was removed); kept for saves.
  double campaignPower = 1;

  /// What the player paid for the song's own campaign, and the income it
  /// brought in (estimated; docs K57).
  int campaignCostCents = 0;
  double campaignReturnCents = 0;

  /// The player's income from this song so far (their share), and what
  /// writing and recording it cost (docs K60).
  double revenueCents = 0;
  int productionCostCents = 0;

  /// Scratch: share of this week's attention (and reach) owed to the
  /// campaign.
  double campaignShareOfAttention = 0;
  double campaignShareOfReach = 0;

  /// This week's streams and downloads per region ([streams ×3,
  /// downloads ×3]); only kept while the song is active.
  Float64List? weekRegion;

  // Dormant accrual.
  double dormantRate = 0;

  /// Per-region lifetime (settled part) and dormant settle indices, layout
  /// [SongReg]. One array per song keeps memory low for 100k+ songs.
  final Float64List reg = Float64List(SongReg.length);

  double get lifetimeStreams =>
      reg[SongReg.lifeStreams] +
      reg[SongReg.lifeStreams + 1] +
      reg[SongReg.lifeStreams + 2];
  double get lifetimeDownloads =>
      reg[SongReg.lifeDownloads] +
      reg[SongReg.lifeDownloads + 1] +
      reg[SongReg.lifeDownloads + 2];

  double get riseWeeks => 0.6 + 7.0 * (1.0 - virality) * longevity;
  double get lifeWeeks => 5.0 + 32.0 * longevity;
}

class Album with Charted {
  Album({
    required this.id,
    required this.title,
    required this.artistId,
    required this.type,
    required this.releaseWeek,
    required this.songIds,
    required this.quality,
  });

  final int id;
  final String title;
  final int artistId;
  final AlbumType type;
  final int releaseWeek;
  final List<int> songIds;
  final double quality;

  AlbumStatus status = AlbumStatus.active;
  double hypeAtRelease = 0;
  Campaign campaign = Campaign.standard;

  /// Release offsets (weeks after release) of each edition/variant, sorted.
  /// Index 0 is the standard edition. Staggering variants keeps an album on
  /// top for several weeks (docs/game-design.md §8.5).
  List<int> variantWeeks = const [0];

  /// [EditionFormat] index of each edition, parallel to [variantWeeks]
  /// (docs K46). Empty or shorter (AI albums, older saves): a classic
  /// edition that sells as before.
  List<int> variantFormats = const [];

  /// The player's schedule it came out of (docs K45), or -1.
  int scheduleId = -1;

  /// Pitchwork's review score (1.0–10.0) given at release (docs K55).
  double criticScore = -1;

  /// Album units from singles out before the album (docs K56): part of the
  /// lifetime total, never of a week's sales or the chart.
  double preSingleUnits = 0;

  /// What the player paid for the album campaign and the income it brought
  /// in through the album's own tracks and sales (estimated; docs K57).
  int campaignCostCents = 0;
  double campaignReturnCents = 0;

  /// The player's income from the album's own sales (their share; its
  /// tracks keep their own; docs K60).
  double revenueCents = 0;

  /// Scratch: share of this week's sales owed to the campaign.
  double campaignShareOfSales = 0;

  /// How well edition [k] sells to collectors in [year].
  double editionAppeal(int k, int year) {
    final f = k < variantFormats.length ? variantFormats[k] : -1;
    return f < 0 ? 1.0 : EditionFormat.values[f].appeal(year);
  }

  // Weekly (global totals).
  double weekPure = 0;
  double weekTea = 0;
  double weekSea = 0;
  double weekUnits = 0;
  int weeksBelowCutoff = 0;

  /// This week's pure sales and units per region: [pure ×3, units ×3].
  final Float64List weekRegion = Float64List(2 * regionCount);

  double firstWeekUnits = 0;
  double firstWeekPure = 0;

  // Dormant song share of this album (lazy SEA while album is dormant).
  double sumDormantRate = 0;

  /// Per-region lifetime, settle indices and first week, layout [AlbumReg].
  final Float64List reg = Float64List(AlbumReg.length);

  double get lifetimePure =>
      reg[AlbumReg.lifePure] +
      reg[AlbumReg.lifePure + 1] +
      reg[AlbumReg.lifePure + 2];
  double get lifetimeUnits =>
      reg[AlbumReg.lifeUnits] +
      reg[AlbumReg.lifeUnits + 1] +
      reg[AlbumReg.lifeUnits + 2];

  bool get chartsOnAlbumChart =>
      type == AlbumType.album || type == AlbumType.ep;

  bool get isMixtape => type == AlbumType.mixtape;
}

/// Whether [s] came out as a single before [al] (docs K56): its album units
/// count towards the album's lifetime total, not its weekly sales.
bool isPreSingle(Song s, Album al) =>
    s.isSingle && s.singleWeek >= 0 && s.singleWeek < al.releaseWeek;

/// Day jobs (docs K36): steady pay that costs some creative energy every
/// week. Some teach a little on the side. Index order is stored in saves
/// (index 1 is the original $350 day job): only append.
enum Job {
  none(0, 0),
  cafe(35000, 3),
  musicTeacher(45000, 5),
  studioAssistant(50000, 6),
  barGigs(60000, 8),
  nightShift(80000, 12);

  const Job(this.wageCents, this.energyCost);
  final int wageCents;

  /// Creative energy lost each week.
  final double energyCost;
}

class Collaborator {
  Collaborator({
    required this.id,
    required this.name,
    required this.role,
    required this.skill,
    required this.genre,
    required this.feeCents,
    required this.minFame,
  });

  final int id;
  final String name;
  final CollaboratorRole role;
  final double skill;
  final int genre;
  final int feeCents;
  final double minFame;
}

class ChartEntry {
  ChartEntry({
    required this.position,
    required this.entityId,
    required this.points,
    required this.lastPos,
    required this.peak,
    required this.weeksOn,
  });

  final int position;
  final int entityId;
  final double points;
  final int lastPos;
  final int peak;
  final int weeksOn;

  bool get isDebut => lastPos == 0 && weeksOn == 1;
}

const List<String> genreNames = [
  'Pop',
  'Hip-Hop',
  'R&B',
  'Rock',
  'Country',
  'Dance/Electronic',
  'Latin',
  'Indie/Alternative',
  'Metal',
  'Punk',
  'Soul',
  'Funk',
  'Disco',
  'Jazz',
  'Blues',
  'Folk',
  'Reggae',
  'Afrobeats',
  'K-Pop',
  'Gospel',
  'Classical',
];

/// Relative share of AI artists per genre (index-aligned with [genreNames]).
const List<double> genreAiWeights = [
  22, // Pop
  18, // Hip-Hop
  9, // R&B
  10, // Rock
  8, // Country
  7, // Dance/Electronic
  7, // Latin
  6, // Indie/Alternative
  2, // Metal
  1, // Punk
  1, // Soul
  1, // Funk
  0.5, // Disco
  1, // Jazz
  0.5, // Blues
  2, // Folk
  1, // Reggae
  2, // Afrobeats
  2, // K-Pop
  1, // Gospel
  0.5, // Classical
];

/// A song has a primary genre and up to this many genres in total.
const maxSongGenres = 3;

/// Offsets into [Artist.reg] (each block has one value per [Region]).
abstract final class ArtistReg {
  static const indexStreams = 0;
  static const indexDownloads = 3;
  static const settleSpa = 6;
  static const settleDpa = 9;
  static const lifeStreams = 12;
  static const lifeDownloads = 15;
  static const lifePure = 18;
  static const lifeUnits = 21;
  static const length = 24;
}

/// Offsets into [Song.reg].
abstract final class SongReg {
  static const lifeStreams = 0;
  static const lifeDownloads = 3;
  static const indexStreams = 6;
  static const indexDownloads = 9;
  static const length = 12;
}

/// Offsets into [Album.reg].
abstract final class AlbumReg {
  static const lifePure = 0;
  static const lifeUnits = 3;
  static const indexStreams = 6;
  static const firstWeekUnits = 9;
  static const firstWeekPure = 12;
  static const length = 15;
}

/// A player single or album set for a later week, announced at
/// [announceWeek] (docs K45). From the announcement until the release,
/// [buzz] builds and is added to the artist's hype when it comes out.
class ScheduledRelease {
  ScheduledRelease({
    required this.id,
    required this.type,
    required this.songIds,
    required this.releaseWeek,
    required this.announceWeek,
    required this.createdWeek,
    this.title = '',
    this.variantWeeks = const [0],
    this.variantFormats = const [],
    this.campaign = Campaign.standard,
    this.radioPush = RadioPush.none,
    this.paidCents = 0,
    this.buzz = 0,
  });

  final int id;

  /// [AlbumType.single] for a single (one song in [songIds]).
  final AlbumType type;
  final List<int> songIds;
  final String title;
  final List<int> variantWeeks;

  /// [EditionFormat] index per edition (-1 = standard / classic).
  final List<int> variantFormats;
  final Campaign campaign;

  /// Radio push for a single (docs K84).
  final RadioPush radioPush;
  int releaseWeek;

  /// Equal to [releaseWeek]: a surprise release with no announcement.
  int announceWeek;
  final int createdWeek;

  /// Campaign and edition costs paid when it was scheduled.
  final int paidCents;
  double buzz;

  bool get isAlbum => type != AlbumType.single;
  bool get isSurprise => announceWeek >= releaseWeek;
  bool announcedBy(int week) => !isSurprise && week >= announceWeek;

  /// An album kept in the vault with no date yet (docs F31): it never comes
  /// out by itself and nothing has been paid for it.
  bool get isDraft => releaseWeek >= draftWeek;

  /// [releaseWeek] (and [announceWeek]) of a draft.
  static const draftWeek = 1 << 30;
}

/// A scheduled release that came out: the single's song id or the album id.
typedef ScheduledOut = ({int scheduleId, bool isAlbum, int id});

/// What an extra album edition is (docs K46). Collectors want different
/// things in different eras: CDs before streaming, vinyl in its revival,
/// cassettes as a niche. The standard edition (index 0) is digital + CD.
enum EditionFormat {
  cd(4000000),
  vinyl(6000000),
  cassette(2000000),
  deluxe(1500000),
  signed(8000000);

  const EditionFormat(this.costCents);

  /// Manufacturing and setup cost for the player.
  final int costCents;

  /// Collector demand relative to a classic edition (1.0) in [year].
  double appeal(int year) => switch (this) {
        cd => year < 2008
            ? 1.0
            : year < 2015
                ? 0.85
                : 0.75,
        vinyl => year < 2008
            ? 0.4
            : year < 2015
                ? 0.8
                : 1.3,
        cassette => year < 2004
            ? 0.6
            : year < 2018
                ? 0.25
                : 0.55,
        deluxe => year < 2005 ? 0.35 : 0.8,
        signed => 1.4,
      };
}

/// Managers (docs K68): they book more and better offers and get better
/// tour terms, for a cut of everything the player earns.
enum Manager {
  none(commission: 0, minFans: 0, offerBoost: 1, feeBoost: 1, tourCut: 0),
  local(
      commission: 0.10,
      minFans: 0,
      offerBoost: 1.3,
      feeBoost: 1.2,
      tourCut: 0.03),
  pro(
      commission: 0.15,
      minFans: 1e5,
      offerBoost: 1.7,
      feeBoost: 1.5,
      tourCut: 0.06),
  star(
      commission: 0.20,
      minFans: 1e6,
      offerBoost: 2.2,
      feeBoost: 2.0,
      tourCut: 0.10);

  const Manager({
    required this.commission,
    required this.minFans,
    required this.offerBoost,
    required this.feeBoost,
    required this.tourCut,
  });

  /// Share of the player's income the manager keeps.
  final double commission;

  /// Core fans a manager wants before taking the player on.
  final double minFans;

  /// More offers (interviews, duets, festivals, brand deals) ...
  final double offerBoost;

  /// ... paying more ...
  final double feeBoost;

  /// ... and a bigger share of the ticket money on tour.
  final double tourCut;

  /// What the player keeps of [cents] earned.
  double net(double cents) => cents * (1 - commission);
}

/// Music video budgets (docs K52).
enum VideoBudget {
  low(2000000, 0.12),
  medium(15000000, 0.28),
  high(100000000, 0.45);

  const VideoBudget(this.costCents, this.basePower);
  final int costCents;

  /// Exposure lift before the director's craft and the era.
  final double basePower;
}

/// Record labels the player can sign with (docs K54). Rivals keep their
/// own implicit labels ([Artist.labelReach]). Bigger labels reach more
/// people, run bigger campaigns and pay more of them, but take more of
/// the money and only sign artists who have proved themselves.
enum Label {
  independent(
      // 0.7 until docs K70: too little to ever chart without a label.
      reach: 0.85,
      artistShare: 1.0,
      maxCampaign: Campaign.standard,
      campaignShare: 1.0,
      advanceCents: 0,
      contractAlbums: 0,
      minFans: 0,
      minFame: 0,
      minResult: null),
  small(
      reach: 1.0,
      artistShare: 0.6,
      maxCampaign: Campaign.standard,
      campaignShare: 0.8,
      advanceCents: 2500000,
      contractAlbums: 2,
      minFans: 0,
      minFame: 0,
      minResult: null),
  mid(
      reach: 1.15,
      artistShare: 0.5,
      maxCampaign: Campaign.intensive,
      campaignShare: 0.6,
      advanceCents: 25000000,
      contractAlbums: 3,
      minFans: 150000,
      minFame: 0,
      minResult: EraResult.disappointing),
  major(
      reach: 1.3,
      artistShare: 0.4,
      maxCampaign: Campaign.global,
      campaignShare: 0.5,
      advanceCents: 200000000,
      contractAlbums: 3,
      minFans: 500000,
      minFame: 0.3,
      minResult: EraResult.normal),
  giant(
      reach: 1.4,
      artistShare: 0.35,
      maxCampaign: Campaign.global,
      campaignShare: 0.4,
      advanceCents: 1000000000,
      contractAlbums: 4,
      minFans: 2000000,
      minFame: 0.6,
      minResult: EraResult.success);

  const Label({
    required this.reach,
    required this.artistShare,
    required this.maxCampaign,
    required this.campaignShare,
    required this.advanceCents,
    required this.contractAlbums,
    required this.minFans,
    required this.minFame,
    required this.minResult,
  });

  /// Promotion and radio reach (multiplies exposure).
  final double reach;

  /// The artist's share of the money from sales and streams.
  final double artistShare;

  /// The biggest campaign the label can run.
  final Campaign maxCampaign;

  /// Share of a campaign's cost the artist pays (the label pays the rest).
  final double campaignShare;

  /// Paid to the artist on signing.
  final int advanceCents;

  /// Albums the artist owes before being free to leave (0 = none).
  final int contractAlbums;

  /// To be signed: core fans, fame and the last era's result at least.
  final double minFans;
  final double minFame;
  final EraResult? minResult;

  /// Labels that drop an artist after a flop.
  bool get dropsAfterFlop => index >= Label.mid.index;
}
