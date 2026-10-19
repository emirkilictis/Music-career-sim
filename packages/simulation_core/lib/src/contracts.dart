import 'model.dart';
import 'world.dart';

/// How a record deal is shaped (docs K107). Index order is stored.
enum ContractDeal {
  /// The label's usual terms.
  standard,

  /// More money now, a smaller split and one more album owed.
  bigAdvance,

  /// A bigger split for a small advance.
  betterSplit,
}

/// What a deal gives and asks.
class ContractTerms {
  const ContractTerms(
      {required this.advanceCents,
      required this.artistShare,
      required this.albums});

  /// Paid on signing and paid back from the artist's royalties.
  final int advanceCents;

  /// The artist's share of the money from sales and streams.
  final double artistShare;

  /// Albums owed before the artist is free to leave.
  final int albums;
}

abstract final class Contracts {
  /// How much a label wants the artist (docs K107): 0 at what it asks
  /// for, 1 at four times as many fans. Proven artists get bigger
  /// advances and better splits.
  static double leverage(World w, Artist a, Label l) {
    if (l == Label.independent) return 0;
    final ask = l.minFans > 0 ? l.minFans.toDouble() : 50000.0;
    return ((a.coreFans / ask - 1) / 3).clamp(0.0, 1.0);
  }

  /// The terms of [deal] with [l] for [a].
  static ContractTerms terms(World w, Artist a, Label l, ContractDeal deal) {
    if (l == Label.independent) {
      return ContractTerms(
          advanceCents: 0, artistShare: l.artistShare, albums: 0);
    }
    final lev = leverage(w, a, l);
    final advance = l.advanceCents * (1 + lev);
    return switch (deal) {
      ContractDeal.standard => ContractTerms(
          advanceCents: advance.round(),
          artistShare: l.artistShare + 0.04 * lev,
          albums: l.contractAlbums),
      ContractDeal.bigAdvance => ContractTerms(
          advanceCents: (advance * 2).round(),
          artistShare: l.artistShare - 0.08 + 0.04 * lev,
          albums: l.contractAlbums + 1),
      ContractDeal.betterSplit => ContractTerms(
          advanceCents: (advance * 0.35).round(),
          artistShare: l.artistShare + 0.1 + 0.06 * lev,
          albums: l.contractAlbums),
    };
  }

  /// Royalties [cents] (the artist's share) after paying back what is
  /// left of the advance.
  static double recoup(Artist a, double cents) {
    if (a.unrecoupedCents <= 0 || cents <= 0) return cents;
    final take = cents < a.unrecoupedCents ? cents : a.unrecoupedCents * 1.0;
    a.unrecoupedCents -= take.round();
    if (a.unrecoupedCents < 0) a.unrecoupedCents = 0;
    return cents - take;
  }
}
