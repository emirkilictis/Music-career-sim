import 'credits.dart';
import 'go_solo.dart';
import 'lineups.dart';
import 'model.dart';
import 'rng.dart';
import 'world.dart';

/// What happened with the player's group's members this week (docs K195).
enum MemberNewsKind {
  /// Word is out that someone wants to leave.
  unhappy,

  /// Someone left the group for a career of their own.
  quit,

  /// The members' contracts come up for renewal soon.
  renewalSoon,

  /// The contracts were renewed; some may not have signed.
  renewalDone,
}

class MemberNews {
  const MemberNews(this.kind,
      {this.names = const [], this.fansLost = 0, this.stayed = 0});
  final MemberNewsKind kind;

  /// Who it is about (for [MemberNewsKind.renewalSoon]: who may not sign).
  final List<String> names;

  /// Share of the group's fans gone with them.
  final double fansLost;

  /// Members who signed again.
  final int stayed;
}

/// Members' morale and what comes of it (docs K195): unhappy members
/// talk, the unhappiest walk out, and every [renewalYears] years the
/// contracts come up and those who are not happy enough do not sign
/// again (the K-pop seven-year mark). A member who leaves takes their
/// fans and starts a career of their own, as a rival.
abstract final class MemberMorale {
  /// Below this, word gets out; below [quitAt] they may walk out.
  static const unhappyAt = 30.0, quitAt = 12.0;
  static const rumorChance = 0.15, rumorEveryWeeks = 8;
  static const quitChance = 0.06;

  /// Contracts run this long; members below [renewAt] do not sign again.
  static const renewalYears = 7, renewAt = 50.0, warnWeeks = 8;
  static const renewalWeeks = renewalYears * 52;

  /// Weeks before a member who left puts out their first record.
  static const departedBreakWeeks = 13;

  /// The next week the group's contracts come up.
  static int nextRenewal(World w, Artist a) {
    final age = w.week - a.debutWeek;
    return a.debutWeek + (age ~/ renewalWeeks + 1) * renewalWeeks;
  }

  /// Members who would not sign again now, lowest morale first.
  static List<int> atRisk(Artist a) => [
        for (var i = 0; i < a.memberMorale.length; i++)
          if (a.memberMorale[i] < renewAt) i
      ]..sort((x, y) => a.memberMorale[x].compareTo(a.memberMorale[y]));

  /// The week's member news for the player's group.
  static List<MemberNews> weekly(World w, Artist a) {
    if (!a.kind.isGroup || a.members.length < ArtistKind.minMembers) {
      return const [];
    }
    Lineups.ensure(w, a);
    final out = <MemberNews>[];
    final r = RandomStream.keyed(w.seed, w.week, a.id, RngPurpose.lineup);

    // Contracts: a warning first, then who signs.
    final renewal = nextRenewal(w, a);
    if (renewal - w.week == warnWeeks) {
      out.add(MemberNews(MemberNewsKind.renewalSoon,
          names: [for (final i in atRisk(a)) a.members[i]]));
    }
    if ((w.week - a.debutWeek) % renewalWeeks == 0 && w.week > a.debutWeek) {
      final left = <String>[];
      var lost = 0.0;
      // Indexes shift as members go: follow them by name.
      for (final name in [for (final i in atRisk(a)) a.members[i]]) {
        if (a.members.length <= ArtistKind.minMembers) break;
        final now = a.members.indexOf(name);
        if (now < 0) continue;
        lost = 1 - (1 - lost) * (1 - quit(w, a, now));
        left.add(name);
      }
      out.add(MemberNews(MemberNewsKind.renewalDone,
          names: left, fansLost: lost, stayed: a.members.length));
      return out;
    }

    // The unhappiest may walk out; the unhappy talk.
    for (var i = 0; i < a.memberMorale.length; i++) {
      if (a.memberMorale[i] >= quitAt) continue;
      if (a.members.length <= ArtistKind.minMembers) break;
      if (!r.chance(quitChance)) continue;
      final name = a.members[i];
      final lost = quit(w, a, i);
      out.add(MemberNews(MemberNewsKind.quit, names: [name], fansLost: lost));
      return out;
    }
    if (w.week - a.rumorWeek >= rumorEveryWeeks) {
      for (var i = 0; i < a.memberMorale.length; i++) {
        if (a.memberMorale[i] >= unhappyAt || !r.chance(rumorChance)) continue;
        a.rumorWeek = w.week;
        w.dirtyArtists.add(a.id);
        out.add(MemberNews(MemberNewsKind.unhappy, names: [a.members[i]]));
        break;
      }
    }
    return out;
  }

  /// [member] leaves the player's group for a career of their own, taking
  /// their fans (as when the player goes solo, docs K191). Returns the
  /// share of the group's fans gone.
  static double quit(World w, Artist group, int member) {
    final k = Lineups.importance(w, group, member);
    final m = Credits.memberArtist(w, group, member);
    final fans = group.coreFans;
    GoSolo.shareAudience(group, m, k);
    m
      ..managedBy = -1
      ..tier = ArtistTier.b
      ..nextEraWeek = w.week + departedBreakWeeks;
    m.plan.clear();
    group.members.removeAt(member);
    if (member < group.memberArtistIds.length) {
      group.memberArtistIds.removeAt(member);
    }
    Lineups.remove(group, member);
    w.rebuildPlayerSongLists();
    w.dirtyArtists
      ..add(group.id)
      ..add(m.id);
    return fans <= 0 ? 0 : 1 - group.coreFans / fans;
  }
}
