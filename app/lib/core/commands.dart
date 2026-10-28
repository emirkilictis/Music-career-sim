import 'dart:async';
import 'dart:typed_data';

import 'package:game/game.dart';

import 'event_lines.dart';
import 'game_controller.dart';

typedef HostCmd<R> = FutureOr<R> Function(GameHost h);
typedef SessionCmd<R> = FutureOr<R> Function(GameSession s);

/// Every command sent to the game isolate is built here.
///
/// Why a separate file: a closure sent to another isolate carries every
/// variable captured in the scope where it was created. Built inside a
/// widget method it could drag the widget tree along (and fail to send).
/// Each factory below captures only its own sendable parameters.
abstract final class Cmd {
  // ------------------------------------------------------------- careers

  static HostCmd<List<Map<String, Object?>>> listSlots() =>
      (h) => h.slots.list()
        ..sort((a, b) => (b['savedAt'] as String? ?? '')
            .compareTo(a['savedAt'] as String? ?? ''));

  static HostCmd<void> deleteSlot(String slotId) =>
      (h) => h.slots.delete(slotId);

  /// [slotId]'s database for a backup (docs K219).
  static HostCmd<Uint8List> backupSlot(String slotId) => (h) async {
        await h.slots.prepare(slotId);
        return GameSession.backup(h.slots, slotId);
      };

  /// Adds a backup's database as a new career; returns its slot.
  static HostCmd<String> restoreSlot(Uint8List database) =>
      (h) => GameSession.restore(h.slots, database);

  static HostCmd<void> resume(String slotId) => (h) async {
        h.session?.close();
        h.session = null;
        // The web reads the career in first (docs K218).
        await h.slots.prepare(slotId);
        h.session = GameSession.resume(h.slots, slotId);
      };

  /// Creates a career; progress (0..1) is sent to [progress].
  static HostCmd<String> start(CareerSetup setup, ProgressSink progress) =>
      (h) async {
        h.session?.close();
        h.session = null;
        var last = -1;
        // Gives the event loop turns: on the web the game shares the
        // page's thread (docs K218).
        final s = await GameSession.startAsync(h.slots, setup, onProgress: (p) {
          final pct = (p * 100).floor();
          if (pct != last) progress.send(p);
          last = pct;
        });
        h.session = s;
        return s.slotId;
      };

  static SessionCmd<String> slotId() => (s) => s.slotId;

  static HostCmd<void> closeCareer() => (h) {
        h.session?.close();
        h.session = null;
      };

  // --------------------------------------------------------------- weeks

  static SessionCmd<(ArtistView, int, Difficulty)> snapshot() =>
      (s) => (s.player, s.week, s.difficulty);

  /// Plays a week: its number, news, money change and what went to the
  /// label's advance (docs K107).
  static SessionCmd<(int, List<EventLine>, int, int)> nextWeek() => (s) {
        final r = s.advanceWeek();
        return (
          r.week,
          describeEvents(s, r.events),
          r.moneyDeltaCents,
          r.recoupedCents
        );
      };

  /// Skips up to [weeks] weeks (52 = a year), stopping per [stop]; the
  /// number of weeks played is sent to [progress].
  static SessionCmd<(YearReport, List<EventLine>)> skipWeeks(
          int weeks, SkipStop stop, ProgressSink progress) =>
      (s) async {
        var n = 0;
        final y = await s.advanceWeeksAsync(weeks,
            stop: stop, onWeek: (_) => progress.send(++n));
        return (y, describeEvents(s, y.events));
      };

  // ------------------------------------------------------------- actions

  static SessionCmd<SongView> writeSong({
    int? producerId,
    int? cowriterId,
    required BudgetTier budget,
    required List<int> genres,
    String? title,
    bool holiday = false,
    int dissTarget = -1,
  }) =>
      (s) => s.writeSong(
          producerId: producerId,
          cowriterId: cowriterId,
          budget: budget,
          genres: genres,
          title: title,
          holiday: holiday,
          dissTarget: dissTarget);

  /// Beefs (docs K229).
  static SessionCmd<BeefsView> beefs() => (s) => s.beefs;
  static SessionCmd<List<DissTargetView>> dissTargets() =>
      (s) => s.dissTargets;
  static SessionCmd<void> dissPost(int rivalId) => (s) => s.dissPost(rivalId);
  static SessionCmd<bool> dissHaters() => (s) => s.dissHaters();
  static SessionCmd<void> makePeace() => (s) => s.makePeace();

  static SessionCmd<void> releaseSingle(int songId, Campaign campaign,
          [RadioPush radio = RadioPush.none]) =>
      (s) => s.releaseSingle(songId, campaign: campaign, radio: radio);

  static SessionCmd<AlbumView> releaseAlbum({
    required String title,
    required List<int> songIds,
    required AlbumType type,
    required List<int> variantWeeks,
    List<EditionFormat?> variantFormats = const [],
    required Campaign campaign,
    bool exclusive = false,
    int windowWeeks = 0,
    AlbumBundle bundle = AlbumBundle.none,
    int partnerId = -1,
  }) =>
      (s) => s.releaseAlbum(title, songIds,
          type: type,
          variantWeeks: variantWeeks,
          variantFormats: variantFormats,
          campaign: campaign,
          exclusive: exclusive,
          windowWeeks: windowWeeks,
          bundle: bundle,
          partnerId: partnerId);

  /// Rivals who would make a joint album (docs K150).
  static SessionCmd<List<JointPartnerView>> jointPartners() =>
      (s) => s.jointPartners;

  /// What each album bundle would add now (docs K144).
  static SessionCmd<Map<AlbumBundle, double>> bundleOptions() =>
      (s) => s.bundleOptions;

  /// The exclusive fee on offer for an album now (docs K135).
  static SessionCmd<int?> exclusiveOffer() => (s) => s.exclusiveOffer;

  /// Whether an album can be kept off streaming now (docs K174).
  static SessionCmd<bool> canWindow() => (s) => s.canWindow(AlbumType.album);

  static SessionCmd<ScheduledView> scheduleSingle(
          int songId, Campaign campaign, int releaseWeek, int announceWeek,
          [RadioPush radio = RadioPush.none]) =>
      (s) => s.scheduleSingle(songId,
          campaign: campaign,
          radio: radio,
          releaseWeek: releaseWeek,
          announceWeek: announceWeek);

  static SessionCmd<ScheduledView> scheduleAlbum({
    required String title,
    required List<int> songIds,
    required AlbumType type,
    required List<int> variantWeeks,
    List<EditionFormat?> variantFormats = const [],
    required Campaign campaign,
    required int releaseWeek,
    required int announceWeek,
    bool exclusive = false,
    int windowWeeks = 0,
    AlbumBundle bundle = AlbumBundle.none,
  }) =>
      (s) => s.scheduleAlbum(title, songIds,
          type: type,
          variantWeeks: variantWeeks,
          variantFormats: variantFormats,
          campaign: campaign,
          releaseWeek: releaseWeek,
          announceWeek: announceWeek,
          exclusive: exclusive,
          windowWeeks: windowWeeks,
          bundle: bundle);

  static SessionCmd<ScheduledView> saveDraft({
    required String title,
    required List<int> songIds,
    required AlbumType type,
    required List<int> variantWeeks,
    List<EditionFormat?> variantFormats = const [],
  }) =>
      (s) => s.saveDraft(title, songIds,
          type: type,
          variantWeeks: variantWeeks,
          variantFormats: variantFormats);

  static SessionCmd<AlbumView> releaseDraft(int id, Campaign campaign) =>
      (s) => s.releaseDraft(id, campaign: campaign);

  static SessionCmd<ScheduledView> scheduleDraft(
          int id, Campaign campaign, int releaseWeek, int announceWeek) =>
      (s) => s.scheduleDraft(id,
          campaign: campaign,
          releaseWeek: releaseWeek,
          announceWeek: announceWeek);

  static SessionCmd<void> reschedule(
          int id, int releaseWeek, int? announceWeek) =>
      (s) => s.reschedule(id,
          releaseWeek: releaseWeek, announceWeek: announceWeek);

  static SessionCmd<void> cancelScheduled(int id) =>
      (s) => s.cancelScheduled(id);

  static SessionCmd<void> setJob(Job job) => (s) => s.setJob(job);

  static SessionCmd<void> rest() => (s) => s.rest();

  static SessionCmd<void> scrapSong(int id) => (s) => s.scrapSong(id);

  static SessionCmd<List<LabelView>> labels() => (s) => s.labels;
  static SessionCmd<List<MilestoneView>> milestones() => (s) => s.milestones;
  static SessionCmd<List<PlatformView>> platforms() => (s) => s.platforms;
  static SessionCmd<void> hireManager(Manager m) => (s) => s.hireManager(m);

  /// Album tracks for the next single (docs K182).
  static SessionCmd<List<SinglePickView>> singlePicks(int albumId) =>
      (s) => s.singlePicks(albumId);

  /// Nights a tour leg can fill (docs K181).
  static SessionCmd<int> suggestTourShows(TourRequest r, TourMarket m) =>
      (s) => s.suggestTourShows(r, m);

  /// Mood playlists (docs K186).
  static SessionCmd<List<({Mood mood, double fit, double chance})>> moodOptions(
          int songId) =>
      (s) => s.moodOptions(songId);
  static SessionCmd<bool> pitchMood(int songId, Mood m) =>
      (s) => s.pitchMood(songId, m);

  /// The Artist Pick (docs K185).
  static SessionCmd<PickView> artistPick() => (s) => s.artistPick;
  static SessionCmd<void> setMemberFocus(int member) =>
      (s) => s.setMemberFocus(member);
  static SessionCmd<void> setMemberRoles(int member, Set<MemberRole> roles) =>
      (s) => s.setMemberRoles(member, roles);
  static SessionCmd<LineupView?> lineup() => (s) => s.lineup;
  static SessionCmd<void> setLineSplit(LineSplit split) =>
      (s) => s.setLineSplit(split);
  static SessionCmd<void> cheerMember(int member) =>
      (s) => s.cheerMember(member);
  static SessionCmd<ReunionView?> reunion() => (s) => s.reunion;
  static SessionCmd<void> startReunion() => (s) => s.startReunion();
  static SessionCmd<List<int>> reunionCosts() => (s) => s.reunionCosts;
  static SessionCmd<void> releaseReunionSingle(int songId, Campaign campaign) =>
      (s) => s.releaseReunionSingle(songId, campaign: campaign);
  static SessionCmd<AlbumView> releaseReunionAlbum(
          String title, List<int> songIds, AlbumType type, Campaign campaign) =>
      (s) =>
          s.releaseReunionAlbum(title, songIds, type: type, campaign: campaign);
  static SessionCmd<GoSoloView> goSoloPreview(int member) =>
      (s) => s.goSoloPreview(member);
  static SessionCmd<void> goSolo(int member) => (s) => s.goSolo(member);
  static SessionCmd<(ArtistView, bool)?> formerGroup() => (s) => s.formerGroup;
  static SessionCmd<void> addCanvas(int songId) => (s) => s.addCanvas(songId);
  static SessionCmd<ThisIsView> thisIs(int artistId) =>
      (s) => s.thisIs(artistId);
  static SessionCmd<void> setArtistPick(PickKind kind, int id) =>
      (s) => s.setArtistPick(kind, id);

  /// Streamify Sessions (docs K178).
  static SessionCmd<SessionsView> sessions() => (s) => s.sessions;
  static SessionCmd<void> recordSession(int songId, int coverSongId) =>
      (s) => s.recordSession(songId, coverSongId);

  /// The next weeks' dates (docs K177).
  static SessionCmd<List<CalendarWeek>> calendar() => (s) => s.calendar;
  static SessionCmd<List<UpcomingRelease>> upcomingRivalAlbums() =>
      (s) => s.upcomingRivalAlbums;
  static SessionCmd<PlatformView> platform(MusicPlatform p) =>
      (s) => s.platform(p);
  static SessionCmd<TourPlanView> tourPreview(TourRequest r) =>
      (s) => s.tourPreview(r);
  static SessionCmd<List<OpenerView>> tourOpeners() => (s) => s.tourOpeners;
  static SessionCmd<void> startTour(TourRequest r) => (s) => s.startTour(r);
  static SessionCmd<List<SetlistSong>> setlistOptions(TourRequest r) =>
      (s) => s.setlistOptions(r);
  static SessionCmd<List<TourCityView>> tourCities(TourMarket m, TourKind k) =>
      (s) => s.tourCities(m, k);

  static SessionCmd<List<FestivalView>> festivals() => (s) => s.festivals;
  static SessionCmd<void> bookFestival(int festival) =>
      (s) => s.bookFestival(festival);
  static SessionCmd<void> cancelFestival(int festival, int year) =>
      (s) => s.cancelFestival(festival, year);
  static SessionCmd<Map<FestivalSlot, List<FestivalAct>>> festivalLineup(
          int festival, int year) =>
      (s) => s.festivalLineup(festival, year);

  /// Years with a Golden Record Awards show (newest first) and the show of
  /// [year] (null: the newest; docs K91).
  static SessionCmd<(List<int>, AwardShowView?)> awards(int? year) => (s) {
        final years = s.awardYears;
        final y = year ?? (years.isEmpty ? null : years.first);
        return (years, y == null ? null : s.awardShow(y));
      };

  /// The year's top tours (null: all time) and the first year on the books.
  /// Rivals who could feature on a vault song, and getting one (K117).
  static SessionCmd<List<FeatureCandidateView>> featureCandidates(int songId) =>
      (s) => s.featureCandidates(songId);
  static SessionCmd<void> requestFeature(int songId, int artistId) =>
      (s) => s.requestFeature(songId, artistId);

  /// Re-releases an album as a deluxe edition (docs K115).
  static SessionCmd<void> releaseDeluxe(int albumId, List<int> songIds) =>
      (s) => s.releaseDeluxe(albumId, songIds);

  /// Award submissions (docs K227).
  static SessionCmd<AwardSubmissionsView?> awardSubmissions() =>
      (s) => s.awardSubmissions;
  static SessionCmd<void> submitForAwards(
          List<AwardSubmission> entries, bool newArtist) =>
      (s) => s.submitForAwards(entries, newArtist: newArtist);

  /// A new version of an album after it came out (docs K225, K226); the
  /// edition (cover index) it became.
  static SessionCmd<int> releaseAlbumVersion(int albumId,
          {required String name,
          required List<int> songIds,
          required EditionFormat format,
          bool anniversary = false}) =>
      (s) => s.releaseAlbumVersion(albumId,
          name: name,
          songIds: songIds,
          format: format,
          anniversary: anniversary);

  /// An album anniversary to ask about, and having asked (docs K226).
  static SessionCmd<AnniversaryPrompt?> anniversaryPrompt() =>
      (s) => s.anniversaryPrompt;
  static SessionCmd<void> anniversaryAsked(int albumId) =>
      (s) => s.anniversaryAsked(albumId);

  /// Records an album again into a vault draft (docs K139).
  static SessionCmd<void> rerecordAlbum(
          int albumId, String title, List<int> vaultSongIds) =>
      (s) => s.rerecordAlbum(albumId, title, vaultSongIds: vaultSongIds);

  /// Writing for others (docs K143).
  static SessionCmd<List<SongBuyerView>> songBuyers(int songId) =>
      (s) => s.songBuyers(songId);
  static SessionCmd<void> sellSong(int songId, int artistId) =>
      (s) => s.sellSong(songId, artistId);
  static SessionCmd<List<WrittenSongView>> writtenForOthers() =>
      (s) => s.writtenForOthers;
  static SessionCmd<SongMarketView> songMarket() => (s) => s.songMarket;
  static SessionCmd<CertificationsView> certifications() =>
      (s) => s.certifications;
  static SessionCmd<StreamCounterView> streamCounter(EntityKind kind, int id) =>
      (s) => s.streamCounter(kind, id);
  static SessionCmd<List<TourHistoryView>> tourHistory() =>
      (s) => s.tourHistory;
  static SessionCmd<TourView?> pastTour(int startWeek) =>
      (s) => s.pastTour(startWeek);
  static SessionCmd<SongView> buySong(int index) => (s) => s.buySong(index);
  static SessionCmd<Map<int, int>> groupSizes() => (s) => s.groupSizes;
  static SessionCmd<List<RivalEditRow>> rivalsToEdit(String query) =>
      (s) => s.rivalsToEdit(query: query);
  static SessionCmd<void> renameArtist(int artistId, String name) =>
      (s) => s.renameArtist(artistId, name);

  /// Distribution for independents (docs K157).
  // Documentaries (docs K172).
  static SessionCmd<DocumentaryView> documentary() => (s) => s.documentary;
  static SessionCmd<void> startDocumentary(DocDeal deal, String title) =>
      (s) => s.startDocumentary(deal, title);

  // Awards campaigns (docs K171).
  static SessionCmd<FycView> fyc() => (s) => s.fyc;
  static SessionCmd<void> runFyc(FycTier tier) => (s) => s.runFyc(tier);

  // The player's own label (docs K169).
  static SessionCmd<ImprintView> imprint() => (s) => s.imprint;
  static SessionCmd<List<SigneeCandidateView>> imprintCandidates() =>
      (s) => s.imprintCandidates;
  static SessionCmd<void> foundImprint(String name) =>
      (s) => s.foundImprint(name);
  static SessionCmd<void> signToImprint(int artistId) =>
      (s) => s.signToImprint(artistId);
  static SessionCmd<int> pushSignee(int artistId) =>
      (s) => s.pushSignee(artistId);
  static SessionCmd<void> dropFromImprint(int artistId) =>
      (s) => s.dropFromImprint(artistId);

  // The paid fan club (docs K164).
  static SessionCmd<FanClubView> fanClub() => (s) => s.fanClub;
  static SessionCmd<void> openFanClub(ClubPrice price) =>
      (s) => s.openFanClub(price);
  static SessionCmd<void> setClubPrice(ClubPrice price) =>
      (s) => s.setClubPrice(price);

  // Download price cuts (docs K163).
  static SessionCmd<void> cutAlbumPrice(int albumId, PriceCut cut) =>
      (s) => s.cutAlbumPrice(albumId, cut);

  // Buying masters back (docs K162).
  static SessionCmd<int> buyAlbumMasters(int albumId) =>
      (s) => s.buyAlbumMasters(albumId);
  static SessionCmd<int> buySongMaster(int songId) =>
      (s) => s.buySongMaster(songId);

  // Greatest hits (docs K161).
  static SessionCmd<CompilationBlock?> compilationBlock() =>
      (s) => s.compilationBlock;
  static SessionCmd<List<HitCandidateView>> compilationCandidates() =>
      (s) => s.compilationCandidates;
  static SessionCmd<AlbumView> releaseGreatestHits(String title,
          List<int> hitIds, List<int> newIds, Campaign campaign) =>
      (s) => s.releaseGreatestHits(title, hitIds, newIds, campaign: campaign);

  // Independent curators (docs K160).
  static SessionCmd<Map<CuratorPack, int>> curatorCosts() =>
      (s) => s.curatorCosts;
  static SessionCmd<void> submitToCurators(int songId, CuratorPack pack) =>
      (s) => s.submitToCurators(songId, pack);
  static SessionCmd<List<CuratorAnswer>> curatorAnswers(int songId) =>
      (s) => s.curatorAnswers(songId);

  // The player's own playlist (docs K159).
  static SessionCmd<bool> ownPlaylistOpen() => (s) => s.ownPlaylistOpen;
  static SessionCmd<OwnPlaylistView?> ownPlaylist() => (s) => s.ownPlaylist;
  static SessionCmd<void> createPlaylist(String name) =>
      (s) => s.createPlaylist(name);
  static SessionCmd<void> renamePlaylist(String name) =>
      (s) => s.renamePlaylist(name);
  static SessionCmd<void> addToPlaylist(int songId) =>
      (s) => s.addToPlaylist(songId);
  static SessionCmd<void> removeFromPlaylist(int songId) =>
      (s) => s.removeFromPlaylist(songId);
  static SessionCmd<List<PlaylistTrackView>> playlistCandidates() =>
      (s) => s.playlistCandidates;

  // Members' solo records and the player's features (docs K158).
  static SessionCmd<List<MemberView>> members() => (s) => s.members;
  static SessionCmd<List<int>> memberSoloCosts(int member) => (s) => [
        for (final c in Campaign.values) s.memberSoloCost(member, c),
      ];
  static SessionCmd<void> releaseMemberSolo(
          int member, int songId, Campaign campaign) =>
      (s) => s.releaseMemberSolo(member, songId, campaign: campaign);
  static SessionCmd<AlbumView> releaseMemberAlbum(int member, String title,
          List<int> songIds, AlbumType type, Campaign campaign) =>
      (s) => s.releaseMemberAlbum(member, title, songIds,
          type: type, campaign: campaign);
  static SessionCmd<List<WrittenSongView>> guestSongs() => (s) => s.guestSongs;
  static SessionCmd<DistributionView> distribution() => (s) => s.distribution;
  static SessionCmd<void> chooseDistributor(Distributor d) =>
      (s) => s.chooseDistributor(d);

  /// A version in another language (docs K155).
  static SessionCmd<void> releaseLanguageVersion(
          int songId, LanguageVersion v) =>
      (s) => s.releaseLanguageVersion(songId, v);

  /// A visual album (docs K154).
  static SessionCmd<void> makeVisualAlbum(int albumId) =>
      (s) => s.makeVisualAlbum(albumId);

  /// Selling the catalog (docs K153).
  static SessionCmd<CatalogOfferView> catalogOffer() => (s) => s.catalogOffer;
  static SessionCmd<int> sellCatalog() => (s) => s.sellCatalog();

  /// A snippet test (docs K152).
  static SessionCmd<void> teaseSnippet(int songId) =>
      (s) => s.teaseSnippet(songId);

  /// An anniversary reissue (docs K149).
  static SessionCmd<void> reissueAnniversary(int albumId) =>
      (s) => s.reissueAnniversary(albumId);

  /// A free upload to the audio site (docs K148).
  static SessionCmd<void> uploadToCloud(int songId) =>
      (s) => s.uploadToCloud(songId);

  /// The streaming app's Marquee and Showcase (docs K147).
  static SessionCmd<void> runMarquee(int songId) => (s) => s.runMarquee(songId);
  static SessionCmd<void> runAlbumMarquee(int albumId) =>
      (s) => s.runAlbumMarquee(albumId);
  static SessionCmd<void> runShowcase(int songId) =>
      (s) => s.runShowcase(songId);

  /// Live albums (docs K146).
  static SessionCmd<List<LiveTourView>> liveAlbumTours() =>
      (s) => s.liveAlbumTours;
  static SessionCmd<AlbumView> releaseLiveAlbum(int tourStartWeek, String title,
          List<int> songIds, Campaign campaign) =>
      (s) =>
          s.releaseLiveAlbum(tourStartWeek, title, songIds, campaign: campaign);

  /// Record money by source (docs K145).
  static SessionCmd<IncomeBreakdown> songIncome(int songId) =>
      (s) => s.songIncome(songId);
  static SessionCmd<IncomeBreakdown> careerIncome() => (s) => s.careerIncome;
  static SessionCmd<List<SongEarningView>> songEarnings() =>
      (s) => s.songEarnings;

  /// The player's channel on the video site (docs K142).
  static SessionCmd<ChannelView> channel() => (s) => s.channel;
  static SessionCmd<void> uploadVideo(VideoKind kind, int songId) =>
      (s) => s.uploadVideo(kind, songId: songId);

  /// The player's videos and the biggest of all time (docs K118).
  static SessionCmd<(List<VideoRow>, List<VideoRow>)> videos() => (s) => (
        Platforms.topVideos(s.world, limit: 5, mine: true),
        [
          for (final v in Platforms.topVideos(s.world, limit: 15))
            if (v.views >= Platforms.billionViews) v
        ],
      );

  /// The player's honours beyond awards (docs K116).
  static SessionCmd<HonorsView> honors() => (s) => s.honors;

  /// The K-pop music show's recent weeks (docs K114).
  static SessionCmd<List<MusicShowRow>> musicShow() => (s) => s.musicShow;

  /// This week's top artists (docs K113).
  static SessionCmd<List<ArtistChartRow>> artistChart() => (s) => s.artistChart;

  /// Every all-time record's top 10 and the year they count from (K111).
  static SessionCmd<(Map<RecordKind, List<RecordEntry>>, int)> records() =>
      (s) => (s.records, GameTime.yearOf(s.historyStartWeek));

  /// Best sellers (docs K141): the all-time list of [kind] by [measure]
  /// and the player's place among artists (0: none).
  static SessionCmd<(List<BestSellerRow>, int)> bestSellers(
          BestSellerKind kind, SalesMeasure measure) =>
      (s) => (
            s.bestSellers(kind, measure: measure),
            s.bestSellerRank(measure: measure)
          );

  /// [year]'s list of [kind] (docs K141): artists by their share of the
  /// year's charts, albums and songs from the global year-end charts.
  static SessionCmd<List<BestSellerRow>> yearBestSellers(
          BestSellerKind kind, int year) =>
      (s) {
        if (kind == BestSellerKind.artists) return s.yearEndArtists(year);
        final albums = kind == BestSellerKind.albums;
        return [
          for (final r in s.yearEnd(
              albums ? Charts.globalAlbums : Charts.globalSongs, year))
            BestSellerRow(
                rank: r.rank,
                kind: kind,
                entityId: r.entityId,
                title: r.title,
                artistId: r.artistId,
                artistName: r.artistName,
                albumId: r.albumId,
                isPlayer: r.isPlayer,
                value: r.points.toDouble(),
                releaseYear: year),
        ];
      };

  /// Each year's winners and the years there are (docs K141).
  static SessionCmd<List<YearWinners>> yearWinners() => (s) => s.yearWinners;
  static SessionCmd<List<int>> yearEndYears() => (s) => s.yearEndYears;

  /// A year-end chart and the years there are (docs K110); [year] null
  /// is the latest.
  static SessionCmd<(List<YearEndRow>, List<int>)> yearEnd(
          int chartId, int? year) =>
      (s) {
        final years =
            chartId == YearEnd.summer ? s.summerYears : s.yearEndYears;
        final y = year != null && years.contains(year)
            ? year
            : (years.isEmpty ? null : years.first);
        return (
          y == null ? const <YearEndRow>[] : s.yearEnd(chartId, y),
          years
        );
      };

  static SessionCmd<List<BillionsRow>> billionsClub() => (s) => s.billionsClub;

  /// The streaming app's editorial playlists open last week (docs K125).
  static SessionCmd<List<EditorialPlaylist>> editorialPlaylists() =>
      (s) => Editorial.playlists(s.world);

  static SessionCmd<EditorialView> editorial(EditorialPlaylist p) =>
      (s) => Editorial.view(s.world, p);

  /// Where a song is on the editorial playlists.
  static SessionCmd<List<EditorialPlacement>> placements(int songId) =>
      (s) => Editorial.placements(s.world, songId);

  /// The player's year on the streaming app and the years there are (docs
  /// K123); [year] null is the latest.
  static SessionCmd<(WrappedView?, List<int>)> wrapped(int? year) => (s) {
        final years = s.wrappedYears;
        final y = year ?? (years.isEmpty ? null : years.first);
        return (y == null ? null : s.wrapped(y), years);
      };

  /// The latest year with a Wrapped (null: none yet).
  static SessionCmd<int?> latestWrapped() => (s) {
        final years = s.wrappedYears;
        return years.isEmpty ? null : years.first;
      };

  static SessionCmd<(List<TourRankView>, int)> topTours(int? year) => (s) =>
      (year == null ? s.allTimeTours() : s.topTours(year), s.firstTourYear);

  static SessionCmd<void> signLabel(Label label,
          {ContractDeal deal = ContractDeal.standard}) =>
      (s) => s.signLabel(label, deal: deal);

  static SessionCmd<OpportunityOutcome> answerOpportunity(
          OpportunityChoice choice) =>
      (s) => s.answerOpportunity(choice);

  static SessionCmd<void> shootVideo(int id, VideoBudget budget) =>
      (s) => s.shootVideo(id, budget);
  static SessionCmd<SocialView> social() => (s) => s.social;
  static SessionCmd<List<BrandDealView>> brandDeals() => (s) => s.brandDeals;
  static SessionCmd<int> doDealTask(int deal, int task) =>
      (s) => s.doDealTask(deal, task);
  static SessionCmd<void> buyBots(int id, BotPackage pkg) =>
      (s) => s.buyBots(id, pkg);
  static SessionCmd<void> setAutoplay(int id, bool on) =>
      (s) => s.setAutoplay(id, on);

  static SessionCmd<void> setAutoplayLevel(int id, AutoplayLevel level) =>
      (s) => s.setAutoplayLevel(id, level);

  static SessionCmd<void> upgradeRadio(int id, RadioPush to) =>
      (s) => s.upgradeRadio(id, to);

  static SessionCmd<void> setRadioFormat(int id, RadioFormat f) =>
      (s) => s.setRadioFormat(id, f);

  static SessionCmd<void> runCreators(int id, CreatorCampaign c) =>
      (s) => s.runCreators(id, c);
  static SessionCmd<void> pitchSong(int id) => (s) => s.pitchSong(id);
  static SessionCmd<PostOutcome> post(PostKind kind, {int songId = -1}) =>
      (s) => s.post(kind, songId: songId);
  static SessionCmd<void> releaseVersion(int id, SongVersion v) =>
      (s) => s.releaseVersion(id, v);
  static SessionCmd<void> releaseVariant(int id, SingleFormat f) =>
      (s) => s.releaseVariant(id, f);

  static SessionCmd<void> spendSkillPoint(SkillKind kind) =>
      (s) => s.spendSkillPoint(kind);

  static SessionCmd<int> spendSkillPoints(SkillKind kind, int count) =>
      (s) => s.spendSkillPoints(kind, count);

  static SessionCmd<int> spreadSkillPoints() => (s) => s.spreadSkillPoints();

  static SessionCmd<void> rewardAd() => (s) => s.rewardAd();

  static SessionCmd<bool> dailyBonus(bool premium) =>
      (s) => s.claimDailyBonus(premium: premium);

  // --------------------------------------------------------------- reads

  static SessionCmd<List<SongView>> songs() => (s) => s.songs;
  static SessionCmd<List<SongView>> vault() => (s) => s.vault;
  static SessionCmd<List<AlbumView>> albums() => (s) => s.albums;

  static SessionCmd<List<ScheduledView>> scheduled() => (s) => s.scheduled;
  static SessionCmd<SongView> song(int id) => (s) => s.song(id);
  static SessionCmd<AlbumView> album(int id) => (s) => s.album(id);

  /// An album with its tracks, for the Streamify album page (docs F23).
  static SessionCmd<(AlbumView, List<SongView>)> albumPage(int id) => (s) {
        final al = s.album(id);
        return (al, [for (final t in al.trackIds) s.song(t)]);
      };
  static SessionCmd<ChartView> chart(int id) => (s) => s.chart(id);
  static SessionCmd<ArtistPageView> artistPage(int artistId) =>
      (s) => s.artistPage(artistId);
  static SessionCmd<List<int>> activeCharts() =>
      (s) => [for (final c in s.activeCharts) c.id];
  static SessionCmd<List<CollaboratorView>> collaborators(
          CollaboratorRole role) =>
      (s) => s.collaborators(role);
  static SessionCmd<List<HistoryPoint>> songHistory(int id) =>
      (s) => s.songHistory(id);
  static SessionCmd<List<HistoryPoint>> albumHistory(int id) =>
      (s) => s.albumHistory(id);
  static SessionCmd<List<AlbumSalesWeek>> albumSales(int id) =>
      (s) => s.albumSales(id);
  static SessionCmd<List<ChartWeek>> chartRun(EntityKind kind, int id) =>
      (s) => s.chartRun(kind, id);
  static SessionCmd<List<CareerYear>> careerByYear() => (s) => s.careerByYear();
}
