import 'config/sim_config.dart';
import 'model.dart';

/// The hot, in-memory simulation state ("current world").
class World {
  World({required this.config, required this.seed, required this.week});

  final SimConfig config;
  final int seed;

  /// Current week (the next week to be simulated).
  int week;

  final List<Artist> artists = [];
  final List<Song> songs = [];
  final List<Album> albums = [];
  final List<Collaborator> collaborators = [];

  int playerArtistId = -1;

  /// Non-retired artists, sorted by id. Weekly loops run over these only.
  final List<int> activeArtistIds = [];

  /// Cumulative streams-per-attention and catalog-downloads-per-attention.
  double spaIndex = 0;
  double dpaIndex = 0;

  /// Σ sumDormantRate × catalogFactor over retired artists (frozen factors).
  double retiredDormantAttention = 0;

  int dormantSongCount = 0;

  // Entities changed outside the active sets since the last save.
  final Set<int> dirtyArtists = {};
  final Set<int> dirtySongs = {};
  final Set<int> dirtyAlbums = {};

  /// Released, non-dormant songs, kept sorted by id.
  final List<int> activeSongIds = [];

  /// Released, non-dormant albums (album/EP only), kept sorted by id.
  final List<int> activeAlbumIds = [];

  // Smoothed simulated totals used for the "rest of the market" term.
  double emaAttention = 0;
  double emaDownloadDemand = 0;
  double emaRadioDemand = 0;

  // Last chart cut-offs (points of last place).
  double songCutoff = 0;
  double albumCutoff = 0;

  List<ChartEntry> songChart = const [];
  List<ChartEntry> albumChart = const [];

  Artist? get player => playerArtistId >= 0 ? artists[playerArtistId] : null;

  Artist primaryOf(Song s) => artists[s.primaryArtistId];

  void addArtist(Artist a) {
    assert(a.id == artists.length);
    artists.add(a);
    insertSorted(activeArtistIds, a.id);
    a.catalogSettleSpa = spaIndex;
    a.catalogSettleDpa = dpaIndex;
    dirtyArtists.add(a.id);
  }

  /// Retires an artist; from now on their catalog accrues lazily.
  void retire(Artist a) {
    if (a.isRetired) return;
    a.retiredWeek = week;
    final i = activeArtistIds.indexOf(a.id);
    if (i >= 0) activeArtistIds.removeAt(i);
    retiredDormantAttention += a.sumDormantRate * a.catalogFactor;
    dirtyArtists.add(a.id);
  }

  /// Brings a retired artist's catalog accounting up to date.
  void settleRetired(Artist a) {
    if (!a.isRetired) return;
    final ds = spaIndex - a.catalogSettleSpa;
    final dd = dpaIndex - a.catalogSettleDpa;
    if (ds == 0 && dd == 0) return;
    final f = a.catalogFactor;
    a.catalogIndexStreams += f * ds;
    a.catalogIndexDownloads += f * dd;
    a.lifetimeStreams += a.sumDormantRate * f * ds;
    a.lifetimeDownloads += a.sumDormantRate * f * dd;
    a.catalogSettleSpa = spaIndex;
    a.catalogSettleDpa = dpaIndex;
    dirtyArtists.add(a.id);
  }

  /// Catalog index including lazily accrued weeks for retired artists.
  double artistIndexStreams(Artist a) => a.isRetired
      ? a.catalogIndexStreams +
          a.catalogFactor * (spaIndex - a.catalogSettleSpa)
      : a.catalogIndexStreams;

  double artistIndexDownloads(Artist a) => a.isRetired
      ? a.catalogIndexDownloads +
          a.catalogFactor * (dpaIndex - a.catalogSettleDpa)
      : a.catalogIndexDownloads;

  double artistLifetimeStreams(Artist a) => a.isRetired
      ? a.lifetimeStreams +
          a.sumDormantRate * a.catalogFactor * (spaIndex - a.catalogSettleSpa)
      : a.lifetimeStreams;

  /// Lifetime streams of a song, including lazily accrued dormant streams.
  double songLifetimeStreams(Song s) {
    if (s.status != SongStatus.dormant) return s.lifetimeStreams;
    final a = primaryOf(s);
    return s.lifetimeStreams +
        s.dormantRate * (artistIndexStreams(a) - s.indexAtSettleStreams);
  }

  double songLifetimeDownloads(Song s) {
    if (s.status != SongStatus.dormant) return s.lifetimeDownloads;
    final a = primaryOf(s);
    return s.lifetimeDownloads +
        s.dormantRate * (artistIndexDownloads(a) - s.indexAtSettleDownloads);
  }

  /// Lifetime units of an album, including lazily accrued SEA while dormant.
  double albumLifetimeUnits(Album al) {
    if (al.status == AlbumStatus.active) return al.lifetimeUnits;
    final a = artists[al.artistId];
    return al.lifetimeUnits +
        al.sumDormantRate *
            (artistIndexStreams(a) - al.indexAtSettle) /
            config.streamEquivalentAlbum;
  }

  static void insertSorted(List<int> list, int id) {
    var lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid] < id) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo < list.length && list[lo] == id) return;
    list.insert(lo, id);
  }
}
