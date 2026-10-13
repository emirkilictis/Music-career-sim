import 'dart:isolate';

import 'package:game/game.dart';

import 'event_lines.dart';
import 'game_controller.dart';

typedef HostCmd<R> = R Function(GameHost h);
typedef SessionCmd<R> = R Function(GameSession s);

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

  static HostCmd<void> resume(String slotId) => (h) {
        h.session?.close();
        h.session = GameSession.resume(h.slots, slotId);
      };

  /// Creates a career; progress (0..1) is sent to [progress].
  static HostCmd<String> start(CareerSetup setup, SendPort progress) => (h) {
        h.session?.close();
        h.session = null;
        var last = -1;
        final s = GameSession.start(h.slots, setup, onProgress: (p) {
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

  static SessionCmd<(int, List<EventLine>, int)> nextWeek() => (s) {
        final r = s.advanceWeek();
        return (r.week, describeEvents(s, r.events), r.moneyDeltaCents);
      };

  /// Skips up to [weeks] weeks (52 = a year), stopping per [stop]; the
  /// number of weeks played is sent to [progress].
  static SessionCmd<(YearReport, List<EventLine>)> skipWeeks(
          int weeks, SkipStop stop, SendPort progress) =>
      (s) {
        var n = 0;
        final y = s.advanceWeeks(weeks,
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
  }) =>
      (s) => s.writeSong(
          producerId: producerId,
          cowriterId: cowriterId,
          budget: budget,
          genres: genres,
          title: title);

  static SessionCmd<void> releaseSingle(int songId, Campaign campaign) =>
      (s) => s.releaseSingle(songId, campaign: campaign);

  static SessionCmd<AlbumView> releaseAlbum({
    required String title,
    required List<int> songIds,
    required AlbumType type,
    required List<int> variantWeeks,
    List<EditionFormat?> variantFormats = const [],
    required Campaign campaign,
  }) =>
      (s) => s.releaseAlbum(title, songIds,
          type: type,
          variantWeeks: variantWeeks,
          variantFormats: variantFormats,
          campaign: campaign);

  static SessionCmd<ScheduledView> scheduleSingle(
          int songId, Campaign campaign, int releaseWeek, int announceWeek) =>
      (s) => s.scheduleSingle(songId,
          campaign: campaign,
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
  }) =>
      (s) => s.scheduleAlbum(title, songIds,
          type: type,
          variantWeeks: variantWeeks,
          variantFormats: variantFormats,
          campaign: campaign,
          releaseWeek: releaseWeek,
          announceWeek: announceWeek);

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
  static SessionCmd<List<UpcomingRelease>> upcomingRivalAlbums() =>
      (s) => s.upcomingRivalAlbums;
  static SessionCmd<PlatformView> platform(MusicPlatform p) =>
      (s) => s.platform(p);
  static SessionCmd<TourPlanView> tourPreview(TourRequest r) =>
      (s) => s.tourPreview(r);
  static SessionCmd<List<OpenerView>> tourOpeners() => (s) => s.tourOpeners;
  static SessionCmd<void> startTour(TourRequest r) => (s) => s.startTour(r);

  static SessionCmd<List<FestivalView>> festivals() => (s) => s.festivals;
  static SessionCmd<void> bookFestival(int festival) =>
      (s) => s.bookFestival(festival);
  static SessionCmd<void> cancelFestival(int festival, int year) =>
      (s) => s.cancelFestival(festival, year);
  static SessionCmd<Map<FestivalSlot, List<FestivalAct>>> festivalLineup(
          int festival, int year) =>
      (s) => s.festivalLineup(festival, year);

  /// The year's top tours (null: all time) and the first year on the books.
  static SessionCmd<(List<TourRankView>, int)> topTours(int? year) => (s) =>
      (year == null ? s.allTimeTours() : s.topTours(year), s.firstTourYear);

  static SessionCmd<void> signLabel(Label label) => (s) => s.signLabel(label);

  static SessionCmd<OpportunityOutcome> answerOpportunity(
          OpportunityChoice choice) =>
      (s) => s.answerOpportunity(choice);

  static SessionCmd<void> shootVideo(int id, VideoBudget budget) =>
      (s) => s.shootVideo(id, budget);

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
