import 'dart:convert';
import 'dart:typed_data';

import 'package:simulation_core/simulation_core.dart';

/// Row mapping between the hot world model and SQLite. Every field the
/// simulation reads across weeks must round-trip exactly (doubles are stored
/// as 64-bit REAL, so they do). Regional arrays become readable columns with
/// NA / EU / OT suffixes so the UI can query them directly.
abstract final class Codec {
  static const regionSuffixes = ['NA', 'EU', 'OT'];

  static List<String> _regional(List<String> prefixes) => [
        for (final p in prefixes)
          for (final s in regionSuffixes) '$p$s',
      ];

  /// In [ArtistReg] order.
  static final artistRegColumns = _regional([
    'idxStreams', 'idxDownloads', 'settleSpa', 'settleDpa', //
    'lifeStreams', 'lifeDownloads', 'lifePure', 'lifeUnits',
  ]);

  /// In [SongReg] order.
  static final songRegColumns =
      _regional(['lifeStreams', 'lifeDownloads', 'idxStreams', 'idxDownloads']);

  /// In [AlbumReg] order.
  static final albumRegColumns = _regional(
      ['lifePure', 'lifeUnits', 'idxStreams', 'firstUnits', 'firstPure']);

  // ---------------------------------------------------------------- artist
  static final artistColumns = [
    'id', 'name', 'tier', 'genre', 'homeCountry', 'debutWeek', 'retiredWeek', //
    'songwriting', 'vocals', 'production', 'performance', 'charisma',
    'fame', 'popularity', 'coreFans', 'casual', 'buzz', 'devotion',
    'hype', 'anticipation', 'anticipationCap',
    'eraOpen', 'eraAlbumId', 'eraStartWeek', 'eraUnits',
    'eraExpected', 'lastEraUnits', 'lastEraResult', 'flopSupport',
    'lastReleaseWeek',
    'creativeEnergy', 'burnoutUntilWeek', 'lastWriteWeek',
    'songsWrittenThisWeek',
    'kind', 'members',
    'hasJob', 'lastAdWeek', 'adsWatchedThisWeek',
    'labelReach', 'artistShare', 'moneyCents',
    'sumDormantRate',
    'nextEraWeek', 'plan', 'pendingSongs', 'pendingAlbumTitle',
    'pendingAlbumType', 'pendingVariants',
    ...artistRegColumns,
    'no1Singles', 'no1SinglesFeatured', 'no1Albums', 'weeksAtNo1',
  ];

  static List<Object?> artistRow(Artist a) => [
        a.id, a.name, a.tier.index, a.genre, a.homeCountry.index, //
        a.debutWeek, a.retiredWeek,
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
        a.kind.index, jsonEncode(a.members),
        a.hasJob ? 1 : 0, a.lastAdWeek, a.adsWatchedThisWeek,
        a.labelReach, a.artistShare, a.moneyCents,
        a.sumDormantRate,
        a.nextEraWeek, _encodePlan(a.plan), _ints(a.pendingAlbumSongIds),
        a.pendingAlbumTitle, a.pendingAlbumType.index,
        _ints(a.pendingVariantWeeks),
        ...a.reg,
        _ints(a.no1Singles), _ints(a.no1SinglesFeatured), _ints(a.no1Albums),
        _ints(a.weeksAtNo1),
      ];

  static Artist artistFrom(Map<String, Object?> r) {
    final a = Artist(
      id: r['id'] as int,
      name: r['name'] as String,
      tier: ArtistTier.values[r['tier'] as int],
      genre: r['genre'] as int,
      homeCountry: HomeCountry.values[r['homeCountry'] as int],
      kind: ArtistKind.values[r['kind'] as int],
      members: (jsonDecode(r['members'] as String) as List).cast<String>(),
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
      ..hasJob = r['hasJob'] == 1
      ..lastAdWeek = r['lastAdWeek'] as int
      ..adsWatchedThisWeek = r['adsWatchedThisWeek'] as int
      ..sumDormantRate = _d(r['sumDormantRate'])
      ..nextEraWeek = r['nextEraWeek'] as int
      ..pendingAlbumTitle = r['pendingAlbumTitle'] as String
      ..pendingAlbumType = AlbumType.values[r['pendingAlbumType'] as int]
      ..pendingVariantWeeks = _parseInts(r['pendingVariants'] as String);
    a.plan.addAll(_decodePlan(r['plan'] as String));
    a.pendingAlbumSongIds.addAll(_parseInts(r['pendingSongs'] as String));
    _readReg(r, artistRegColumns, a.reg);
    _readInts(r['no1Singles'] as String, a.no1Singles);
    _readInts(r['no1SinglesFeatured'] as String, a.no1SinglesFeatured);
    _readInts(r['no1Albums'] as String, a.no1Albums);
    _readInts(r['weeksAtNo1'] as String, a.weeksAtNo1);
    // Derived from (fame, genre, home): recomputing gives the exact value.
    a.updateRegionShare();
    return a;
  }

  // ------------------------------------------------------------------ song
  static final songColumns = [
    'id', 'title', 'genre', 'primaryArtistId', 'writtenWeek', //
    'quality', 'commercial', 'fanAppeal', 'radioAppeal',
    'virality', 'longevity', 'estimatedGrade',
    'status', 'releasedWeek', 'albumId', 'isSingle', 'singleWeek',
    'lastAttention', 'lastReach', 'weekStreams', 'weekDownloads',
    'weekPhysical', 'weekRadio', 'weekPoints', 'viralBoost', 'viralRamp',
    'weeksBelowCutoff', 'lifetimeRadio', 'dormantRate',
    ...songRegColumns,
    'charts',
  ];

  static List<Object?> songRow(Song s) => [
        s.id, s.title, s.genre, s.primaryArtistId, s.writtenWeek, //
        s.quality, s.commercial, s.fanAppeal, s.radioAppeal,
        s.virality, s.longevity, s.estimatedGrade,
        s.status.index, s.releasedWeek, s.albumId, s.isSingle ? 1 : 0,
        s.singleWeek,
        s.lastAttention, s.lastReach, s.weekStreams, s.weekDownloads,
        s.weekPhysical, s.weekRadio, s.weekPoints, s.viralBoost, s.viralRamp,
        s.weeksBelowCutoff, s.lifetimeRadio, s.dormantRate,
        ...s.reg,
        _encodeCharts(s),
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
    s
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
      ..viralRamp = r['viralRamp'] as int
      ..weeksBelowCutoff = r['weeksBelowCutoff'] as int
      ..lifetimeRadio = _d(r['lifetimeRadio'])
      ..dormantRate = _d(r['dormantRate']);
    _readReg(r, songRegColumns, s.reg);
    _decodeCharts(r['charts'] as String, s);
    return s;
  }

  // ----------------------------------------------------------------- album
  static final albumColumns = [
    'id', 'title', 'artistId', 'type', 'releaseWeek', 'quality', //
    'status', 'hypeAtRelease', 'variants',
    'weekPure', 'weekTea', 'weekSea', 'weekUnits', 'weeksBelowCutoff',
    'firstWeekUnits', 'firstWeekPure', 'sumDormantRate',
    ...albumRegColumns,
    'charts',
  ];

  static List<Object?> albumRow(Album al) => [
        al.id, al.title, al.artistId, al.type.index, al.releaseWeek, //
        al.quality,
        al.status.index, al.hypeAtRelease, _ints(al.variantWeeks),
        al.weekPure, al.weekTea, al.weekSea, al.weekUnits, al.weeksBelowCutoff,
        al.firstWeekUnits, al.firstWeekPure, al.sumDormantRate,
        ...al.reg,
        _encodeCharts(al),
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
    al
      ..status = AlbumStatus.values[r['status'] as int]
      ..hypeAtRelease = _d(r['hypeAtRelease'])
      ..variantWeeks = _parseInts(r['variants'] as String)
      ..weekPure = _d(r['weekPure'])
      ..weekTea = _d(r['weekTea'])
      ..weekSea = _d(r['weekSea'])
      ..weekUnits = _d(r['weekUnits'])
      ..weeksBelowCutoff = r['weeksBelowCutoff'] as int
      ..firstWeekUnits = _d(r['firstWeekUnits'])
      ..firstWeekPure = _d(r['firstWeekPure'])
      ..sumDormantRate = _d(r['sumDormantRate']);
    _readReg(r, albumRegColumns, al.reg);
    _decodeCharts(r['charts'] as String, al);
    return al;
  }

  // ------------------------------------------------------------ helpers
  static String insertSql(String table, List<String> cols) =>
      'INSERT OR REPLACE INTO $table (${cols.join(', ')}) '
      'VALUES (${List.filled(cols.length, '?').join(', ')})';

  static double _d(Object? v) => (v as num).toDouble();

  static String _ints(List<int> v) => v.join(',');

  static List<int> _parseInts(String s) =>
      s.isEmpty ? <int>[] : s.split(',').map(int.parse).toList();

  static void _readInts(String s, Int32List into) {
    final v = _parseInts(s);
    for (var i = 0; i < v.length && i < into.length; i++) {
      into[i] = v[i];
    }
  }

  static void _readReg(
      Map<String, Object?> r, List<String> cols, Float64List into) {
    for (var i = 0; i < cols.length; i++) {
      into[i] = _d(r[cols[i]]);
    }
  }

  /// "chart:last:peak:weeksOn:weeksAtNo1:debut;..." for charts with stats.
  static String _encodeCharts(Charted e) {
    final cs = e.charts;
    if (cs == null) return '';
    final parts = <String>[];
    for (var c = 0; c < cs.length; c++) {
      final st = cs[c];
      if (st == null) continue;
      parts.add(
          '$c:${st.lastPos}:${st.peak}:${st.weeksOn}:${st.weeksAtNo1}:${st.debutPos}');
    }
    return parts.join(';');
  }

  static void _decodeCharts(String s, Charted e) {
    if (s.isEmpty) return;
    for (final part in s.split(';')) {
      final f = part.split(':').map(int.parse).toList();
      e.stats(f[0])
        ..lastPos = f[1]
        ..peak = f[2]
        ..weeksOn = f[3]
        ..weeksAtNo1 = f[4]
        ..debutPos = f[5];
    }
  }

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
