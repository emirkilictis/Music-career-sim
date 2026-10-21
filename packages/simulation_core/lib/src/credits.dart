import 'dart:math' as math;

import 'actions.dart';
import 'lineups.dart';
import 'model.dart';
import 'world.dart';

/// Songs that count for the player without being under their name (docs
/// K158): a group member's solo records, under the member's own name but
/// run and paid by the group, and the player's verses on rivals' songs.
abstract final class Credits {
  // ---------------------------------------------------------- member solos

  /// What a member brings from the group to their own name.
  static const memberFans = 0.2, memberCasual = 0.15, memberFame = 0.6;

  /// [group]'s member [member] as an artist of their own, made the first
  /// time they put out a solo record.
  static Artist memberArtist(World w, Artist group, int member) {
    final known = memberIdOf(group, member);
    if (known >= 0) return w.artists[known];
    final a = _newMember(w, group, member);
    w.addArtist(a);
    while (group.memberArtistIds.length < group.members.length) {
      group.memberArtistIds.add(-1);
    }
    group.memberArtistIds[member] = a.id;
    w.dirtyArtists.add(group.id);
    return a;
  }

  /// The artist id of [group]'s member [member] (-1: no solo record yet).
  static int memberIdOf(Artist group, int member) {
    if (member < 0 || member >= group.members.length) {
      throw ActionException('No such member');
    }
    return member < group.memberArtistIds.length
        ? group.memberArtistIds[member]
        : -1;
  }

  static Artist _newMember(World w, Artist group, int member) {
    final s = group.skills;
    // A popular member brings more of the group's fans (docs K192).
    final k = Lineups.importance(w, group, member);
    return Artist(
      id: w.artists.length,
      name: group.members[member],
      tier: ArtistTier.b,
      genre: group.genre,
      debutWeek: w.week,
      skills: Skills(
          songwriting: s.songwriting * 0.9,
          vocals: s.vocals,
          production: s.production * 0.9,
          performance: s.performance,
          charisma: s.charisma),
      fame: math.min(0.95, group.fame * memberFame * (0.75 + 0.25 * k)),
      coreFans: group.coreFans * memberFans * k,
      casual: group.casual * memberCasual * k,
      homeCountry: group.homeCountry,
      labelReach: group.labelReach,
      artistShare: group.artistShare,
    )
      ..managedBy = group.id
      ..devotion = group.devotion
      ..label = group.label
      // The group decides what comes out: no plans of their own.
      ..nextEraWeek = 1 << 30;
  }

  /// What [group] pays for [campaign] on member [member]'s solo single:
  /// priced on the member's audience, the group's label paying its part.
  static int soloCostCents(
      World w, Artist group, int member, Campaign campaign) {
    final id = memberIdOf(group, member);
    final m = id >= 0 ? w.artists[id] : _newMember(w, group, member);
    return (campaign.costCents *
            Actions.campaignSizeFactor(m) *
            group.label.campaignShare)
        .round();
  }

  /// Puts out [group]'s vault song [s] as member [member]'s solo single:
  /// the song becomes theirs (the group's version is gone), the group
  /// pays the campaign and keeps the money. Returns the member's song.
  static Song releaseMemberSolo(World w, Artist group, int member, Song s,
      {Campaign campaign = Campaign.standard}) {
    if (s.primaryArtistId != group.id || s.status != SongStatus.vault) {
      throw ActionException('Only unreleased songs');
    }
    final cost = soloCostCents(w, group, member, campaign);
    if (group.moneyCents < cost) throw ActionException('Not enough money');
    final m = memberArtist(w, group, member);
    group.moneyCents -= cost;
    final song = _transfer(w, group, m, s);
    Lineups.onSolo(w, group, member);
    Actions.releaseSingle(w, m, song,
        campaign: campaign, prepaid: true, paidCents: cost);
    return song;
  }

  /// Moves [group]'s vault song [s] to member [m]: the member's own
  /// recording of it; the group's version is gone.
  static Song _transfer(World w, Artist group, Artist m, Song s) {
    final song = Song(
      id: w.songs.length,
      title: s.title,
      genre: s.genre,
      extraGenres: List.of(s.extraGenres),
      primaryArtistId: m.id,
      featuredArtistIds: List.of(s.featuredArtistIds),
      writtenWeek: w.week,
      quality: s.quality,
      commercial: s.commercial,
      fanAppeal: s.fanAppeal,
      radioAppeal: s.radioAppeal,
      virality: s.virality,
      longevity: s.longevity,
      estimatedGrade: s.estimatedGrade,
    )
      ..gradeSpread = s.gradeSpread
      ..holiday = s.holiday
      ..productionCostCents = s.productionCostCents;
    w.songs.add(song);
    w.managedSongIds.add(song.id);
    s.status = SongStatus.scrapped;
    s.soldTo = song.id;
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(group.id);
    return song;
  }

  /// Album types a member can put out.
  static const memberAlbumTypes = [AlbumType.ep, AlbumType.album];

  /// Puts out [group]'s vault songs [songs] as member [member]'s solo
  /// EP or album [title] (docs K173): under the member's name, paid for
  /// by the group, earning for it. Returns the album.
  static Album releaseMemberAlbum(
      World w, Artist group, int member, String title, List<Song> songs,
      {AlbumType type = AlbumType.album,
      Campaign campaign = Campaign.standard}) {
    if (!memberAlbumTypes.contains(type)) throw ActionException('EP or album');
    for (final s in songs) {
      if (s.primaryArtistId != group.id || s.status != SongStatus.vault) {
        throw ActionException('Only unreleased songs');
      }
    }
    final cost = soloCostCents(w, group, member, campaign);
    if (group.moneyCents < cost) throw ActionException('Not enough money');
    final m = memberArtist(w, group, member);
    group.moneyCents -= cost;
    final ids = [for (final s in songs) _transfer(w, group, m, s).id];
    Lineups.onSolo(w, group, member);
    return Actions.releaseAlbum(w, m, title, ids,
        type: type, campaign: campaign, prepaid: true, paidCents: cost);
  }

  /// Whether [a] is run by [owner] (a member's solo name).
  static bool runBy(Artist a, int owner) => a.managedBy == owner;

  // ------------------------------------------------- the player's features

  /// A featured artist's share of what a song earns.
  static const guestShare = 0.15;

  /// Weeks until the song with the player's verse comes out.
  static const guestReleaseAfter = 2;

  /// [partner] records a song with [guest] on it and plans it as a single
  /// ([producerSkill] their team's craft). Returns the song.
  static Song guestOn(World w, Artist partner, Artist guest,
      {double producerSkill = 70}) {
    final s = Actions.writeSong(w, partner,
        producerSkill: producerSkill, aiMode: true, featured: [guest.id]);
    w.guestSongIds.add(s.id);
    final at = w.week + guestReleaseAfter;
    final i = partner.plan.indexWhere((p) => p.week > at);
    final planned =
        PlannedRelease(week: at, kind: PlannedKind.single, songId: s.id);
    if (i < 0) {
      partner.plan.add(planned);
    } else {
      partner.plan.insert(i, planned);
    }
    w.dirtyArtists.add(partner.id);
    return s;
  }
}
