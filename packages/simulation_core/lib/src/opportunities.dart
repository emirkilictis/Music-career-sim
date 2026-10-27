import 'dart:convert';
import 'dart:math' as math;

import 'audience.dart';
import 'awards.dart';
import 'brands.dart';
import 'credits.dart';
import 'model.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// Things that come up in a career between releases (docs K59): offers the
/// player takes or turns down, a scandal to handle, an award nomination.
enum OpportunityKind {
  interview,
  feature,
  festival,
  brandDeal,
  scandal,
  award,

  /// A group member wants to put out a solo record (docs K87).
  memberSolo,

  /// A member is feuding with the rest of the group, in public (K87).
  memberRift,

  /// An online pile-on, most often after a release that let people down
  /// (docs K228).
  hateWave,

  /// Private messages of the player's leaked (docs K228).
  dmLeak,

  /// Something went wrong on stage, on tour (docs K228).
  stageMishap;

  /// Trouble to handle rather than an offer to take (docs K228).
  bool get isCrisis =>
      this == scandal ||
      this == memberRift ||
      this == hateWave ||
      this == dmLeak ||
      this == stageMishap;
}

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
    this.member = -1,
    this.brand = -1,
  });

  final OpportunityKind kind;

  /// Week it came up; it lapses after [Opportunities.answerWeeks].
  final int week;

  /// The rival asking for a duet.
  final int partnerArtistId;

  /// What it pays (festival, brand deal, duet).
  final int feeCents;

  /// The group member it is about (index in [Artist.members]).
  final int member;

  /// The brand of a brand deal ([Brands.all] index; docs K102).
  final int brand;

  List<OpportunityChoice> get choices => switch (kind) {
        _ when kind.isCrisis => const [
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
  OpportunityChoice get lapse =>
      kind.isCrisis ? OpportunityChoice.ignore : OpportunityChoice.decline;

  Map<String, Object?> toJson() => {
        'k': kind.index,
        'w': week,
        'p': partnerArtistId,
        'f': feeCents,
        'm': member,
        'b': brand,
      };

  static Opportunity fromJson(Map<String, Object?> j) => Opportunity(
        kind: OpportunityKind.values[j['k'] as int],
        week: j['w'] as int,
        partnerArtistId: j['p'] as int? ?? -1,
        feeCents: j['f'] as int? ?? 0,
        member: j['m'] as int? ?? -1,
        brand: j['b'] as int? ?? -1,
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
    this.backfired = false,
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

  /// A bold answer to a crisis went wrong (docs K228).
  final bool backfired;
}

abstract final class Opportunities {
  /// Weeks the player has to answer.
  static const answerWeeks = 2;

  /// Energy each kind of appearance takes.
  static const interviewEnergy = 10.0,
      featureEnergy = 20.0,
      festivalEnergy = 25.0,
      performEnergy = 15.0,
      memberSoloEnergy = 20.0,
      memberTalkEnergy = 25.0,
      crisisTalkEnergy = 10.0;

  /// A new offer may come up for the player this week (none while one is
  /// waiting). Deterministic per week.
  static Opportunity? roll(World w, Artist p) {
    if (p.opportunity != null) return null;
    final r = RandomStream.keyed(w.seed, w.week, p.id, RngPurpose.opportunity);
    final weekOfYear = GameTime.weekOfYear(w.week);
    // The award show (docs K91): invited when nominated.
    final show = Awards.upcoming(w);
    if (weekOfYear == Awards.ceremonyWeekOfYear - 1 &&
        show != null &&
        show.racesOf(p.id).isNotEmpty) {
      return Opportunity(kind: OpportunityKind.award, week: w.week);
    }
    final recent = p.lastReleaseWeek >= 0 && w.week - p.lastReleaseWeek <= 6;
    final fame = p.fame;
    final roll = r.nextDouble();
    var at = 0.0;
    // A manager books more of everything but scandals (docs K68).
    final boost = p.manager.offerBoost;
    bool hit(double chance, {bool booked = true}) {
      at += chance * (booked ? boost : 1);
      return roll < at;
    }

    if (fame > 0.2 && hit(0.01, booked: false)) {
      return Opportunity(kind: OpportunityKind.scandal, week: w.week);
    }
    // Trouble (docs K228): a release that let people down brings the
    // haters out; a careless performer slips up on tour; the famous get
    // their messages leaked.
    final flop = recent && _letDown(w, p);
    if (fame > 0.05 && hit(flop ? 0.08 : 0.004, booked: false)) {
      return Opportunity(kind: OpportunityKind.hateWave, week: w.week);
    }
    if (p.tour != null &&
        hit(0.02 + 0.04 * (1 - p.skills.performance / 100), booked: false)) {
      return Opportunity(kind: OpportunityKind.stageMishap, week: w.week);
    }
    if (fame > 0.2 && hit(0.005, booked: false)) {
      return Opportunity(kind: OpportunityKind.dmLeak, week: w.week);
    }
    // Group life (docs K87): a member's solo plans, a feud in public.
    if (p.kind.isGroup && p.members.length >= 2) {
      if (fame > 0.1 && hit(0.006, booked: false)) {
        return Opportunity(
            kind: OpportunityKind.memberRift,
            week: w.week,
            member: r.nextInt(p.members.length));
      }
      if (fame > 0.15 && hit(0.01, booked: false)) {
        return Opportunity(
            kind: OpportunityKind.memberSolo,
            week: w.week,
            member: r.nextInt(p.members.length));
      }
    }
    if (fame > 0.05 && hit(recent ? 0.12 : 0.04)) {
      return Opportunity(kind: OpportunityKind.interview, week: w.week);
    }
    if (weekOfYear >= 20 && weekOfYear <= 32 && p.coreFans > 5e4 && hit(0.07)) {
      return Opportunity(
          kind: OpportunityKind.festival,
          week: w.week,
          feeCents: (_fee(2e6, 2e8, fame, r) * p.manager.feeBoost).round());
    }
    // Brands knock once the artist is somebody (docs K102), never with
    // three deals already running.
    if (fame > 0.15 && Brands.activeCount(w) < Brands.maxActive && hit(0.03)) {
      final brand = Brands.pick(p, r);
      return Opportunity(
          kind: OpportunityKind.brandDeal,
          week: w.week,
          brand: brand,
          feeCents: (_fee(1e7, 1e9, fame, r) *
                  Brands.feeFactor(Brands.all[brand]) *
                  p.manager.feeBoost)
              .round());
    }
    if (fame > 0.15 && hit(0.03)) {
      final partner = _partner(w, p, r);
      if (partner != null) {
        return Opportunity(
            kind: OpportunityKind.feature,
            week: w.week,
            partnerArtistId: partner.id,
            feeCents: (_fee(5e5, 5e7, fame, r) * p.manager.feeBoost).round());
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
    var won = false, blewOver = false, backfired = false;
    // What putting a crisis right costs, paid in full (docs K228).
    var paid = 0;

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
        // A real song with the player on it, out in two weeks (K158).
        if (!partner.isRetired) {
          Credits.guestOn(w, partner, p,
              producerSkill: partner.tier == ArtistTier.a ? 85 : 60);
        }
        money = o.feeCents;
        fans = partner.coreFans * (0.01 + 0.02 * s.vocals / 100);
        Audience.addCasual(w, p, partner.casual * 0.02);
        hype = 0.04;
      case (OpportunityKind.festival, OpportunityChoice.accept):
        spendEnergy(festivalEnergy);
        money = o.feeCents;
        fans = p.casual * (0.005 + 0.015 * stage);
        p.devotion = math.min(1.0, p.devotion + 0.01 + 0.02 * stage);
      // Half now, half when the work is done (docs K102). Older offers
      // without a brand become a beverage deal.
      case (OpportunityKind.brandDeal, OpportunityChoice.accept):
        Brands.sign(w, p, o.brand >= 0 ? o.brand : 0, o.feeCents);
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
      // The show itself happens at the end of the week (docs K91).
      case (
          OpportunityKind.award,
          OpportunityChoice.perform || OpportunityChoice.accept
        ):
        final perform = choice == OpportunityChoice.perform;
        if (perform) spendEnergy(performEnergy);
        Awards.upcoming(w)?.attendance =
            perform ? AwardAttendance.perform : AwardAttendance.attend;
      // Backing a member's solo record: their audience finds the group, but
      // they are away from the studio for a while.
      case (OpportunityKind.memberSolo, OpportunityChoice.accept):
        spendEnergy(memberSoloEnergy);
        fans = p.casual * 0.008;
        Audience.addCasual(w, p, p.casual * 0.03);
        hype = 0.04;
      // Asked to wait: some fans wanted it.
      case (OpportunityKind.memberSolo, OpportunityChoice.decline):
        p.devotion = math.max(0.0, p.devotion - 0.02);
      // Talking it out takes time, and the fans are relieved.
      case (OpportunityKind.memberRift, OpportunityChoice.apologize):
        spendEnergy(memberTalkEnergy);
        p.devotion = math.min(1.0, p.devotion + 0.01);
      case (OpportunityKind.memberRift, OpportunityChoice.ignore):
        blewOver = r.chance(0.5);
        if (!blewOver) {
          fans = -p.coreFans * 0.03;
          p.devotion = math.max(0.0, p.devotion - 0.04);
          hype = -0.05;
        }
      // Airing it out: everyone talks about the group, some fans leave.
      case (OpportunityKind.memberRift, OpportunityChoice.leanIn):
        hype = 0.12;
        p.buzz += 0.5;
        fans = -p.coreFans * 0.01;
        p.devotion = math.max(0.0, p.devotion - 0.04);
      // An online pile-on (docs K228).
      case (OpportunityKind.hateWave, OpportunityChoice.apologize):
        spendEnergy(crisisTalkEnergy);
        p.popularity = math.max(0.0, p.popularity - 0.01);
        p.devotion = math.min(1.0, p.devotion + 0.01);
      case (OpportunityKind.hateWave, OpportunityChoice.ignore):
        // Logging off is a rest too.
        p.creativeEnergy = math.min(100.0, p.creativeEnergy + 5);
        blewOver = r.chance(0.6);
        if (!blewOver) {
          p.popularity = math.max(0.0, p.popularity - 0.05);
          p.devotion = math.max(0.0, p.devotion - 0.02);
        }
      case (OpportunityKind.hateWave, OpportunityChoice.leanIn):
        backfired = !r.chance(0.3 + 0.5 * charm);
        if (backfired) {
          p.popularity = math.max(0.0, p.popularity - 0.08);
          p.devotion = math.max(0.0, p.devotion - 0.03);
          hype = 0.04;
        } else {
          hype = 0.08;
          p.buzz += 0.3;
          fans = p.casual * 0.006;
        }
      // Leaked messages (docs K228).
      case (OpportunityKind.dmLeak, OpportunityChoice.apologize):
        p.popularity = math.max(0.0, p.popularity - 0.04);
        p.devotion = math.min(1.0, p.devotion + 0.01);
      case (OpportunityKind.dmLeak, OpportunityChoice.ignore):
        blewOver = r.chance(0.5);
        if (!blewOver) {
          p.popularity = math.max(0.0, p.popularity - 0.08);
          p.devotion = math.max(0.0, p.devotion - 0.03);
          hype = -0.04;
        }
      case (OpportunityKind.dmLeak, OpportunityChoice.leanIn):
        // Calling them fake: believed, it is over; proven real, it is
        // much worse.
        backfired = !r.chance(0.55);
        if (backfired) {
          p.popularity = math.max(0.0, p.popularity - 0.15);
          p.devotion = math.max(0.0, p.devotion - 0.06);
          hype = -0.08;
        } else {
          hype = 0.03;
        }
      // A slip on stage (docs K228).
      case (OpportunityKind.stageMishap, OpportunityChoice.apologize):
        // A free show for the night's crowd.
        paid = _fee(5e6, 2e8, p.fame, r);
        p.devotion = math.min(1.0, p.devotion + 0.02);
      case (OpportunityKind.stageMishap, OpportunityChoice.ignore):
        blewOver = r.chance(0.5);
        if (!blewOver) {
          // The clip goes around.
          p.popularity = math.max(0.0, p.popularity - 0.03);
          hype = 0.03;
        }
      case (OpportunityKind.stageMishap, OpportunityChoice.leanIn):
        backfired = !r.chance(0.35 + 0.5 * charm);
        if (backfired) {
          p.popularity = math.max(0.0, p.popularity - 0.05);
        } else {
          hype = 0.1;
          Audience.addCasual(w, p, p.casual * 0.02);
          fans = p.casual * 0.004;
        }
      case _:
        break; // declined
    }
    money = p.manager.net(money.toDouble()).round() - paid;
    p.moneyCents += money;
    p.hype = math.max(0.0, p.hype + hype);
    fans = Audience.addFans(w, p, fans);
    return OpportunityOutcome(
        kind: o.kind,
        choice: choice,
        moneyCents: money,
        fans: fans,
        hype: hype,
        energy: energy,
        won: won,
        blewOver: blewOver,
        backfired: backfired);
  }

  /// Whether the player's latest release let people down: a weak record
  /// or a bad review.
  static bool _letDown(World w, Artist p) {
    for (final al in w.albums.reversed) {
      if (al.artistId != p.id) continue;
      if (w.week - al.releaseWeek > 6) break;
      if (al.quality < 55 || (al.criticScore >= 0 && al.criticScore < 5.5)) {
        return true;
      }
    }
    for (final id in w.playerSongIds.reversed) {
      final s = w.songs[id];
      if (s.primaryArtistId != p.id || !s.isSingle) continue;
      if (s.singleWeek < 0 || w.week - s.singleWeek > 6) continue;
      if (s.quality < 50) return true;
    }
    return false;
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
}
