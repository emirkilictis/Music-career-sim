import 'codec.dart';

/// Versioned schema. Each entry migrates the database from version i to i+1
/// (docs/data-model.md). Never edit a shipped migration; append a new one.
/// (v1 has not shipped yet, so it is still being shaped.)
final List<String> migrations = [
  _v1(), _v2, _v3, _v4, _v5, _v6, _v7, _v8, _v9, _v10, _v11, _v12, _v13,
  _v14, _v15, _v16, _v17, _v18, _v19, _v20, _v21, _v22, _v23, _v24, _v25, _v26, _v27, _v28, _v29, _v30, //
];

/// v30: re-recordings and label-owned masters (docs K139).
const _v30 = '''
ALTER TABLE song ADD COLUMN rerecordOf INTEGER;
ALTER TABLE song ADD COLUMN replacedWeek INTEGER;
ALTER TABLE song ADD COLUMN masterShare REAL;
ALTER TABLE album ADD COLUMN masterShare REAL;
''';

/// v29: holiday songs (docs K136).
const _v29 = '''
ALTER TABLE song ADD COLUMN holiday INTEGER;
''';

/// v28: streaming exclusives (docs K135).
const _v28 = '''
ALTER TABLE album ADD COLUMN exclusiveUntil INTEGER;
ALTER TABLE album ADD COLUMN exclusiveFee INTEGER;
''';

/// v27: the radio format a single is worked to (docs K134).
const _v27 = '''
ALTER TABLE song ADD COLUMN radioFormat INTEGER;
''';

/// v26: creator campaigns on the short-video app (docs K131).
const _v26 = '''
ALTER TABLE song ADD COLUMN creator TEXT;
''';

/// v25: album copies ordered before the release (docs K126).
const _v25 = '''
ALTER TABLE album ADD COLUMN preOrders REAL;
''';

/// v24: the week of the artist's last surprise drop (docs K124).
const _v24 = '''
ALTER TABLE artist ADD COLUMN surpriseWeek INTEGER;
''';

/// v23: where a player song's listening came from last week (docs K120)
/// and the pre-saves it came out with (K121).
const _v23 = '''
ALTER TABLE song ADD COLUMN sources TEXT;
ALTER TABLE song ADD COLUMN preSaves REAL;
''';

/// v22: when a song's music video came out (docs K118).
const _v22 = '''
ALTER TABLE song ADD COLUMN videoWeek INTEGER;
ALTER TABLE song ADD COLUMN videoBase REAL;
''';

/// v21: the record deal signed and what of its advance is unrecouped
/// (docs K107).
const _v21 = '''
ALTER TABLE artist ADD COLUMN dealAdvance INTEGER;
ALTER TABLE artist ADD COLUMN dealAlbums INTEGER;
ALTER TABLE artist ADD COLUMN unrecouped INTEGER;
''';

/// v20: bought streams, autoplay and playlist pitches (docs K95–K97).
const _v20 = '''
ALTER TABLE song ADD COLUMN bots TEXT;
ALTER TABLE song ADD COLUMN autoplay INTEGER;
ALTER TABLE song ADD COLUMN pitchWeek INTEGER;
''';

/// v19: a song's versions and a single's physical editions (docs K92).
const _v19 = '''
ALTER TABLE song ADD COLUMN versions TEXT;
ALTER TABLE song ADD COLUMN variants TEXT;
ALTER TABLE song ADD COLUMN versionBoost REAL;
''';

/// v18: a single's paid radio push (docs K84).
const _v18 = 'ALTER TABLE song ADD COLUMN radioPush INTEGER;';

/// v17: how unsure the team's grade estimate is (docs F36).
const _v17 = 'ALTER TABLE song ADD COLUMN gradeSpread INTEGER;';

/// v16: the player's manager (docs K68).
const _v16 = 'ALTER TABLE artist ADD COLUMN manager INTEGER;';

/// v15: the player's tour (docs K63).
const _v15 = 'ALTER TABLE artist ADD COLUMN tour TEXT;';

/// v14: career milestones reached (docs K61).
const _v14 = 'ALTER TABLE artist ADD COLUMN milestones TEXT;';

/// v13: the player's income per song and album (docs K60).
const _v13 = '''
  ALTER TABLE song ADD COLUMN revenue REAL;
  ALTER TABLE song ADD COLUMN productionCost INTEGER;
  ALTER TABLE album ADD COLUMN revenue REAL;
''';

/// v12: the player's waiting offer (docs K59).
const _v12 = 'ALTER TABLE artist ADD COLUMN opportunity TEXT;';

/// v11: campaign fatigue and profit/loss (docs K57).
const _v11 = '''
  ALTER TABLE artist ADD COLUMN campaignFatigue REAL;
  ALTER TABLE song ADD COLUMN campaignPower REAL;
  ALTER TABLE song ADD COLUMN campaignCost INTEGER;
  ALTER TABLE song ADD COLUMN campaignReturn REAL;
  ALTER TABLE album ADD COLUMN campaignCost INTEGER;
  ALTER TABLE album ADD COLUMN campaignReturn REAL;
''';

/// v10: album units from pre-released singles (docs K56).
const _v10 = 'ALTER TABLE album ADD COLUMN preSingleUnits REAL;';

/// v9: album review scores (docs K55).
const _v9 = 'ALTER TABLE album ADD COLUMN criticScore REAL;';

/// v8: the player's record label and contract (docs K54).
const _v8 = '''
  ALTER TABLE artist ADD COLUMN label INTEGER;
  ALTER TABLE artist ADD COLUMN contractAlbums INTEGER;
''';

/// v7: the schedule an album came out of (its advance cover).
const _v7 = 'ALTER TABLE album ADD COLUMN scheduleId INTEGER;';

/// v6: music videos (docs K52).
const _v6 = '''
  ALTER TABLE song ADD COLUMN videoBudget INTEGER;
  ALTER TABLE song ADD COLUMN videoPower REAL;
''';

/// v5: album edition formats (docs K46).
const _v5 = 'ALTER TABLE album ADD COLUMN editionFormats TEXT;';

/// v4: the player's scheduled releases as JSON (docs K45).
const _v4 = 'ALTER TABLE artist ADD COLUMN schedule TEXT;';

/// v3: unspent skill points (docs K43).
const _v3 = 'ALTER TABLE artist ADD COLUMN skillPoints INTEGER;';

/// v2: a song's weekly streams/downloads per region (so "this week" numbers
/// survive closing and reopening a career), its CD single sales, and the
/// artist's rest week.
const _v2 = '''
  ALTER TABLE song ADD COLUMN weekRegion TEXT;
  ALTER TABLE song ADD COLUMN lifetimePhysical REAL;
  ALTER TABLE artist ADD COLUMN restWeek INTEGER;
''';

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
    extraGenres TEXT,
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
