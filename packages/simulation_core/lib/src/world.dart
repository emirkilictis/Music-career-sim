import 'dart:math' as math;
import 'dart:typed_data';

import 'awards.dart';
import 'brands.dart';
import 'channel.dart';
import 'social.dart';
import 'config/charts.dart';
import 'config/difficulty.dart';
import 'config/regions.dart';
import 'config/sim_config.dart';
import 'festivals.dart';
import 'model.dart';
import 'award_campaigns.dart';
import 'documentaries.dart';
import 'streamify_sessions.dart';
import 'artist_pick.dart';
import 'fan_club.dart';
import 'imprints.dart';
import 'own_playlist.dart';
import 'music_show.dart';
import 'rival_splits.dart';
import 'tours.dart';

/// The hot, in-memory simulation state ("current world").
class World {
  World({
    required this.config,
    required this.seed,
    required this.week,
    this.difficulty = Difficulty.normal,
    this.realNames = false,
  }) : regionalEra = RegionalEra(config.era);

  final SimConfig config;
  final RegionalEra regionalEra;
  final int seed;

  /// Chosen when the career starts; scales only the player's numbers.
  final Difficulty difficulty;

  /// Rivals carry real artists' names where one fits (docs K66).
  final bool realNames;

  /// Current week (the next week to be simulated).
  int week;

  final List<Artist> artists = [];
  final List<Song> songs = [];
  final List<Album> albums = [];
  final List<Collaborator> collaborators = [];

  int playerArtistId = -1;

  /// Tours for the box-office rankings: rivals' and the player's finished
  /// ones (docs K77).
  final List<TourRecord> tourRecords = [];

  /// The player's festival slots to come (docs K77).
  final List<FestivalBooking> festivalBookings = [];

  /// Golden Record Awards, nominated and held (docs K91).
  final List<AwardShow> awardShows = [];

  /// The player's social media (docs K93).
  final SocialState social = SocialState();

  /// The player's brand deals, running and past (docs K102).
  final List<BrandDeal> brandDeals = [];

  /// The player's most monthly listeners on the streaming app so far (docs
  /// K156; -1: not known yet, set quietly on the next week).
  double playerPeakListeners = -1;

  /// The player's channel videos besides music videos (docs K142).
  final List<ChannelVideo> channelVideos = [];

  /// The player's own playlist on the streaming app (docs K159).
  OwnPlaylist? ownPlaylist;

  /// The player's paid fan club (docs K164).
  FanClub? fanClub;

  /// The player's own label (docs K169).
  Imprint? imprint;

  /// The player's latest awards campaign (docs K171).
  FycCampaign? fycCampaign;

  /// The player's documentaries (docs K172).
  final List<Documentary> documentaries = [];

  /// What the player pinned on their streaming profile (docs K185).
  ArtistPick? artistPick;

  /// The player's Streamify Sessions (docs K178).
  final List<StreamifySession> streamifySessions = [];

  /// The week the editors made the player's This Is list, or -1 (docs
  /// K189).
  int thisIsWeek = -1;

  /// After the player went solo (docs K191): the group they left (-1:
  /// never did), the week they became the player's artist, and what the
  /// career had streamed before them, so the career's streams run on.
  int formerGroupId = -1;
  int playerSinceWeek = 0;
  double careerStreamsBase = 0;

  /// The group's audience just before the player left it (docs K194).
  double formerFans = 0, formerCasual = 0, formerFame = 0;

  /// The player's reunion with that group (docs K194): when it started
  /// and ends (-1: none yet), and whether the group had ended before.
  int reunionStartWeek = -1, reunionEndWeek = -1;
  bool reunionWasRetired = false;

  /// Rival groups' members who went solo (docs K199).
  final List<RivalSplit> rivalSplits = [];

  /// The K-pop music show's record (docs K114).
  final MusicShowState musicShow = MusicShowState();

  /// The week's top artists by chart points, best first, and last week's
  /// (docs K113; ids).
  List<int> artistChart = const [];
  List<int> artistChartPrev = const [];

  /// The player's best place on it (0: never on it) and weeks at #1.
  int playerBestArtistRank = 0;
  int playerWeeksTopArtist = 0;

  /// Non-retired artists, sorted by id. Weekly loops run over these only.
  final List<int> activeArtistIds = [];

  /// Cumulative streams-per-attention and catalog-downloads-per-attention,
  /// per region.
  final Float64List spaIndex = Float64List(regionCount);
  final Float64List dpaIndex = Float64List(regionCount);

  /// Last simulated week's streams/downloads per attention, per region; lets
  /// the UI show "this week" numbers for catalog (dormant) songs in O(1).
  final Float64List lastSpa = Float64List(regionCount);
  final Float64List lastDpa = Float64List(regionCount);

  /// The player's songs (written or released), so player screens and saves
  /// never scan the whole world.
  final List<int> playerSongIds = [];

  /// Songs the player wrote for other artists (docs K143).
  final List<int> writtenSongIds = [];

  /// The player's members' solo songs, and rivals' songs the player is
  /// featured on (docs K158).
  final List<int> managedSongIds = [];
  final List<int> guestSongIds = [];

  /// Per region: Σ sumDormantRate × catalogFactor × regionShare over retired
  /// artists (their factors are frozen).
  final Float64List retiredDormantAttention = Float64List(regionCount);

  int dormantSongCount = 0;

  // Entities changed outside the active sets since the last save.
  final Set<int> dirtyArtists = {};
  final Set<int> dirtySongs = {};
  final Set<int> dirtyAlbums = {};

  /// Released, non-dormant songs, kept sorted by id.
  final List<int> activeSongIds = [];

  /// Released, non-dormant albums (album/EP only), kept sorted by id.
  final List<int> activeAlbumIds = [];

  // Smoothed simulated totals per region for the "rest of the market" term.
  final Float64List emaAttention = Float64List(regionCount);
  final Float64List emaDownloadDemand = Float64List(regionCount);
  final Float64List emaRadioDemand = Float64List(regionCount);

  /// Last week's last-place points for every chart.
  final Float64List chartCutoff = Float64List(Charts.count);

  /// Latest published charts, by chart id.
  List<List<ChartEntry>> charts =
      List.generate(Charts.count, (_) => const <ChartEntry>[]);

  List<ChartEntry> get songChart => charts[Charts.usSongs];
  List<ChartEntry> get albumChart => charts[Charts.usAlbums];

  Artist? get player => playerArtistId >= 0 ? artists[playerArtistId] : null;

  /// Everything the player's career has streamed, the group's years
  /// included after going solo (docs K191).
  double get playerCareerStreams {
    final p = player;
    return p == null ? 0 : careerStreamsBase + artistLifetimeStreams(p);
  }

  /// Fills [playerSongIds], [managedSongIds] and [guestSongIds] again
  /// from the songs, as a load does (after the player's artist changed).
  void rebuildPlayerSongLists() {
    playerSongIds.clear();
    managedSongIds.clear();
    guestSongIds.clear();
    for (final s in songs) {
      if (s.primaryArtistId == playerArtistId) playerSongIds.add(s.id);
      if (artists[s.primaryArtistId].managedBy == playerArtistId &&
          playerArtistId >= 0) {
        managedSongIds.add(s.id);
      } else if (s.primaryArtistId != playerArtistId &&
          s.featuredArtistIds.contains(playerArtistId)) {
        guestSongIds.add(s.id);
      }
    }
  }

  Artist primaryOf(Song s) => artists[s.primaryArtistId];

  void addArtist(Artist a) {
    assert(a.id == artists.length);
    artists.add(a);
    insertSorted(activeArtistIds, a.id);
    for (var r = 0; r < regionCount; r++) {
      a.reg[ArtistReg.settleSpa + r] = spaIndex[r];
      a.reg[ArtistReg.settleDpa + r] = dpaIndex[r];
    }
    dirtyArtists.add(a.id);
  }

  /// Retires an artist; from now on their catalog accrues lazily.
  void retire(Artist a) {
    if (a.isRetired) return;
    a.retiredWeek = week;
    final i = activeArtistIds.indexOf(a.id);
    if (i >= 0) activeArtistIds.removeAt(i);
    for (var r = 0; r < regionCount; r++) {
      retiredDormantAttention[r] +=
          a.sumDormantRate * a.catalogFactor * a.regionShare[r];
    }
    dirtyArtists.add(a.id);
  }

  /// Brings a retired artist back (docs K194): their catalog accrues week
  /// by week again.
  void unretire(Artist a) {
    if (!a.isRetired) return;
    settleRetired(a);
    for (var r = 0; r < regionCount; r++) {
      retiredDormantAttention[r] = math.max(0.0,
          retiredDormantAttention[r] -
              a.sumDormantRate * a.catalogFactor * a.regionShare[r]);
    }
    a.retiredWeek = -1;
    insertSorted(activeArtistIds, a.id);
    dirtyArtists.add(a.id);
  }

  /// Brings a retired artist's catalog accounting up to date.
  void settleRetired(Artist a) {
    if (!a.isRetired) return;
    final f = a.catalogFactor;
    var changed = false;
    for (var r = 0; r < regionCount; r++) {
      final ds = spaIndex[r] - a.reg[ArtistReg.settleSpa + r];
      final dd = dpaIndex[r] - a.reg[ArtistReg.settleDpa + r];
      if (ds == 0 && dd == 0) continue;
      changed = true;
      final share = a.regionShare[r];
      a.reg[ArtistReg.indexStreams + r] += f * share * ds;
      a.reg[ArtistReg.indexDownloads + r] += f * share * dd;
      a.reg[ArtistReg.lifeStreams + r] += a.sumDormantRate * f * share * ds;
      a.reg[ArtistReg.lifeDownloads + r] += a.sumDormantRate * f * share * dd;
      a.reg[ArtistReg.settleSpa + r] = spaIndex[r];
      a.reg[ArtistReg.settleDpa + r] = dpaIndex[r];
    }
    if (changed) dirtyArtists.add(a.id);
  }

  /// Catalog index in region [r], including lazily accrued weeks for
  /// retired artists.
  double artistIndexStreams(Artist a, int r) {
    final v = a.reg[ArtistReg.indexStreams + r];
    if (!a.isRetired) return v;
    return v +
        a.catalogFactor *
            a.regionShare[r] *
            (spaIndex[r] - a.reg[ArtistReg.settleSpa + r]);
  }

  double artistIndexDownloads(Artist a, int r) {
    final v = a.reg[ArtistReg.indexDownloads + r];
    if (!a.isRetired) return v;
    return v +
        a.catalogFactor *
            a.regionShare[r] *
            (dpaIndex[r] - a.reg[ArtistReg.settleDpa + r]);
  }

  /// Lifetime streams of an artist in region [r] (or all regions).
  double artistLifetimeStreams(Artist a, [int? r]) {
    if (r == null) {
      var t = 0.0;
      for (var i = 0; i < regionCount; i++) {
        t += artistLifetimeStreams(a, i);
      }
      return t;
    }
    final v = a.reg[ArtistReg.lifeStreams + r];
    if (!a.isRetired) return v;
    return v +
        a.sumDormantRate *
            a.catalogFactor *
            a.regionShare[r] *
            (spaIndex[r] - a.reg[ArtistReg.settleSpa + r]);
  }

  /// Lifetime streams of a song in region [r] (or all regions), including
  /// lazily accrued dormant streams.
  double songLifetimeStreams(Song s, [int? r]) {
    if (r == null) {
      var t = 0.0;
      for (var i = 0; i < regionCount; i++) {
        t += songLifetimeStreams(s, i);
      }
      return t;
    }
    final v = s.reg[SongReg.lifeStreams + r];
    if (s.status != SongStatus.dormant) return v;
    return v +
        s.dormantRate *
            (artistIndexStreams(primaryOf(s), r) -
                s.reg[SongReg.indexStreams + r]);
  }

  double songLifetimeDownloads(Song s, [int? r]) {
    if (r == null) {
      var t = 0.0;
      for (var i = 0; i < regionCount; i++) {
        t += songLifetimeDownloads(s, i);
      }
      return t;
    }
    final v = s.reg[SongReg.lifeDownloads + r];
    if (s.status != SongStatus.dormant) return v;
    return v +
        s.dormantRate *
            (artistIndexDownloads(primaryOf(s), r) -
                s.reg[SongReg.indexDownloads + r]);
  }

  /// Lifetime units of an album in region [r] (or all regions), including
  /// lazily accrued SEA while dormant.
  /// An artist's album units: the sum of their albums' (with the catalog
  /// part accrued lazily).
  double artistLifetimeUnits(Artist a, [int? r]) {
    var t = 0.0;
    for (final al in albums) {
      if (al.artistId == a.id) t += albumLifetimeUnits(al, r);
    }
    return t;
  }

  double albumLifetimeUnits(Album al, [int? r]) {
    if (r == null) {
      var t = 0.0;
      for (var i = 0; i < regionCount; i++) {
        t += albumLifetimeUnits(al, i);
      }
      return t;
    }
    final v = al.reg[AlbumReg.lifeUnits + r];
    if (al.status == AlbumStatus.active) return v;
    // Catalog streams become album units only from 2015 (docs K44, K49).
    if (!Charts.songRules(ChartMarket.global, week).albumUsesUnits) return v;
    return v +
        al.sumDormantRate *
            (artistIndexStreams(artists[al.artistId], r) -
                al.reg[AlbumReg.indexStreams + r]) /
            config.streamEquivalentAlbum;
  }

  /// First-week units (or pure sales) of an album in a chart market:
  /// US/UK are shares of their region, global is the sum.
  double albumFirstWeekIn(Album al, ChartMarket market, {bool pure = false}) {
    final home = artists[al.artistId].homeCountry;
    final base = pure ? AlbumReg.firstWeekPure : AlbumReg.firstWeekUnits;
    return switch (market) {
      ChartMarket.us => CountryShares.usOfNorthAmerica(home) *
          al.reg[base + Region.northAmerica.index],
      ChartMarket.uk =>
        CountryShares.ukOfEurope(home) * al.reg[base + Region.europe.index],
      _ => al.reg[base] + al.reg[base + 1] + al.reg[base + 2],
    };
  }

  /// Last week's streams of a song in region [r]: exact for active songs,
  /// and for catalog (dormant) songs derived from the catalog formula.
  double songWeekStreamsRegion(Song s, int r) {
    if (s.status == SongStatus.active) return s.weekRegion?[r] ?? 0;
    if (s.status != SongStatus.dormant) return 0;
    final a = primaryOf(s);
    return s.dormantRate * a.catalogFactor * a.regionShare[r] * lastSpa[r];
  }

  /// This week's streams of a song in a chart market.
  double songWeekStreamsIn(Song s, ChartMarket market) {
    final wr = [
      for (var r = 0; r < regionCount; r++) songWeekStreamsRegion(s, r),
    ];
    final home = primaryOf(s).homeCountry;
    return switch (market) {
      ChartMarket.us ||
      ChartMarket.usRadio ||
      ChartMarket.usStreaming ||
      ChartMarket.usDigital ||
      ChartMarket.usAlbumSales ||
      ChartMarket.usStreamingAlbums ||
      ChartMarket.usRingtones ||
      ChartMarket.platformNorthAmerica =>
        (market != ChartMarket.platformNorthAmerica
                ? CountryShares.usOfNorthAmerica(home)
                : 1) *
            wr[Region.northAmerica.index],
      ChartMarket.uk ||
      ChartMarket.platformEurope =>
        (market == ChartMarket.uk ? CountryShares.ukOfEurope(home) : 1) *
            wr[Region.europe.index],
      _ => wr[0] + wr[1] + wr[2],
    };
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
