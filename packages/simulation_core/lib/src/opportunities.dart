import 'dart:convert';
import 'dart:math' as math;

import 'config/charts.dart';
import 'model.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// Things that come up in a career between releases (docs K59): offers the
/// player takes or turns down, a scandal to handle, an award nomination.
enum OpportunityKind { interview, feature, festival, brandDeal, scandal, award }

/// How the player answers. Most offers are [accept] / [decline]; a scandal
/// is [apologize] / [ignore] / [leanIn]; an award is [perform] (attend and
/// perform), [accept] (attend) or [decline] (stay home).
enum OpportunityChoice { accept, decline, apologize, ignore, leanIn, perform }

/// An offer waiting for the player's answer.
class Opportunity {
  Opportunity({
    required this.kind,
    required this.week,
    this.partnerArtistId = -1,
    this.feeCents = 0,
  });

  final OpportunityKind kind;

  /// Week it came up; it lapses after [Opportunities.answerWeeks].
  final int week;

  /// The rival asking for a duet.
  final int partnerArtistId;

  /// What it pays (festival, brand deal, duet).
  final int feeCents;

  List<OpportunityChoice> get choices => switch (kind) {
        OpportunityKind.scandal => const [
            OpportunityChoice.apologize,
            OpportunityChoice.ignore,
            OpportunityChoice.leanIn,
          ],
        OpportunityKind.award => const [
            OpportunityChoice.perform,
            OpportunityChoice.accept,
            OpportunityChoice.decline,
          ],
        _ => const [OpportunityChoice.accept, OpportunityChoice.decline],
      };

  /// What happens when it lapses unanswered.
  OpportunityChoice get lapse => kind == OpportunityKind.scandal
      ? OpportunityChoice.ignore
      : OpportunityChoice.decline;

  Map<String, Object?> toJson() => {
        'k': kind.index,
        'w': week,
        'p': partnerArtistId,
        'f': feeCents,
      };

  static Opportunity fromJson(Map<String, Object?> j) => Opportunity(
        kind: OpportunityKind.values[j['k'] as int],
        week: j['w'] as int,
        partnerArtistId: j['p'] as int? ?? -1,
        feeCents: j['f'] as int? ?? 0,
      );

  static String? encode(Opportunity? o) =>
      o == null ? null : jsonEncode(o.toJson());

  static Opportunity? decode(String? s) => s == null || s.isEmpty
      ? null
      : fromJson(jsonDecode(s) as Map<String, Object?>);
}

/// What an answer did, for the news.
class OpportunityOutcome {
  OpportunityOutcome({
    required this.kind,
    required this.choice,
    this.moneyCents = 0,
    this.fans = 0,
    this.hype = 0,
    this.energy = 0,
    this.won = false,
    this.blewOver = false,
  });

  final OpportunityKind kind;
  final OpportunityChoice choice;
  final int moneyCents;
  final double fans;
  final double hype;
  final double energy;

  /// Award: won it.
  final bool won;

  /// Scandal ignored: it blew over by itself.
  final bool blewOver;
}

abstract final class Opportunities {
  /// Weeks the player has to answer.
  static const answerWeeks = 2;

  /// Award show week (mid-February) and the first nominations' year.
  static const awardWeek = 6;

  /// Energy each kind of appearance takes.
  static const interviewEnergy = 10.0,
      featureEnergy = 20.0,
      festivalEnergy = 25.0,
      performEnergy = 15.0;

  /// A new offer may come up for the player this week (none while one is
  /// waiting). Deterministic per week.
  static Opportunity? roll(World w, Artist p) {
    if (p.opportunity != null) return null;
    final r = RandomStream.keyed(w.seed, w.week, p.id, RngPurpose.opportunity);
    final weekOfYear = GameTime.weekOfYear(w.week);
    // The award show: nominated after a year with a top-10 hit.
    if (weekOfYear == awardWeek - 1 && _bestPeakLastYear(w, p) <= 10) {
      return Opportunity(kind: OpportunityKind.award, week: w.week);
    }
    final recent = p.lastReleaseWeek >= 0 && w.week - p.lastReleaseWeek <= 6;
    final fame = p.fame;
    final roll = r.nextDouble();
    var at = 0.0;
    bool hit(double chance) {
      at += chance;
      return roll < at;
    }

    if (fame > 0.3 && hit(0.008)) {
      return Opportunity(kind: OpportunityKind.scandal, week: w.week);
    }
    if (fame > 0.05 && hit(recent ? 0.12 : 0.04)) {
      return Opportunity(kind: OpportunityKind.interview, week: w.week);
    }
    if (weekOfYear >= 20 && weekOfYear <= 32 && p.coreFans > 5e4 && hit(0.07)) {
      return Opportunity(
          kind: OpportunityKind.festival,
          week: w.week,
          feeCents: _fee(2e6, 2e8, fame, r));
    }
    if (fame > 0.3 && hit(0.025)) {
      return Opportunity(
          kind: OpportunityKind.brandDeal,
          week: w.week,
          feeCents: _fee(1e7, 1e9, fame, r));
    }
    if (fame > 0.15 && hit(0.03)) {
      final partner = _partner(w, p, r);
      if (partner != null) {
        return Opportunity(
            kind: OpportunityKind.feature,
            week: w.week,
            partnerArtistId: partner.id,
            feeCents: _fee(5e5, 5e7, fame, r));
      }
    }
    return null;
  }

  /// The waiting offer has run out of time.
  static bool lapseDue(World w, Artist p) =>
      p.opportunity != null && w.week - p.opportunity!.week >= answerWeeks;

  /// Answers the waiting offer and applies its effects.
  static OpportunityOutcome answer(
      World w, Artist p, OpportunityChoice choice) {
    final o = p.opportunity!;
    if (!o.choices.contains(choice)) {
      throw ArgumentError('Not a choice for ${o.kind.name}');
    }
    p.opportunity = null;
    w.dirtyArtists.add(p.id);
    final r =
        RandomStream.keyed(w.seed, o.week, p.id, RngPurpose.opportunity + 100);
    final s = p.skills;
    final charm = s.charisma / 100, stage = s.performance / 100;
    var money = 0, fans = 0.0, hype = 0.0, energy = 0.0;
    var won = false, blewOver = false;

    void spendEnergy(double e) {
      energy = -math.min(e, p.creativeEnergy);
      p.creativeEnergy += energy;
    }

    switch ((o.kind, choice)) {
      case (OpportunityKind.interview, OpportunityChoice.accept):
        spendEnergy(interviewEnergy);
        hype = 0.03 + 0.07 * charm;
        fans = p.casual * (0.004 + 0.01 * charm);
      case (OpportunityKind.feature, OpportunityChoice.accept):
        spendEnergy(featureEnergy);
        final partner = w.artists[o.partnerArtistId];
        money = o.feeCents;
        fans = partner.coreFans * (0.01 + 0.02 * s.vocals / 100);
        p.casual += partner.casual * 0.02;
        hype = 0.04;
      case (OpportunityKind.festival, OpportunityChoice.accept):
        spendEnergy(festivalEnergy);
        money = o.feeCents;
        fans = p.casual * (0.005 + 0.015 * stage);
        p.devotion = math.min(1.0, p.devotion + 0.01 + 0.02 * stage);
      case (OpportunityKind.brandDeal, OpportunityChoice.accept):
        money = o.feeCents;
        hype = 0.02;
        // Some fans see it as selling out.
        p.devotion = math.max(0.0, p.devotion - 0.03);
      case (OpportunityKind.scandal, OpportunityChoice.apologize):
        p.popularity = math.max(0.0, p.popularity - 0.03);
        hype = -0.05;
      case (OpportunityKind.scandal, OpportunityChoice.ignore):
        blewOver = r.chance(0.5);
        if (!blewOver) {
          p.popularity = math.max(0.0, p.popularity - 0.1);
          p.devotion = math.max(0.0, p.devotion - 0.03);
          hype = -0.1;
        }
      case (OpportunityKind.scandal, OpportunityChoice.leanIn):
        hype = 0.1;
        p.buzz += 0.5;
        fans = p.casual * 0.01;
        p.devotion = math.max(0.0, p.devotion - 0.06);
      case (
          OpportunityKind.award,
          OpportunityChoice.perform || OpportunityChoice.accept
        ):
        final perform = choice == OpportunityChoice.perform;
        if (perform) spendEnergy(performEnergy);
        final peak = _bestPeakLastYear(w, p);
        final odds = (peak == 1 ? 0.45 : 0.25) + (perform ? 0.1 : 0);
        won = r.chance(odds);
        hype = (perform ? 0.06 : 0.02) + (won ? 0.12 : 0);
        fans = p.casual * ((perform ? 0.006 : 0.002) + (won ? 0.01 : 0));
        if (won) {
          p.fame = math.min(1.0, p.fame + 0.03);
          p.devotion = math.min(1.0, p.devotion + 0.02);
        }
      case _:
        break; // declined
    }
    p.moneyCents += money;
    p.hype = math.max(0.0, p.hype + hype);
    p.coreFans += fans;
    return OpportunityOutcome(
        kind: o.kind,
        choice: choice,
        moneyCents: money,
        fans: fans,
        hype: hype,
        energy: energy,
        won: won,
        blewOver: blewOver);
  }

  /// Fee between [lowCents] and [highCents], growing with fame.
  static int _fee(
          double lowCents, double highCents, double fame, RandomStream r) =>
      (lowCents *
              math.pow(highCents / lowCents, fame.clamp(0.0, 1.0)) *
              (0.8 + 0.4 * r.nextDouble()))
          .round();

  /// A rival a bit bigger than the player, or about their size.
  static Artist? _partner(World w, Artist p, RandomStream r) {
    final pool = [
      for (final id in w.activeArtistIds)
        if (w.artists[id].tier != ArtistTier.player &&
            w.artists[id].fame >= p.fame * 0.8 &&
            w.artists[id].fame <= p.fame + 0.3)
          w.artists[id],
    ];
    if (pool.isEmpty) return null;
    return pool[r.nextInt(pool.length)];
  }

  /// Best US or global peak of the player's songs and albums out last year
  /// (999 if none charted).
  static int _bestPeakLastYear(World w, Artist p) {
    final year = GameTime.yearOf(w.week) - 1;
    var best = 999;
    void check(Charted c) {
      for (final ch in [
        Charts.usSongs,
        Charts.globalSongs,
        Charts.usAlbums,
        Charts.globalAlbums
      ]) {
        final peak = c.statsOrNull(ch)?.peak ?? 0;
        if (peak > 0 && peak < best) best = peak;
      }
    }

    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.primaryArtistId == p.id &&
          s.releasedWeek >= 0 &&
          GameTime.yearOf(s.releasedWeek) == year) {
        check(s);
      }
    }
    for (final al in w.albums) {
      if (al.artistId == p.id && GameTime.yearOf(al.releaseWeek) == year) {
        check(al);
      }
    }
    return best;
  }
}
