import 'dart:convert';
import 'dart:io' show Directory;
import 'dart:typed_data';

import 'package:simulation_core/simulation_core.dart';
import 'package:sqlite3/common.dart';

import 'binary.dart';
import 'codec.dart';
import 'save_fs.dart';
import 'save_fs_stub.dart' if (dart.library.io) 'save_fs_io.dart';
import 'schema.dart';

/// One career = one SQLite file. The hot world lives in memory; each week is
/// written in a single transaction (docs/architecture.md §3):
///   - changed state only (active sets + dirty entities), never the whole world
///   - immutable history (charts, weekly stats for charted/player releases)
///   - meta.currentWeek in the same transaction, so a crash leaves the
///     previous week intact.
class SaveStore {
  SaveStore._(this.db, this.fs);

  final CommonDatabase db;

  /// Where the save lives (docs K218).
  final SaveFs fs;
  static const simulationVersion = 1;

  /// Creates a new save file for [world] (fails if the file exists).
  static SaveStore create(String path, World world, {SaveFs? fs}) {
    fs ??= defaultSaveFs();
    if (fs.exists(path)) {
      throw StateError('Save already exists: $path');
    }
    final store = SaveStore._(fs.openDatabase(path), fs);
    store._migrate();
    store._transaction(() {
      store._writeMeta(world);
      store._writeCollaborators(world);
      store._writeArtists(world, world.artists);
      store._writeSongs(world, world.songs, withCredits: true);
      store._writeAlbums(world, world.albums, withTracks: true);
      store._writeCharts(world.week - 1, world.charts);
      store._writeHot(world);
    });
    _clearDirty(world);
    return store;
  }

  /// Opens an existing save.
  static SaveStore open(String path, {SaveFs? fs}) {
    fs ??= defaultSaveFs();
    if (!fs.exists(path)) throw StateError('No save at $path');
    final store = SaveStore._(fs.openDatabase(path), fs);
    store._migrate();
    return store;
  }

  void _migrate() {
    final v = db.userVersion;
    for (var i = v; i < migrations.length; i++) {
      _transaction(() {
        db.execute(migrations[i]);
        db.userVersion = i + 1;
      });
    }
  }

  void close() {
    _checkpoint();
    db.dispose();
    fs.saved();
  }

  // ------------------------------------------------------------------ load

  /// Rebuilds the in-memory world exactly as it was after the last commit.
  World load({SimConfig? config}) {
    final meta = {
      for (final r in db.select('SELECT key, value FROM meta'))
        r['key'] as String: r['value'],
    };
    final version = meta['simulationVersion'] as int;
    if (version > simulationVersion) {
      throw StateError('Save made by a newer game version ($version)');
    }
    final w = World(
      config: config ?? SimConfig(),
      seed: meta['seed'] as int,
      week: meta['week'] as int,
      difficulty: Difficulty
          .values[meta['difficulty'] as int? ?? Difficulty.normal.index],
      realNames: (meta['realNames'] as int? ?? 0) == 1,
    );
    w.playerArtistId = meta['playerArtistId'] as int;
    // Box-office records and festival slots (docs K77).
    w.tourRecords.addAll(TourRecord.decode(meta['tourRecords'] as String?));
    w.festivalBookings
        .addAll(FestivalBooking.decode(meta['festivals'] as String?));
    // Award shows (docs K91).
    w.awardShows.addAll(AwardShow.decode(meta['awards'] as String?));
    // Social media (docs K93).
    w.social.decode(meta['social'] as String?);
    // Brand deals (docs K102).
    w.brandDeals.addAll(BrandDeal.decode(meta['brandDeals'] as String?));
    w.musicShow.decode(meta['musicShow'] as String?);
    // The player's channel (docs K142).
    w.channelVideos.addAll(ChannelVideo.decode(meta['channel'] as String?));
    // The player's own playlist (docs K159).
    w.ownPlaylist = OwnPlaylist.decode(meta['playlist'] as String?);
    w.artistPick = ArtistPick.decode(meta['pick'] as String?);
    // The player's fan club (docs K164).
    w.fanClub = FanClub.decode(meta['fanClub'] as String?);
    // The player's own label (docs K169).
    w.imprint = Imprint.decode(meta['imprint'] as String?);
    // The player's awards campaign (docs K171).
    w.fycCampaign = FycCampaign.decode(meta['fyc'] as String?);
    // What the player submitted for the awards (docs K227).
    w.awardSubmissions = AwardSubmissions.decode(meta['awardSubs'] as String?);
    // The player's beefs (docs K229).
    w.beefs.addAll(Beef.decode(meta['beefs'] as String?));
    // The player's documentaries (docs K172).
    w.documentaries.addAll(Documentary.decode(meta['docs'] as String?));
    // The player's Streamify Sessions (docs K178).
    w.streamifySessions
        .addAll(StreamifySession.decode(meta['sessions'] as String?));
    w.playerPeakListeners = (meta['listenersPeak'] as num?)?.toDouble() ?? -1;
    // The player's This Is list (docs K189).
    w.thisIsWeek = (meta['thisIs'] as num?)?.toInt() ?? -1;
    // Going solo (docs K191).
    w.formerGroupId = (meta['formerGroup'] as num?)?.toInt() ?? -1;
    w.playerSinceWeek = (meta['playerSince'] as num?)?.toInt() ?? 0;
    w.careerStreamsBase = (meta['careerBase'] as num?)?.toDouble() ?? 0;
    // The reunion (docs K194).
    Reunions.decode(w, meta['reunion'] as String?);
    w.rivalSplits.addAll(RivalSplit.decode(meta['rivalSplits'] as String?));
    // The player's certifications (docs K209).
    if (meta['certs'] case final String s) {
      w.certsTracked = true;
      if (s.isNotEmpty) {
        for (final e in (jsonDecode(s) as Map<String, Object?>).entries) {
          w.certs[int.parse(e.key)] = [
            for (final x in e.value as List) (x as List).cast<int>()
          ];
        }
      }
    }
    // The player's finished tours (docs K208).
    if (meta['pastTours'] case final String s when s.isNotEmpty) {
      w.pastTours.addAll([
        for (final x in jsonDecode(s) as List)
          Tour.fromJson(x as Map<String, Object?>)
      ]);
    }
    // A moment waiting for the player (docs K256).
    w.moment = Moment.decode(meta['moment'] as String?);
    // Radio station visits (docs K254).
    if (meta['radioVisits'] case final String s when s.isNotEmpty) {
      w.radioVisits.addAll([
        for (final x in jsonDecode(s) as List)
          ((x as List)[0] as int, x[1] as int)
      ]);
    }
    // The song market's bought offers (docs K205).
    if (meta['songMarket'] case final String s when s.isNotEmpty) {
      w.boughtPitches.addAll((jsonDecode(s) as List).cast<int>());
    }
    if (meta['artistChart'] case final String s when s.isNotEmpty) {
      final j = jsonDecode(s) as List;
      w.artistChartPrev = List.unmodifiable((j[0] as List).cast<int>());
      w.artistChart = List.unmodifiable((j[1] as List).cast<int>());
      if (j.length > 3) {
        w.playerBestArtistRank = j[2] as int;
        w.playerWeeksTopArtist = j[3] as int;
      }
    }
    // Arrays grow with new charts and regions: a save from before them
    // keeps the defaults for the entries it lacks.
    for (final (key, arr) in _metaArrays(w)) {
      for (var i = 0; i < arr.length; i++) {
        if (meta['$key$i'] case final num v) arr[i] = v.toDouble();
      }
    }

    for (final r in db.select('SELECT * FROM collaborator ORDER BY id')) {
      w.collaborators.add(Collaborator(
        id: r['id'] as int,
        name: r['name'] as String,
        role: CollaboratorRole.values[r['role'] as int],
        skill: _d(r['skill']),
        genre: r['genre'] as int,
        feeCents: r['feeCents'] as int,
        minFame: _d(r['minFame']),
      ));
    }

    // Relational rows are authoritative for cold entities; the hot snapshot
    // overrides them for entities that were active at the last commit.
    final hot = _readHot();

    for (final r in db.select('SELECT * FROM artist ORDER BY id')) {
      final a = Codec.artistFrom(hot.artists[r['id'] as int] ?? r);
      w.artists.add(a);
      if (!a.isRetired) w.activeArtistIds.add(a.id);
    }

    final featured = <int, List<int>>{};
    for (final r in db.select(
        'SELECT songId, artistId FROM songCredit ORDER BY songId, position')) {
      (featured[r['songId'] as int] ??= []).add(r['artistId'] as int);
    }
    for (final r in db.select('SELECT * FROM song ORDER BY id')) {
      final id = r['id'] as int;
      final s = Codec.songFrom(hot.songs[id] ?? r, featured[id] ?? []);
      w.songs.add(s);
      if (s.primaryArtistId == w.playerArtistId) w.playerSongIds.add(s.id);
      if (s.writerId >= 0) w.writtenSongIds.add(s.id);
      // Members' solo songs and the player's verses (docs K158); a group
      // the player left keeps its members' (K191).
      if (w.artists[s.primaryArtistId].managedBy == w.playerArtistId) {
        w.managedSongIds.add(s.id);
      } else if (s.primaryArtistId != w.playerArtistId &&
          s.featuredArtistIds.contains(w.playerArtistId)) {
        w.guestSongIds.add(s.id);
      }
      if (s.status == SongStatus.active) w.activeSongIds.add(s.id);
      if (s.status == SongStatus.dormant) {
        w.artists[s.primaryArtistId].dormantSongIds.add(s.id);
        w.dormantSongCount++;
      }
    }

    final tracks = <int, List<int>>{};
    for (final r in db.select(
        'SELECT albumId, songId FROM albumTrack ORDER BY albumId, position')) {
      (tracks[r['albumId'] as int] ??= []).add(r['songId'] as int);
    }
    for (final r in db.select('SELECT * FROM album ORDER BY id')) {
      final id = r['id'] as int;
      final al = Codec.albumFrom(hot.albums[id] ?? r, tracks[id] ?? []);
      w.albums.add(al);
      if (al.status == AlbumStatus.active) w.activeAlbumIds.add(al.id);
    }

    w.charts = [for (final def in Charts.all) _loadChart(def.id, w.week - 1)];
    return w;
  }

  List<ChartEntry> _loadChart(int chartId, int week) => [
        for (final r in db.select(
            'SELECT * FROM chartEntry WHERE chartId = ? AND week = ? '
            'ORDER BY position',
            [chartId, week]))
          ChartEntry(
            position: r['position'] as int,
            entityId: r['entityId'] as int,
            points: _d(r['points']),
            lastPos: r['lastPos'] as int,
            peak: r['peak'] as int,
            weeksOn: r['weeksOn'] as int,
          ),
      ];

  // ---------------------------------------------------------------- commit

  /// Writes the week that was just simulated. [debugBeforeCommit] is a test
  /// hook used to simulate a crash in the middle of a save.
  void commitWeek(World w, WeekResult r,
      {void Function()? debugBeforeCommit, Map<String, int>? profile}) {
    final sw = Stopwatch()..start();
    void lap(String k) {
      if (profile != null) {
        profile[k] = (profile[k] ?? 0) + sw.elapsedMicroseconds;
        sw.reset();
      }
    }

    _transaction(() {
      // 1. New or changed (status) entities: relational rows.
      _writeArtists(w, [for (final id in w.dirtyArtists) w.artists[id]]);
      final dirtySongs = [for (final id in w.dirtySongs) w.songs[id]];
      _writeSongs(w, dirtySongs);
      _writeCredits(dirtySongs);
      final dirtyAlbums = [for (final id in w.dirtyAlbums) w.albums[id]];
      _writeAlbums(w, dirtyAlbums);
      _writeTracks(dirtyAlbums);
      lap('dirty');

      // 2. The hot world as one contiguous blob.
      _writeHot(w);
      lap('hot');

      // 3. Periodically refresh relational rows of active entities so SQL
      //    queries (UI, history screens) stay close to current.
      if (w.week % flushEveryWeeks == 0) _flushActiveRows(w);
      lap('flush');

      _writeHistory(w, r);
      lap('history');
      _writeMeta(w);
      debugBeforeCommit?.call();
    });
    lap('commit');
    if (w.week % flushEveryWeeks == 0) _checkpoint();
    lap('checkpoint');
    _clearDirty(w);
  }

  /// Saves player actions taken between weeks (a written song, a release,
  /// money) right away, without writing history; the week stays the same.
  void saveState(World w) {
    _transaction(() {
      _writeArtists(w, [for (final id in w.dirtyArtists) w.artists[id]]);
      final dirtySongs = [for (final id in w.dirtySongs) w.songs[id]];
      _writeSongs(w, dirtySongs);
      _writeCredits(dirtySongs);
      final dirtyAlbums = [for (final id in w.dirtyAlbums) w.albums[id]];
      _writeAlbums(w, dirtyAlbums);
      _writeTracks(dirtyAlbums);
      _writeHot(w);
      _writeMeta(w);
    });
    _clearDirty(w);
  }

  /// Relational rows of active entities are refreshed this often, and by
  /// [flushActive] (call it when the app goes to the background or closes).
  static const flushEveryWeeks = 13;

  void flushActive(World w) => _transaction(() => _flushActiveRows(w));

  void _checkpoint() => db.execute('PRAGMA wal_checkpoint(PASSIVE)');

  void _flushActiveRows(World w) {
    _writeArtists(w, [for (final id in w.activeArtistIds) w.artists[id]]);
    _writeSongs(w, [for (final id in w.activeSongIds) w.songs[id]]);
    _writeAlbums(w, [for (final id in w.activeAlbumIds) w.albums[id]]);
  }

  void _writeHot(World w) {
    final out = RowWriter();
    out.count(w.activeArtistIds.length);
    for (final id in w.activeArtistIds) {
      out.row(Codec.artistRow(w.artists[id]));
    }
    out.count(w.activeSongIds.length);
    for (final id in w.activeSongIds) {
      out.row(Codec.songRow(w.songs[id]));
    }
    out.count(w.activeAlbumIds.length);
    for (final id in w.activeAlbumIds) {
      out.row(Codec.albumRow(w.albums[id]));
    }
    db.execute(
        'INSERT OR REPLACE INTO hotState (id, week, data) VALUES (1, ?, ?)',
        [w.week, out.takeBytes()]);
  }

  ({
    Map<int, Map<String, Object?>> artists,
    Map<int, Map<String, Object?>> songs,
    Map<int, Map<String, Object?>> albums,
  }) _readHot() {
    final rows = db.select('SELECT data FROM hotState WHERE id = 1');
    final artists = <int, Map<String, Object?>>{};
    final songs = <int, Map<String, Object?>>{};
    final albums = <int, Map<String, Object?>>{};
    if (rows.isNotEmpty) {
      final r = RowReader(rows.first['data'] as Uint8List);
      for (final (cols, target) in [
        (Codec.artistColumns, artists),
        (Codec.songColumns, songs),
        (Codec.albumColumns, albums),
      ]) {
        final n = r.count();
        for (var i = 0; i < n; i++) {
          final row = r.row(cols);
          target[row['id'] as int] = row;
        }
      }
    }
    return (artists: artists, songs: songs, albums: albums);
  }

  static void _clearDirty(World w) {
    w.dirtyArtists.clear();
    w.dirtySongs.clear();
    w.dirtyAlbums.clear();
  }

  void _transaction(void Function() body) {
    db.execute('BEGIN IMMEDIATE');
    try {
      body();
      db.execute('COMMIT');
      fs.saved();
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _writeMeta(World w) {
    final st =
        db.prepare('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)');
    final values = <String, Object>{
      'simulationVersion': simulationVersion,
      'seed': w.seed,
      'week': w.week,
      'playerArtistId': w.playerArtistId,
      'difficulty': w.difficulty.index,
      'realNames': w.realNames ? 1 : 0,
      'tourRecords': TourRecord.encode(w.tourRecords),
      'festivals': FestivalBooking.encode(w.festivalBookings),
      'awards': AwardShow.encode(w.awardShows),
      'social': w.social.encode(),
      'brandDeals': BrandDeal.encode(w.brandDeals),
      'artistChart': jsonEncode([
        w.artistChartPrev,
        w.artistChart,
        w.playerBestArtistRank,
        w.playerWeeksTopArtist,
      ]),
      'musicShow': w.musicShow.encode(),
      'channel': ChannelVideo.encode(w.channelVideos),
      'playlist': OwnPlaylist.encode(w.ownPlaylist),
      'pick': w.artistPick?.encode() ?? '',
      'fanClub': w.fanClub?.encode() ?? '',
      'imprint': w.imprint?.encode() ?? '',
      'fyc': w.fycCampaign?.encode() ?? '',
      'awardSubs': w.awardSubmissions?.encode() ?? '',
      'beefs': Beef.encode(w.beefs),
      'docs': Documentary.encode(w.documentaries),
      'sessions': StreamifySession.encode(w.streamifySessions),
      'listenersPeak': w.playerPeakListeners,
      'thisIs': w.thisIsWeek,
      'formerGroup': w.formerGroupId,
      'playerSince': w.playerSinceWeek,
      'careerBase': w.careerStreamsBase,
      'reunion': Reunions.encode(w),
      'rivalSplits': RivalSplit.encode(w.rivalSplits),
      'songMarket': jsonEncode(w.boughtPitches.toList()..sort()),
      'pastTours': jsonEncode([for (final t in w.pastTours) t.toJson()]),
      'moment': w.moment?.encode() ?? '',
      'radioVisits': jsonEncode([
        for (final (week, m) in w.radioVisits) [week, m]
      ]),
      if (w.certsTracked)
        'certs':
            jsonEncode({for (final e in w.certs.entries) '${e.key}': e.value}),
      for (final (key, arr) in _metaArrays(w))
        for (var i = 0; i < arr.length; i++) '$key$i': arr[i],
    };
    for (final e in values.entries) {
      st.execute([e.key, e.value]);
    }
    st.dispose();
  }

  void _writeCollaborators(World w) {
    final st = db.prepare(
        'INSERT OR REPLACE INTO collaborator VALUES (?, ?, ?, ?, ?, ?, ?)');
    for (final c in w.collaborators) {
      st.execute([
        c.id,
        c.name,
        c.role.index,
        c.skill,
        c.genre,
        c.feeCents,
        c.minFame
      ]);
    }
    st.dispose();
  }

  void _writeArtists(World w, Iterable<Artist> artists) {
    final st = db.prepare(Codec.insertSql('artist', Codec.artistColumns));
    for (final a in artists) {
      st.execute(Codec.artistRow(a));
    }
    st.dispose();
  }

  void _writeSongs(World w, Iterable<Song> songs, {bool withCredits = false}) {
    final st = db.prepare(Codec.insertSql('song', Codec.songColumns));
    for (final s in songs) {
      st.execute(Codec.songRow(s));
    }
    st.dispose();
    if (withCredits) _writeCredits(songs);
  }

  void _writeCredits(Iterable<Song> songs) {
    final st = db.prepare(
        'INSERT OR IGNORE INTO songCredit (songId, artistId, position) VALUES (?, ?, ?)');
    for (final s in songs) {
      for (var i = 0; i < s.featuredArtistIds.length; i++) {
        st.execute([s.id, s.featuredArtistIds[i], i]);
      }
    }
    st.dispose();
  }

  void _writeAlbums(World w, Iterable<Album> albums,
      {bool withTracks = false}) {
    final st = db.prepare(Codec.insertSql('album', Codec.albumColumns));
    for (final al in albums) {
      st.execute(Codec.albumRow(al));
    }
    st.dispose();
    if (withTracks) _writeTracks(albums);
  }

  void _writeTracks(Iterable<Album> albums) {
    final st = db.prepare(
        'INSERT OR IGNORE INTO albumTrack (albumId, position, songId) VALUES (?, ?, ?)');
    for (final al in albums) {
      for (var i = 0; i < al.songIds.length; i++) {
        st.execute([al.id, i, al.songIds[i]]);
      }
    }
    st.dispose();
  }

  /// Regional/per-chart world arrays stored in meta as key0, key1, ….
  static List<(String, Float64List)> _metaArrays(World w) => [
        ('spaIndex', w.spaIndex),
        ('dpaIndex', w.dpaIndex),
        ('retiredDormantAttention', w.retiredDormantAttention),
        ('emaAttention', w.emaAttention),
        ('emaDownloadDemand', w.emaDownloadDemand),
        ('emaRadioDemand', w.emaRadioDemand),
        ('chartCutoff', w.chartCutoff),
        ('lastSpa', w.lastSpa),
        ('lastDpa', w.lastDpa),
      ];

  void _writeCharts(int week, List<List<ChartEntry>> charts) {
    final chart = db.prepare('INSERT OR REPLACE INTO chartEntry '
        '(chartId, week, position, entityId, points, lastPos, peak, weeksOn) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
    for (var id = 0; id < charts.length; id++) {
      for (final e in charts[id]) {
        chart.execute([
          id,
          week,
          e.position,
          e.entityId,
          e.points.round(),
          e.lastPos,
          e.peak,
          e.weeksOn
        ]);
      }
    }
    chart.dispose();
  }

  void _writeHistory(World w, WeekResult r) {
    _writeCharts(r.week, r.charts);

    // Detailed weekly stats (regional streams, sales) are kept for the
    // player's releases; AI releases keep their full chart history
    // (docs/data-model.md §4.2).
    final player = w.playerArtistId;
    // Every released player song gets a weekly row (catalog songs' numbers
    // come from the catalog formula), so per-song graphs are complete.
    final songIds = <int>[
      for (final id in w.playerSongIds)
        if (w.songs[id].releasedWeek >= 0 && w.songs[id].releasedWeek <= r.week)
          id,
    ];
    final sw = db.prepare('INSERT OR REPLACE INTO songWeek '
        '(songId, week, streams, downloads, radio, physical, points, '
        'streamsNA, streamsEU, streamsOT) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    for (final id in songIds) {
      final s = w.songs[id];
      final wr = [
        for (var k = 0; k < regionCount; k++) w.songWeekStreamsRegion(s, k),
      ];
      final total = wr[0] + wr[1] + wr[2];
      final active = s.status == SongStatus.active;
      sw.execute([
        id,
        r.week,
        total,
        active ? s.weekDownloads : 0.0,
        active ? s.weekRadio : 0.0,
        active ? s.weekPhysical : 0.0,
        active ? s.weekPoints : 0.0,
        wr[0],
        wr[1],
        wr[2],
      ]);
    }
    sw.dispose();

    final albumIds = <int>{
      for (final id in w.activeAlbumIds)
        if (w.albums[id].artistId == player) id,
    };
    final aw = db.prepare('INSERT OR REPLACE INTO albumWeek '
        '(albumId, week, pure, tea, sea, units, '
        'pureNA, pureEU, pureOT, unitsNA, unitsEU, unitsOT) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    for (final id in albumIds) {
      final al = w.albums[id];
      aw.execute([
        id, r.week, al.weekPure, al.weekTea, al.weekSea, al.weekUnits, //
        ...al.weekRegion,
      ]);
    }
    aw.dispose();

    final p = w.player;
    if (p != null) {
      db.execute(
          'INSERT OR REPLACE INTO playerWeek VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [
        r.week,
        p.fame,
        p.popularity,
        p.coreFans,
        p.casual,
        p.devotion,
        p.moneyCents,
        // Runs on across going solo (docs K191).
        w.playerCareerStreams,
      ]);
    }
  }

  static double _d(Object? v) => (v as num).toDouble();
}

/// Save slots: one folder per career, each with its database and a small
/// summary.json so the slot list never has to open large databases.
class SaveSlots {
  /// Slots in [root] on the device.
  SaveSlots(Directory root) : this.on(defaultSaveFs(), root.path);

  /// Slots under [rootPath] in [fs] (the browser's on the web; docs K218).
  SaveSlots.on(this.fs, this.rootPath);

  final SaveFs fs;
  final String rootPath;

  String dbPath(String slotId) => '$rootPath/$slotId/career.sqlite';

  List<Map<String, Object?>> list() {
    final out = <Map<String, Object?>>[];
    for (final slot in fs.folders(rootPath)) {
      final text = fs.readText('$rootPath/$slot/summary.json');
      if (text != null) out.add(jsonDecode(text) as Map<String, Object?>);
    }
    out.sort(
        (a, b) => (a['slotId'] as String).compareTo(b['slotId'] as String));
    return out;
  }

  SaveStore create(String slotId, World world) {
    fs.makeFolder('$rootPath/$slotId');
    final store = SaveStore.create(dbPath(slotId), world, fs: fs);
    writeSummary(slotId, world);
    return store;
  }

  SaveStore open(String slotId) => SaveStore.open(dbPath(slotId), fs: fs);

  /// Call (and wait) before [open] (docs K218).
  Future<void> prepare(String slotId) => fs.prepare(dbPath(slotId));

  /// A copy of [slotId]'s database for a backup (docs K219), compacted
  /// and whole even if the career is open. On the web, [prepare] first.
  Uint8List backupOf(String slotId) {
    final tmp = '$rootPath/$slotId/backup.tmp';
    fs.deleteFile(tmp);
    final db = fs.openDatabase(dbPath(slotId));
    try {
      db.execute('VACUUM INTO ?', [tmp]);
    } finally {
      db.dispose();
    }
    final bytes = fs.readBytes(tmp)!;
    fs.deleteFile(tmp);
    return bytes;
  }

  /// A new slot holding the database [bytes] from a backup (docs K219).
  /// The caller opens it to check it, and deletes the slot if it fails.
  String restoreInto(Uint8List bytes) {
    const header = 'SQLite format 3';
    if (bytes.length < 100 ||
        String.fromCharCodes(bytes.sublist(0, header.length)) != header) {
      throw const FormatException('Not a career database');
    }
    final slotId = 'career_${DateTime.now().microsecondsSinceEpoch}';
    fs.makeFolder('$rootPath/$slotId');
    fs.writeBytes(dbPath(slotId), bytes);
    return slotId;
  }

  /// Premium daily login bonus: true at most once per local calendar day for
  /// the whole account (not per slot), and records the claim. The caller
  /// checks Premium and then credits it with `Actions.grantDailyBonus`.
  bool claimDailyBonus(DateTime now) {
    final path = '$rootPath/account.json';
    final text = fs.readText(path);
    final account = text != null
        ? jsonDecode(text) as Map<String, Object?>
        : <String, Object?>{};
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    if (account['lastDailyBonus'] == today) return false;
    account['lastDailyBonus'] = today;
    fs.writeText(path, jsonEncode(account));
    return true;
  }

  void writeSummary(String slotId, World w) {
    final p = w.player;
    // The latest album and the biggest US hit, for the career list (E9).
    var lastAlbum = -1, hit = -1, hitPeak = 0;
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.albumId > lastAlbum &&
          w.albums[s.albumId].type != AlbumType.single) {
        lastAlbum = s.albumId;
      }
      final peak = s.statsOrNull(Charts.usSongs)?.peak ?? 0;
      if (peak > 0 && (hit < 0 || peak < hitPeak)) {
        hit = id;
        hitPeak = peak;
      }
    }
    fs.writeText(
        '$rootPath/$slotId/summary.json',
        jsonEncode({
          'slotId': slotId,
          'artistName': p?.name,
          'artistId': p?.id,
          'kind': p?.kind.name,
          'genre': p?.genre,
          'difficulty': w.difficulty.name,
          'year': GameTime.yearOf(w.week),
          'weekOfYear': GameTime.weekOfYear(w.week),
          'fame': p?.fame,
          'coreFans': p?.coreFans,
          'moneyCents': p?.moneyCents,
          'lastAlbumId': lastAlbum,
          'lastAlbumTitle': lastAlbum >= 0 ? w.albums[lastAlbum].title : null,
          'hitTitle': hit >= 0 ? w.songs[hit].title : null,
          'hitPeak': hitPeak,
          'savedAt': DateTime.now().toUtc().toIso8601String(),
        }));
  }

  void delete(String slotId) => fs.deleteFolder('$rootPath/$slotId');
}
