import 'package:simulation_core/simulation_core.dart';

import 'events.dart';

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
        lifetimeUnits =
            _regional((r) => a.reg[ArtistReg.lifeUnits + r].toDouble()),
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
        lastEraResult = a.lastEraResult,
        comebackSupport = a.flopSupport,
        creativeEnergy = a.creativeEnergy,
        burnoutWeeksLeft =
            a.burnoutUntilWeek > w.week ? a.burnoutUntilWeek - w.week : 0,
        songsLeftThisWeek = Actions.canWrite(w, a)
            ? Actions.maxSongsPerWeek -
                (a.lastWriteWeek == w.week ? a.songsWrittenThisWeek : 0)
            : 0,
        adsLeftThisWeek = Actions.adsLeftThisWeek(w, a),
        job = a.job,
        lastReleaseWeek = a.lastReleaseWeek,
        everCharted = a.tier == ArtistTier.player &&
            (w.playerSongIds.any((id) => _charted(w.songs[id])) ||
                w.albums.any((al) => al.artistId == a.id && _charted(al))),
        vaultCount = a.tier == ArtistTier.player
            ? w.playerSongIds
                .where((id) => w.songs[id].status == SongStatus.vault)
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
  final EraResult? lastEraResult;

  /// Comeback support after a flop (0..1), docs/game-design.md §6.
  final double comebackSupport;
  final double creativeEnergy;
  final int burnoutWeeksLeft;
  final int songsLeftThisWeek;
  final int adsLeftThisWeek;
  final Job job;
  bool get hasJob => job != Job.none;

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
        estimatedGrade = s.estimatedGrade,
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
        lifetimeRadio = s.lifetimeRadio;

  factory SongView.of(World w, Song s) => SongView._(w, s);

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

  /// The team's estimate of the song's quality (1–100), not the true value.
  final int estimatedGrade;
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
        campaign = al.campaign,
        charts = _records(al),
        firstWeekUsUnits = w.albumFirstWeekIn(al, ChartMarket.us),
        firstWeekUsPure = w.albumFirstWeekIn(al, ChartMarket.us, pure: true),
        firstWeekUkUnits = w.albumFirstWeekIn(al, ChartMarket.uk),
        firstWeekUnits = al.firstWeekUnits,
        firstWeekPure = al.firstWeekPure,
        weekUnits = al.status == AlbumStatus.active ? al.weekUnits : 0,
        weekPure = al.status == AlbumStatus.active ? al.weekPure : 0,
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
  final Campaign campaign;
  final List<ChartRecord> charts;
  final double firstWeekUsUnits;
  final double firstWeekUsPure;
  final double firstWeekUkUnits;
  final double firstWeekUnits;
  final double firstWeekPure;
  final double weekUnits;
  final double weekPure;
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
            e.entityId),
    ];
    return ChartView._(def, w.week - 1, rows);
  }

  static ChartRow _row(World w, ChartMarket market, EntityKind kind,
      int position, int lastPos, int peak, int weeksOn, int id) {
    final title =
        kind == EntityKind.song ? w.songs[id].title : w.albums[id].title;
    final artistId = kind == EntityKind.song
        ? w.songs[id].primaryArtistId
        : w.albums[id].artistId;
    return ChartRow(
      albumId: kind == EntityKind.song ? w.songs[id].albumId : id,
      weekValue: kind == EntityKind.song
          ? w.songWeekStreamsIn(w.songs[id], market)
          : albumWeekUnitsIn(w, w.albums[id], market),
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
    required this.popular,
    required this.albums,
    required this.singles,
  });

  final ArtistView artist;

  /// All platforms; use [Streamify] for the platform's numbers.
  final double weeklyStreams;

  /// Most played songs right now (up to 10).
  final List<SongView> popular;

  /// Albums and EPs, newest first.
  final List<AlbumView> albums;

  /// Singles not on an album, newest first.
  final List<SongView> singles;

  double get monthlyListeners => Streamify.monthlyListeners(weeklyStreams);
}

/// Which number best tells a song's success in a given year (docs K38):
/// CD singles and radio in the early 2000s, then downloads, then streams.
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
