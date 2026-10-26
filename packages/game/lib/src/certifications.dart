import 'package:simulation_core/simulation_core.dart';

import 'events.dart';
import 'views.dart';

/// The player's US certifications as they come (docs K209): each new
/// level (gold, every platinum, every diamond) is recorded with its week
/// and the label then, and is news.
abstract final class Certs {
  /// A release's key in [World.certs].
  static int key(EntityKind kind, int id) =>
      kind == EntityKind.song ? id * 2 : id * 2 + 1;

  static (EntityKind, int) fromKey(int key) =>
      (key.isEven ? EntityKind.song : EntityKind.album, key ~/ 2);

  /// US units of a release, as certifications count them.
  static double units(World w, EntityKind kind, int id) =>
      kind == EntityKind.song
          ? usSingleUnits(w, w.songs[id])
          : usAlbumUnits(w, w.albums[id]);

  /// Units a level asks for.
  static double needs(Certification c, int multiple) => c.units * multiple;

  /// The levels between the last recorded one and [units], in order.
  static List<(Certification, int)> newLevels(
      List<List<int>> have, double units) {
    final reached = Certification.of(units);
    if (reached == null) return const [];
    final steps = <(Certification, int)>[
      (Certification.gold, 1),
      for (var m = 1; m < 10; m++) (Certification.platinum, m),
      for (var m = 1;
          m <= reached.$2 && reached.$1 == Certification.diamond;
          m++)
        (Certification.diamond, m),
    ];
    final lastUnits = have.isEmpty
        ? 0.0
        : needs(Certification.values[have.last[0]], have.last[1]);
    return [
      for (final s in steps)
        if (needs(s.$1, s.$2) > lastUnits && needs(s.$1, s.$2) <= units) s
    ];
  }

  /// The player's releases that can be certified.
  static Iterable<(EntityKind, int)> releases(World w) sync* {
    for (final id in w.playerSongIds) {
      if (w.songs[id].releasedWeek >= 0) yield (EntityKind.song, id);
    }
    for (final al in w.albums) {
      if (al.artistId == w.playerArtistId) yield (EntityKind.album, al.id);
    }
  }

  /// Records this week's new levels and returns them as news.
  static List<CertificationEarned> update(World w) {
    final p = w.player;
    if (p == null) return const [];
    final out = <CertificationEarned>[];
    for (final (kind, id) in releases(w)) {
      final k = key(kind, id);
      final have = w.certs[k] ?? const [];
      final fresh = newLevels(have, units(w, kind, id));
      if (fresh.isEmpty) continue;
      w.certs[k] = [
        ...have,
        for (final (c, m) in fresh) [c.index, m, w.week, p.label.index]
      ];
      final (c, m) = fresh.last;
      out.add(CertificationEarned(kind, id, c, m));
    }
    return out;
  }

  /// Fills [World.certs] once for a save from before docs K209, dating
  /// each level by when the release's [cumulative] history (week, units
  /// so far worldwide) crossed it in the US share it has now.
  static void backfill(World w,
      List<(int, double)> Function(EntityKind kind, int id) cumulative) {
    final p = w.player;
    if (p == null) return;
    for (final (kind, id) in releases(w)) {
      final us = units(w, kind, id);
      final levels = newLevels(const [], us);
      if (levels.isEmpty) continue;
      final hist = cumulative(kind, id);
      final total = hist.isEmpty ? 0.0 : hist.last.$2;
      final share = total > 0 ? us / total : 0.0;
      w.certs[key(kind, id)] = [
        for (final (c, m) in levels)
          [
            c.index,
            m,
            hist
                    .where((h) => h.$2 * share >= needs(c, m))
                    .map((h) => h.$1)
                    .firstOrNull ??
                w.week,
            p.label.index,
          ]
      ];
    }
    w.certsTracked = true;
  }
}
