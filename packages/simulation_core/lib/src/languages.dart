import 'dart:math' as math;

import 'actions.dart';
import 'config/regions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// A version of a released song in another language (docs K155): the
/// Despacito and Dynamite moves. It brings the song a wave of listening
/// and opens a market for the artist for good.
enum LanguageVersion {
  /// For Latin America and beyond (the rest of the world).
  spanish(Region.other),

  /// For North America, from an artist from elsewhere.
  english(Region.northAmerica);

  const LanguageVersion(this.market);

  /// The market it opens.
  final Region market;
}

abstract final class Languages {
  static const costCents = 5000000;
  static const energy = 4.0;

  /// The wave it brings the song (a remix brings 0.35).
  static const boost = 0.15;

  /// How much more of the artist's audience a version brings from its
  /// market, and the most versions can bring.
  static const marketStep = 0.06;
  static const marketCap = 0.4;

  /// Whether [a] can put out [s] in [v] now: a released song, once per
  /// language, for a market that is not home.
  static bool can(World w, Artist a, Song s, LanguageVersion v) =>
      open(w) &&
      s.primaryArtistId == a.id &&
      s.releasedWeek >= 0 &&
      s.status != SongStatus.scrapped &&
      s.languages & (1 << v.index) == 0 &&
      a.homeCountry.region != v.market;

  static void release(World w, Artist a, Song s, LanguageVersion v) {
    if (!can(w, a, s, v)) throw ActionException('Not this version');
    if (a.moneyCents < costCents) throw ActionException('Not enough money');
    if (a.creativeEnergy < energy) {
      throw ActionException('Not enough creativity');
    }
    a.moneyCents -= costCents;
    a.creativeEnergy -= energy;
    s.productionCostCents += costCents;
    s.languages |= 1 << v.index;
    if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
    s.weeksBelowCutoff = 0;
    // Each version in the same couple of months brings less (K92).
    final recent = s.versions.where((x) => w.week - x.$2 < 8).length;
    s.versionBoost += boost * math.pow(0.7, recent);
    final m = v.market.index;
    a.marketBonus[m] = math.min(marketCap, a.marketBonus[m] + marketStep);
    a.updateRegionShare();
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// Whether the year has the version at all (the video site era).
  static bool open(World w) => GameTime.yearOf(w.week) >= 2005;
}
