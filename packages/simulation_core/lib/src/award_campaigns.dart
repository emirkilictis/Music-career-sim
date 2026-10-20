import 'dart:convert';

import 'actions.dart';
import 'awards.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// How much the player spends on a For Your Consideration campaign
/// (docs K171). Index order is stored.
enum FycTier {
  small(10000000, 0.03, 1.3),
  big(50000000, 0.06, 1.7),
  allOut(200000000, 0.10, 2.2);

  const FycTier(this.costCents, this.nominationLift, this.voteFactor);
  final int costCents;

  /// Added to the voters' score of each of the player's contenders.
  final double nominationLift;

  /// How much likelier voters pick the player's nominee.
  final double voteFactor;
}

/// Which part of the awards season it is.
enum FycPhase { closed, nominations, voting }

/// The player's campaign for one show.
class FycCampaign {
  FycCampaign(this.year, {this.nomination, this.vote});
  final int year;
  FycTier? nomination;
  FycTier? vote;

  String encode() =>
      jsonEncode([year, nomination?.index ?? -1, vote?.index ?? -1]);

  static FycCampaign? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    final j = jsonDecode(s) as List;
    final n = j[1] as int, v = j[2] as int;
    return FycCampaign(j[0] as int,
        nomination: n < 0 ? null : FycTier.values[n],
        vote: v < 0 ? null : FycTier.values[v]);
  }
}

/// For Your Consideration (docs K171): trade ads, screenings and parties
/// for the voters. Before the nominations it lifts every record of the
/// player in the running; after them it makes the voters likelier to pick
/// the player's nominees. It cannot make a weak record a contender.
abstract final class AwardCampaigns {
  /// The nominations campaign runs from the end of the eligibility
  /// window to the nominations.
  static const nominationFromWeekOfYear = Awards.windowStartWeekOfYear;

  /// The show a campaign this week is for, and which part of the season.
  static (int, FycPhase) phase(World w) {
    final woy = GameTime.weekOfYear(w.week);
    final year = GameTime.yearOf(w.week);
    if (woy >= nominationFromWeekOfYear && woy < Awards.nominationsWeekOfYear) {
      return (year + 1, FycPhase.nominations);
    }
    final show = woy >= Awards.nominationsWeekOfYear
        ? Awards.showFor(w, year + 1)
        : woy < Awards.ceremonyWeekOfYear
            ? Awards.showFor(w, year)
            : null;
    final me = w.playerArtistId;
    if (show != null && !show.held && show.racesOf(me).isNotEmpty) {
      return (show.year, FycPhase.voting);
    }
    return (0, FycPhase.closed);
  }

  static FycCampaign? current(World w, int year) {
    final c = w.fycCampaign;
    return c != null && c.year == year ? c : null;
  }

  /// Runs the campaign of the current part of the season at [tier].
  static void run(World w, Artist a, FycTier tier) {
    final (year, ph) = phase(w);
    if (ph == FycPhase.closed) throw ActionException('Not the season');
    final c = current(w, year) ?? FycCampaign(year);
    if (ph == FycPhase.nominations ? c.nomination != null : c.vote != null) {
      throw ActionException('Already running');
    }
    if (a.moneyCents < tier.costCents) {
      throw ActionException('Not enough money');
    }
    a.moneyCents -= tier.costCents;
    if (ph == FycPhase.nominations) {
      c.nomination = tier;
    } else {
      c.vote = tier;
    }
    w.fycCampaign = c;
    w.dirtyArtists.add(a.id);
  }

  /// The lift the player's contenders get in [year]'s nominations.
  static double nominationLift(World w, int year, int artistId) {
    if (artistId != w.playerArtistId) return 0;
    return current(w, year)?.nomination?.nominationLift ?? 0;
  }

  /// How much likelier the voters pick [artistId] at [year]'s show.
  static double voteFactor(World w, int year, int artistId) {
    if (artistId != w.playerArtistId) return 1;
    return current(w, year)?.vote?.voteFactor ?? 1;
  }
}
