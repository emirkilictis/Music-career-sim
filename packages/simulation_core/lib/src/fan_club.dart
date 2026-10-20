import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// What a membership costs a month (docs K164). Index order is stored.
enum ClubPrice {
  low(300, 0.03),
  mid(500, 0.02),
  high(1000, 0.01);

  const ClubPrice(this.monthCents, this.joinRate);
  final int monthCents;

  /// Share of devoted fans who join at this price.
  final double joinRate;
}

/// The player's paid fan club (docs K164).
class FanClub {
  FanClub(
      {required this.openWeek,
      required this.price,
      this.members = 0,
      this.revenueCents = 0});

  final int openWeek;
  ClubPrice price;
  double members;

  /// What the club has paid the artist so far.
  double revenueCents;

  String encode() =>
      jsonEncode([openWeek, price.index, members, revenueCents]);

  static FanClub? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    final j = jsonDecode(s) as List;
    return FanClub(
        openWeek: j[0] as int,
        price: ClubPrice.values[j[1] as int],
        members: (j[2] as num).toDouble(),
        revenueCents: (j[3] as num).toDouble());
  }
}

/// A paid fan club, the Patreon way (docs K164): the most devoted fans
/// pay every month for being close (early news, members-only posts,
/// presales). Members come with devotion and the price, leave when the
/// artist goes quiet, and order every new record ahead.
abstract final class FanClubs {
  /// Fans needed to start one, and what setting it up costs.
  static const minFans = 20000;
  static const setupCents = 2000000;

  /// Members move this share of the way to what the club can hold.
  static const pull = 0.1;

  /// Weeks without a release before members start to leave, and how
  /// much of the target is left the longer it lasts.
  static const quietWeeks = 26;
  static const quietFloor = 0.4;

  /// Members keep the fandom warm: devotion each week at full strength
  /// (members 2% of the fans or more).
  static const devotionLift = 0.002;

  /// Share of members who order each new album or EP ahead.
  static const albumBuy = 0.6;

  static bool can(World w, Artist a) =>
      w.fanClub == null && a.coreFans >= minFans;

  static FanClub open(World w, Artist a, ClubPrice price) {
    if (w.fanClub != null) throw ActionException('Already open');
    if (a.coreFans < minFans) throw ActionException('Not enough fans');
    if (a.moneyCents < setupCents) throw ActionException('Not enough money');
    a.moneyCents -= setupCents;
    w.dirtyArtists.add(a.id);
    return w.fanClub = FanClub(openWeek: w.week, price: price);
  }

  /// How active the artist looks to members (1: recent release).
  static double activity(World w, Artist a) {
    final quiet = w.week - a.lastReleaseWeek - quietWeeks;
    if (a.lastReleaseWeek < 0 || quiet <= 0) return 1;
    return math.max(quietFloor, 1 - quiet / 52);
  }

  /// Members the club can hold now.
  static double target(World w, Artist a, FanClub c) =>
      a.coreFans * (0.4 + a.devotion) * c.price.joinRate * activity(w, a);

  /// The week's membership: members come and go, pay, and keep the
  /// fandom warm. Returns this week's money.
  static double weekly(World w, Artist a) {
    final c = w.fanClub;
    if (c == null) return 0;
    c.members += (target(w, a, c) - c.members) * pull;
    if (c.members < 1) c.members = 0;
    final share =
        a.coreFans <= 0 ? 0.0 : math.min(1.0, c.members / a.coreFans * 50);
    a.devotion = math.min(1.0, a.devotion + devotionLift * share);
    final cents = c.members * c.price.monthCents * 12 / GameTime.weeksPerYear;
    c.revenueCents += cents;
    w.dirtyArtists.add(a.id);
    return cents;
  }

  /// Copies members order of a new album or EP.
  static double albumCopies(World w, AlbumType type) {
    final c = w.fanClub;
    if (c == null || (type != AlbumType.album && type != AlbumType.ep)) {
      return 0;
    }
    return c.members * albumBuy;
  }
}
