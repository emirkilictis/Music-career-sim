import 'package:simulation_core/simulation_core.dart';

/// Something worth telling the player after a week (docs/game-design.md §15).
/// Events carry ids and numbers only; the UI builds the localized text.
sealed class GameEvent {
  const GameEvent();

  /// Major events stop a year skip so the player sees them (§1.1).
  bool get isMajor;

  /// Industry news about rivals, not about the player (docs K37: these are
  /// never shown as notifications).
  bool get isIndustry => false;
}

/// What an event or view refers to.
enum EntityKind { song, album }

/// A player release entered a main chart for the first time.
class ChartDebut extends GameEvent {
  const ChartDebut(this.chartId, this.kind, this.entityId, this.position);
  final int chartId;
  final EntityKind kind;
  final int entityId;
  final int position;
  @override
  bool get isMajor => position <= 10;
}

/// A player release reached #1 ([weeksAtNo1] counts this week).
class NumberOne extends GameEvent {
  const NumberOne(this.chartId, this.kind, this.entityId, this.weeksAtNo1);
  final int chartId;
  final EntityKind kind;
  final int entityId;
  final int weeksAtNo1;
  bool get isFirstTime => weeksAtNo1 == 1;
  @override
  bool get isMajor => true;
}

/// A player song climbed to a new peak (top 40, after its debut week).
class NewPeak extends GameEvent {
  const NewPeak(this.chartId, this.songId, this.position);
  final int chartId;
  final int songId;
  final int position;
  @override
  bool get isMajor => false;
}

/// First-week numbers of a player album.
class AlbumFirstWeek extends GameEvent {
  const AlbumFirstWeek(
      {required this.albumId,
      required this.usUnits,
      required this.usPure,
      required this.globalUnits,
      required this.usPosition});
  final int albumId;
  final double usUnits;
  final double usPure;
  final double globalUnits;

  /// US album chart debut position (0 = did not chart).
  final int usPosition;
  @override
  bool get isMajor => true;
}

/// A player song started a short-video viral trend.
class ViralTrend extends GameEvent {
  const ViralTrend(this.songId);
  final int songId;
  @override
  bool get isMajor => true;
}

/// A player song was added to an editorial streaming playlist.
class PlaylistAdded extends GameEvent {
  const PlaylistAdded(this.songId, this.size);
  final int songId;
  final PlaylistAdd size;
  @override
  bool get isMajor => false;
}

/// The player's album era ended and was scored against expectations.
class EraClosed extends GameEvent {
  const EraClosed(this.result, this.units, this.expected);
  final EraResult result;
  final double units;
  final double expected;
  @override
  bool get isMajor => true;
}

/// Burnout is over; the player can write again.
class BurnoutOver extends GameEvent {
  const BurnoutOver();
  @override
  bool get isMajor => false;
}

/// Industry headline: a rival reached #1 for the first time.
class RivalNumberOne extends GameEvent {
  const RivalNumberOne(this.chartId, this.kind, this.entityId, this.artistId);
  final int chartId;
  final EntityKind kind;
  final int entityId;
  final int artistId;
  @override
  bool get isMajor => false;
  @override
  bool get isIndustry => true;
}

/// A streaming platform opened in a region this week (docs K38): its Top 50
/// chart [chartId] starts.
class PlatformLaunched extends GameEvent {
  const PlatformLaunched(this.chartId);
  final int chartId;
  @override
  bool get isMajor => false;
}

/// A scheduled player release came out this week (docs K45). Albums also
/// report [AlbumFirstWeek] when they chart.
class ReleaseOut extends GameEvent {
  const ReleaseOut(this.kind, this.entityId, this.scheduleId);
  final EntityKind kind;
  final int entityId;

  /// The [ScheduledView.id] it was planned under.
  final int scheduleId;
  @override
  bool get isMajor => true;
}

/// A scheduled player release was announced this week.
class ReleaseAnnounced extends GameEvent {
  const ReleaseAnnounced(
      {required this.isAlbum,
      required this.songId,
      required this.title,
      required this.releaseWeek});
  final bool isAlbum;

  /// The single's song (-1 for an album).
  final int songId;
  final String title;
  final int releaseWeek;
  @override
  bool get isMajor => false;
}
