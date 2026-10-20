import 'actions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// How far an album's download price is cut for a week (docs K163).
/// Index order is stored in saves: only append.
enum PriceCut {
  /// $7.99.
  sale(0.8, 1.6),

  /// $3.99.
  deep(0.4, 4.0),

  /// $0.99, the Born This Way move.
  ninetyNine(0.12, 12.0);

  const PriceCut(this.price, this.uplift);

  /// Share of the full price each discounted copy pays.
  final double price;

  /// How many more download copies sell that week.
  final double uplift;
}

/// Why an album's price cannot be cut now.
enum PriceCutBlock { noStore, notOut, tooSoon, chartRule, mixtape }

/// A week's price cut on the download store (docs K163): download copies
/// of the album sell several times over, each paying a fraction. A way to
/// a bigger week on the chart at the cost of the money, until Billboard
/// stopped counting albums sold for under $3.49 in their first four
/// weeks (2011).
abstract final class PriceCuts {
  /// Download stores sell albums from this year.
  static const fromYear = 2004;

  /// Weeks between two price cuts of an album.
  static const gapWeeks = 8;

  /// The chart stops counting cheap copies early in an album's life.
  static const ruleYear = 2011, ruleWeeks = 4;

  /// Share of album copies bought as downloads in [year] (US-like).
  static double digitalShare(int year) {
    const byYear = {
      2004: 0.01, 2005: 0.03, 2006: 0.06, 2007: 0.10, 2008: 0.15, //
      2009: 0.20, 2010: 0.27, 2011: 0.32, 2012: 0.37, 2013: 0.40,
      2014: 0.41, 2015: 0.42, 2016: 0.42, 2017: 0.40, 2018: 0.38,
      2019: 0.35,
    };
    if (year < fromYear) return 0;
    return byYear[year] ?? 0.32;
  }

  /// What stops [a] cutting [al]'s price with [cut] now (null: nothing).
  static PriceCutBlock? block(World w, Artist a, Album al, PriceCut cut) {
    final year = GameTime.yearOf(w.week);
    if (year < fromYear) return PriceCutBlock.noStore;
    if (al.isMixtape) return PriceCutBlock.mixtape;
    if (al.artistId != a.id || w.week <= al.releaseWeek) {
      return PriceCutBlock.notOut;
    }
    if (al.priceCutWeek >= 0 && w.week - al.priceCutWeek < gapWeeks) {
      return PriceCutBlock.tooSoon;
    }
    if (cut == PriceCut.ninetyNine &&
        year >= ruleYear &&
        w.week - al.releaseWeek < ruleWeeks) {
      return PriceCutBlock.chartRule;
    }
    return null;
  }

  /// Cuts [al]'s download price with [cut] for this week.
  static void start(World w, Artist a, Album al, PriceCut cut) {
    if (block(w, a, al, cut) case final b?) {
      throw ActionException('No price cut: ${b.name}');
    }
    al.priceCutWeek = w.week;
    al.priceCut = cut;
    if (al.status == AlbumStatus.dormant) Lifecycle.reactivateAlbum(w, al);
    al.weeksBelowCutoff = 0;
    w.dirtyAlbums.add(al.id);
  }

  /// [al] is on sale this week.
  static bool on(World w, Album al) => al.priceCutWeek == w.week;

  /// How many copies sell this week against the usual (1: no sale).
  static double salesFactor(World w, Album al) {
    if (!on(w, al)) return 1;
    final d = digitalShare(GameTime.yearOf(w.week));
    return 1 + d * (al.priceCut.uplift - 1);
  }

  /// What this week's copies pay on average against the full price.
  static double priceFactor(World w, Album al) {
    if (!on(w, al)) return 1;
    final d = digitalShare(GameTime.yearOf(w.week));
    final cut = al.priceCut;
    return ((1 - d) + d * cut.uplift * cut.price) / salesFactor(w, al);
  }
}
