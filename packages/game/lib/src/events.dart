import 'package:simulation_core/simulation_core.dart';

import 'milestones.dart';
import 'platforms.dart';

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

  /// Every entry on a main chart is news the player hears about (F67: a
  /// #45 debut on the global chart went by unnoticed).
  @override
  bool get isMajor => true;
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

/// A career milestone was reached; it paid skill points (docs K61).
class MilestoneReached extends GameEvent {
  const MilestoneReached(this.milestone);
  final Milestone milestone;
  @override
  bool get isMajor => true;
}

/// The player's tour played its last show (docs K63, K76).
class TourFinished extends GameEvent {
  const TourFinished(
      {required this.kind,
      this.name = '',
      this.shows = 0,
      this.soldOut = 0,
      this.grossCents = 0,
      required this.tickets,
      required this.netCents,
      required this.fans});
  final TourKind kind;

  /// The player's name for it ('' = named after its venues).
  final String name;
  final int shows;
  final int soldOut;
  final int grossCents;
  final double tickets;
  final int netCents;
  final double fans;
  @override
  bool get isMajor => true;
}

/// The player played a festival set (docs K77).
class FestivalPlayed extends GameEvent {
  const FestivalPlayed(
      {required this.festival,
      required this.slot,
      required this.watched,
      required this.feeCents,
      required this.fans});
  final String festival;
  final FestivalSlot slot;
  final double watched;
  final int feeCents;
  final double fans;
  @override
  bool get isMajor => true;
}

/// The platform caught the player's bought streams (docs K95): removed,
/// royalties paid back, the song filtered from the charts for a while.
class BotsCaught extends GameEvent {
  const BotsCaught(this.songId, this.removed, {this.refundCents = 0});
  final int songId;
  final double removed;

  /// Royalties paid back for the removed streams.
  final int refundCents;
  @override
  bool get isMajor => true;
}

/// A rival's streams were removed for botting: shown in the player's news
/// too (docs K95, F65).
class RivalBotsCaught extends GameEvent {
  const RivalBotsCaught(this.songId, this.artistId, this.removed);
  final int songId;
  final int artistId;
  final double removed;
  @override
  bool get isMajor => false;
}

/// The playlist editors passed on the player's pitch (docs K97).
class PitchDeclined extends GameEvent {
  const PitchDeclined(this.songId);
  final int songId;
  @override
  bool get isMajor => false;
}

/// The player is up for Golden Record Awards (docs K91).
class AwardNominated extends GameEvent {
  const AwardNominated(this.year, this.categories);

  /// The show's year (held next February).
  final int year;
  final List<AwardCategory> categories;
  @override
  bool get isMajor => true;
}

/// The show the player was nominated at was held: what they won and what
/// the night did.
class AwardResults extends GameEvent {
  const AwardResults(
      {required this.year,
      required this.nominations,
      required this.won,
      required this.attendance,
      required this.fans});
  final int year;
  final int nominations;
  final List<AwardCategory> won;
  final AwardAttendance attendance;
  final double fans;
  @override
  bool get isMajor => true;
}

/// Industry headline: the year's big winners (docs K91).
class AwardWinners extends GameEvent {
  const AwardWinners(
      {required this.year,
      required this.albumArtistId,
      required this.albumId,
      required this.recordArtistId,
      required this.songId});
  final int year;

  /// -1 when the category was not held.
  final int albumArtistId;
  final int albumId;
  final int recordArtistId;
  final int songId;
  @override
  bool get isMajor => false;
  @override
  bool get isIndustry => true;
}

/// A new platform opened this year (docs K67).
class PlatformOpened extends GameEvent {
  const PlatformOpened(this.platform);
  final MusicPlatform platform;
  @override
  bool get isMajor => false;
}

/// The player's release came out the same week as a big rival's (docs
/// K69): where each landed on the US chart that week. A position of 0 is
/// off the chart.
class ChartBattle extends GameEvent {
  const ChartBattle({
    required this.kind,
    required this.playerEntityId,
    required this.rivalEntityId,
    required this.rivalArtistId,
    required this.playerPosition,
    required this.rivalPosition,
  });
  final EntityKind kind;
  final int playerEntityId;
  final int rivalEntityId;
  final int rivalArtistId;
  final int playerPosition;
  final int rivalPosition;

  bool get won =>
      playerPosition > 0 &&
      (rivalPosition == 0 || playerPosition < rivalPosition);
  @override
  bool get isMajor => true;
}
