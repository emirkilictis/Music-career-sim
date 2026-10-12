import 'codec.dart';

/// Versioned schema. Each entry migrates the database from version i to i+1
/// (docs/data-model.md). Never edit a shipped migration; append a new one.
/// (v1 has not shipped yet, so it is still being shaped.)
final List<String> migrations = [_v1()];

String _cols(List<String> names, String type) =>
    names.map((n) => '$n $type').join(', ');

String _v1() => '''
  CREATE TABLE meta (key TEXT PRIMARY KEY, value) WITHOUT ROWID;

  CREATE TABLE artist (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    tier INTEGER NOT NULL,
    genre INTEGER NOT NULL,
    homeCountry INTEGER NOT NULL,
    debutWeek INTEGER NOT NULL,
    retiredWeek INTEGER NOT NULL,
    songwriting REAL, vocals REAL, production REAL, performance REAL, charisma REAL,
    fame REAL, popularity REAL, coreFans REAL, casual REAL, buzz REAL, devotion REAL,
    hype REAL, anticipation REAL, anticipationCap REAL,
    eraOpen INTEGER, eraAlbumId INTEGER, eraStartWeek INTEGER, eraUnits REAL,
    eraExpected REAL, lastEraUnits REAL, lastEraResult INTEGER, flopSupport REAL,
    lastReleaseWeek INTEGER,
    creativeEnergy REAL, burnoutUntilWeek INTEGER, lastWriteWeek INTEGER,
    songsWrittenThisWeek INTEGER,
    kind INTEGER, members TEXT,
    hasJob INTEGER, lastAdWeek INTEGER, adsWatchedThisWeek INTEGER,
    labelReach REAL, artistShare REAL, moneyCents INTEGER,
    sumDormantRate REAL,
    nextEraWeek INTEGER, plan TEXT, pendingSongs TEXT, pendingAlbumTitle TEXT,
    pendingAlbumType INTEGER, pendingVariants TEXT,
    ${_cols(Codec.artistRegColumns, 'REAL')},
    no1Singles TEXT, no1SinglesFeatured TEXT, no1Albums TEXT, weeksAtNo1 TEXT
  );

  CREATE TABLE song (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    genre INTEGER NOT NULL,
    primaryArtistId INTEGER NOT NULL,
    writtenWeek INTEGER NOT NULL,
    quality REAL, commercial REAL, fanAppeal REAL, radioAppeal REAL,
    virality REAL, longevity REAL, estimatedGrade INTEGER,
    status INTEGER NOT NULL, releasedWeek INTEGER, albumId INTEGER,
    isSingle INTEGER, singleWeek INTEGER,
    lastAttention REAL, lastReach REAL, weekStreams REAL, weekDownloads REAL,
    weekPhysical REAL, weekRadio REAL, weekPoints REAL, viralBoost REAL, viralRamp INTEGER,
    campaign INTEGER, playlistAdd INTEGER, playlistWeek INTEGER, playlistBoost REAL,
    weeksBelowCutoff INTEGER, lifetimeRadio REAL, dormantRate REAL,
    ${_cols(Codec.songRegColumns, 'REAL')},
    charts TEXT
  );
  CREATE INDEX song_artist ON song(primaryArtistId);
  CREATE INDEX song_album ON song(albumId);

  -- Featured artists (the primary artist lives on the song row).
  CREATE TABLE songCredit (
    songId INTEGER NOT NULL, artistId INTEGER NOT NULL, position INTEGER NOT NULL,
    PRIMARY KEY (songId, artistId)
  ) WITHOUT ROWID;
  CREATE INDEX songCredit_artist ON songCredit(artistId, songId);

  CREATE TABLE album (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    artistId INTEGER NOT NULL,
    type INTEGER NOT NULL,
    releaseWeek INTEGER NOT NULL,
    quality REAL,
    status INTEGER NOT NULL, hypeAtRelease REAL, campaign INTEGER, variants TEXT,
    weekPure REAL, weekTea REAL, weekSea REAL, weekUnits REAL, weeksBelowCutoff INTEGER,
    firstWeekUnits REAL, firstWeekPure REAL, sumDormantRate REAL,
    ${_cols(Codec.albumRegColumns, 'REAL')},
    charts TEXT
  );
  CREATE INDEX album_artist ON album(artistId, releaseWeek);

  CREATE TABLE albumTrack (
    albumId INTEGER NOT NULL, position INTEGER NOT NULL, songId INTEGER NOT NULL,
    PRIMARY KEY (albumId, position)
  ) WITHOUT ROWID;

  -- Weekly snapshot of the hot world (active artists/songs/albums) as one
  -- binary blob; relational rows for active entities are flushed periodically.
  CREATE TABLE hotState (id INTEGER PRIMARY KEY, week INTEGER NOT NULL, data BLOB NOT NULL);

  CREATE TABLE collaborator (
    id INTEGER PRIMARY KEY, name TEXT NOT NULL, role INTEGER NOT NULL, skill REAL,
    genre INTEGER, feeCents INTEGER, minFame REAL
  );

  -- History: immutable once written. chartId = Charts.* in simulation_core.
  CREATE TABLE chartEntry (
    chartId INTEGER NOT NULL, week INTEGER NOT NULL, position INTEGER NOT NULL,
    entityId INTEGER NOT NULL, points INTEGER NOT NULL,
    lastPos INTEGER, peak INTEGER, weeksOn INTEGER,
    PRIMARY KEY (chartId, week, position)
  ) WITHOUT ROWID;
  CREATE INDEX chartEntry_entity ON chartEntry(entityId, chartId, week);

  CREATE TABLE songWeek (
    songId INTEGER NOT NULL, week INTEGER NOT NULL,
    streams REAL, downloads REAL, radio REAL, physical REAL, points REAL,
    streamsNA REAL, streamsEU REAL, streamsOT REAL,
    PRIMARY KEY (songId, week)
  ) WITHOUT ROWID;

  CREATE TABLE albumWeek (
    albumId INTEGER NOT NULL, week INTEGER NOT NULL,
    pure REAL, tea REAL, sea REAL, units REAL,
    pureNA REAL, pureEU REAL, pureOT REAL, unitsNA REAL, unitsEU REAL, unitsOT REAL,
    PRIMARY KEY (albumId, week)
  ) WITHOUT ROWID;

  CREATE TABLE playerWeek (
    week INTEGER PRIMARY KEY,
    fame REAL, popularity REAL, coreFans REAL, casual REAL, devotion REAL,
    moneyCents INTEGER, lifetimeStreams REAL
  );
''';
