import 'dart:math' as math;

import 'actions.dart';
import 'config/regions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'world.dart';

/// The radio markets the player works on their own (docs K254).
enum RadioMarket {
  us(Region.northAmerica),
  uk(Region.europe);

  const RadioMarket(this.region);

  /// The simulation region whose stations it stands for.
  final Region region;
}

/// More ways to work the radio (docs K254): a radio edit, a push of its
/// own in the UK, and visits to the stations.
abstract final class RadioTools {
  /// A radio edit's lift on the stations' play: a tight, clean version
  /// they add more readily.
  static const editLift = 1.2;

  /// A radio edit in 2020 money for an artist of ~1.5M listeners; scales
  /// like the pushes.
  static const editCents = 2500000;

  /// A UK push against the same push everywhere: the UK is a smaller
  /// market.
  static const ukPriceShare = 0.3;

  /// A station visit: the energy it takes, how long and how much the
  /// stations favour the artist after, and how often one market takes one.
  static const visitEnergy = 15.0;
  static const visitWeeks = 8, visitGapWeeks = 4;
  static const visitLift = 0.25;

  static int editCostFor(Artist a) =>
      (editCents * math.sqrt(Actions.campaignSizeFactor(a))).round();

  /// A single on the radio in its first half year without an edit yet.
  static bool canEdit(World w, Artist a, Song s) =>
      s.isSingle &&
      s.status == SongStatus.active &&
      s.radioEditWeek < 0 &&
      !s.radioPush.isPulled &&
      w.week - s.singleWeek < 26;

  static void cutEdit(World w, Artist a, Song s) {
    if (!canEdit(w, a, s)) throw ActionException('No radio edit now');
    final cost = editCostFor(a);
    if (cost > a.moneyCents) throw ActionException('Not enough money');
    a.moneyCents -= cost;
    s.campaignCostCents += cost;
    s.radioEditWeek = w.week;
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// The push the UK stations get.
  static RadioPush ukPush(Song s) => s.ukRadioPush ?? s.radioPush;

  /// UK pushes the player can raise [s] to now, with their price.
  static Map<RadioPush, int> ukOptions(World w, Artist a, Song s) {
    if (!s.isSingle ||
        s.status != SongStatus.active ||
        s.radioPush.isPulled ||
        w.week - s.singleWeek >= Actions.radioUpgradeWeeks) {
      return const {};
    }
    final now = ukPush(s);
    return {
      for (final r in RadioPush.ladder)
        if (r.rank > now.rank && r.rank <= Actions.maxRadioPush(a.label).rank)
          r: ukCost(a, now, r),
    };
  }

  static int ukCost(Artist a, RadioPush from, RadioPush to) =>
      (ukPriceShare *
              math.max(
                  0,
                  Actions.radioPushCostFor(a, to) -
                      Actions.radioPushCostFor(a, from)))
          .round();

  /// Raises [s]'s push in the UK alone.
  static void raiseUk(World w, Artist a, Song s, RadioPush to) {
    final options = ukOptions(w, a, s);
    final cost = options[to];
    if (cost == null) throw ActionException('UK push not possible');
    if (cost > a.moneyCents) throw ActionException('Not enough money');
    a.moneyCents -= cost;
    s.campaignCostCents += cost;
    s.ukRadioPush = to;
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// The last visit to [m]'s stations (-1: never).
  static int lastVisit(World w, RadioMarket m) {
    var last = -1;
    for (final (week, x) in w.radioVisits) {
      if (x == m.index && week > last) last = week;
    }
    return last;
  }

  static bool canVisit(World w, Artist a, RadioMarket m) {
    final last = lastVisit(w, m);
    return (last < 0 || w.week - last >= visitGapWeeks) &&
        a.creativeEnergy >= visitEnergy &&
        a.tour == null;
  }

  /// Visits [m]'s stations: interviews and a live set on air. They play
  /// the artist's singles more for [visitWeeks] weeks.
  static void visit(World w, Artist a, RadioMarket m) {
    if (!canVisit(w, a, m)) throw ActionException('No visit now');
    a.creativeEnergy -= visitEnergy;
    a.hype += 0.01 * (0.5 + a.skills.charisma / 100);
    w.radioVisits.add((w.week, m.index));
    if (w.radioVisits.length > 50) w.radioVisits.removeAt(0);
    w.dirtyArtists.add(a.id);
  }

  /// The stations' extra play for the player in [region] this week from a
  /// visit, 1 without one.
  static double visitFactor(World w, int region) {
    for (final m in RadioMarket.values) {
      if (m.region.index != region) continue;
      final last = lastVisit(w, m);
      if (last >= 0 && w.week - last < visitWeeks) {
        return 1 + visitLift * (1 - (w.week - last) / visitWeeks);
      }
    }
    return 1;
  }

  // ------------------------------------------------- the radio budget

  /// The radio push as a weekly budget (docs K290): a level from 0 to 100,
  /// changed any time after release, through the pushes of the release:
  /// 0 none, 25 a light push, 50 a standard one, 75 heavy rotation, 100 a
  /// blitz. A push bought at release covers about [levelWeeks] weeks; the
  /// level costs that push's price over as many weeks, every week it runs.
  static const levelWeeks = 12;
  static const maxLevelValue = 100;

  /// Weeks after which the stations have let a song go: raising its level
  /// then works it to them again, as a new run.
  static const radioRunWeeks = 26;

  static (RadioPush, RadioPush, double) _between(int level) {
    final x = level.clamp(0, maxLevelValue) / 25;
    final i = x.floor().clamp(0, RadioPush.ladder.length - 2);
    return (RadioPush.ladder[i], RadioPush.ladder[i + 1], x - i);
  }

  /// The play a level brings for an artist this famous.
  static double levelFactor(int level, double fame) {
    final (a, b, t) = _between(level);
    final fa = a.factorFor(fame), fb = b.factorFor(fame);
    return fa + (fb - fa) * t;
  }

  /// What a level costs [a] each week.
  static int levelWeeklyCents(Artist a, int level) {
    if (level <= 0) return 0;
    final (lo, hi, t) = _between(level);
    final ca = Actions.radioPushCostFor(a, lo),
        cb = Actions.radioPushCostFor(a, hi);
    return ((ca + (cb - ca) * t) / levelWeeks).round();
  }

  /// The highest level [a]'s label can run (a standard push without one,
  /// heavy rotation with a mid-size label, a blitz with a major).
  static int maxLevel(Artist a) =>
      Actions.maxRadioPush(a.label).rank * 25;

  /// Weeks since [s]'s radio run began.
  static int radioAge(World w, Song s) =>
      w.week - (s.radioPushWeek >= 0 ? s.radioPushWeek : s.singleWeek);

  /// The play [s] gets from its push: its budget once set, else the push
  /// bought at release.
  static double pushFactor(Song s, double fame) => s.radioLevel >= 0
      ? levelFactor(s.radioLevel, fame)
      : s.radioPush.factorFor(fame);

  /// The level [s] runs at (the release push's place if none was set).
  static int levelOf(Song s) => s.radioLevel >= 0
      ? s.radioLevel
      : s.radioPush.isPulled
          ? 0
          : s.radioPush.rank * 25;

  /// Whether [a] can set [s]'s radio budget: a released single of theirs
  /// whose album is on sale.
  static bool canSetLevel(World w, Artist a, Song s) =>
      s.isSingle &&
      s.releasedWeek >= 0 &&
      s.releasedWeek <= w.week &&
      s.primaryArtistId == a.id &&
      (s.albumId < 0 || !w.albums[s.albumId].isOff);

  /// Sets [s]'s radio budget. A song the stations let go long ago, or one
  /// in the catalog, is worked to them again from this week (docs K290).
  static void setLevel(World w, Artist a, Song s, int level) {
    if (!canSetLevel(w, a, s)) throw ActionException('Not on the radio');
    if (level < 0 || level > maxLevel(a)) {
      throw ActionException('The label cannot run this');
    }
    if (level > 0 &&
        (s.status == SongStatus.dormant || radioAge(w, s) >= radioRunWeeks)) {
      s.radioPushWeek = w.week;
      Lifecycle.reactivateSong(w, s);
    }
    if (s.radioPush.isPulled) s.radioPush = RadioPush.none;
    // One budget everywhere: a UK push of its own ends.
    s.ukRadioPush = null;
    s.radioLevel = level;
    w.dirtySongs.add(s.id);
  }

  /// Pays this week's radio budgets of [a]'s active singles; a budget the
  /// money no longer covers stops (level 0). Returns what was paid.
  static int bill(World w, Artist a) {
    var paid = 0;
    for (final id in w.activeSongIds) {
      final s = w.songs[id];
      if (s.primaryArtistId != a.id || s.radioLevel <= 0) continue;
      final cost = levelWeeklyCents(a, s.radioLevel);
      if (cost > a.moneyCents) {
        s.radioLevel = 0;
        w.dirtySongs.add(s.id);
        continue;
      }
      a.moneyCents -= cost;
      s.campaignCostCents += cost;
      paid += cost;
      w.dirtySongs.add(s.id);
    }
    return paid;
  }

  /// [s]'s radio in [region] against the push it was given everywhere:
  /// the UK push, the edit and, for the player, a station visit.
  static double regionFactor(World w, Artist a, Song s, int region,
      {required double visit}) {
    var f = s.radioEditWeek >= 0 ? editLift : 1.0;
    if (region == Region.europe.index && s.ukRadioPush != null) {
      final main = s.radioPush.factorFor(a.fame);
      if (main > 0) f *= s.ukRadioPush!.factorFor(a.fame) / main;
    }
    return f * visit;
  }
}
