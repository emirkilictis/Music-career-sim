import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'model.dart';
import 'rng.dart';
import 'world.dart';

/// A member's place in the player's group (docs K192). Index order is
/// stored (as bits): only append.
enum MemberRole {
  leader(6, unique: true),
  mainVocal(18, unique: true),
  leadVocal(10),
  mainDancer(12, unique: true),
  mainRapper(12, unique: true),
  visual(20, unique: true),
  maknae(10, unique: true),
  frontman(30, unique: true),
  guitar(12),
  bass(4, unique: true),
  drums(6, unique: true),
  keys(4, unique: true);

  const MemberRole(this.appeal, {this.unique = false});

  /// How much the public notices a member in this role (popularity
  /// points over a member's base).
  final int appeal;

  /// Only one member holds it at a time.
  final bool unique;

  int get bit => 1 << index;

  /// The roles a group of [kind] has.
  static List<MemberRole> forKind(ArtistKind kind) => kind == ArtistKind.band
      ? const [leader, frontman, guitar, bass, drums, keys]
      : const [
          leader,
          mainVocal,
          leadVocal,
          mainDancer,
          mainRapper,
          visual,
          maknae
        ];
}

/// How the player's group splits a song's lines (docs K193). Index order
/// is stored.
enum LineSplit {
  /// Everyone sings about as much: fans of every member are happy.
  even,

  /// The center sings more.
  featured,

  /// The center carries the song; the others get a line or two.
  center;

  /// What the songs gain from the center carrying them, at a center of
  /// 70 popularity.
  double get lift => switch (this) {
        even => 0,
        featured => 0.03,
        center => 0.07,
      };

  /// What the center gains a week, and what the others lose.
  double get centerGain => switch (this) {
        even => 0,
        featured => 0.25,
        center => 0.5,
      };
  double get othersLoss => switch (this) {
        even => 0,
        featured => 0.05,
        center => 0.1,
      };

  /// Morale a week for the center and for the others (docs K195).
  double get centerMorale => switch (this) {
        even => 0.4,
        featured => 0.15,
        center => 0.3,
      };
  double get othersMorale => switch (this) {
        even => 0.4,
        featured => -0.25,
        center => -0.6,
      };

  /// What the fandom's devotion does a week: fans of every member like a
  /// fair split and resent a one-person group.
  double get devotion => switch (this) {
        even => 0.0003,
        featured => 0,
        center => -0.0006,
      };
}

/// The player's group's lineup (docs K192): each member's roles and their
/// own popularity, which the label can push for one member at a time. A
/// popular member draws the group's fans: their solo records start
/// bigger, and when they leave, the group can fall apart.
abstract final class Lineups {
  /// What every member starts from before roles.
  static const basePop = 35.0;

  /// Weekly pull of a member's popularity back to what their roles give.
  static const drift = 0.02, focusDrift = 0.01;

  /// What the label's push adds a week (less near the top), and what the
  /// others lose while someone else is pushed.
  static const focusGain = 1.5, focusLoss = 0.2;

  /// What a member's solo record adds.
  static const soloGain = 4.0;

  /// A member this much more popular than the average is the group's ace.
  static const aceAt = 1.5;

  /// Morale (docs K195): where it settles on its own and how fast, what
  /// the label's push does to it, what a solo record and a bonus give,
  /// and how often a bonus can be paid.
  static const moraleRest = 70.0, moraleDrift = 0.02;
  static const focusMorale = 0.4, focusResent = 0.8;
  static const lowPopAt = 30.0, lowPopMorale = 0.3;
  static const soloMorale = 10.0, cheerMorale = 25.0, cheerEveryWeeks = 8;

  /// A morale bonus: a fixed part and a part that grows with the fandom.
  static int cheerCostCents(Artist a) => 5000000 + (a.coreFans * 2).round();

  /// The popularity [roles] give a member.
  static double target(int roles) {
    var t = basePop;
    for (final r in MemberRole.values) {
      if (roles & r.bit != 0) t += r.appeal;
    }
    return t.clamp(15.0, 95.0);
  }

  static List<MemberRole> rolesOf(int roles) => [
        for (final r in MemberRole.values)
          if (roles & r.bit != 0) r
      ];

  /// Gives [a]'s members roles and popularity if they have none yet (a
  /// new group, or a save from before docs K192).
  static void ensure(World w, Artist a) {
    final n = a.members.length;
    if (!a.kind.isGroup || n == 0) return;
    if (a.memberMorale.length != n) {
      a.memberMorale
        ..clear()
        ..addAll(List.filled(n, moraleRest));
    }
    if (a.memberRoles.length == n && a.memberPop.length == n) return;
    a.memberRoles
      ..clear()
      ..addAll(List.filled(n, 0));
    final r = RandomStream.keyed(w.seed, 0, a.id, RngPurpose.lineup);
    if (a.kind == ArtistKind.band) {
      const parts = [
        MemberRole.frontman,
        MemberRole.guitar,
        MemberRole.bass,
        MemberRole.drums,
        MemberRole.keys,
      ];
      for (var i = 0; i < n; i++) {
        a.memberRoles[i] |=
            (i < parts.length ? parts[i] : MemberRole.guitar).bit;
      }
    } else {
      const parts = [
        MemberRole.mainVocal,
        MemberRole.mainDancer,
        MemberRole.mainRapper,
        MemberRole.leadVocal,
      ];
      for (var i = 0; i < n; i++) {
        a.memberRoles[i] |=
            (i < parts.length ? parts[i] : MemberRole.leadVocal).bit;
      }
      a.memberRoles[n - 1] |= MemberRole.maknae.bit;
      a.memberRoles[r.nextInt(n)] |= MemberRole.visual.bit;
    }
    a.memberRoles[r.nextInt(n)] |= MemberRole.leader.bit;
    a.memberPop
      ..clear()
      ..addAll([
        for (var i = 0; i < n; i++)
          (target(a.memberRoles[i]) + (r.nextDouble() * 16 - 8))
              .clamp(0.0, 100.0)
      ]);
    w.dirtyArtists.add(a.id);
  }

  /// [member]'s share of the group's popularity.
  static double share(Artist a, int member) {
    final total = a.memberPop.fold(0.0, (t, p) => t + p);
    return total <= 0 ? 1 / a.memberPop.length : a.memberPop[member] / total;
  }

  /// How much [member] matters to the fans next to the average member
  /// (1: average). Squared, so a standout counts for much more than a
  /// little above average.
  static double importance(World w, Artist a, int member) {
    ensure(w, a);
    if (a.memberPop.isEmpty) return 1;
    final x = share(a, member) * a.memberPop.length;
    return (x * x).clamp(0.3, 2.5);
  }

  static LineSplit splitOf(Artist a) => LineSplit.values[a.lineSplit];

  /// The member the songs are built around: the one the label pushes, or
  /// else the most popular.
  static int center(Artist a) {
    if (a.focusMember >= 0 && a.focusMember < a.memberPop.length) {
      return a.focusMember;
    }
    var best = 0;
    for (var i = 1; i < a.memberPop.length; i++) {
      if (a.memberPop[i] > a.memberPop[best]) best = i;
    }
    return best;
  }

  /// What the player's group's songs gain from their line split (docs
  /// K193): more with a popular center.
  static double lineLift(World w, Artist a) {
    if (!a.kind.isGroup || a.memberPop.isEmpty) return 0;
    final split = splitOf(a);
    if (split == LineSplit.even) return 0;
    final pop = a.memberPop[center(a)];
    return split.lift * (pop / 70).clamp(0.3, 1.4);
  }

  /// The week for the player's group: the pushed member and the center
  /// rise, the rest drift back to what their roles give them; morale
  /// follows how fairly they are treated (docs K193, K195).
  static void weekly(World w, Artist a) {
    if (!a.kind.isGroup || a.members.isEmpty) return;
    ensure(w, a);
    final f = a.focusMember;
    final split = splitOf(a);
    final c = center(a);
    for (var i = 0; i < a.memberPop.length; i++) {
      var p = a.memberPop[i];
      final t = target(a.memberRoles[i]);
      p += (f >= 0 ? focusDrift : drift) * (t - p);
      if (f == i) {
        p += focusGain * (1 - p / 100);
      } else if (f >= 0) {
        p -= focusLoss;
      }
      p += i == c ? split.centerGain * (1 - p / 100) : -split.othersLoss;
      a.memberPop[i] = p.clamp(0.0, 100.0);

      var m = a.memberMorale[i];
      m += moraleDrift * (moraleRest - m);
      if (f >= 0) m += f == i ? focusMorale : -focusResent;
      m += i == c ? split.centerMorale : split.othersMorale;
      if (a.memberPop[i] < lowPopAt) m -= lowPopMorale;
      a.memberMorale[i] = m.clamp(0.0, 100.0);
    }
    a.devotion = (a.devotion + split.devotion).clamp(0.0, 1.0);
    w.dirtyArtists.add(a.id);
  }

  /// Sets how the group's songs split their lines (docs K193).
  static void setLineSplit(World w, Artist a, LineSplit split) {
    if (!a.kind.isGroup) throw ActionException('Not a group');
    a.lineSplit = split.index;
    w.dirtyArtists.add(a.id);
  }

  /// Whether a morale bonus can be paid now.
  static bool canCheer(World w, Artist a) =>
      a.kind.isGroup && w.week - a.cheerWeek >= cheerEveryWeeks;

  /// Pays [member] a bonus and listens to them (docs K195).
  static void cheer(World w, Artist a, int member) {
    if (member < 0 || member >= a.members.length) {
      throw ActionException('No such member');
    }
    if (!canCheer(w, a)) throw ActionException('Too soon');
    final cost = cheerCostCents(a);
    if (a.moneyCents < cost) throw ActionException('Not enough money');
    ensure(w, a);
    a
      ..moneyCents -= cost
      ..cheerWeek = w.week;
    a.memberMorale[member] =
        math.min(100.0, a.memberMorale[member] + cheerMorale);
    w.dirtyArtists.add(a.id);
  }

  /// The label pushes [member] (-1: nobody).
  static void focus(World w, Artist a, int member) {
    if (!a.kind.isGroup) throw ActionException('Not a group');
    if (member < -1 || member >= a.members.length) {
      throw ActionException('No such member');
    }
    ensure(w, a);
    a
      ..focusMember = member
      ..focusSinceWeek = member < 0 ? -1 : w.week;
    w.dirtyArtists.add(a.id);
  }

  /// Gives [member] [roles]; a role only one member can hold moves from
  /// whoever had it.
  static void setRoles(World w, Artist a, int member, Set<MemberRole> roles) {
    if (!a.kind.isGroup) throw ActionException('Not a group');
    if (member < 0 || member >= a.members.length) {
      throw ActionException('No such member');
    }
    final allowed = MemberRole.forKind(a.kind);
    if (roles.any((r) => !allowed.contains(r))) {
      throw ActionException('Not a role of this group');
    }
    ensure(w, a);
    var bits = 0;
    for (final r in roles) {
      bits |= r.bit;
      if (!r.unique) continue;
      for (var i = 0; i < a.memberRoles.length; i++) {
        if (i != member) a.memberRoles[i] &= ~r.bit;
      }
    }
    a.memberRoles[member] = bits;
    w.dirtyArtists.add(a.id);
  }

  /// [member]'s solo record got them noticed.
  static void onSolo(World w, Artist a, int member) {
    ensure(w, a);
    if (member < 0 || member >= a.memberPop.length) return;
    a.memberPop[member] = math.min(100.0, a.memberPop[member] + soloGain);
    a.memberMorale[member] =
        math.min(100.0, a.memberMorale[member] + soloMorale);
    w.dirtyArtists.add(a.id);
  }

  /// A member joins at the end of the lineup (a reunion, docs K194).
  static void addMember(Artist a,
      {int roles = 0, double pop = 50, double morale = moraleRest}) {
    if (a.memberRoles.isEmpty) return;
    a.memberRoles.add(roles);
    a.memberPop.add(pop);
    if (a.memberMorale.isNotEmpty) a.memberMorale.add(morale);
  }

  /// [member] left: their place in the lineup goes.
  static void remove(Artist a, int member) {
    if (member < a.memberRoles.length) a.memberRoles.removeAt(member);
    if (member < a.memberPop.length) a.memberPop.removeAt(member);
    if (member < a.memberMorale.length) a.memberMorale.removeAt(member);
    if (a.focusMember == member) {
      a
        ..focusMember = -1
        ..focusSinceWeek = -1;
    } else if (a.focusMember > member) {
      a.focusMember--;
    }
  }

  static String? encode(Artist a) => a.memberRoles.isEmpty
      ? null
      : jsonEncode({
          'r': a.memberRoles,
          'p': [for (final p in a.memberPop) (p * 100).round() / 100],
          'f': a.focusMember,
          'fw': a.focusSinceWeek,
          'ls': a.lineSplit,
          'm': [for (final m in a.memberMorale) (m * 100).round() / 100],
          'cw': a.cheerWeek,
          'rw': a.rumorWeek,
        });

  static void decode(Artist a, String? s) {
    if (s == null || s.isEmpty) return;
    final j = jsonDecode(s) as Map<String, dynamic>;
    a.memberRoles.addAll((j['r'] as List).cast<int>());
    a.memberPop.addAll([for (final p in j['p'] as List) (p as num).toDouble()]);
    a
      ..focusMember = j['f'] as int
      ..focusSinceWeek = j['fw'] as int
      ..lineSplit = j['ls'] as int? ?? 0
      ..cheerWeek = j['cw'] as int? ?? -1000
      ..rumorWeek = j['rw'] as int? ?? -1000;
    a.memberMorale.addAll(
        [for (final m in j['m'] as List? ?? const []) (m as num).toDouble()]);
  }
}
