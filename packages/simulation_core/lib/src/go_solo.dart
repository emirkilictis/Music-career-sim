import 'dart:math' as math;

import 'actions.dart';
import 'credits.dart';
import 'lineups.dart';
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
  /// What an average member takes of the group's audience.
  static const takeFans = 0.35, takeCasual = 0.3, takeFame = 0.8;

  /// What the group keeps of its own when an average member leaves.
  static const keepFans = 0.75, keepCasual = 0.85, keepFame = 0.9;

  // A member's weight in the split is their importance [k] (1: average;
  // docs K192): a popular member takes more, and the group loses more.
  static double fansTaken(double k) => (takeFans * k).clamp(0.1, 0.7);
  static double casualTaken(double k) => (takeCasual * k).clamp(0.08, 0.6);
  static double fameTaken(double k) =>
      math.min(0.95, takeFame * (0.75 + 0.25 * k));
  static double fansKept(double k) =>
      (1 - (1 - keepFans) * k).clamp(0.35, 0.95);
  static double casualKept(double k) =>
      (1 - (1 - keepCasual) * k).clamp(0.5, 0.97);
  static double fameKept(double k) => (1 - (1 - keepFame) * k).clamp(0.7, 0.98);

  /// The group's ace leaving shakes the fandom too.
  static bool isAce(double k) => k >= Lineups.aceAt;

  /// Without a star this far above the rest, the group goes on a hiatus
  /// it never comes back from (the way a boy band ends when its frontman
  /// goes solo).
  static const hiatusAt = 2.0;
  static bool endsGroup(Artist group, double k) =>
      breaksUp(group) || k >= hiatusAt;

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
    final k = Lineups.importance(w, group, member);
    final solo = Credits.memberArtist(w, group, member);

    // Plans made as a group are off; what was paid comes back.
    for (final sr in group.scheduled) {
      group.moneyCents += sr.paidCents;
    }
    group.scheduled.clear();
    group.opportunity = null;

    final ends = endsGroup(group, k);
    _takeOver(group, solo);
    _splitAudience(group, solo, k);

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
    Lineups.remove(group, member);
    group
      ..tier = group.fame >= 0.4 ? ArtistTier.a : ArtistTier.b
      ..nextEraWeek = w.week + groupBreakWeeks
      ..moneyCents = 0;
    group.plan.clear();
    group.pendingAlbumSongIds.clear();
    if (ends) w.retire(group);

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

  static void _splitAudience(Artist group, Artist solo, double k) {
    solo
      ..fame = math.max(solo.fame, group.fame * fameTaken(k))
      ..popularity = math.max(solo.popularity, group.popularity * fameTaken(k))
      ..coreFans = math.max(solo.coreFans, group.coreFans * fansTaken(k))
      ..casual = math.max(solo.casual, group.casual * casualTaken(k))
      ..devotion = math.max(solo.devotion, group.devotion * 0.9)
      ..hype = math.max(solo.hype, group.hype * 0.5)
      ..buzz = solo.buzz + splitBuzz;
    group
      ..fame = group.fame * fameKept(k)
      ..popularity = group.popularity * fameKept(k)
      ..coreFans = group.coreFans * fansKept(k)
      ..casual = group.casual * casualKept(k)
      ..devotion = math.max(0.0, group.devotion - (isAce(k) ? 0.15 : 0.05))
      ..hype = isAce(k) ? 0 : group.hype * 0.5;
    solo.updateRegionShare();
    group.updateRegionShare();
  }
}
