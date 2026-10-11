import 'package:simulation_core/simulation_core.dart';

/// Row mapping between the hot world model and SQLite. Every field the
/// simulation reads across weeks must round-trip exactly (doubles are stored
/// as 64-bit REAL, so they do).
abstract final class Codec {
  // ---------------------------------------------------------------- artist
  static const artistColumns = [
    'id', 'name', 'tier', 'genre', 'debutWeek', 'retiredWeek', //
    'songwriting', 'vocals', 'production', 'performance', 'charisma',
    'fame', 'popularity', 'coreFans', 'casual', 'buzz', 'devotion',
    'hype', 'anticipation', 'anticipationCap',
    'eraOpen', 'eraAlbumId', 'eraStartWeek', 'eraUnits',
    'eraExpected', 'lastEraUnits', 'lastEraResult', 'flopSupport',
    'lastReleaseWeek',
    'creativeEnergy', 'burnoutUntilWeek', 'lastWriteWeek',
    'songsWrittenThisWeek',
    'labelReach', 'artistShare', 'moneyCents',
    'sumDormantRate', 'catalogIndexStreams', 'catalogIndexDownloads',
    'catalogSettleSpa', 'catalogSettleDpa',
    'nextEraWeek', 'plan', 'pendingSongs', 'pendingAlbumTitle',
    'pendingAlbumType', 'pendingVariants',
    'lifetimeStreams', 'lifetimeDownloads', 'lifetimeAlbumPure',
    'lifetimeAlbumUnits',
    'no1Singles', 'no1SinglesFeatured', 'no1Albums', 'weeksAtNo1',
  ];

  static List<Object?> artistRow(Artist a) => [
        a.id, a.name, a.tier.index, a.genre, a.debutWeek, a.retiredWeek, //
        a.skills.songwriting, a.skills.vocals, a.skills.production,
        a.skills.performance, a.skills.charisma,
        a.fame, a.popularity, a.coreFans, a.casual, a.buzz, a.devotion,
        a.hype, a.anticipation, a.anticipationCap,
        a.eraOpen ? 1 : 0, a.eraAlbumId, a.eraStartWeek, a.eraUnits,
        a.eraExpected, a.lastEraUnits, a.lastEraResult?.index ?? -1,
        a.flopSupport,
        a.lastReleaseWeek,
        a.creativeEnergy, a.burnoutUntilWeek, a.lastWriteWeek,
        a.songsWrittenThisWeek,
        a.labelReach, a.artistShare, a.moneyCents,
        a.sumDormantRate, a.catalogIndexStreams, a.catalogIndexDownloads,
        a.catalogSettleSpa, a.catalogSettleDpa,
        a.nextEraWeek, _encodePlan(a.plan), _ints(a.pendingAlbumSongIds),
        a.pendingAlbumTitle, a.pendingAlbumType.index,
        _ints(a.pendingVariantWeeks),
        a.lifetimeStreams, a.lifetimeDownloads, a.lifetimeAlbumPure,
        a.lifetimeAlbumUnits,
        a.no1Singles, a.no1SinglesFeatured, a.no1Albums, a.weeksAtNo1,
      ];

  static Artist artistFrom(Map<String, Object?> r) {
    final a = Artist(
      id: r['id'] as int,
      name: r['name'] as String,
      tier: ArtistTier.values[r['tier'] as int],
      genre: r['genre'] as int,
      debutWeek: r['debutWeek'] as int,
      skills: Skills(
        songwriting: _d(r['songwriting']),
        vocals: _d(r['vocals']),
        production: _d(r['production']),
        performance: _d(r['performance']),
        charisma: _d(r['charisma']),
      ),
      fame: _d(r['fame']),
      coreFans: _d(r['coreFans']),
      casual: _d(r['casual']),
      labelReach: _d(r['labelReach']),
      artistShare: _d(r['artistShare']),
      moneyCents: r['moneyCents'] as int,
    );
    final lastEra = r['lastEraResult'] as int;
    a
      ..retiredWeek = r['retiredWeek'] as int
      ..popularity = _d(r['popularity'])
      ..buzz = _d(r['buzz'])
      ..devotion = _d(r['devotion'])
      ..hype = _d(r['hype'])
      ..anticipation = _d(r['anticipation'])
      ..anticipationCap = _d(r['anticipationCap'])
      ..eraOpen = r['eraOpen'] == 1
      ..eraAlbumId = r['eraAlbumId'] as int
      ..eraStartWeek = r['eraStartWeek'] as int
      ..eraUnits = _d(r['eraUnits'])
      ..eraExpected = _d(r['eraExpected'])
      ..lastEraUnits = _d(r['lastEraUnits'])
      ..lastEraResult = lastEra < 0 ? null : EraResult.values[lastEra]
      ..flopSupport = _d(r['flopSupport'])
      ..lastReleaseWeek = r['lastReleaseWeek'] as int
      ..creativeEnergy = _d(r['creativeEnergy'])
      ..burnoutUntilWeek = r['burnoutUntilWeek'] as int
      ..lastWriteWeek = r['lastWriteWeek'] as int
      ..songsWrittenThisWeek = r['songsWrittenThisWeek'] as int
      ..sumDormantRate = _d(r['sumDormantRate'])
      ..catalogIndexStreams = _d(r['catalogIndexStreams'])
      ..catalogIndexDownloads = _d(r['catalogIndexDownloads'])
      ..catalogSettleSpa = _d(r['catalogSettleSpa'])
      ..catalogSettleDpa = _d(r['catalogSettleDpa'])
      ..nextEraWeek = r['nextEraWeek'] as int
      ..pendingAlbumTitle = r['pendingAlbumTitle'] as String
      ..pendingAlbumType = AlbumType.values[r['pendingAlbumType'] as int]
      ..pendingVariantWeeks = _parseInts(r['pendingVariants'] as String)
      ..lifetimeStreams = _d(r['lifetimeStreams'])
      ..lifetimeDownloads = _d(r['lifetimeDownloads'])
      ..lifetimeAlbumPure = _d(r['lifetimeAlbumPure'])
      ..lifetimeAlbumUnits = _d(r['lifetimeAlbumUnits'])
      ..no1Singles = r['no1Singles'] as int
      ..no1SinglesFeatured = r['no1SinglesFeatured'] as int
      ..no1Albums = r['no1Albums'] as int
      ..weeksAtNo1 = r['weeksAtNo1'] as int;
    a.plan.addAll(_decodePlan(r['plan'] as String));
    a.pendingAlbumSongIds.addAll(_parseInts(r['pendingSongs'] as String));
    return a;
  }

  // ------------------------------------------------------------------ song
  static const songColumns = [
    'id', 'title', 'genre', 'primaryArtistId', 'writtenWeek', //
    'quality', 'commercial', 'fanAppeal', 'radioAppeal',
    'virality', 'longevity', 'estimatedGrade',
    'status', 'releasedWeek', 'albumId', 'isSingle', 'singleWeek',
    'lastAttention', 'lastReach', 'weekStreams', 'weekDownloads',
    'weekPhysical', 'weekRadio', 'weekPoints', 'viralBoost',
    'weeksBelowCutoff',
    'lastPos', 'peakPos', 'weeksOn', 'weeksAtNo1',
    'lifetimeStreams', 'lifetimeDownloads', 'lifetimeRadio',
    'dormantRate', 'indexAtSettleStreams', 'indexAtSettleDownloads',
  ];

  static List<Object?> songRow(Song s) => [
        s.id, s.title, s.genre, s.primaryArtistId, s.writtenWeek, //
        s.quality, s.commercial, s.fanAppeal, s.radioAppeal,
        s.virality, s.longevity, s.estimatedGrade,
        s.status.index, s.releasedWeek, s.albumId, s.isSingle ? 1 : 0,
        s.singleWeek,
        s.lastAttention, s.lastReach, s.weekStreams, s.weekDownloads,
        s.weekPhysical, s.weekRadio, s.weekPoints, s.viralBoost,
        s.weeksBelowCutoff,
        s.lastPos, s.peakPos, s.weeksOn, s.weeksAtNo1,
        s.lifetimeStreams, s.lifetimeDownloads, s.lifetimeRadio,
        s.dormantRate, s.indexAtSettleStreams, s.indexAtSettleDownloads,
      ];

  static Song songFrom(Map<String, Object?> r, List<int> featured) {
    final s = Song(
      id: r['id'] as int,
      title: r['title'] as String,
      genre: r['genre'] as int,
      primaryArtistId: r['primaryArtistId'] as int,
      writtenWeek: r['writtenWeek'] as int,
      quality: _d(r['quality']),
      commercial: _d(r['commercial']),
      fanAppeal: _d(r['fanAppeal']),
      radioAppeal: _d(r['radioAppeal']),
      virality: _d(r['virality']),
      longevity: _d(r['longevity']),
      estimatedGrade: r['estimatedGrade'] as int,
      featuredArtistIds: featured,
    );
    return s
      ..status = SongStatus.values[r['status'] as int]
      ..releasedWeek = r['releasedWeek'] as int
      ..albumId = r['albumId'] as int
      ..isSingle = r['isSingle'] == 1
      ..singleWeek = r['singleWeek'] as int
      ..lastAttention = _d(r['lastAttention'])
      ..lastReach = _d(r['lastReach'])
      ..weekStreams = _d(r['weekStreams'])
      ..weekDownloads = _d(r['weekDownloads'])
      ..weekPhysical = _d(r['weekPhysical'])
      ..weekRadio = _d(r['weekRadio'])
      ..weekPoints = _d(r['weekPoints'])
      ..viralBoost = _d(r['viralBoost'])
      ..weeksBelowCutoff = r['weeksBelowCutoff'] as int
      ..lastPos = r['lastPos'] as int
      ..peakPos = r['peakPos'] as int
      ..weeksOn = r['weeksOn'] as int
      ..weeksAtNo1 = r['weeksAtNo1'] as int
      ..lifetimeStreams = _d(r['lifetimeStreams'])
      ..lifetimeDownloads = _d(r['lifetimeDownloads'])
      ..lifetimeRadio = _d(r['lifetimeRadio'])
      ..dormantRate = _d(r['dormantRate'])
      ..indexAtSettleStreams = _d(r['indexAtSettleStreams'])
      ..indexAtSettleDownloads = _d(r['indexAtSettleDownloads']);
  }

  // ----------------------------------------------------------------- album
  static const albumColumns = [
    'id', 'title', 'artistId', 'type', 'releaseWeek', 'quality', //
    'status', 'hypeAtRelease', 'variants',
    'weekPure', 'weekTea', 'weekSea', 'weekUnits', 'weeksBelowCutoff',
    'lastPos', 'peakPos', 'weeksOn', 'weeksAtNo1',
    'firstWeekUnits', 'firstWeekPure', 'debutPos',
    'lifetimePure', 'lifetimeUnits', 'sumDormantRate', 'indexAtSettle',
  ];

  static List<Object?> albumRow(Album al) => [
        al.id, al.title, al.artistId, al.type.index, al.releaseWeek, //
        al.quality,
        al.status.index, al.hypeAtRelease, _ints(al.variantWeeks),
        al.weekPure, al.weekTea, al.weekSea, al.weekUnits, al.weeksBelowCutoff,
        al.lastPos, al.peakPos, al.weeksOn, al.weeksAtNo1,
        al.firstWeekUnits, al.firstWeekPure, al.debutPos,
        al.lifetimePure, al.lifetimeUnits, al.sumDormantRate, al.indexAtSettle,
      ];

  static Album albumFrom(Map<String, Object?> r, List<int> songIds) {
    final al = Album(
      id: r['id'] as int,
      title: r['title'] as String,
      artistId: r['artistId'] as int,
      type: AlbumType.values[r['type'] as int],
      releaseWeek: r['releaseWeek'] as int,
      songIds: songIds,
      quality: _d(r['quality']),
    );
    return al
      ..status = AlbumStatus.values[r['status'] as int]
      ..hypeAtRelease = _d(r['hypeAtRelease'])
      ..variantWeeks = _parseInts(r['variants'] as String)
      ..weekPure = _d(r['weekPure'])
      ..weekTea = _d(r['weekTea'])
      ..weekSea = _d(r['weekSea'])
      ..weekUnits = _d(r['weekUnits'])
      ..weeksBelowCutoff = r['weeksBelowCutoff'] as int
      ..lastPos = r['lastPos'] as int
      ..peakPos = r['peakPos'] as int
      ..weeksOn = r['weeksOn'] as int
      ..weeksAtNo1 = r['weeksAtNo1'] as int
      ..firstWeekUnits = _d(r['firstWeekUnits'])
      ..firstWeekPure = _d(r['firstWeekPure'])
      ..debutPos = r['debutPos'] as int
      ..lifetimePure = _d(r['lifetimePure'])
      ..lifetimeUnits = _d(r['lifetimeUnits'])
      ..sumDormantRate = _d(r['sumDormantRate'])
      ..indexAtSettle = _d(r['indexAtSettle']);
  }

  // ------------------------------------------------------------ helpers
  static String insertSql(String table, List<String> cols) =>
      'INSERT OR REPLACE INTO $table (${cols.join(', ')}) '
      'VALUES (${List.filled(cols.length, '?').join(', ')})';

  static double _d(Object? v) => (v as num).toDouble();

  static String _ints(List<int> v) => v.join(',');

  static List<int> _parseInts(String s) =>
      s.isEmpty ? <int>[] : s.split(',').map(int.parse).toList();

  static String _encodePlan(List<PlannedRelease> plan) =>
      plan.map((p) => '${p.week}:${p.kind.index}:${p.songId}').join(';');

  static List<PlannedRelease> _decodePlan(String s) => s.isEmpty
      ? []
      : s.split(';').map((e) {
          final f = e.split(':').map(int.parse).toList();
          return PlannedRelease(
              week: f[0], kind: PlannedKind.values[f[1]], songId: f[2]);
        }).toList();
}
