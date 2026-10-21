import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'credits.dart';
import 'lineups.dart';
import 'model.dart';
import 'world.dart';

/// What stops a reunion now (docs K194).
enum ReunionBlock {
  /// The player never left a group.
  noGroup,

  /// Not long enough apart (or since the last reunion).
  tooSoon,

  /// A reunion is on.
  active,
}

/// The reunion (docs K194): years after going solo, the player gets back
/// together with the group they left for a year. Nostalgia brings back
/// fans the group had lost, and the more years apart the more come back.
/// The player puts out records under the group's name, paid by them and
/// earning for them, and the group's old songs earn for them that year
/// too. Then the group goes back to what it was: a rival, or over.
abstract final class Reunions {
  /// Years apart before a reunion, and between reunions.
  static const gapWeeks = 156;

  /// How long it lasts.
  static const weeks = 52;

  /// Nostalgia: what comes back grows with the years apart, up to [maxNostalgia].
  static const nostalgiaPerYear = 0.06, maxNostalgia = 0.5;

  /// The talk a reunion makes.
  static const hype = 0.8, buzz = 0.6, soloBuzz = 0.2;

  static Artist? group(World w) =>
      w.formerGroupId < 0 ? null : w.artists[w.formerGroupId];

  static bool active(World w) =>
      w.reunionStartWeek >= 0 &&
      w.week >= w.reunionStartWeek &&
      w.week < w.reunionEndWeek;

  static ReunionBlock? block(World w) {
    if (w.player == null || w.formerGroupId < 0) return ReunionBlock.noGroup;
    if (active(w)) return ReunionBlock.active;
    final since = math.max(w.playerSinceWeek, w.reunionEndWeek);
    if (w.week - since < gapWeeks) return ReunionBlock.tooSoon;
    return null;
  }

  /// The week a reunion can happen from.
  static int openWeek(World w) =>
      math.max(w.playerSinceWeek, w.reunionEndWeek) + gapWeeks;

  static double nostalgia(World w) => math.min(maxNostalgia,
      nostalgiaPerYear * (w.week - w.playerSinceWeek) / 52);

  /// The group's audience during the reunion.
  static ({double fans, double casual, double fame}) audience(World w) {
    final g = group(w)!;
    final f = nostalgia(w);
    return (
      fans: math.max(g.coreFans, w.formerFans * (0.5 + f)),
      casual: math.max(g.casual, w.formerCasual * (0.4 + f)),
      fame: math.max(g.fame, math.min(0.95, w.formerFame * (0.8 + f / 2))),
    );
  }

  /// Gets the band back together.
  static void start(World w) {
    final why = block(w);
    if (why != null) throw ActionException('No reunion: ${why.name}');
    final p = w.player!;
    final g = group(w)!;
    final a = audience(w);
    w.reunionWasRetired = g.isRetired;
    if (g.isRetired) w.unretire(g);
    g
      ..coreFans = a.fans
      ..casual = a.casual
      ..fame = a.fame
      ..popularity = math.max(g.popularity, a.fame)
      ..hype = math.max(g.hype, hype)
      ..buzz = g.buzz + buzz
      // The player runs it: no plans of the group's own.
      ..managedBy = p.id
      ..nextEraWeek = 1 << 30;
    g.plan.clear();
    g.pendingAlbumSongIds.clear();
    g.updateRegionShare();
    // Back in the lineup.
    g.members.add(p.name);
    Lineups.addMember(g, pop: 80, morale: 80);
    p.buzz += soloBuzz;
    w.reunionStartWeek = w.week;
    w.reunionEndWeek = w.week + weeks;
    w.rebuildPlayerSongLists();
    w.dirtyArtists
      ..add(g.id)
      ..add(p.id);
  }

  /// Ends the reunion when its year is up; true if it ended now.
  static bool endIfDue(World w) {
    final g = group(w);
    final p = w.player;
    if (g == null || p == null || w.reunionStartWeek < 0) return false;
    if (w.week < w.reunionEndWeek || g.managedBy != p.id) return false;
    g.managedBy = -1;
    final i = g.members.lastIndexOf(p.name);
    if (i >= 0) {
      g.members.removeAt(i);
      Lineups.remove(g, i);
    }
    if (w.reunionWasRetired) {
      w.retire(g);
    } else {
      g
        ..tier = g.fame >= 0.4 ? ArtistTier.a : ArtistTier.b
        ..nextEraWeek = w.week + 26;
    }
    w.rebuildPlayerSongLists();
    w.dirtyArtists.add(g.id);
    return true;
  }

  /// What [campaign] costs on a reunion record: priced on the group's
  /// audience, the player's label paying its part.
  static int costCents(World w, Artist p, Campaign campaign) =>
      (campaign.costCents *
              Actions.campaignSizeFactor(group(w)!) *
              p.label.campaignShare)
          .round();

  static void _check(World w, Artist p, Iterable<Song> songs, int cost) {
    if (!active(w)) throw ActionException('No reunion on');
    for (final s in songs) {
      if (s.primaryArtistId != p.id || s.status != SongStatus.vault) {
        throw ActionException('Only unreleased songs');
      }
    }
    if (p.moneyCents < cost) throw ActionException('Not enough money');
  }

  /// Puts out the player's vault song [s] as the group's single.
  static Song releaseSingle(World w, Artist p, Song s,
      {Campaign campaign = Campaign.standard}) {
    final cost = costCents(w, p, campaign);
    _check(w, p, [s], cost);
    final g = group(w)!;
    p.moneyCents -= cost;
    final song = Credits.transfer(w, p, g, s);
    Actions.releaseSingle(w, g, song,
        campaign: campaign, prepaid: true, paidCents: cost);
    w.dirtyArtists.add(p.id);
    return song;
  }

  /// Puts out the player's vault songs as the group's EP or album.
  static Album releaseAlbum(World w, Artist p, String title, List<Song> songs,
      {AlbumType type = AlbumType.album,
      Campaign campaign = Campaign.standard}) {
    if (!Credits.memberAlbumTypes.contains(type)) {
      throw ActionException('EP or album');
    }
    final cost = costCents(w, p, campaign);
    _check(w, p, songs, cost);
    final g = group(w)!;
    p.moneyCents -= cost;
    final ids = [for (final s in songs) Credits.transfer(w, p, g, s).id];
    w.dirtyArtists.add(p.id);
    return Actions.releaseAlbum(w, g, title, ids,
        type: type, campaign: campaign, prepaid: true, paidCents: cost);
  }

  static String encode(World w) => jsonEncode([
        w.formerFans,
        w.formerCasual,
        w.formerFame,
        w.reunionStartWeek,
        w.reunionEndWeek,
        w.reunionWasRetired ? 1 : 0,
      ]);

  static void decode(World w, String? s) {
    if (s == null || s.isEmpty) return;
    final j = jsonDecode(s) as List;
    w
      ..formerFans = (j[0] as num).toDouble()
      ..formerCasual = (j[1] as num).toDouble()
      ..formerFame = (j[2] as num).toDouble()
      ..reunionStartWeek = j[3] as int
      ..reunionEndWeek = j[4] as int
      ..reunionWasRetired = j[5] == 1;
  }
}
