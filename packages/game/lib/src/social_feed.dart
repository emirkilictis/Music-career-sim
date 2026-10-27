import 'package:simulation_core/simulation_core.dart';

import 'events.dart';
import 'platforms.dart';

/// Fans react to the player's week in the feed (docs K93): a release, a
/// #1, a review, the awards, a scandal, a long silence.
abstract final class SocialFeed {
  /// Fan posts in one week at most.
  static const maxPerWeek = 5;

  static void react(World w, Artist p, List<GameEvent> events, int week) {
    final r = RandomStream.keyed(w.seed, week, p.id, RngPurpose.social + 1);
    final followers = Social.followers(w, p);
    final items = <SocialItem>[];
    // The same topic twice in a week takes its next wording.
    final base = r.nextInt(Social.variants);
    final used = <FanTopic, int>{};
    void fan(FanTopic topic,
        {int songId = -1, int albumId = -1, int number = 0}) {
      items.add(SocialItem(
        week: week,
        topic: topic,
        variant:
            (base + (used[topic] = (used[topic] ?? -1) + 1)) % Social.variants,
        fan: r.nextInt(1 << 20),
        songId: songId,
        albumId: albumId,
        number: number,
        likes: (followers * r.range(0.0005, 0.01)).round(),
      ));
    }

    // How a release lands: its quality (an album's reviews count too).
    void release(double quality, {int songId = -1, int albumId = -1}) {
      if (quality >= 72) {
        fan(FanTopic.releaseLove, songId: songId, albumId: albumId);
        fan(FanTopic.releaseLove, songId: songId, albumId: albumId);
      } else if (quality >= 55) {
        fan(FanTopic.releaseLove, songId: songId, albumId: albumId);
        fan(FanTopic.releaseMixed, songId: songId, albumId: albumId);
      } else {
        fan(FanTopic.releaseMixed, songId: songId, albumId: albumId);
        fan(FanTopic.releaseHate, songId: songId, albumId: albumId);
      }
    }

    // What came out this week, scheduled or not.
    for (final al in w.albums.reversed) {
      if (al.releaseWeek < week) break;
      if (al.artistId == p.id && al.releaseWeek == week) {
        release(al.quality, albumId: al.id);
      }
    }
    // A new version of an album out this week (docs K115, K225, K226):
    // the third in a few weeks reads as a cash grab.
    for (final al in w.albums) {
      if (al.artistId != p.id || al.versions.isEmpty) continue;
      // The week's last version is the news.
      final i = al.versions.lastIndexWhere((v) => v.week == week);
      if (i < 0) continue;
      final v = al.versions[i];
      final before = al.versions
          .take(i)
          .where((x) => week - x.week < AlbumVersions.fatigueWeeks)
          .length;
      final format = v.edition < al.variantFormats.length
          ? al.variantFormats[v.edition]
          : -1;
      final topic = v.anniversary >= 0
          ? FanTopic.anniversaryOut
          : format == EditionFormat.deluxe.index
              ? FanTopic.deluxeOut
              : FanTopic.versionOut;
      if (before >= 2) {
        fan(FanTopic.cashGrab, albumId: al.id);
        fan(FanTopic.cashGrab, albumId: al.id);
        fan(topic, albumId: al.id);
      } else {
        fan(topic, albumId: al.id);
        fan(topic, albumId: al.id);
      }
    }
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.primaryArtistId == p.id &&
          s.isSingle &&
          s.singleWeek == week &&
          (s.albumId < 0 || w.albums[s.albumId].releaseWeek != week)) {
        release(s.quality, songId: id);
      }
    }
    for (final e in events) {
      switch (e) {
        case NumberOne(:final kind, :final entityId, firstForRelease: true):
          fan(FanTopic.numberOne,
              songId: kind == EntityKind.song ? entityId : -1,
              albumId: kind == EntityKind.album ? entityId : -1);
        case ChartDebut(kind: EntityKind.song, :final entityId, :final position)
            when position <= 10 && position > 1:
          fan(FanTopic.topTen, songId: entityId, number: position);
        case AlbumFirstWeek(:final albumId, :final usUnits) when usUnits >= 1e5:
          fan(FanTopic.bigWeek, albumId: albumId, number: usUnits.round());
        case CriticReview(:final albumId, :final score):
          if (score >= 7.5) {
            fan(FanTopic.criticHigh,
                albumId: albumId, number: (score * 10).round());
          } else if (score < 5.5) {
            fan(FanTopic.criticLow,
                albumId: albumId, number: (score * 10).round());
          }
        case AwardNominated():
          fan(FanTopic.nominated);
        case AwardResults(:final won):
          fan(won.isEmpty ? FanTopic.awardRobbed : FanTopic.awardWon);
          fan(won.isEmpty ? FanTopic.awardRobbed : FanTopic.awardWon);
        case OpportunityCame(kind: OpportunityKind.scandal):
          fan(FanTopic.scandal);
          fan(FanTopic.scandal);
        case TourFinished():
          fan(FanTopic.tour);
          fan(FanTopic.tour);
        case ViralTrend(:final songId):
          fan(FanTopic.viral, songId: songId);
        case EraClosed(:final result)
            when result == EraResult.flop || result == EraResult.disappointing:
          fan(FanTopic.flopEra);
        case ChartBattle(:final won, :final kind, :final playerEntityId)
            when !won:
          fan(FanTopic.battleLost,
              songId: kind == EntityKind.song ? playerEntityId : -1,
              albumId: kind == EntityKind.album ? playerEntityId : -1);
        case BotsCaught(:final songId):
          fan(FanTopic.botsCaught, songId: songId);
          fan(FanTopic.botsCaught, songId: songId);
        case RivalBotsCaught(:final songId):
          fan(FanTopic.rivalPurge, songId: songId);
        case MilestoneReached():
          fan(FanTopic.milestone);
        // The newer stories (docs K108–K115).
        case RecordBroken(:final kind, :final entityId):
          fan(FanTopic.recordBroken,
              songId: kind.isAlbum ? -1 : entityId,
              albumId: kind.isAlbum ? entityId : -1);
          fan(FanTopic.recordBroken,
              songId: kind.isAlbum ? -1 : entityId,
              albumId: kind.isAlbum ? entityId : -1);
        case YearEndCharts(:final songs, :final albums) when e.hasPlayer:
          if (songs.isNotEmpty) {
            fan(FanTopic.yearEndHit,
                songId: songs.first.$2, number: songs.first.$1);
          } else {
            fan(FanTopic.yearEndHit,
                albumId: albums.first.$2, number: albums.first.$1);
          }
        case SurpriseDrop(:final albumId):
          fan(FanTopic.surpriseDrop, albumId: albumId);
          fan(FanTopic.surpriseDrop, albumId: albumId);
        case StreamMilestone(:final songId, :final plays)
            when plays >= Platforms.billionsClub:
          fan(FanTopic.billionsClub, songId: songId);
          fan(FanTopic.billionsClub, songId: songId);
        case WrappedOut(:final topSongId):
          fan(FanTopic.wrapped, songId: topSongId);
          fan(FanTopic.wrapped, songId: topSongId);
        case MusicShowResult(:final songId, won: true, tripleCrown: true):
          fan(FanTopic.tripleCrown, songId: songId);
          fan(FanTopic.tripleCrown, songId: songId);
        case MusicShowResult(:final songId, won: true, :final wins):
          fan(FanTopic.musicShowWin, songId: songId, number: wins);
        case CatchingOn(:final songId):
          fan(FanTopic.catchingOn, songId: songId);
        case TopArtist(rank: 1):
          fan(FanTopic.topArtistNo1);
          fan(FanTopic.topArtistNo1);
        default:
          break;
      }
    }
    // A long silence: fans ask for new music every couple of months.
    final st = w.social;
    if (p.lastReleaseWeek >= 0 &&
        week - p.lastReleaseWeek >= 26 &&
        week - st.lastHiatusWeek >= 8) {
      st.lastHiatusWeek = week;
      fan(FanTopic.hiatus, number: (week - p.lastReleaseWeek) * 7);
    }
    for (final item in items.take(maxPerWeek)) {
      Social.add(w, item);
    }
  }
}
