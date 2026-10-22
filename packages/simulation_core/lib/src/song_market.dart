import 'dart:math' as math;

import 'actions.dart';
import 'model.dart';
import 'names.dart';
import 'rng.dart';
import 'world.dart';

/// A finished demo a songwriter offers the player (docs K205).
class SongPitch {
  const SongPitch({
    required this.index,
    required this.writer,
    required this.title,
    required this.genre,
    required this.demo,
    required this.priceCents,
    required this.takenWeek,
  });

  /// Its place in this month's offers.
  final int index;
  final Collaborator writer;
  final String title;
  final int genre;

  /// How good the demo is (0–100): the writer's craft and their team's
  /// production. The record also takes the player's voice.
  final double demo;
  final int priceCents;

  /// The week a rival snaps it up if the player has not (past the month:
  /// nobody does).
  final int takenWeek;
}

/// The song market (docs K205): every month songwriters who would work
/// with the player send a few finished demos. Buying one puts it in the
/// vault recorded, without the creativity writing costs; the writer keeps
/// a publishing share of what it earns. Rivals buy demos too, so a good
/// one may be gone by the time the player decides.
abstract final class SongMarket {
  /// Offers a month, weeks in a month, and the writer's share of what a
  /// bought song earns the player.
  static const size = 5, periodWeeks = 4;
  static const writerCut = 0.15;

  /// How much of the record is the demo; the rest is the player's voice.
  static const demoWeight = 0.75;

  /// How far the team's guess may be off, either way.
  static const spread = 4;

  static int period(int week) => week ~/ periodWeeks;

  static RandomStream _r(World w, Artist a, int p, int n) =>
      RandomStream.keyed(w.seed, p, a.id * 16 + n, RngPurpose.songMarket);

  /// This month's offers to [a], those already bought or taken included.
  static List<SongPitch> pitches(World w, Artist a) {
    final p = period(w.week);
    final writers = [
      for (final c in w.collaborators)
        if (c.role == CollaboratorRole.songwriter &&
            Actions.collaboratorAvailable(c, a))
          c
    ];
    if (writers.isEmpty) return const [];
    final pick = _r(w, a, p, 15);
    final chosen = <Collaborator>[];
    // Writers of the artist's genre pitch to them first.
    final pool = [...writers];
    while (chosen.length < size && pool.isNotEmpty) {
      final weights = [for (final c in pool) c.genre == a.genre ? 3.0 : 1.0];
      final total = weights.fold(0.0, (t, x) => t + x);
      var x = pick.nextDouble() * total;
      var i = 0;
      while (i < pool.length - 1 && (x -= weights[i]) >= 0) {
        i++;
      }
      chosen.add(pool.removeAt(i));
    }
    final start = p * periodWeeks;
    return [
      for (final (i, c) in chosen.indexed)
        () {
          final r = _r(w, a, p, i);
          final demo = (c.skill * 0.9 + 10 + r.nextNormal() * 6)
              .clamp(1.0, 100.0)
              .toDouble();
          return SongPitch(
            index: i,
            writer: c,
            title: Names.song(r),
            genre: r.chance(0.7) ? a.genre : c.genre,
            demo: demo,
            priceCents: priceCents(c),
            takenWeek: start + 1 + r.nextInt(periodWeeks + 3),
          );
        }(),
    ];
  }

  /// A writer's demo, recorded: five of their co-writing fees and a
  /// studio (the best one for the best writers).
  static int priceCents(Collaborator c) =>
      c.feeCents * 5 +
      Actions.budgetCostCents(
          c.skill >= 60 ? BudgetTier.high : BudgetTier.medium);

  /// What the record of [demo] would be with [a]'s voice, before luck.
  static double expected(World w, Artist a, double demo) =>
      Actions.softCeiling(demoWeight * demo +
              (1 - demoWeight) * a.skills.vocals +
              (a.tier == ArtistTier.player ? w.difficulty.qualityBonus : 0))
          .clamp(1.0, 100.0)
          .toDouble();

  static int _key(int period, int index) => period * size + index;

  /// Whether [x] can still be bought this week.
  static bool open(World w, SongPitch x) =>
      !w.boughtPitches.contains(_key(period(w.week), x.index)) &&
      w.week < x.takenWeek;

  /// Buys offer [index] of this month: the song goes to [a]'s vault.
  static Song buy(World w, Artist a, int index) {
    final all = pitches(w, a);
    if (index < 0 || index >= all.length) {
      throw ActionException('No such demo');
    }
    final x = all[index];
    if (!open(w, x)) throw ActionException('Gone');
    if (a.moneyCents < x.priceCents) throw ActionException('Not enough money');
    a.moneyCents -= x.priceCents;
    w.boughtPitches.add(_key(period(w.week), index));

    final r = _r(w, a, period(w.week), 8 + index);
    final quality =
        (expected(w, a, x.demo) + r.nextNormal() * 3).clamp(1.0, 100.0);
    final q01 = quality / 100;
    double mix(double weight, double u) =>
        (weight * q01 + (1 - weight) * u).clamp(0.02, 1.0);
    final commercial = mix(0.55, r.nextDouble());
    final song = Song(
      id: w.songs.length,
      title: x.title,
      genre: x.genre,
      primaryArtistId: a.id,
      writtenWeek: w.week,
      quality: quality,
      commercial: commercial,
      fanAppeal: mix(0.5, r.nextDouble()),
      radioAppeal: (0.5 * commercial +
              0.3 * a.skills.vocals / 100 +
              0.2 * r.nextDouble())
          .clamp(0.02, 1.0),
      virality: (math.pow(r.nextDouble(), 1.6) * (0.5 + 0.5 * q01))
          .toDouble()
          .clamp(0.0, 1.0),
      longevity: mix(0.6, r.nextDouble()),
      estimatedGrade: (quality + r.nextNormal() * 3).round().clamp(1, 100),
    )
      ..gradeSpread = 4
      ..boughtFrom = x.writer.id
      ..productionCostCents = x.priceCents;
    w.songs.add(song);
    w.dirtySongs.add(song.id);
    if (a.id == w.playerArtistId) w.playerSongIds.add(song.id);
    w.dirtyArtists.add(a.id);
    return song;
  }

  /// What a song keeps of its money: a bought one pays its writer.
  static double keep(Song s) => s.boughtFrom >= 0 ? 1 - writerCut : 1.0;
}
