import 'dart:math' as math;

import 'actions.dart';
import 'credits.dart';
import 'model.dart';
import 'world.dart';

/// What stops the player's group splitting now (docs K191).
enum GoSoloBlock {
  /// The player is a solo artist.
  notGroup,

  /// Not with a tour on the road.
  onTour,
}

/// Going solo (docs K191): a member leaves the player's group and the
/// player goes on as that member, under their own name. The member takes
/// the player's money, skills, team, contract and unreleased songs, and a
/// share of the group's audience; the group, a few fans lighter, carries
/// on without them as a rival after a break (or breaks up if one member
/// would be left). The group's records stay the group's.
abstract final class GoSolo {
  /// What the member takes of the group's audience.
  static const takeFans = 0.35, takeCasual = 0.3, takeFame = 0.8;

  /// What the group keeps of its own.
  static const keepFans = 0.75, keepCasual = 0.85, keepFame = 0.9;

  /// The talk a split makes, for the new solo artist.
  static const splitBuzz = 0.3;

  /// Weeks the group rests before it puts out anything again.
  static const groupBreakWeeks = 26;

  static GoSoloBlock? block(World w) {
    final p = w.player;
    if (p == null || !p.kind.isGroup || p.members.isEmpty) {
      return GoSoloBlock.notGroup;
    }
    if (p.tour != null) return GoSoloBlock.onTour;
    return null;
  }

  /// Whether the group breaks up when [member] leaves.
  static bool breaksUp(Artist group) =>
      group.members.length - 1 < ArtistKind.minMembers;

  /// Splits the player's group: member [member] leaves and becomes the
  /// player. Returns the member's artist.
  static Artist split(World w, int member) {
    final why = block(w);
    if (why != null) throw ActionException('Cannot go solo: ${why.name}');
    final group = w.player!;
    if (member < 0 || member >= group.members.length) {
      throw ActionException('No such member');
    }
    final solo = Credits.memberArtist(w, group, member);

    // Plans made as a group are off; what was paid comes back.
    for (final sr in group.scheduled) {
      group.moneyCents += sr.paidCents;
    }
    group.scheduled.clear();
    group.opportunity = null;

    _takeOver(group, solo);
    _splitAudience(group, solo);

    // The songs no one has heard go with the member.
    for (final s in w.songs) {
      if (s.primaryArtistId == group.id && s.status == SongStatus.vault) {
        s.primaryArtistId = solo.id;
        w.dirtySongs.add(s.id);
      }
    }

    // The member is the player now.
    solo
      ..tier = ArtistTier.player
      ..managedBy = -1
      ..nextEraWeek = -1;
    solo.plan.clear();
    // The career's streams run on from the group's (docs K191).
    w.careerStreamsBase +=
        w.artistLifetimeStreams(group) - w.artistLifetimeStreams(solo);
    w.playerArtistId = solo.id;
    w.playerSinceWeek = w.week;
    w.formerGroupId = group.id;

    // The group without them: a rival after a break, or the end.
    group.members.removeAt(member);
    if (member < group.memberArtistIds.length) {
      group.memberArtistIds.removeAt(member);
    }
    group
      ..tier = group.fame >= 0.4 ? ArtistTier.a : ArtistTier.b
      ..nextEraWeek = w.week + groupBreakWeeks
      ..moneyCents = 0;
    group.plan.clear();
    group.pendingAlbumSongIds.clear();
    if (breaksUp(group)) w.retire(group);

    // What belonged to the group's page.
    w.fanClub = null;
    w.artistPick = null;
    w.thisIsWeek = -1;
    w.playerPeakListeners = -1;
    w.rebuildPlayerSongLists();
    w.dirtyArtists
      ..add(group.id)
      ..add(solo.id);
    return solo;
  }

  /// The player's own things move from [group] to [solo].
  static void _takeOver(Artist group, Artist solo) {
    solo
      ..moneyCents = solo.moneyCents + group.moneyCents
      ..creativeEnergy = group.creativeEnergy
      ..burnoutUntilWeek = group.burnoutUntilWeek
      ..lastWriteWeek = group.lastWriteWeek
      ..songsWrittenThisWeek = group.songsWrittenThisWeek
      ..restWeek = group.restWeek
      ..skillPoints = group.skillPoints
      ..label = group.label
      ..contractAlbumsLeft = group.contractAlbumsLeft
      ..contractAdvanceCents = group.contractAdvanceCents
      ..contractAlbums = group.contractAlbums
      ..unrecoupedCents = group.unrecoupedCents
      ..manager = group.manager
      ..job = group.job
      ..lastAdWeek = group.lastAdWeek
      ..adsWatchedThisWeek = group.adsWatchedThisWeek
      ..labelReach = group.labelReach
      ..artistShare = group.artistShare
      ..distributor = group.distributor
      ..surpriseWeek = group.surpriseWeek;
    for (final k in SkillKind.values) {
      solo.skills[k] = group.skills[k];
    }
    // Milestones already reached are not reached again.
    solo.milestones.addAll(group.milestones);
    for (var i = 0; i < solo.marketBonus.length; i++) {
      solo.marketBonus[i] = math.max(solo.marketBonus[i], group.marketBonus[i]);
    }
    group
      ..moneyCents = 0
      ..skillPoints = 0
      ..job = Job.none
      ..manager = Manager.none
      ..contractAlbumsLeft = 0
      ..contractAdvanceCents = 0
      ..contractAlbums = 0
      ..unrecoupedCents = 0;
  }

  static void _splitAudience(Artist group, Artist solo) {
    solo
      ..fame = math.max(solo.fame, group.fame * takeFame)
      ..popularity = math.max(solo.popularity, group.popularity * takeFame)
      ..coreFans = math.max(solo.coreFans, group.coreFans * takeFans)
      ..casual = math.max(solo.casual, group.casual * takeCasual)
      ..devotion = math.max(solo.devotion, group.devotion * 0.9)
      ..hype = math.max(solo.hype, group.hype * 0.5)
      ..buzz = solo.buzz + splitBuzz;
    group
      ..fame = group.fame * keepFame
      ..popularity = group.popularity * keepFame
      ..coreFans = group.coreFans * keepFans
      ..casual = group.casual * keepCasual
      ..devotion = math.max(0.0, group.devotion - 0.05)
      ..hype = group.hype * 0.5;
    solo.updateRegionShare();
    group.updateRegionShare();
  }
}
