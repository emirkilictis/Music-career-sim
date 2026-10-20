import 'actions.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// How an independent artist gets their music out (docs K157). Index
/// order is stored.
enum Distributor {
  /// On their own (or a flat-fee uploader): every cent theirs.
  selfRelease(share: 1.0, reach: 0, pitch: 1.0, fromYear: 0, minFans: 0),

  /// A distributor taking a cut: more reach and a contact at the playlist
  /// editors.
  percent(share: 0.85, reach: 0.08, pitch: 1.3, fromYear: 2008, minFans: 0),

  /// A distribution deal: an advance, label-size campaigns, a bigger cut.
  deal(share: 0.75, reach: 0.15, pitch: 1.5, fromYear: 2010, minFans: 50000);

  const Distributor(
      {required this.share,
      required this.reach,
      required this.pitch,
      required this.fromYear,
      required this.minFans});

  /// The artist's share of what their music earns.
  final double share;

  /// Reach on top of an independent's.
  final double reach;

  /// How much likelier a playlist pitch lands.
  final double pitch;
  final int fromYear;

  /// Core fans a deal asks for.
  final int minFans;
}

abstract final class Distribution {
  /// The player's reach: their label's, and their distributor's when
  /// independent.
  static double reachOf(Artist a) =>
      a.label.reach +
      (a.label == Label.independent ? a.distributor.reach : 0);

  /// Biggest campaign an independent with [d] can run.
  static Campaign maxCampaign(Artist a) =>
      a.label == Label.independent && a.distributor == Distributor.deal
          ? Campaign.intensive
          : a.label.maxCampaign;

  /// A deal's advance: more for a bigger audience.
  static int advanceCents(Artist a) =>
      (5000000 + a.coreFans * 50).round();

  /// Whether [a] can go with [d] now.
  static bool can(World w, Artist a, Distributor d) =>
      a.label == Label.independent &&
      d != a.distributor &&
      GameTime.yearOf(w.week) >= d.fromYear &&
      a.coreFans >= d.minFans &&
      // A deal's advance is paid back before leaving it.
      (a.distributor != Distributor.deal || a.unrecoupedCents <= 0);

  /// Moves [a] to [d]: its share and reach from now on (songs already
  /// out keep theirs, docs K139); a deal pays its advance now.
  static void choose(World w, Artist a, Distributor d) {
    if (!can(w, a, d)) throw ActionException('Not this distributor');
    a.distributor = d;
    a.artistShare = d.share;
    a.labelReach = reachOf(a);
    if (d == Distributor.deal) {
      final advance = advanceCents(a);
      a.moneyCents += advance;
      a.unrecoupedCents += advance;
    }
    w.dirtyArtists.add(a.id);
  }
}
