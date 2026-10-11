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

  /// Lifetime streams of a song, including lazily accrued dormant streams.
  double songLifetimeStreams(Song s) {
    if (s.status != SongStatus.dormant) return s.lifetimeStreams;
    final a = primaryOf(s);
    return s.lifetimeStreams +
        s.dormantRate * (a.catalogIndexStreams - s.indexAtSettleStreams);
  }

  double songLifetimeDownloads(Song s) {
    if (s.status != SongStatus.dormant) return s.lifetimeDownloads;
    final a = primaryOf(s);
    return s.lifetimeDownloads +
        s.dormantRate * (a.catalogIndexDownloads - s.indexAtSettleDownloads);
  }

  /// Lifetime units of an album, including lazily accrued SEA while dormant.
  double albumLifetimeUnits(Album al) {
    if (al.status == AlbumStatus.active) return al.lifetimeUnits;
    final a = artists[al.artistId];
    return al.lifetimeUnits +
        al.sumDormantRate *
            (a.catalogIndexStreams - al.indexAtSettle) /
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
