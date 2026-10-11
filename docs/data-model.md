# Veri Modeli

Her kayıt slotu tek bir SQLite dosyasıdır (drift). Tüm ID'ler `INTEGER`'dır (UUID değil;
milyonlarca satırlık index'lerde boyut farkı büyüktür). Sayımlar ve paralar `INTEGER` (64-bit; Dart `int`,
para cent cinsinden). Zaman birimi **mutlak hafta indeksi** (`week INTEGER`); takvim yılı ve
hafta numarası gösterimde türetilir (ISO yıllarının 52/53 hafta sorunu yaşanmaz).

## 1. Kavramsal model

```
Artist
 └── SongCredit (primary / featured)  ──▶ Song (eser)        ← şarkı listeleri bu seviyede
                                            └── Recording     ← original, remix, live, re-recording
Album (liste kimliği)                    ← albüm listeleri bu seviyede
 ├── AlbumCredit (primary / featured)
 └── Edition (standard, deluxe, anniversary)
      ├── EditionTrack ──▶ Recording
      └── Variant / SKU (CD, renkli vinil, imzalı, dijital…)  ← sadece satış/maliyet
Era (sanatçı + albüm dönemi; eraScore, flop faktörleri)
```

- Remix ve orijinal aynı **Song**'un kayıtlarıdır; listede birleşir.
- Deluxe aynı **Album**'ün bir edition'ıdır; listede birleşir, stream'ler iki kez sayılmaz.
- Single de bir Album kaydıdır (`type = single`).
- MVP'de her Song'un tek bir `original` Recording'i olur; tablo ileride remix/live için hazırdır.
- Haftalık stream/satış istatistikleri **Song** seviyesinde tutulur. Albüm SEA'sı albümün
  şarkılarının stream'lerinden dönem kuralıyla hesaplanır (bir şarkı birden fazla albümde ise
  "ev albümü" kuralı konfigürasyondan gelir).

## 2. Şema (taslak)

```sql
-- Meta
CREATE TABLE meta (
  key TEXT PRIMARY KEY, value TEXT NOT NULL
); -- currentWeek, saveSeed, simulationVersion, contentVersion, difficulty, startYear, playerArtistID

-- Sanatçılar
CREATE TABLE artist (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  isPlayer INTEGER NOT NULL DEFAULT 0,
  tier INTEGER NOT NULL,                 -- 0 = oyuncu, 1 = A, 2 = B, 3 = C (materyalize)
  genreID INTEGER NOT NULL,
  debutWeek INTEGER NOT NULL,
  retiredWeek INTEGER,
  avatarAssetID INTEGER REFERENCES asset(id),   -- sadece oyuncu
  bannerAssetID INTEGER REFERENCES asset(id),   -- sadece oyuncu
  socialAvatarAssetID INTEGER REFERENCES asset(id)
);

CREATE TABLE artistState (               -- sıcak durum, her hafta güncellenir
  artistID INTEGER PRIMARY KEY REFERENCES artist(id),
  fame REAL, currentPopularity REAL, momentum REAL, buzz REAL, legacy REAL,
  coreFans INTEGER, casualAudience INTEGER, followers INTEGER,
  anticipation REAL, anticipationCap REAL,
  flopSupportLevel REAL,
  lastReleaseWeek INTEGER, lastPostWeek INTEGER, postFatigue REAL,
  currentEraID INTEGER, lastEraID INTEGER,
  catalogIndex REAL, sumDormantRate REAL,
  moneyCents INTEGER
);

-- Bölgesel hayran dağılımı (turne ve ileride çok ülke için hazırlık; MVP'de basit tutulur)
CREATE TABLE artistRegion (
  artistID INTEGER NOT NULL REFERENCES artist(id),
  regionID INTEGER NOT NULL,             -- Kuzey Amerika, Avrupa, Latin Amerika, Asya, Okyanusya…
  fanShare REAL NOT NULL,                -- sanatçının hayranlarının bu bölgedeki payı
  PRIMARY KEY (artistID, regionID)
) WITHOUT ROWID;

-- Şarkılar ve krediler (feat)
CREATE TABLE song (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  genreID INTEGER NOT NULL,
  createdWeek INTEGER NOT NULL,
  quality REAL, commercialAppeal REAL, fanAppeal REAL, radioAppeal REAL,
  streamingAppeal REAL, longevity REAL, virality REAL,
  homeAlbumID INTEGER
);

CREATE TABLE songCredit (
  songID INTEGER NOT NULL REFERENCES song(id),
  artistID INTEGER NOT NULL REFERENCES artist(id),
  role INTEGER NOT NULL,                 -- 0 = primary, 1 = featured
  position INTEGER NOT NULL,             -- gösterim sırası
  PRIMARY KEY (songID, artistID)
) WITHOUT ROWID;
CREATE INDEX songCredit_artist ON songCredit(artistID, songID);

CREATE TABLE recording (
  id INTEGER PRIMARY KEY,
  songID INTEGER NOT NULL REFERENCES song(id),
  kind INTEGER NOT NULL,                 -- original, remix, live, acoustic, reRecording
  title TEXT
);

-- Albümler, edition'lar, varyantlar
CREATE TABLE album (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  type INTEGER NOT NULL,                 -- single, ep, album, compilation
  eraID INTEGER,
  releaseWeek INTEGER,
  coverAssetID INTEGER REFERENCES asset(id)
);
CREATE TABLE albumCredit (
  albumID INTEGER NOT NULL, artistID INTEGER NOT NULL, role INTEGER NOT NULL, position INTEGER NOT NULL,
  PRIMARY KEY (albumID, artistID)
) WITHOUT ROWID;
CREATE INDEX albumCredit_artist ON albumCredit(artistID, albumID);

CREATE TABLE edition (
  id INTEGER PRIMARY KEY,
  albumID INTEGER NOT NULL REFERENCES album(id),
  kind INTEGER NOT NULL,                 -- standard, deluxe, anniversary, ...
  title TEXT,
  releaseWeek INTEGER NOT NULL,
  coverAssetID INTEGER REFERENCES asset(id)
);
CREATE TABLE editionTrack (
  editionID INTEGER NOT NULL, position INTEGER NOT NULL, recordingID INTEGER NOT NULL,
  PRIMARY KEY (editionID, position)
) WITHOUT ROWID;

CREATE TABLE variant (
  id INTEGER PRIMARY KEY,
  editionID INTEGER NOT NULL REFERENCES edition(id),
  format INTEGER NOT NULL,               -- vinyl, cassette, cd, digital, ...
  name TEXT NOT NULL,
  priceCents INTEGER, unitCostCents INTEGER,
  releaseWeek INTEGER NOT NULL,
  limitedQuantity INTEGER
);

-- Era
CREATE TABLE era (
  id INTEGER PRIMARY KEY,
  artistID INTEGER NOT NULL,
  albumID INTEGER,
  startWeek INTEGER NOT NULL, endWeek INTEGER,
  expected REAL, actual REAL, score REAL, result INTEGER
);
CREATE TABLE eraFactor (                 -- "Neden flop oldu?" raporu
  eraID INTEGER NOT NULL, factor INTEGER NOT NULL, weight REAL NOT NULL, refID INTEGER,
  PRIMARY KEY (eraID, factor)
) WITHOUT ROWID;

-- Takvim
CREATE TABLE scheduledEvent (
  id INTEGER PRIMARY KEY,
  week INTEGER NOT NULL,
  type INTEGER NOT NULL,
  artistID INTEGER, refID INTEGER,
  payload BLOB
);
CREATE INDEX scheduledEvent_week ON scheduledEvent(week, type);

-- Sosyal medya
CREATE TABLE socialPost (
  id INTEGER PRIMARY KEY,
  artistID INTEGER NOT NULL,
  week INTEGER NOT NULL,
  channelID INTEGER NOT NULL,            -- döneme göre platform / basın-TV
  assetID INTEGER REFERENCES asset(id),
  caption TEXT,
  likes INTEGER, comments INTEGER, newFollowers INTEGER, buzzGain REAL
);
CREATE INDEX socialPost_artist ON socialPost(artistID, week);

-- Görseller (dosyalar diskte; DB'de sadece referans)
CREATE TABLE asset (
  id INTEGER PRIMARY KEY,
  kind INTEGER NOT NULL,                 -- cover, avatar, banner, socialAvatar, post
  fileHash TEXT NOT NULL UNIQUE,         -- dosya adı = içerik hash'i
  width INTEGER, height INTEGER,
  refCount INTEGER NOT NULL DEFAULT 0
);

-- Sıcak şarkı durumu: sadece ACTIVE + CATALOG (+ oyuncu şarkıları)
CREATE TABLE songState (
  songID INTEGER PRIMARY KEY,
  status INTEGER NOT NULL,               -- active, catalog
  momentum REAL, popularity REAL,
  lastWeekStreams INTEGER, lastWeekPoints INTEGER,
  weeksBelowThreshold INTEGER
);
-- Dormant/Frozen alanları (tembel birikim)
CREATE TABLE songDormant (
  songID INTEGER PRIMARY KEY,
  frozen INTEGER NOT NULL DEFAULT 0,
  dormantRate REAL, indexAtSettle REAL, lifetimeAtSettle INTEGER, lastSettledWeek INTEGER
);
```

## 3. Toplamlar (artımlı, her hafta O(1))

UI açıldığında `SUM()` yapılmaz; toplamlar her hafta güncellenir.

```sql
CREATE TABLE songTotals (
  songID INTEGER PRIMARY KEY,
  streams INTEGER, downloads INTEGER, physicalSingles INTEGER, videoViews INTEGER, radioAudience INTEGER,
  peakPosUS INTEGER, peakPosGlobal INTEGER, weeksOnUS INTEGER, weeksAtNo1US INTEGER,
  certLevelUS INTEGER, nextCertThreshold INTEGER
);
CREATE TABLE albumTotals (
  albumID INTEGER PRIMARY KEY,
  pureSalesPhysical INTEGER, pureSalesDigital INTEGER, tea INTEGER, sea INTEGER, units INTEGER,
  firstWeekUnits INTEGER, peakPosUS INTEGER, weeksOnUS INTEGER, weeksAtNo1US INTEGER,
  certLevelUS INTEGER, nextCertThreshold INTEGER
);
-- Sanatçı: tüm kariyer, yıl bazında, era bazında; ana ve featured ayrı
CREATE TABLE artistTotals (
  artistID INTEGER NOT NULL, scope INTEGER NOT NULL, scopeKey INTEGER NOT NULL, -- scope: career/year/era
  streams INTEGER, videoViews INTEGER,
  pureAlbumPhysical INTEGER, pureAlbumDigital INTEGER, digitalSingles INTEGER, physicalSingles INTEGER,
  albumUnits INTEGER,
  no1Singles INTEGER, no1SinglesFeatured INTEGER, no1Albums INTEGER,
  weeksAtNo1 INTEGER, top10Singles INTEGER, top10SinglesFeatured INTEGER,
  revenueCents INTEGER, costCents INTEGER,
  PRIMARY KEY (artistID, scope, scopeKey)
) WITHOUT ROWID;
```

Debug ekranında "yeniden hesapla ve doğrula" aracı artımlı toplamları geçmişten kontrol eder.

## 4. Geçmiş

### 4.1 Listeler — değişmez
```sql
CREATE TABLE chartEntry (
  chartID INTEGER NOT NULL, week INTEGER NOT NULL, position INTEGER NOT NULL,
  entityID INTEGER NOT NULL,            -- songID veya albumID (listeye göre)
  points INTEGER NOT NULL,
  lastWeek INTEGER, peak INTEGER, weeksOn INTEGER,   -- denormalize: tek okumada liste
  PRIMARY KEY (chartID, week, position)
) WITHOUT ROWID;
CREATE INDEX chartEntry_entity ON chartEntry(entityID, chartID, week);
```
Hacim: haftada ~700 satır × 2.600 hafta ≈ 1,8M satır.
Sanatçının liste geçmişi: `songCredit`/`albumCredit` üzerinden `chartEntry_entity` index'i ile.

### 4.2 Haftalık istatistikler — hibrit

| Kim | Ne saklanır |
|---|---|
| **Oyuncunun tüm şarkıları/albümleri** | **Her hafta, kalıcı** (50 yıl × 500 şarkı ≈ 30–40 MB) |
| Tier A şarkıları | Aktif haftalar haftalık; sonrası aylık |
| Tier B | Sadece listede olduğu haftalar |
| Tier C | Hiçbir şey (liste satırları hariç) |
| Dormant dönemler | Satır yok; grafik kümülatif indeks formülüyle doldurur |

```sql
CREATE TABLE songWeek (
  songID INTEGER NOT NULL, week INTEGER NOT NULL,
  streams INTEGER, downloads INTEGER, physical INTEGER, radioAudience INTEGER, videoViews INTEGER,
  PRIMARY KEY (songID, week)
) WITHOUT ROWID;                          -- bir şarkının geçmişi diskte bitişik

CREATE TABLE albumWeek (
  albumID INTEGER NOT NULL, week INTEGER NOT NULL,
  pureSalesPhysical INTEGER, pureSalesDigital INTEGER, tea INTEGER, sea INTEGER, units INTEGER,
  PRIMARY KEY (albumID, week)
) WITHOUT ROWID;

-- Grafik çözünürlükleri: yazma anında O(1) güncellenir
CREATE TABLE songMonth (songID INTEGER, month INTEGER, streams INTEGER, sales INTEGER,
                        bestPosUS INTEGER, PRIMARY KEY (songID, month)) WITHOUT ROWID;
CREATE TABLE songYear  (songID INTEGER, year INTEGER,  streams INTEGER, sales INTEGER,
                        bestPosUS INTEGER, PRIMARY KEY (songID, year))  WITHOUT ROWID;
-- (albüm ve sanatçı için de aynısı)
```

Toplama kuralları: stream/satış **toplanır**, liste pozisyonu için bucket içindeki **en iyi** değer
saklanır (ortalama alınırsa #1 zirvesi grafikten kaybolur).

## 5. Diğer

```sql
CREATE TABLE certification (entityKind INTEGER, entityID INTEGER, marketID INTEGER,
                            level INTEGER, week INTEGER,
                            PRIMARY KEY (entityKind, entityID, marketID, level)) WITHOUT ROWID;
CREATE TABLE record (recordKey INTEGER PRIMARY KEY, holderKind INTEGER, holderID INTEGER,
                     value INTEGER, week INTEGER);
CREATE TABLE recordHistory (recordKey INTEGER, week INTEGER, holderKind INTEGER, holderID INTEGER,
                            value INTEGER, PRIMARY KEY (recordKey, week)) WITHOUT ROWID;
CREATE TABLE notification (id INTEGER PRIMARY KEY, week INTEGER, kind INTEGER, payload BLOB);
```

## 6. Index kuralları

- En büyük tablolarda **tek kümeleme anahtarı** (bileşik PK + `WITHOUT ROWID`), gereksiz ikinci index yok.
- Düşük kardinaliteli kolonlara (status) index yerine ayrı küçük tablo (`songState`) veya partial index.
- Test: tüm sıcak sorgularda `EXPLAIN QUERY PLAN` çalıştırılır; büyük tablolarda `SCAN` görülürse test başarısız olur.

## 7. Migrasyonlar
- drift şema versiyonları ve migrasyon adımları; her migrasyon numaralı ve geri alınamaz.
- `meta.simulationVersion` formül değişikliklerini, `meta.contentVersion` konfigürasyon değişikliklerini izler.
- Eski kayıtlar açılırken migrasyon uygulanır; geçmiş satırlar asla yeniden hesaplanmaz.
