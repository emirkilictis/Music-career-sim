import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'model.dart';
import 'rng.dart';
import 'social.dart';
import 'time.dart';
import 'world.dart';

/// Kinds of brand (docs K102). Index order is stored: only append.
enum BrandCategory {
  fashion,
  beverage,
  tech,
  beauty,
  luxury,
  sportswear,
  fastFood,
  gaming,
  auto,
}

/// A made-up brand: its category and how upmarket it is (0 = everyday,
/// 1 = luxury house). Artists whose fame matches it look natural there.
class BrandInfo {
  const BrandInfo(this.name, this.category, this.prestige);
  final String name;
  final BrandCategory category;
  final double prestige;
}

/// What a deal asks the artist to do (docs K102). Index order is stored.
enum DealTask {
  /// A sponsored post on the artist's social media.
  sponsoredPost(0),

  /// A day on set for an ad.
  adShoot(15),

  /// A launch or store event.
  launchEvent(10);

  const DealTask(this.energy);

  /// Creative energy it takes.
  final double energy;
}

/// Where a deal stands. Index order is stored.
enum DealStatus { active, completed, broken }

/// A signed brand deal: half the fee up front, the rest when every task
/// is done before its due week (docs K102).
class BrandDeal {
  BrandDeal({
    required this.brand,
    required this.startWeek,
    required this.feeCents,
    required this.tasks,
    this.paidCents = 0,
    this.status = DealStatus.active,
  });

  /// Index into [Brands.all].
  final int brand;
  final int startWeek;
  final int feeCents;
  int paidCents;
  DealStatus status;

  /// Each task with its due week and the week it was done (-1: not yet).
  final List<(DealTask, int, int)> tasks;

  BrandInfo get info => Brands.all[brand];
  bool get allDone => tasks.every((t) => t.$3 >= 0);

  List<Object> toJson() => [
        brand,
        startWeek,
        feeCents,
        paidCents,
        status.index,
        [
          for (final (t, due, done) in tasks) [t.index, due, done]
        ],
      ];

  static BrandDeal fromJson(List<dynamic> j) => BrandDeal(
        brand: j[0] as int,
        startWeek: j[1] as int,
        feeCents: j[2] as int,
        paidCents: j[3] as int,
        status: DealStatus.values[j[4] as int],
        tasks: [
          for (final t in j[5] as List)
            (DealTask.values[(t as List)[0] as int], t[1] as int, t[2] as int)
        ],
      );

  static String encode(List<BrandDeal> d) =>
      jsonEncode([for (final x in d) x.toJson()]);

  static List<BrandDeal> decode(String? s) => s == null || s.isEmpty
      ? []
      : [for (final x in jsonDecode(s) as List) fromJson(x as List)];
}

/// What finishing (or failing) a deal did, for the news.
class DealOutcome {
  DealOutcome(this.deal, {required this.cents});
  final BrandDeal deal;

  /// Paid on completion, or the half lost when broken.
  final int cents;
}

abstract final class Brands {
  /// Deals running at once at most; no offers beyond.
  static const maxActive = 3;

  static const all = <BrandInfo>[
    BrandInfo('Volta Cola', BrandCategory.beverage, 0.25),
    BrandInfo('Fizzbloom', BrandCategory.beverage, 0.15),
    BrandInfo('Crunch King', BrandCategory.fastFood, 0.05),
    BrandInfo('Nimbus Phones', BrandCategory.tech, 0.55),
    BrandInfo('Pixel Forge', BrandCategory.gaming, 0.2),
    BrandInfo('Glossé', BrandCategory.beauty, 0.5),
    BrandInfo('Petal & Pout', BrandCategory.beauty, 0.3),
    BrandInfo('Stride', BrandCategory.sportswear, 0.45),
    BrandInfo('Kinetic', BrandCategory.sportswear, 0.3),
    BrandInfo('Velvet & Co.', BrandCategory.fashion, 0.4),
    BrandInfo('Urban Thread', BrandCategory.fashion, 0.2),
    BrandInfo('Maison Lumière', BrandCategory.luxury, 0.95),
    BrandInfo('Arcadia Paris', BrandCategory.luxury, 0.85),
    BrandInfo('Aurora Motors', BrandCategory.auto, 0.7),
    BrandInfo('Echo Audio', BrandCategory.tech, 0.4),
    BrandInfo('Solstice Water', BrandCategory.beverage, 0.35),
  ];

  /// How natural the artist looks with [b]: 1 when the brand is as
  /// upmarket as the artist is famous; a superstar selling burgers or a
  /// newcomer in a luxury campaign feel off.
  static double fit(BrandInfo b, Artist a) =>
      (1 - (b.prestige - a.fame).abs() * 1.4).clamp(0.0, 1.0);

  /// A brand that wants [a]: mostly ones near their standing.
  static int pick(Artist a, RandomStream r) {
    final weights = [
      for (final b in all) 0.05 + math.pow(fit(b, a), 2).toDouble()
    ];
    final total = weights.fold(0.0, (x, y) => x + y);
    var x = r.nextDouble() * total;
    for (var i = 0; i < all.length; i++) {
      x -= weights[i];
      if (x <= 0) return i;
    }
    return all.length - 1;
  }

  /// The fee: grows with fame, more from upmarket brands.
  static double feeFactor(BrandInfo b) => 0.6 + 0.8 * b.prestige;

  /// What a deal with [b] asks: always a sponsored post, an ad shoot for
  /// brands that run ads, a launch event for fashion, beauty, luxury and
  /// tech.
  static List<(DealTask, int, int)> tasksFor(BrandInfo b, int week) => [
        if (Social.canPostIn(GameTime.yearOf(week)))
          (DealTask.sponsoredPost, week + 2, -1),
        // Before social media every deal is an ad.
        if (b.prestige >= 0.2 ||
            b.category == BrandCategory.fastFood ||
            !Social.canPostIn(GameTime.yearOf(week)))
          (DealTask.adShoot, week + 4, -1),
        if (const {
          BrandCategory.fashion,
          BrandCategory.beauty,
          BrandCategory.luxury,
          BrandCategory.tech,
        }.contains(b.category))
          (DealTask.launchEvent, week + 6, -1),
      ];

  static int activeCount(World w) =>
      w.brandDeals.where((d) => d.status == DealStatus.active).length;

  /// Signs [brand] for [feeCents]: half paid now (less the manager's
  /// cut), fans react to the fit, more of them grumble about selling out
  /// with every other deal running.
  static BrandDeal sign(World w, Artist a, int brand, int feeCents) {
    final b = all[brand];
    final deal = BrandDeal(
      brand: brand,
      startWeek: w.week,
      feeCents: feeCents,
      tasks: tasksFor(b, w.week),
    );
    final half = a.manager.net(feeCents / 2).round();
    a.moneyCents += half;
    deal.paidCents = half;
    final others = activeCount(w);
    a.devotion =
        (a.devotion + (fit(b, a) - 0.6) * 0.05 - 0.01 * others).clamp(0.0, 1.0);
    a.hype += 0.02;
    w.brandDeals.add(deal);
    w.dirtyArtists.add(a.id);
    return deal;
  }

  /// Does task [task] of deal [deal]. Returns the completion when it was
  /// the last task.
  static DealOutcome? doTask(World w, Artist a, int deal, int task) {
    final d = w.brandDeals[deal];
    if (d.status != DealStatus.active) throw ActionException('Deal over');
    final (kind, due, done) = d.tasks[task];
    if (done >= 0) throw ActionException('Already done');
    if (a.creativeEnergy < kind.energy) throw ActionException('Too tired');
    final b = d.info;
    final fitness = fit(b, a);
    switch (kind) {
      case DealTask.sponsoredPost:
        if (w.social.postsIn(w.week) >= Social.postsPerWeek) {
          throw ActionException('Posted enough this week');
        }
        Social.sponsoredPost(w, a, deal, fitness);
      case DealTask.adShoot:
        a.creativeEnergy -= kind.energy;
        a.hype += 0.03;
        a.casual += a.casual * (0.003 + 0.005 * b.prestige);
      case DealTask.launchEvent:
        a.creativeEnergy -= kind.energy;
        a.hype += 0.04;
        a.devotion = math.min(1.0, a.devotion + 0.005);
    }
    d.tasks[task] = (kind, due, w.week);
    w.dirtyArtists.add(a.id);
    if (!d.allDone) return null;
    final rest = a.manager.net((d.feeCents - d.feeCents / 2)).round();
    a.moneyCents += rest;
    d.paidCents += rest;
    d.status = DealStatus.completed;
    return DealOutcome(d, cents: rest);
  }

  /// Deals with a task past its due week break: the second half is lost
  /// and the story hurts a little.
  static List<DealOutcome> weekly(World w) {
    final a = w.player;
    if (a == null) return const [];
    final broken = <DealOutcome>[];
    for (final d in w.brandDeals) {
      if (d.status != DealStatus.active) continue;
      if (!d.tasks.any((t) => t.$3 < 0 && t.$2 < w.week)) continue;
      d.status = DealStatus.broken;
      a.hype = math.max(0.0, a.hype - 0.03);
      a.devotion = math.max(0.0, a.devotion - 0.01);
      w.dirtyArtists.add(a.id);
      broken.add(DealOutcome(d, cents: d.feeCents - d.feeCents ~/ 2));
    }
    return broken;
  }

  /// Weeks left for a task due in [due] (0 = this week is the last).
  static int weeksLeft(World w, int due) => due - w.week;

  /// The year a brand would first come knocking (no social media, no
  /// sponsored posts before 2004).
  static bool open(World w) => GameTime.yearOf(w.week) >= 2004;
}
