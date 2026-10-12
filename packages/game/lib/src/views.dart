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
        hasJob = a.hasJob,
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
  final bool hasJob;
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
  final double lifetimeRadio;

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
        _row(w, kind, e.position, e.lastPos, e.peak, e.weeksOn, e.entityId),
    ];
    return ChartView._(def, w.week - 1, rows);
  }

  static ChartRow _row(World w, EntityKind kind, int position, int lastPos,
      int peak, int weeksOn, int id) {
    final title =
        kind == EntityKind.song ? w.songs[id].title : w.albums[id].title;
    final artistId = kind == EntityKind.song
        ? w.songs[id].primaryArtistId
        : w.albums[id].artistId;
    return ChartRow(
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
  CollaboratorView(Collaborator c, {required this.available})
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

  /// False when the collaborator still refuses the player (not famous enough).
  final bool available;
}
