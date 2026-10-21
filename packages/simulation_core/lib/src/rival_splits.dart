import 'dart:convert';
import 'dart:math' as math;

import 'credits.dart';
import 'go_solo.dart';
import 'lineups.dart';
import 'model.dart';
import 'rng.dart';
import 'world.dart';

/// A rival group's member who left for a career of their own (docs K199).
class RivalSplit {
  const RivalSplit(this.week, this.groupId, this.soloId, this.ended);
  final int week;
  final int groupId;
  final int soloId;

  /// The group did not go on without them.
  final bool ended;

  static String encode(List<RivalSplit> s) => jsonEncode([
        for (final x in s) [x.week, x.groupId, x.soloId, x.ended ? 1 : 0]
      ]);
  static List<RivalSplit> decode(String? s) => s == null || s.isEmpty
      ? []
      : [
          for (final x in jsonDecode(s) as List)
            RivalSplit(x[0] as int, x[1] as int, x[2] as int, x[3] == 1)
        ];
}

/// Rival groups split too (docs K199): once a year, a group some years
/// in may lose a member to a solo career, more likely the longer it has
/// been together. The member takes their part of the fans, as when the
/// player goes solo (docs K191), and starts putting out records of their
/// own after a few months; a group left with one member, or losing its
/// star, ends.
abstract final class RivalSplits {
  /// Years together before anyone leaves, the yearly chance then (it
  /// grows with the years, up to twice), and the most splits a year.
  static const minYears = 4, chancePerYear = 0.06, maxPerYear = 3;

  /// Weeks before the new solo artist's first record.
  static const soloBreakWeeks = 13;

  static void yearly(World w) {
    var n = 0;
    for (final a in [...w.artists]) {
      if (n >= maxPerYear) break;
      if (a.tier == ArtistTier.player ||
          a.isRetired ||
          a.managedBy >= 0 ||
          !a.kind.isGroup ||
          a.members.length < ArtistKind.minMembers ||
          // The player's old group's story is the player's (docs K194).
          a.id == w.formerGroupId) {
        continue;
      }
      final years = (w.week - a.debutWeek) / 52;
      if (years < minYears) continue;
      final r = RandomStream.keyed(w.seed, w.week, a.id, RngPurpose.lineup);
      final odds =
          chancePerYear * math.min(2.0, 0.5 + 0.1 * (years - minYears + 5));
      if (!r.chance(odds)) continue;
      final member = r.nextInt(a.members.length);
      // How much they mattered: no lineup to read, so a guess.
      final k = 0.6 + 1.6 * r.nextDouble();
      final solo = Credits.memberArtist(w, a, member);
      GoSolo.shareAudience(a, solo, k);
      solo
        ..managedBy = -1
        ..tier = ArtistTier.b
        ..nextEraWeek = w.week + soloBreakWeeks;
      solo.plan.clear();
      a.members.removeAt(member);
      if (member < a.memberArtistIds.length) a.memberArtistIds.removeAt(member);
      Lineups.remove(a, member);
      final ends =
          a.members.length < ArtistKind.minMembers || k >= GoSolo.hiatusAt;
      if (ends) w.retire(a);
      w.rivalSplits.add(RivalSplit(w.week, a.id, solo.id, ends));
      w.dirtyArtists
        ..add(a.id)
        ..add(solo.id);
      n++;
    }
  }
}
