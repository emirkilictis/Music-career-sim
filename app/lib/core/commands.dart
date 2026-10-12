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
    required Campaign campaign,
  }) =>
      (s) => s.releaseAlbum(title, songIds,
          type: type, variantWeeks: variantWeeks, campaign: campaign);

  static SessionCmd<void> setJob(Job job) => (s) => s.setJob(job);

  static SessionCmd<void> rest() => (s) => s.rest();

  static SessionCmd<void> rewardAd() => (s) => s.rewardAd();

  static SessionCmd<bool> dailyBonus(bool premium) =>
      (s) => s.claimDailyBonus(premium: premium);

  // --------------------------------------------------------------- reads

  static SessionCmd<List<SongView>> songs() => (s) => s.songs;
  static SessionCmd<List<SongView>> vault() => (s) => s.vault;
  static SessionCmd<List<AlbumView>> albums() => (s) => s.albums;
  static SessionCmd<SongView> song(int id) => (s) => s.song(id);
  static SessionCmd<AlbumView> album(int id) => (s) => s.album(id);
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
  static SessionCmd<List<CareerYear>> careerByYear() => (s) => s.careerByYear();
}
