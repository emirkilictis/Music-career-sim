import 'dart:math' as math;

import 'actions.dart';
import 'config/charts.dart';
import 'config/era_table.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// Why a greatest hits album cannot be made now.
enum CompilationBlock { tooEarly, tooSoon, fewSongs }

/// Greatest hits (docs K161): a best-of of the artist's released songs
/// with one to three new ones on top. Fans have the old songs already;
/// people who know the hits from the radio buy it, for years, most of all
/// when records sell (the CD era's biggest sellers were best-ofs). Its
/// own streams are the new songs': listening to the old ones stays with
/// their albums.
abstract final class Compilations {
  /// Years since the debut before a best-of, and between two.
  static const minYears = 5, gapYears = 5;

  static const minHits = 8, maxHits = 20;
  static const minNew = 1, maxNew = 3;

  /// Weekly buyers among people who know the artist, at full hit power.
  static const hitsRate = 0.03;

  /// Later weeks sell this share of the first, halving over a year more.
  static const tailShare = 0.15, tailWeeks = 52.0;

  /// Fans and event buyers have the songs: this share of them buys.
  static const fanShare = 0.3;

  /// Hit power is capped here (about eight top-10 hits' worth).
  static const maxPower = 2.0;

  static bool isCompilation(Album al) => al.hitIds.isNotEmpty;

  /// Songs [a] could put on a best-of: their released studio songs.
  static List<Song> candidates(World w, Artist a) => [
        for (final id in w.playerSongIds)
          if (_eligible(w.songs[id], a)) w.songs[id]
      ];

  static bool _eligible(Song s, Artist a) =>
      s.primaryArtistId == a.id &&
      s.releasedWeek >= 0 &&
      s.status != SongStatus.scrapped &&
      !s.cloudOnly &&
      s.liveOf < 0 &&
      s.replacedWeek < 0;

  /// What stops [a] making a best-of now (null: nothing).
  static CompilationBlock? block(World w, Artist a) {
    if (w.week - a.debutWeek < minYears * GameTime.weeksPerYear) {
      return CompilationBlock.tooEarly;
    }
    for (final al in w.albums) {
      if (al.artistId == a.id &&
          isCompilation(al) &&
          w.week - al.releaseWeek < gapYears * GameTime.weeksPerYear) {
        return CompilationBlock.tooSoon;
      }
    }
    if (candidates(w, a).length < minHits) return CompilationBlock.fewSongs;
    return null;
  }

  /// A song's best place on any songs chart (0: never charted).
  static int bestPeak(Song s) {
    var best = 0;
    for (var c = 0; c < Charts.count; c++) {
      if (Charts.all[c].kind != ChartKind.songs) continue;
      final p = s.statsOrNull(c)?.peak ?? 0;
      if (p > 0 && (best == 0 || p < best)) best = p;
    }
    return best;
  }

  /// What a song brings a best-of: its best place on the songs charts.
  static double hitWeight(Song s) {
    final peak = bestPeak(s);
    if (peak <= 0) return 0.03;
    if (peak == 1) return 1.0;
    if (peak <= 10) return 0.6;
    if (peak <= 40) return 0.3;
    return 0.1;
  }

  /// The best-of's pull (0..[maxPower]).
  static double power(World w, Iterable<int> hitIds) {
    var sum = 0.0;
    for (final id in hitIds) {
      sum += hitWeight(w.songs[id]);
    }
    return math.min(maxPower, sum / 4);
  }

  /// Copies of [al] sold this week in a region with [casual] listeners
  /// of the artist, [age] weeks after release.
  static double sales(World w, Album al, double casual, EraValues era,
      int age, double holiday) {
    if (!isCompilation(al)) return 0;
    final later = age == 0 ? 1.0 : tailShare / (1 + age / tailWeeks);
    return casual *
        hitsRate *
        era.casualPurchaseRate *
        power(w, al.hitIds) *
        holiday *
        later;
  }

  /// Puts out [title]: released [hitIds] with unreleased [newIds] as its
  /// new songs.
  static Album release(World w, Artist a, String title, List<int> hitIds,
      List<int> newIds,
      {Campaign campaign = Campaign.standard}) {
    if (block(w, a) case final b?) throw ActionException('Blocked: $b');
    if (hitIds.length < minHits || hitIds.length > maxHits) {
      throw ActionException('$minHits–$maxHits hits');
    }
    if (newIds.length < minNew || newIds.length > maxNew) {
      throw ActionException('$minNew–$maxNew new songs');
    }
    if ({...hitIds, ...newIds}.length != hitIds.length + newIds.length) {
      throw ActionException('Twice');
    }
    for (final id in hitIds) {
      if (!_eligible(w.songs[id], a)) throw ActionException('Not a hit');
    }
    for (final id in newIds) {
      final s = w.songs[id];
      if (s.primaryArtistId != a.id || s.status != SongStatus.vault) {
        throw ActionException('Only unreleased songs');
      }
    }
    return Actions.releaseAlbum(w, a, title, newIds,
        campaign: campaign, announced: true, hits: hitIds);
  }
}
