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
  const NumberOne(this.chartId, this.kind, this.entityId, this.weeksAtNo1,
      {this.firstForRelease = false});
  final int chartId;
  final EntityKind kind;
  final int entityId;
  final int weeksAtNo1;
  bool get isFirstTime => weeksAtNo1 == 1;

  /// The release's very first #1 on any chart: the one worth a full-screen
  /// celebration (later #1s on other charts are ordinary news).
  final bool firstForRelease;
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

/// A player song started a viral trend online: on video sites before the
/// short-video apps (2017), on those after.
class ViralTrend extends GameEvent {
  const ViralTrend(this.songId, {this.shortVideo = true});
  final int songId;
  final bool shortVideo;
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

/// A player release stayed at #1 on a US chart for another week.
class StillNumberOne extends GameEvent {
  const StillNumberOne(this.chartId, this.kind, this.entityId, this.weeksAtNo1);
  final int chartId;
  final EntityKind kind;
  final int entityId;
  final int weeksAtNo1;
  @override
  bool get isMajor => false;
}

/// After a good era, a bigger label wants to sign the player (docs K54).
class LabelOffer extends GameEvent {
  const LabelOffer(this.label);
  final Label label;
  @override
  bool get isMajor => true;
}

/// After a flop, the player's label ended the contract.
class LabelDropped extends GameEvent {
  const LabelDropped(this.label);
  final Label label;
  @override
  bool get isMajor => true;
}

/// Pitchwork reviewed a player album that came out this week (docs K55).
class CriticReview extends GameEvent {
  const CriticReview(this.albumId, this.score);
  final int albumId;
  final double score;
  @override
  bool get isMajor => false;
}

/// An offer came up and waits for the player's answer (docs K59). An
/// interview is small news; the rest stop a skip so the player can answer.
class OpportunityCame extends GameEvent {
  const OpportunityCame(this.kind);
  final OpportunityKind kind;
  @override
  bool get isMajor => kind != OpportunityKind.interview;
}

/// An offer ran out unanswered (a scandal left alone plays out by itself).
class OpportunityLapsed extends GameEvent {
  const OpportunityLapsed(this.outcome);
  final OpportunityOutcome outcome;
  @override
  bool get isMajor => false;
}
