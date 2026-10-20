import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'config/regions.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// An artist on the player's label and what they have brought in.
class Signing {
  Signing(
      {required this.artistId,
      required this.signedWeek,
      required this.advanceCents,
      this.earnedCents = 0});
  final int artistId;
  final int signedWeek;
  final int advanceCents;
  double earnedCents;

  List<Object> toJson() => [artistId, signedWeek, advanceCents, earnedCents];
  static Signing fromJson(List<dynamic> j) => Signing(
      artistId: j[0] as int,
      signedWeek: j[1] as int,
      advanceCents: j[2] as int,
      earnedCents: (j[3] as num).toDouble());
}

/// The player's own label (docs K169).
class Imprint {
  Imprint({required this.name, required this.foundedWeek});
  String name;
  final int foundedWeek;
  final List<Signing> roster = [];

  String encode() => jsonEncode(
      [name, foundedWeek, for (final s in roster) s.toJson()]);

  static Imprint? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    final j = jsonDecode(s) as List;
    final i = Imprint(name: j[0] as String, foundedWeek: j[1] as int);
    for (final x in j.skip(2)) {
      i.roster.add(Signing.fromJson(x as List));
    }
    return i;
  }
}

/// The player's own label (docs K169), the Roc-A-Fella / Dreamville move:
/// a star founds an imprint and signs newcomers. Their records come out
/// under their own names on their own plans; the imprint takes a share of
/// what they put out after signing and its push takes them further.
abstract final class Imprints {
  /// What it takes to found one: a name the business knows, and money.
  static const minFame = 0.4;
  static const foundCents = 100000000;

  static const maxRoster = 5;

  /// Weeks until a new signing starts their first era on the label.
  static const firstReleaseWeeks = 6;

  /// The imprint's share of a signee's record money.
  static const share = 0.25;

  /// How much further a signee's music travels with the imprint's push.
  static const reachBoost = 1.15;

  /// Newcomers worth signing: out at most this many years, not famous yet.
  static const newcomerYears = 4;
  static const maxSigneeFame = 0.35;

  static bool canFound(World w, Artist a) =>
      w.imprint == null && a.fame >= minFame;

  static Imprint found(World w, Artist a, String name) {
    if (w.imprint != null) throw ActionException('Already founded');
    if (a.fame < minFame) throw ActionException('Not known enough');
    final n = name.trim();
    if (n.isEmpty) throw ActionException('Name it');
    if (a.moneyCents < foundCents) throw ActionException('Not enough money');
    a.moneyCents -= foundCents;
    w.dirtyArtists.add(a.id);
    return w.imprint = Imprint(name: n, foundedWeek: w.week);
  }

  /// The artist ids on the roster.
  static Set<int> signedIds(World w) =>
      {for (final s in w.imprint?.roster ?? const <Signing>[]) s.artistId};

  /// What signing [r] costs: an advance growing with their name.
  static int advanceCents(Artist r) =>
      (2000000 + 120000000 * r.fame + r.coreFans * 40).round();

  /// Newcomers [a]'s imprint could sign now, most promising first.
  static List<Artist> candidates(World w, Artist a) {
    final signed = signedIds(w);
    final out = [
      for (final id in w.activeArtistIds)
        if (_signable(w, w.artists[id], a, signed)) w.artists[id]
    ]..sort((x, y) {
        final f = y.fame.compareTo(x.fame);
        return f != 0 ? f : x.id.compareTo(y.id);
      });
    return out.take(15).toList();
  }

  static bool _signable(World w, Artist r, Artist a, Set<int> signed) =>
      r.id != a.id &&
      r.tier != ArtistTier.player &&
      r.managedBy < 0 &&
      !r.isRetired &&
      !signed.contains(r.id) &&
      r.fame <= maxSigneeFame &&
      w.week - r.debutWeek <= newcomerYears * GameTime.weeksPerYear;

  static Signing sign(World w, Artist a, Artist r) {
    final i = w.imprint;
    if (i == null) throw ActionException('No label');
    if (i.roster.length >= maxRoster) throw ActionException('Roster full');
    if (!_signable(w, r, a, signedIds(w))) throw ActionException('Not signable');
    final cost = advanceCents(r);
    if (a.moneyCents < cost) throw ActionException('Not enough money');
    a.moneyCents -= cost;
    w.dirtyArtists.add(a.id);
    final s = Signing(artistId: r.id, signedWeek: w.week, advanceCents: cost);
    i.roster.add(s);
    // A new signing gets a record out soon.
    r.nextEraWeek = math.min(r.nextEraWeek, w.week + firstReleaseWeeks);
    w.dirtyArtists.add(r.id);
    return s;
  }

  static void drop(World w, int artistId) {
    final i = w.imprint;
    if (i == null) throw ActionException('No label');
    final before = i.roster.length;
    i.roster.removeWhere((s) => s.artistId == artistId);
    if (i.roster.length == before) throw ActionException('Not signed');
  }

  /// Record money of [s] this week before anyone's share.
  static double songWeekCents(World w, Song s) {
    if (s.status == SongStatus.active) {
      return s.weekStreams * 0.35 + s.weekDownloads * 70 + s.weekPhysical * 100;
    }
    if (s.status != SongStatus.dormant) return 0;
    var cents = 0.0;
    for (var r = 0; r < regionCount; r++) {
      cents += w.songWeekStreamsRegion(s, r) * 0.35;
    }
    return cents;
  }

  /// The imprint's money this week from every signee: their songs and
  /// their albums' copies. Returns the total.
  static double weekly(World w) {
    final i = w.imprint;
    if (i == null || i.roster.isEmpty) return 0;
    final bySigned = {for (final s in i.roster) s.artistId: s};
    var total = 0.0;
    for (final id in w.activeSongIds) {
      final s = w.songs[id];
      final signing = bySigned[s.primaryArtistId];
      // Only what came out on the label is the label's.
      if (signing == null || s.releasedWeek < signing.signedWeek) continue;
      final cut = songWeekCents(w, s) * share;
      signing.earnedCents += cut;
      total += cut;
    }
    for (final signing in i.roster) {
      final r = w.artists[signing.artistId];
      for (final id in r.dormantSongIds) {
        if (w.songs[id].releasedWeek < signing.signedWeek) continue;
        final cut = songWeekCents(w, w.songs[id]) * share;
        signing.earnedCents += cut;
        total += cut;
      }
    }
    for (final id in w.activeAlbumIds) {
      final al = w.albums[id];
      final signing = bySigned[al.artistId];
      if (signing == null || al.releaseWeek < signing.signedWeek) continue;
      final cut = al.weekPure * 600 * share;
      signing.earnedCents += cut;
      total += cut;
    }
    return total;
  }

  /// Reach multiplier for artist [id] this week (1: not signed).
  static double reach(Set<int> signed, int id) =>
      signed.contains(id) ? reachBoost : 1.0;

  /// Signees' best US songs chart place over the roster (0: none yet).
  static int bestPeak(World w, Signing s, int chart) {
    var best = 0;
    for (final song in w.songs) {
      if (song.primaryArtistId != s.artistId ||
          song.releasedWeek < s.signedWeek) {
        continue;
      }
      final p = song.statsOrNull(chart)?.peak ?? 0;
      if (p > 0 && (best == 0 || p < best)) best = p;
    }
    return math.max(0, best);
  }
}
