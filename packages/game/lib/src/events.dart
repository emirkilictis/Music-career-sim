import 'package:simulation_core/simulation_core.dart';

import 'milestones.dart';
import 'platforms.dart';
import 'views.dart' show RecordKind, WrappedStory;

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

/// A player song is catching on by word of mouth (docs K108): more
/// people find it every week, for months.
class CatchingOn extends GameEvent {
  const CatchingOn(this.songId);
  final int songId;
  @override
  bool get isMajor => true;
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

/// The streaming app's discovery mixes picked a player song (docs K119).
class DiscoverPick extends GameEvent {
  const DiscoverPick(this.songId);
  final int songId;
  @override
  bool get isMajor => false;
}

/// The label's advance is paid back: royalties are all the player's
/// again (docs K107, F72).
class AdvanceRecouped extends GameEvent {
  const AdvanceRecouped(this.label);
  final Label label;
  @override
  bool get isMajor => true;
}

/// A player's video passed [views] on the video site (docs K118): 100M
/// is certified, 1B the billion views club.
class VideoMilestone extends GameEvent {
  const VideoMilestone(this.songId, this.views);
  final int songId;
  final double views;
  @override
  bool get isMajor => views >= Platforms.billionViews;
}

/// A player song passed a play count on the streaming app (docs K132);
/// a billion is the Billions Club.
class StreamMilestone extends GameEvent {
  const StreamMilestone(this.songId, this.plays);
  final int songId;
  final double plays;
  @override
  bool get isMajor => plays >= Platforms.billionsClub;
}

/// The player's song on the K-pop music show (docs K114): won (its
/// [wins]th time, a Triple Crown at three in a row) or came second.
class MusicShowResult extends GameEvent {
  const MusicShowResult(this.songId,
      {required this.won,
      required this.wins,
      this.tripleCrown = false,
      this.otherSongId = -1});
  final int songId;
  final bool won;
  final int wins;
  final bool tripleCrown;

  /// The song it lost to (or beat).
  final int otherSongId;
  @override
  bool get isMajor => won && (wins == 1 || tripleCrown);
}

/// The player made the top 10 of the top artists chart, or #1 (docs
/// K113).
class TopArtist extends GameEvent {
  const TopArtist(this.rank);
  final int rank;
  @override
  bool get isMajor => rank == 1;
}

/// The player set an all-time record (docs K111): [value] is weeks,
/// units or streams, by [kind].
class RecordBroken extends GameEvent {
  const RecordBroken(this.kind, this.entityId, this.value);
  final RecordKind kind;
  final int entityId;
  final double value;
  @override
  bool get isMajor => true;
}

/// A song the player wrote for [artistId] reached the US top 10 for the
/// first time, or #1 (docs K143).
class WrittenSongHit extends GameEvent {
  const WrittenSongHit(this.songId, this.artistId, this.position);
  final int songId;
  final int artistId;
  final int position;
  @override
  bool get isMajor => true;
}

/// The player's career records sold passed [copies] (docs K141).
class SalesMilestone extends GameEvent {
  const SalesMilestone(this.copies);
  final double copies;
  @override
  bool get isMajor => copies >= 10e6;
}

/// The player is among the best-selling artists of all time (docs K141):
/// now #[rank] (10 on entering the top 10, 1 at the top).
class AllTimeBestSeller extends GameEvent {
  const AllTimeBestSeller(this.rank);
  final int rank;
  @override
  bool get isMajor => true;
}

/// The year-end charts are out (docs K110): the player's songs and albums
/// in the US top 100 with their ranks, and the song of the year.
class YearEndCharts extends GameEvent {
  const YearEndCharts(this.year,
      {required this.songs, required this.albums, required this.topSongId});
  final int year;
  final List<(int rank, int songId)> songs;
  final List<(int rank, int albumId)> albums;

  /// The year's #1 song on the US chart (-1: none).
  final int topSongId;
  bool get hasPlayer => songs.isNotEmpty || albums.isNotEmpty;
  @override
  bool get isMajor => hasPlayer;
  @override
  bool get isIndustry => !hasPlayer;
}

/// The player's album or EP came out with no announcement and made
/// headlines (docs K124).
class SurpriseDrop extends GameEvent {
  const SurpriseDrop(this.albumId);
  final int albumId;
  @override
  bool get isMajor => true;
}

/// The player's year on the streaming app is out (docs K123).
class WrappedOut extends GameEvent {
  const WrappedOut(this.year,
      {required this.plays, required this.topSongId, required this.story});
  final int year;
  final double plays;
  final int topSongId;
  final WrappedStory story;
  @override
  bool get isMajor => true;
}

/// A rival's answer to the player's announced album (docs K109): moved
/// out of its way, or the same week for a head-to-head.
class RivalAlbumClash extends GameEvent {
  const RivalAlbumClash(this.clash);
  final RivalClash clash;
  @override
  bool get isMajor => !clash.moved;
}

/// A streaming platform opened in a region this week (docs K38): its Top 50
/// chart [chartId] starts.
class PlatformLaunched extends GameEvent {
  const PlatformLaunched(this.chartId);
  final int chartId;
  @override
  bool get isMajor => false;
}

/// The holiday season starts (docs K106): until Christmas people buy far
/// more records as gifts, catalog albums too.
class HolidaySeason extends GameEvent {
  const HolidaySeason();
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
  const CriticReview(this.albumId, this.score, {this.metascore = -1});
  final int albumId;

  /// Pitchwork's score, and the average of every outlet (docs K112).
  final double score;
  final int metascore;
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

/// A brand deal broke over a missed task (docs K102): the second half of
/// the fee is lost.
class BrandDealBroken extends GameEvent {
  const BrandDealBroken(this.brand, this.lostCents);
  final BrandInfo brand;
  final int lostCents;
  @override
  bool get isMajor => true;
}

/// The playlist editors passed on the player's pitch (docs K97).
class PitchDeclined extends GameEvent {
  const PitchDeclined(this.songId);
  final int songId;
  @override
  bool get isMajor => false;
}

/// The songs of the summer are out (docs K137): the #1, and the player's
/// best place in the top 20 (0: none).
class SongOfSummer extends GameEvent {
  const SongOfSummer(this.year,
      {required this.topSongId,
      required this.playerRank,
      required this.playerSongId});
  final int year;
  final int topSongId;
  final int playerRank;
  final int playerSongId;
  bool get hasPlayer => playerRank > 0;
  @override
  bool get isMajor => playerRank > 0 && playerRank <= 10;
  @override
  bool get isIndustry => !hasPlayer;
}

/// An unreleased song of the player's leaked (docs K140): put it out
/// within [Leaks.answerWeeks] weeks to turn the talk into listening.
class SongLeaked extends GameEvent {
  const SongLeaked(this.songId);
  final int songId;
  @override
  bool get isMajor => true;
}

/// A player's holiday song is back for the season (docs K136).
class HolidayReturn extends GameEvent {
  const HolidayReturn(this.songId);
  final int songId;
  @override
  bool get isMajor => false;
}

/// The paid creators did not start a trend (docs K131).
class CreatorsFlopped extends GameEvent {
  const CreatorsFlopped(this.songId);
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
