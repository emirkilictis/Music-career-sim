/// In-memory hot world model. These are mutable simulation-internal objects;
/// IDs are list indices in [World] so lookups are O(1) and iteration order is
/// deterministic.
library;

enum ArtistTier { player, a, b }

enum SongStatus { vault, active, dormant }

enum AlbumType { single, ep, album }

enum AlbumStatus { active, dormant }

enum CollaboratorRole { producer, songwriter }

enum BudgetTier { low, medium, high }

enum EraResult { flop, disappointing, normal, success, smash }

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
    this.labelReach = 1.0,
    this.artistShare = 1.0,
    this.moneyCents = 0,
  }) : popularity = fame;

  final int id;
  final String name;
  ArtistTier tier;
  final int genre;
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

  // Business.
  double labelReach;
  double artistShare;
  int moneyCents;

  // Dormant catalog (lazy accrual, docs/simulation.md §5.3).
  double sumDormantRate = 0;
  double catalogIndexStreams = 0;
  double catalogIndexDownloads = 0;

  /// World cumulative indices at the last catalog settlement. Active artists
  /// settle every week; retired artists (whose popularity is frozen) settle
  /// lazily, so a long history of retired artists costs nothing per week.
  double catalogSettleSpa = 0;
  double catalogSettleDpa = 0;
  final List<int> dormantSongIds = [];

  // AI planning.
  int nextEraWeek = -1;
  final List<PlannedRelease> plan = [];
  final List<int> pendingAlbumSongIds = [];
  String pendingAlbumTitle = '';
  AlbumType pendingAlbumType = AlbumType.album;
  List<int> pendingVariantWeeks = const [0];

  // Totals (incremental).
  double lifetimeStreams = 0;
  double lifetimeDownloads = 0;
  double lifetimeAlbumPure = 0;
  double lifetimeAlbumUnits = 0;
  int no1Singles = 0;
  int no1SinglesFeatured = 0;
  int no1Albums = 0;
  int weeksAtNo1 = 0;

  // Weekly scratch.
  double weekPoints = 0;
  double weekReach = 0;
  double weekStreams = 0;

  bool get isRetired => retiredWeek >= 0;

  /// Superfan purchase multiplier from devotion. Convex: only the most
  /// devoted fanbases produce mega debuts.
  double get devotionBuyFactor =>
      0.7 + 0.3 * devotion + 2.0 * devotion * devotion * devotion;

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

class Song {
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
  }) : featuredArtistIds = featuredArtistIds ?? [];

  final int id;
  final String title;
  final int genre;
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

  SongStatus status = SongStatus.vault;
  int releasedWeek = -1;
  int albumId = -1;
  bool isSingle = false;
  int singleWeek = -1;

  // Weekly state.
  double lastAttention = 0;
  double lastReach = 0;
  double weekStreams = 0;
  double weekDownloads = 0;
  double weekPhysical = 0;
  double weekRadio = 0;
  double weekPoints = 0;
  double viralBoost = 0;
  int weeksBelowCutoff = 0;

  // Chart stats (US Songs).
  int lastPos = 0;
  int peakPos = 0;
  int weeksOn = 0;
  int weeksAtNo1 = 0;

  // Lifetime (settled part for dormant songs).
  double lifetimeStreams = 0;
  double lifetimeDownloads = 0;
  double lifetimeRadio = 0;

  // Dormant accrual.
  double dormantRate = 0;
  double indexAtSettleStreams = 0;
  double indexAtSettleDownloads = 0;

  double get riseWeeks => 0.6 + 7.0 * (1.0 - virality) * longevity;
  double get lifeWeeks => 5.0 + 32.0 * longevity;
}

class Album {
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

  /// Release offsets (weeks after release) of each edition/variant, sorted.
  /// Index 0 is the standard edition. Staggering variants keeps an album on
  /// top for several weeks (docs/game-design.md §8.5).
  List<int> variantWeeks = const [0];

  // Weekly.
  double weekPure = 0;
  double weekTea = 0;
  double weekSea = 0;
  double weekUnits = 0;
  int weeksBelowCutoff = 0;

  // Chart stats (US Albums).
  int lastPos = 0;
  int peakPos = 0;
  int weeksOn = 0;
  int weeksAtNo1 = 0;
  double firstWeekUnits = 0;
  double firstWeekPure = 0;
  int debutPos = 0;

  // Lifetime.
  double lifetimePure = 0;
  double lifetimeUnits = 0;

  // Dormant song share of this album (lazy SEA while album is dormant).
  double sumDormantRate = 0;
  double indexAtSettle = 0;

  bool get chartsOnAlbumChart => type != AlbumType.single;
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
  'Dance',
  'Latin',
  'Indie',
];
