import 'model.dart';
import 'rng.dart';
import 'world.dart';

/// The outlets that review albums (docs K112), each with its taste and
/// its own way of scoring. Index order is UI order.
enum Outlet {
  /// The original reviewer (docs K55): tough, scores to a tenth.
  pitchwork,

  /// Star ratings; generous, fond of rock, folk, blues and soul.
  rollingPage,

  /// The British weekly; loves guitars and clubs, cool on country and pop.
  needle,

  /// Hip-hop and R&B first; letter grades.
  hypeBureau,

  /// Pop's friend; out of 100.
  popMatter,
}

abstract final class Critics {
  /// How an outlet leans on a genre, in points out of 10.
  static double bias(Outlet o, int genre) => switch (o) {
        Outlet.pitchwork => 0,
        Outlet.rollingPage => 0.3 +
            switch (genre) {
              3 || 10 || 14 || 15 => 0.5,
              4 => 0.3,
              _ => 0.0,
            },
        Outlet.needle => switch (genre) {
            3 || 5 || 7 || 8 || 9 => 0.5,
            4 => -0.6,
            0 || 18 => -0.3,
            _ => 0.0,
          },
        Outlet.hypeBureau => switch (genre) {
            1 || 2 || 10 || 17 => 0.6,
            3 || 4 || 8 => -0.4,
            _ => 0.0,
          },
        Outlet.popMatter => 0.2 +
            switch (genre) {
              0 || 5 || 6 || 12 || 18 => 0.5,
              8 => -0.3,
              _ => 0.0,
            },
      };

  /// Every outlet's score of [al] out of 10 (Pitchwork's is the one given
  /// at release). The same album always gets the same reviews.
  static Map<Outlet, double> reviews(World w, Album al) {
    if (al.criticScore < 0) return const {};
    final genre = w.artists[al.artistId].genre;
    final base = (al.quality - 10) / 9;
    final r = RandomStream.keyed(w.seed, 0, al.id, RngPurpose.criticPanel);
    return {
      for (final o in Outlet.values)
        o: o == Outlet.pitchwork
            ? al.criticScore
            : ((base + bias(o, genre) + r.nextNormal() * 0.6).clamp(1.0, 10.0) *
                        10)
                    .round() /
                10,
    };
  }

  /// The average of all reviews out of 100, Metacritic style (-1: not
  /// reviewed).
  static int metascore(World w, Album al) {
    final all = reviews(w, al);
    if (all.isEmpty) return -1;
    final sum = all.values.fold(0.0, (t, x) => t + x);
    return (sum / all.length * 10).round();
  }
}
