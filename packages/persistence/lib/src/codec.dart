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
    // Added in schema v2/v3 (appended: older hot snapshots read null).
    'restWeek', 'skillPoints', 'schedule',
    // Added in schema v8, v11.
    'label', 'contractAlbums', 'campaignFatigue',
    // Added in schema v12, v14, v15.
    'opportunity', 'milestones', 'tour',
    // Added in schema v16, v21.
    'manager',
    'dealAdvance', 'dealAlbums', 'unrecouped',
    // Added in schema v24, v41, v42, v43.
    'surpriseWeek', 'markets', 'distributor', 'managedBy', 'memberIds',
    // Added in schema v52.
    'lineup',
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
        a.job.index, a.lastAdWeek, a.adsWatchedThisWeek,
        a.labelReach, a.artistShare, a.moneyCents,
        a.sumDormantRate,
        a.nextEraWeek, _encodePlan(a.plan), _ints(a.pendingAlbumSongIds),
        a.pendingAlbumTitle, a.pendingAlbumType.index,
        _ints(a.pendingVariantWeeks),
        ...a.reg,
        _ints(a.no1Singles), _ints(a.no1SinglesFeatured), _ints(a.no1Albums),
        _ints(a.weeksAtNo1),
        a.restWeek,
        a.skillPoints,
        _encodeSchedule(a.scheduled),
        a.label.index,
        a.contractAlbumsLeft,
        a.campaignFatigue,
        Opportunity.encode(a.opportunity),
        a.milestones.isEmpty
            ? null
            : jsonEncode(
                {for (final e in a.milestones.entries) '${e.key}': e.value}),
        Tour.encode(a.tour),
        a.manager.index,
        a.contractAdvanceCents,
        a.contractAlbums,
        a.unrecoupedCents,
        a.surpriseWeek,
        a.marketBonus.every((x) => x == 0)
            ? null
            : jsonEncode([for (final x in a.marketBonus) x]),
        a.distributor.index,
        a.managedBy,
        a.memberArtistIds.isEmpty ? null : jsonEncode(a.memberArtistIds),
        Lineups.encode(a),
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
      // Stored as the job index (saves before K36 hold 0/1: 1 = cafe).
      ..job = Job.values[r['hasJob'] as int]
      ..lastAdWeek = r['lastAdWeek'] as int
      ..adsWatchedThisWeek = r['adsWatchedThisWeek'] as int
      ..restWeek = r['restWeek'] as int? ?? -1
      ..skillPoints = r['skillPoints'] as int? ?? 0
      ..sumDormantRate = _d(r['sumDormantRate'])
      ..nextEraWeek = r['nextEraWeek'] as int
      ..pendingAlbumTitle = r['pendingAlbumTitle'] as String
      ..pendingAlbumType = AlbumType.values[r['pendingAlbumType'] as int]
      ..pendingVariantWeeks = _parseInts(r['pendingVariants'] as String);
    a.plan.addAll(_decodePlan(r['plan'] as String));
    a.scheduled.addAll(_decodeSchedule(r['schedule'] as String?));
    // Saves before v8: a player on the small label start shows by its split.
    final label = r['label'] as int?;
    a.label = label != null
        ? Label.values[label]
        : (a.tier == ArtistTier.player && a.artistShare < 1
            ? Label.small
            : Label.independent);
    a.contractAlbumsLeft = r['contractAlbums'] as int? ?? 0;
    a.campaignFatigue = (r['campaignFatigue'] as num?)?.toDouble() ?? 0;
    a.opportunity = Opportunity.decode(r['opportunity'] as String?);
    a.tour = Tour.decode(r['tour'] as String?);
    a.manager = Manager.values[r['manager'] as int? ?? 0];
    a.contractAdvanceCents = r['dealAdvance'] as int? ?? 0;
    a.contractAlbums = r['dealAlbums'] as int? ?? 0;
    a.unrecoupedCents = r['unrecouped'] as int? ?? 0;
    a.surpriseWeek = r['surpriseWeek'] as int? ?? -1000;
    a.distributor = Distributor.values[r['distributor'] as int? ?? 0];
    a.managedBy = r['managedBy'] as int? ?? -1;
    if (r['memberIds'] case final String m when m.isNotEmpty) {
      a.memberArtistIds.addAll((jsonDecode(m) as List).cast<int>());
    }
    Lineups.decode(a, r['lineup'] as String?);
    if (r['markets'] case final String m when m.isNotEmpty) {
      final j = jsonDecode(m) as List;
      for (var i = 0; i < j.length && i < a.marketBonus.length; i++) {
        a.marketBonus[i] = (j[i] as num).toDouble();
      }
    }
    if (r['milestones'] case final String m when m.isNotEmpty) {
      for (final e in (jsonDecode(m) as Map<String, Object?>).entries) {
        a.milestones[int.parse(e.key)] = e.value! as int;
      }
    }
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

  /// "kind:week,kind:week" ('' when empty).
  static String _pairs(List<(int, int)> v) =>
      [for (final (a, b) in v) '$a:$b'].join(',');

  static List<(int, int)> _parsePairs(String? s) => s == null || s.isEmpty
      ? const []
      : [
          for (final p in s.split(','))
            (int.parse(p.split(':')[0]), int.parse(p.split(':')[1]))
        ];

  // ------------------------------------------------------------------ song
  static final songColumns = [
    'id', 'title', 'genre', 'primaryArtistId', 'writtenWeek', //
    'quality', 'commercial', 'fanAppeal', 'radioAppeal',
    'virality', 'longevity', 'estimatedGrade',
    'status', 'releasedWeek', 'albumId', 'isSingle', 'singleWeek',
    'lastAttention', 'lastReach', 'weekStreams', 'weekDownloads',
    'weekPhysical', 'weekRadio', 'weekPoints', 'viralBoost', 'viralRamp',
    'extraGenres',
    'campaign', 'playlistAdd', 'playlistWeek', 'playlistBoost',
    'weeksBelowCutoff', 'lifetimeRadio', 'dormantRate',
    ...songRegColumns,
    'charts',
    // Added in schema v2; new columns go last so older hot snapshots still
    // read (missing trailing columns come back as null).
    'weekRegion', 'lifetimePhysical',
    // Added in schema v6, v11.
    'videoBudget', 'videoPower',
    'campaignPower', 'campaignCost', 'campaignReturn',
    // Added in schema v13, v17, v18, v19.
    'revenue', 'productionCost', 'gradeSpread', 'radioPush',
    'versions', 'variants', 'versionBoost',
    // Added in schema v20, v22, v23.
    'bots', 'autoplay', 'pitchWeek',
    'videoWeek', 'videoBase',
    'sources', 'preSaves',
    // Added in schema v26, v27, v29, v30, v31.
    'creator', 'radioFormat', 'holiday',
    'rerecordOf', 'replacedWeek', 'masterShare',
    'leakedWeek',
    // Added in schema v32, v34, v35, v36, v39, v41, v43, v44.
    'writer', 'liveOf', 'promo', 'cloud', 'snippet', 'langs', 'guestCents',
    'curators',
    // Added in schema v49, v50, v51, v53.
    'ringtones', 'weekRingtones', 'mood', 'canvas', 'bought',
    // Added in schema v55, v56.
    'diss', 'radio',
  ];

  static List<Object?> songRow(Song s) => [
        s.id, s.title, s.genre, s.primaryArtistId, s.writtenWeek, //
        s.quality, s.commercial, s.fanAppeal, s.radioAppeal,
        s.virality, s.longevity, s.estimatedGrade,
        s.status.index, s.releasedWeek, s.albumId, s.isSingle ? 1 : 0,
        s.singleWeek,
        s.lastAttention, s.lastReach, s.weekStreams, s.weekDownloads,
        s.weekPhysical, s.weekRadio, s.weekPoints, s.viralBoost, s.viralRamp,
        _ints(s.extraGenres),
        s.campaign.index, s.playlistAdd.index, s.playlistWeek, s.playlistBoost,
        s.weeksBelowCutoff, s.lifetimeRadio, s.dormantRate,
        ...s.reg,
        _encodeCharts(s),
        s.weekRegion?.join(','),
        s.lifetimePhysical,
        s.videoBudget,
        s.videoPower,
        s.campaignPower,
        s.campaignCostCents,
        s.campaignReturnCents,
        s.revenueCents,
        s.productionCostCents,
        s.gradeSpread,
        s.radioPush.index,
        _pairs([for (final (v, wk) in s.versions) (v.index, wk)]),
        _pairs([for (final (f, wk) in s.variants) (f.index, wk)]),
        s.versionBoost,
        s.botStatus == BotStatus.none && s.chartFilterUntil < 0
            ? null
            : jsonEncode([
                s.botTotal,
                s.botWeeksLeft,
                s.botDelivered,
                s.botStatus.index,
                s.chartFilterUntil,
              ]),
        s.autoplay.index,
        s.pitchWeek,
        s.videoWeek,
        s.streamsAtVideo,
        s.streamSources == null ? null : jsonEncode(s.streamSources),
        s.preSaves,
        s.creatorWeek < 0
            ? null
            : jsonEncode([
                s.creatorWeek,
                s.creatorTier.index,
                s.creatorResult.index,
              ]),
        s.radioFormat?.index,
        s.holiday ? 1 : 0,
        s.rerecordOf,
        s.replacedWeek,
        s.masterShare,
        s.leakedWeek,
        s.writerId < 0 && s.soldTo < 0
            ? null
            : jsonEncode([s.writerId, s.soldTo, s.writerCents]),
        s.liveOf,
        s.marqueeWeek < 0 && s.showcaseWeek < 0
            ? null
            : jsonEncode([s.marqueeWeek, s.showcaseWeek]),
        s.cloudWeek < 0
            ? null
            : jsonEncode([s.cloudWeek, s.cloudOnly ? 1 : 0, s.cloudPlays]),
        s.snippetWeek < 0 ? null : jsonEncode([s.snippetWeek, s.snippetScore]),
        s.languages,
        s.guestCents,
        s.curatorWeek < 0
            ? null
            : jsonEncode([
                s.curatorWeek,
                s.curatorPack.index,
                s.curatorAdds,
                s.curatorReach
              ]),
        s.lifetimeRingtones,
        s.weekRingtones,
        s.moodWeek < 0
            ? null
            : jsonEncode([s.moodWeek, s.mood, s.moodIn ? 1 : 0]),
        s.canvasWeek < 0 ? null : s.canvasWeek,
        s.boughtFrom < 0 ? null : s.boughtFrom,
        s.dissTarget == -1 ? null : s.dissTarget,
        s.ukRadioPush == null && s.radioEditWeek < 0
            ? null
            : jsonEncode([s.ukRadioPush?.index ?? -1, s.radioEditWeek]),
      ];

  static Song songFrom(Map<String, Object?> r, List<int> featured) {
    final s = Song(
      id: r['id'] as int,
      title: r['title'] as String,
      genre: r['genre'] as int,
      extraGenres: _parseInts(r['extraGenres'] as String),
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
    s.gradeSpread = r['gradeSpread'] as int? ?? 6;
    // Before v18 every single had the radio a standard push gives now.
    s.radioPush = RadioPush.values[r['radioPush'] as int? ?? 1];
    // Versions and physical single editions (v19, docs K92).
    for (final (i, wk) in _parsePairs(r['versions'] as String?)) {
      s.versions.add((SongVersion.values[i], wk));
    }
    for (final (i, wk) in _parsePairs(r['variants'] as String?)) {
      s.variants.add((SingleFormat.values[i], wk));
    }
    s.versionBoost = (r['versionBoost'] as num?)?.toDouble() ?? 0;
    // Bought streams, autoplay, pitch (v20, docs K95–K97).
    if (r['bots'] case final String b when b.isNotEmpty) {
      final j = jsonDecode(b) as List;
      s
        ..botTotal = (j[0] as num).toDouble()
        ..botWeeksLeft = j[1] as int
        ..botDelivered = (j[2] as num).toDouble()
        ..botStatus = BotStatus.values[j[3] as int]
        ..chartFilterUntil = j[4] as int;
    }
    s.autoplay = AutoplayLevel.values[r['autoplay'] as int? ?? 0];
    s.pitchWeek = r['pitchWeek'] as int? ?? -1;
    s.videoWeek = r['videoWeek'] as int? ?? -1;
    s.streamsAtVideo = (r['videoBase'] as num?)?.toDouble() ?? 0;
    s.preSaves = (r['preSaves'] as num?)?.toDouble() ?? 0;
    s.holiday = r['holiday'] == 1;
    s.rerecordOf = r['rerecordOf'] as int? ?? -1;
    s.replacedWeek = r['replacedWeek'] as int? ?? -1;
    s.masterShare = (r['masterShare'] as num?)?.toDouble();
    s.leakedWeek = r['leakedWeek'] as int? ?? -1;
    s.liveOf = r['liveOf'] as int? ?? -1;
    if (r['promo'] case final String x when x.isNotEmpty) {
      final j = jsonDecode(x) as List;
      s.marqueeWeek = j[0] as int;
      s.showcaseWeek = j[1] as int;
    }
    if (r['cloud'] case final String x when x.isNotEmpty) {
      final j = jsonDecode(x) as List;
      s.cloudWeek = j[0] as int;
      s.cloudOnly = j[1] == 1;
      s.cloudPlays = (j[2] as num).toDouble();
    }
    s.languages = r['langs'] as int? ?? 0;
    s.guestCents = (r['guestCents'] as num?)?.toDouble() ?? 0;
    s.canvasWeek = r['canvas'] as int? ?? -1;
    s.boughtFrom = r['bought'] as int? ?? -1;
    s.dissTarget = r['diss'] as int? ?? -1;
    if (r['radio'] case final String x when x.isNotEmpty) {
      final j = jsonDecode(x) as List;
      final uk = j[0] as int;
      s
        ..ukRadioPush = uk < 0 ? null : RadioPush.values[uk]
        ..radioEditWeek = j[1] as int;
    }
    if (r['mood'] case final String x when x.isNotEmpty) {
      final j = jsonDecode(x) as List;
      s
        ..moodWeek = j[0] as int
        ..mood = j[1] as int
        ..moodIn = j[2] == 1;
    }
    s
      ..lifetimeRingtones = (r['ringtones'] as num?)?.toDouble() ?? 0
      ..weekRingtones = (r['weekRingtones'] as num?)?.toDouble() ?? 0;
    if (r['curators'] case final String x when x.isNotEmpty) {
      final j = jsonDecode(x) as List;
      s.curatorWeek = j[0] as int;
      s.curatorPack = CuratorPack.values[j[1] as int];
      s.curatorAdds = j[2] as int;
      s.curatorReach = (j[3] as num).toDouble();
    }
    if (r['snippet'] case final String x when x.isNotEmpty) {
      final j = jsonDecode(x) as List;
      s.snippetWeek = j[0] as int;
      s.snippetScore = (j[1] as num).toDouble();
    }
    if (r['writer'] case final String x when x.isNotEmpty) {
      final j = jsonDecode(x) as List;
      s.writerId = j[0] as int;
      s.soldTo = j[1] as int;
      s.writerCents = (j[2] as num).toDouble();
    }
    if (r['radioFormat'] case final int f) {
      s.radioFormat = RadioFormat.values[f];
    }
    if (r['creator'] case final String x when x.isNotEmpty) {
      final v = (jsonDecode(x) as List).cast<int>();
      s
        ..creatorWeek = v[0]
        ..creatorTier = CreatorCampaign.values[v[1]]
        ..creatorResult = CreatorResult.values[v[2]];
    }
    if (r['sources'] case final String x when x.isNotEmpty) {
      s.streamSources = Float64List.fromList(
          [for (final v in jsonDecode(x) as List) (v as num).toDouble()]);
    }
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
      ..campaign = Campaign.values[r['campaign'] as int]
      ..playlistAdd = PlaylistAdd.values[r['playlistAdd'] as int]
      ..playlistWeek = r['playlistWeek'] as int
      ..playlistBoost = _d(r['playlistBoost'])
      ..weeksBelowCutoff = r['weeksBelowCutoff'] as int
      ..lifetimeRadio = _d(r['lifetimeRadio'])
      ..dormantRate = _d(r['dormantRate']);
    _readReg(r, songRegColumns, s.reg);
    _decodeCharts(r['charts'] as String, s);
    s.lifetimePhysical = (r['lifetimePhysical'] as num?)?.toDouble() ?? 0;
    s.videoBudget = r['videoBudget'] as int? ?? -1;
    s.videoPower = (r['videoPower'] as num?)?.toDouble() ?? 0;
    s.campaignPower = (r['campaignPower'] as num?)?.toDouble() ?? 1;
    s.campaignCostCents = r['campaignCost'] as int? ?? 0;
    s.campaignReturnCents = (r['campaignReturn'] as num?)?.toDouble() ?? 0;
    s.revenueCents = (r['revenue'] as num?)?.toDouble() ?? 0;
    s.productionCostCents = r['productionCost'] as int? ?? 0;
    if (r['weekRegion'] case final String wr when wr.isNotEmpty) {
      s.weekRegion =
          Float64List.fromList(wr.split(',').map(double.parse).toList());
    }
    return s;
  }

  // ----------------------------------------------------------------- album
  static final albumColumns = [
    'id', 'title', 'artistId', 'type', 'releaseWeek', 'quality', //
    'status', 'hypeAtRelease', 'campaign', 'variants',
    'weekPure', 'weekTea', 'weekSea', 'weekUnits', 'weeksBelowCutoff',
    'firstWeekUnits', 'firstWeekPure', 'sumDormantRate',
    ...albumRegColumns,
    'charts',
    // Added in schema v5.
    'editionFormats',
    // Added in schema v7, v9, v10.
    'scheduleId', 'criticScore', 'preSingleUnits',
    // Added in schema v11.
    'campaignCost', 'campaignReturn',
    // Added in schema v13, v25, v28, v30.
    'revenue', 'preOrders', 'exclusiveUntil', 'exclusiveFee',
    'masterShare',
    // Added in schema v33, v34, v37, v38, v40, v45, v46.
    'bundle', 'liveTour', 'anniv', 'partner', 'visual', 'hits', 'priceCut',
    // Added in schema v47, v48.
    'rollout', 'windowUntil',
    // Added in schema v54.
    'versions',
  ];

  static List<Object?> albumRow(Album al) => [
        al.id, al.title, al.artistId, al.type.index, al.releaseWeek, //
        al.quality,
        al.status.index, al.hypeAtRelease, al.campaign.index,
        _ints(al.variantWeeks),
        al.weekPure, al.weekTea, al.weekSea, al.weekUnits, al.weeksBelowCutoff,
        al.firstWeekUnits, al.firstWeekPure, al.sumDormantRate,
        ...al.reg,
        _encodeCharts(al),
        _ints(al.variantFormats),
        al.scheduleId,
        al.criticScore,
        al.preSingleUnits,
        al.campaignCostCents,
        al.campaignReturnCents,
        al.revenueCents,
        al.preOrders,
        al.exclusiveUntil,
        al.exclusiveFeeCents,
        al.masterShare,
        al.bundle == AlbumBundle.none
            ? null
            : jsonEncode([al.bundle.index, al.bundleUnits]),
        al.liveTour,
        al.anniversaries,
        al.partnerId,
        al.visual ? 1 : 0,
        al.hitIds.isEmpty ? null : jsonEncode(al.hitIds),
        al.priceCutWeek < 0
            ? null
            : jsonEncode([al.priceCutWeek, al.priceCut.index]),
        al.rolloutApplicable == 0
            ? null
            : jsonEncode([al.rolloutApplicable, al.rolloutDone]),
        al.windowUntil,
        al.versions.isEmpty && al.anniversariesAsked == 0 && al.planned == null
            ? null
            : jsonEncode({
                'v': [for (final v in al.versions) v.toJson()],
                if (al.anniversariesAsked != 0) 'q': al.anniversariesAsked,
                if (al.planned case final p?) 'p': p.toJson(),
              }),
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
      ..campaign = Campaign.values[r['campaign'] as int]
      ..variantWeeks = _parseInts(r['variants'] as String)
      ..scheduleId = r['scheduleId'] as int? ?? -1
      ..criticScore = (r['criticScore'] as num?)?.toDouble() ?? -1
      ..preSingleUnits = (r['preSingleUnits'] as num?)?.toDouble() ?? 0
      ..campaignCostCents = r['campaignCost'] as int? ?? 0
      ..campaignReturnCents = (r['campaignReturn'] as num?)?.toDouble() ?? 0
      ..revenueCents = (r['revenue'] as num?)?.toDouble() ?? 0
      ..preOrders = (r['preOrders'] as num?)?.toDouble() ?? 0
      ..exclusiveUntil = r['exclusiveUntil'] as int? ?? -1
      ..exclusiveFeeCents = r['exclusiveFee'] as int? ?? 0
      ..windowUntil = r['windowUntil'] as int? ?? -1
      ..masterShare = (r['masterShare'] as num?)?.toDouble()
      ..liveTour = r['liveTour'] as int? ?? -1
      ..anniversaries = r['anniv'] as int? ?? 0
      ..partnerId = r['partner'] as int? ?? -1
      ..visual = r['visual'] == 1
      ..priceCutWeek = r['priceCut'] is String
          ? (jsonDecode(r['priceCut'] as String) as List)[0] as int
          : -1
      ..priceCut = r['priceCut'] is String
          ? PriceCut
              .values[(jsonDecode(r['priceCut'] as String) as List)[1] as int]
          : PriceCut.sale
      ..rolloutApplicable = r['rollout'] is String
          ? (jsonDecode(r['rollout'] as String) as List)[0] as int
          : 0
      ..rolloutDone = r['rollout'] is String
          ? (jsonDecode(r['rollout'] as String) as List)[1] as int
          : 0
      ..hitIds.addAll([
        if (r['hits'] case final String x when x.isNotEmpty)
          for (final id in jsonDecode(x) as List) id as int
      ])
      ..variantFormats = r['editionFormats'] == null
          ? const []
          : _parseInts(r['editionFormats'] as String)
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
    if (r['versions'] case final String x when x.isNotEmpty) {
      final j = jsonDecode(x) as Map<String, Object?>;
      al
        ..versions.addAll([
          for (final v in (j['v'] as List?) ?? const [])
            AlbumVersion.fromJson((v as Map).cast<String, Object?>())
        ])
        ..anniversariesAsked = j['q'] as int? ?? 0
        ..planned = j['p'] == null
            ? null
            : PlannedVersion.fromJson((j['p'] as Map).cast<String, Object?>());
    }
    if (r['bundle'] case final String x when x.isNotEmpty) {
      final j = jsonDecode(x) as List;
      al
        ..bundle = AlbumBundle.values[j[0] as int]
        ..bundleUnits = (j[1] as num).toDouble();
    }
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

  static String _encodeSchedule(List<ScheduledRelease> list) => jsonEncode([
        for (final sr in list)
          {
            'id': sr.id,
            'type': sr.type.index,
            'songs': sr.songIds,
            'title': sr.title,
            'variants': sr.variantWeeks,
            'formats': sr.variantFormats,
            'campaign': sr.campaign.index,
            'radio': sr.radioPush.index,
            'release': sr.releaseWeek,
            'announce': sr.announceWeek,
            'created': sr.createdWeek,
            'paid': sr.paidCents,
            'buzz': sr.buzz,
            'ps': sr.preSaves,
            'po': sr.preOrders,
            'ex': sr.exclusive,
            if (sr.windowWeeks > 0) 'win': sr.windowWeeks,
            'bd': sr.bundle.index,
          }
      ]);

  static List<ScheduledRelease> _decodeSchedule(String? json) => [
        if (json != null)
          for (final m
              in (jsonDecode(json) as List).cast<Map<String, Object?>>())
            ScheduledRelease(
              id: m['id'] as int,
              type: AlbumType.values[m['type'] as int],
              songIds: (m['songs'] as List).cast<int>(),
              title: m['title'] as String,
              variantWeeks: (m['variants'] as List).cast<int>(),
              variantFormats: ((m['formats'] as List?) ?? const []).cast<int>(),
              campaign: Campaign.values[m['campaign'] as int],
              // Saved before docs K84: the radio a standard push gives.
              radioPush: RadioPush.values[m['radio'] as int? ?? 1],
              releaseWeek: m['release'] as int,
              announceWeek: m['announce'] as int,
              createdWeek: m['created'] as int,
              paidCents: m['paid'] as int,
              buzz: (m['buzz'] as num).toDouble(),
            )
              ..preSaves = (m['ps'] as num?)?.toDouble() ?? 0
              ..preOrders = (m['po'] as num?)?.toDouble() ?? 0
              ..exclusive = m['ex'] as bool? ?? false
              ..windowWeeks = m['win'] as int? ?? 0
              ..bundle = AlbumBundle.values[m['bd'] as int? ?? 0],
      ];
}
