import 'dart:convert';

import 'config/charts.dart';
import 'model.dart';
import 'rng.dart';
import 'world.dart';

/// A move in a feud between two rivals (docs K311): a diss on social media
/// or a single out while it lasts (a diss track, [songId]).
class FeudMove {
  const FeudMove(this.week, this.byA, [this.songId = -1]);
  final int week;
  final bool byA;
  final int songId;
  bool get isTrack => songId >= 0;
}

/// Two rivals at war (docs K311): how hot it is, what each side did, how
/// their records did on the charts meanwhile, and how it ended.
class RivalFeud {
  RivalFeud(this.a, this.b, this.startWeek, {this.heat = RivalFeuds.startHeat});
  final int a, b;
  final int startWeek;
  int endWeek = -1;
  double heat;

  /// Their best US song chart points, week by week, added up: who comes
  /// out on top is who the public played more.
  double aPoints = 0, bPoints = 0;
  final List<FeudMove> moves = [];

  /// [a] or [b], or -1 for no winner (still on, or a draw).
  int winner = -1;

  bool get isOn => endWeek < 0;
  bool involves(int id) => a == id || b == id;
  int other(int id) => id == a ? b : a;
}

/// Rivals at war with each other, the player watching (docs K311): two
/// stars of a sound and a size start a feud now and then, trade disses
/// and diss tracks while it is hot, and it ends with whoever the public
/// played more on top. It is the world's story: it changes nobody's
/// numbers, it reads them.
abstract final class RivalFeuds {
  /// A week's chance of a new feud, and how many at once.
  static const startChance = 0.06, maxOn = 2;

  /// Who can start one: famous enough, and the other within this much of
  /// their fame.
  static const minFame = 0.3, fameSpread = 1.6;

  /// Heat at the start, kept each week, added by a diss and a track; it
  /// ends when it cools below [endHeat] or after [maxWeeks].
  static const startHeat = 0.6, keep = 0.88, dissHeat = 0.05, trackHeat = 0.35;
  static const endHeat = 0.12, maxWeeks = 20;

  /// The weekly chance of a diss at full heat.
  static const dissChance = 0.3;

  /// Ahead by this much of the other's points to win.
  static const winMargin = 1.15;

  /// Years before the same two fight again.
  static const againWeeks = 3 * 52;

  /// Feuds kept (the old ones go).
  static const kept = 40;

  /// After [week] was played (its charts are the latest).
  static void weekly(World w, int week) {
    if (w.player == null) return;
    final best = _bestPoints(w);
    for (final f in w.rivalFeuds) {
      if (!f.isOn) continue;
      _play(w, f, week, best);
    }
    final on = w.rivalFeuds.where((f) => f.isOn).length;
    if (on < maxOn) _maybeStart(w, week);
    if (w.rivalFeuds.length > kept) {
      w.rivalFeuds.removeRange(0, w.rivalFeuds.length - kept);
    }
  }

  static void _play(World w, RivalFeud f, int week, Map<int, double> best) {
    final r = RandomStream.keyed(w.seed, week, f.a * 7919 + f.b, RngPurpose.rivalFeud);
    f.aPoints += best[f.a] ?? 0;
    f.bPoints += best[f.b] ?? 0;
    f.heat *= keep;
    for (final byA in const [true, false]) {
      final id = byA ? f.a : f.b;
      // A single out while it is on is taken as the answer.
      final track = _singleOutThisWeek(w, id, week);
      if (track >= 0 && week > f.startWeek) {
        f.moves.add(FeudMove(week, byA, track));
        f.heat = (f.heat + trackHeat).clamp(0.0, 1.0);
      } else if (r.chance(dissChance * f.heat)) {
        f.moves.add(FeudMove(week, byA));
        f.heat = (f.heat + dissHeat).clamp(0.0, 1.0);
      }
    }
    if (f.heat < endHeat || week - f.startWeek >= maxWeeks) {
      f.endWeek = week;
      f.winner = f.aPoints > f.bPoints * winMargin
          ? f.a
          : f.bPoints > f.aPoints * winMargin
              ? f.b
              : -1;
    }
  }

  static void _maybeStart(World w, int week) {
    final r = RandomStream.keyed(w.seed, week, -7, RngPurpose.rivalFeud);
    if (!r.chance(startChance)) return;
    final busy = {
      for (final f in w.rivalFeuds)
        if (f.isOn) ...[f.a, f.b]
    };
    bool can(Artist x) =>
        x.tier != ArtistTier.player &&
        !x.isRetired &&
        x.managedBy < 0 &&
        x.fame >= minFame &&
        !busy.contains(x.id);
    final pool = [
      for (final x in w.artists)
        if (can(x)) x
    ];
    if (pool.length < 2) return;
    final a = pool[r.nextInt(pool.length)];
    Artist? b;
    var gap = double.infinity;
    for (final x in pool) {
      if (x.id == a.id || x.genre != a.genre) continue;
      final ratio = x.fame > a.fame ? x.fame / a.fame : a.fame / x.fame;
      if (ratio > fameSpread) continue;
      if (w.rivalFeuds.any((f) =>
          f.involves(a.id) &&
          f.involves(x.id) &&
          week - f.startWeek < againWeeks)) {
        continue;
      }
      final d = (x.fame - a.fame).abs();
      if (d < gap) {
        gap = d;
        b = x;
      }
    }
    if (b == null) return;
    w.rivalFeuds.add(RivalFeud(a.id, b.id, week));
  }

  /// Each artist's best US song this week, in chart points.
  static Map<int, double> _bestPoints(World w) {
    final out = <int, double>{};
    for (final e in w.charts[Charts.usSongs]) {
      final id = w.songs[e.entityId].primaryArtistId;
      if (e.points > (out[id] ?? 0)) out[id] = e.points;
    }
    return out;
  }

  static int _singleOutThisWeek(World w, int artistId, int week) {
    for (final id in w.activeSongIds) {
      final s = w.songs[id];
      if (s.primaryArtistId == artistId && s.isSingle && s.singleWeek == week) {
        return s.id;
      }
    }
    return -1;
  }

  /// The feuds [artistId] was in, latest first.
  static List<RivalFeud> of(World w, int artistId) =>
      [for (final f in w.rivalFeuds.reversed) if (f.involves(artistId)) f];

  static String encode(List<RivalFeud> fs) => jsonEncode([
        for (final f in fs)
          [
            f.a,
            f.b,
            f.startWeek,
            f.endWeek,
            f.heat,
            f.aPoints,
            f.bPoints,
            f.winner,
            [
              for (final m in f.moves) [m.week, m.byA ? 1 : 0, m.songId]
            ],
          ]
      ]);

  static List<RivalFeud> decode(String? s) {
    if (s == null || s.isEmpty) return [];
    return [
      for (final x in jsonDecode(s) as List)
        () {
          final l = x as List;
          final f = RivalFeud(l[0] as int, l[1] as int, l[2] as int,
              heat: (l[4] as num).toDouble())
            ..endWeek = l[3] as int
            ..aPoints = (l[5] as num).toDouble()
            ..bPoints = (l[6] as num).toDouble()
            ..winner = l[7] as int;
          for (final m in l[8] as List) {
            final mm = m as List;
            f.moves.add(
                FeudMove(mm[0] as int, mm[1] == 1, mm[2] as int));
          }
          return f;
        }(),
    ];
  }
}
