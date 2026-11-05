import 'dart:math' as math;

import 'actions.dart';
import 'model.dart';
import 'world.dart';

/// Who the player practises with (docs K285). Stored by index: new ones go
/// last.
enum PracticeTier { self, coach, starCoach }

/// Practice (docs K285): skills grow by working on them, not by a free
/// weekly allowance. Once a week the player takes a lesson in one skill:
/// alone (free, but it takes creativity, so fewer songs that week), with a
/// coach, or with a star coach once known enough. Lessons pay off less the
/// better the skill already is: 30 to 50 comes quickly, 80 to 90 slowly.
abstract final class Practice {
  /// Points a lesson adds at a middling skill (50).
  static double baseGain(PracticeTier t) => switch (t) {
        PracticeTier.self => 1.5,
        PracticeTier.coach => 3.0,
        PracticeTier.starCoach => 5.0,
      };

  /// Creativity a lesson takes.
  static double energy(PracticeTier t) => switch (t) {
        PracticeTier.self => 25.0,
        PracticeTier.coach => 10.0,
        PracticeTier.starCoach => 10.0,
      };

  /// A star coach works only with artists this famous.
  static const starCoachFame = 0.25;

  /// What a lesson costs: the better known the artist, the dearer the
  /// teachers.
  static int costCents(Artist a, PracticeTier t) => switch (t) {
        PracticeTier.self => 0,
        PracticeTier.coach => (80000 * (1 + 4 * a.fame)).round(),
        PracticeTier.starCoach => (600000 * (1 + 4 * a.fame)).round(),
      };

  /// How much of a lesson sticks at skill [skill]: more below the middle,
  /// much less near the top.
  static double learnFactor(double skill) =>
      ((110 - skill) / 60).clamp(0.15, 1.3).toDouble();

  /// Points a lesson in [kind] adds now.
  static double gain(Artist a, SkillKind kind, PracticeTier t) => math.min(
      Actions.maxSkill - a.skills[kind], baseGain(t) * learnFactor(a.skills[kind]));

  /// Why [a] cannot take this lesson now, or null.
  static String? block(World w, Artist a, SkillKind kind, PracticeTier t) {
    if (w.practiceWeek == w.week) return 'Already practised this week';
    if (a.restWeek == w.week) return 'Resting';
    if (a.skills[kind] >= Actions.maxSkill) return 'Skill is maxed';
    if (t == PracticeTier.starCoach && a.fame < starCoachFame) {
      return 'Not known enough';
    }
    if (a.moneyCents < costCents(a, t)) return 'Not enough money';
    if (a.creativeEnergy < energy(t)) return 'Not enough creativity';
    return null;
  }

  /// Takes the lesson; returns the points gained.
  static double practise(World w, Artist a, SkillKind kind, PracticeTier t) {
    final why = block(w, a, kind, t);
    if (why != null) throw ActionException(why);
    final g = gain(a, kind, t);
    a.moneyCents -= costCents(a, t);
    a.creativeEnergy = math.max(0, a.creativeEnergy - energy(t));
    a.skills[kind] = math.min(Actions.maxSkill, a.skills[kind] + g);
    w.practiceWeek = w.week;
    w.dirtyArtists.add(a.id);
    return g;
  }

  /// Learning by doing (docs K285): [amount] at a middling skill, less
  /// near the top.
  static void learn(Artist a, SkillKind kind, double amount) {
    a.skills[kind] = math.min(Actions.maxSkill,
        a.skills[kind] + amount * learnFactor(a.skills[kind]));
  }
}

/// Living costs (docs K285): rent and living at first; a team, stylists
/// and security once famous. Paid each week from the player's money, never
/// below nothing (one lives cheaply when broke).
abstract final class LivingCosts {
  static int weeklyCents(Artist a) {
    final members = a.members.isEmpty ? 1 : a.members.length;
    final people = 0.6 + 0.4 * members;
    return ((15000 + 1500000 * a.fame * a.fame) * people).round();
  }

  /// Pays this week's costs; returns what was paid.
  static int pay(Artist a) {
    final paid = math.min(weeklyCents(a), math.max(0, a.moneyCents));
    a.moneyCents -= paid;
    return paid;
  }
}
