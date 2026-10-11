/// In-memory hot world model. These are mutable simulation-internal objects;
/// IDs are list indices in [World] so lookups are O(1) and iteration order is
/// deterministic.
library;

import 'dart:typed_data';

import 'config/charts.dart';
import 'config/regions.dart';

enum ArtistTier { player, a, b }

enum SongStatus { vault, active, dormant }

enum AlbumType { single, ep, album }

enum AlbumStatus { active, dormant }

enum CollaboratorRole { producer, songwriter }

enum BudgetTier { low, medium, high }

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
    this.homeCountry = HomeCountry.us,
    this.labelReach = 1.0,
    this.artistShare = 1.0,
    this.moneyCents = 0,
  }) : popularity = fame {
    updateRegionShare();
  }

  final int id;
  final String name;
  ArtistTier tier;
  final int genre;
  final HomeCountry homeCountry;
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

  // Weekly state (global totals; regional splits live in world scratch).
  double lastAttention = 0;
  double lastReach = 0;
  double weekStreams = 0;
  double weekDownloads = 0;
  double weekPhysical = 0;
  double weekRadio = 0;

  /// Global chart points this week.
  double weekPoints = 0;
  double viralBoost = 0;

  /// Weeks a viral trend keeps growing before it starts to fade.
  int viralRamp = 0;
  int weeksBelowCutoff = 0;

  double lifetimeRadio = 0;

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

  /// Release offsets (weeks after release) of each edition/variant, sorted.
  /// Index 0 is the standard edition. Staggering variants keeps an album on
  /// top for several weeks (docs/game-design.md §8.5).
  List<int> variantWeeks = const [0];

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
