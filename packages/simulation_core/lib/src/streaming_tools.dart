import 'dart:math' as math;

import 'actions.dart';
import 'config/charts.dart';
import 'config/regions.dart';
import 'config/sim_config.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// The streaming era's grey tools (docs K95–K97): bought streams that the
/// platform can catch and remove, the autoplay programme that trades
/// royalty for reach, and pitching a song to the playlist editors.
abstract final class StreamingTools {
  /// Weeks the charts count a caught song at half weight.
  static const filterWeeks = 4;

  /// Autoplay programmes start in this year.
  static const autoplayYear = 2016;

  /// A pitch only works for a song out this recently.
  static const pitchWindowWeeks = 12;

  /// The streaming platform is open (bots and pitches need it).
  static bool streamingOpen(World w) =>
      Charts.all[Charts.platformGlobal].activeIn(w.week);

  // ------------------------------------------------------------------ bots

  /// Buys [p]'s streams for [s]: they arrive over four weeks, a quarter
  /// is filtered out on the way, and every week the platform may notice.
  static void buyBots(World w, Artist a, Song s, BotPackage p) {
    if (!streamingOpen(w)) throw ActionException('No streaming yet');
    if (s.releasedWeek < 0) throw ActionException('Not released');
    if (s.botStatus == BotStatus.caught) {
      throw ActionException('Already caught');
    }
    if (s.botWeeksLeft > 0) throw ActionException('Bots already running');
    if (a.tier == ArtistTier.player) {
      if (p.costCents > a.moneyCents) throw ActionException('Not enough money');
      a.moneyCents -= p.costCents;
      s.productionCostCents += p.costCents;
    }
    if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
    s.weeksBelowCutoff = 0;
    s.botTotal = p.streams;
    s.botWeeksLeft = BotPackage.schedule.length;
    s.botStatus = BotStatus.running;
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// This week's bought streams of [s] (all regions; 0 if none).
  static double botStreamsThisWeek(World w, Song s) {
    if (s.botWeeksLeft <= 0) return 0;
    final i = BotPackage.schedule.length - s.botWeeksLeft;
    return s.botTotal * BotPackage.schedule[i] * (1 - w.config.botFiltered);
  }

  /// After a week's listening: bought streams move on, and the platform
  /// may catch them. A big share of fake streams is easy to spot; a few
  /// on a real hit rarely are. Returns whether [s] was caught.
  static bool settleBots(World w, Song s, double delivered) {
    if (s.botWeeksLeft <= 0) return false;
    s.botDelivered += delivered;
    s.botWeeksLeft--;
    w.dirtySongs.add(s.id);
    final organic = math.max(0.0, s.weekStreams - delivered);
    final share = delivered / (organic + delivered + 1);
    final year = GameTime.yearOf(w.week);
    // Platforms are good at this (docs K95, F65): a quarter of the weeks
    // even for a few bot streams on a hit, near certain for a fake hit.
    final chance =
        math.min(0.95, (0.25 + 0.6 * share) * (year >= 2020 ? 1.3 : 1.0));
    final r = RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.bots);
    if (!r.chance(chance)) return false;
    _caught(w, s);
    return true;
  }

  /// The platform removes every bought stream that counted, the charts
  /// filter the song for a while, the artist pays the royalties back and
  /// the story gets out.
  static void _caught(World w, Song s) {
    final a = w.artists[s.primaryArtistId];
    final removed = s.botDelivered;
    for (var k = 0; k < regionCount; k++) {
      final part = removed * a.regionShare[k];
      s.reg[SongReg.lifeStreams + k] =
          math.max(0.0, s.reg[SongReg.lifeStreams + k] - part);
      a.reg[ArtistReg.lifeStreams + k] =
          math.max(0.0, a.reg[ArtistReg.lifeStreams + k] - part);
    }
    if (a.tier == ArtistTier.player) {
      final back = (removed * 0.35 * a.artistShare).round();
      a.moneyCents -= back;
      s.revenueCents -= back;
    }
    s.botWeeksLeft = 0;
    s.botStatus = BotStatus.caught;
    s.chartFilterUntil = w.week + 1 + filterWeeks;
    a.hype = math.max(0.0, a.hype - 0.1);
    a.devotion = math.max(0.0, a.devotion - 0.03);
    a.popularity = math.max(0.0, a.popularity - 0.02);
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// Chart weight of [s] this week (half while filtered).
  static double chartWeight(World w, Song s) =>
      w.week < s.chartFilterUntil ? 0.5 : 1.0;

  // -------------------------------------------------------------- autoplay

  static bool autoplayOpen(World w) => GameTime.yearOf(w.week) >= autoplayYear;

  /// Puts [s] in (or takes it out of) the autoplay programme; an
  /// unreleased song starts in it on release (docs K101).
  static void setAutoplay(World w, Song s, bool on) {
    if (on && !autoplayOpen(w)) throw ActionException('No autoplay yet');
    if (s.status == SongStatus.scrapped) throw ActionException('Scrapped');
    s.autoplay = on;
    if (on && s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
    w.dirtySongs.add(s.id);
  }

  // ------------------------------------------------- the algorithm (K119)

  /// Algorithmic playlists start: personal discovery mixes, then the
  /// weekly radar of new releases from the artists one follows.
  static const discoverYear = 2015, releaseRadarYear = 2016;

  /// Weeks after release a song can be picked for discovery mixes.
  static const discoverFrom = 2, discoverTo = 20;

  /// Share of listeners who skip [s] early: good, catchy songs are
  /// played through (docs K119).
  static double skipRate(Song s) =>
      (0.6 - 0.45 * s.quality / 100 - 0.15 * s.commercial).clamp(0.1, 0.7);

  /// Autoplay's lift for [s] [age] weeks after release: it plays songs
  /// people finish, and less as they get old (docs K96, K119).
  static double autoplayLift(SimConfig c, Song s, int age) =>
      c.autoplayLift *
      (1 - skipRate(s)) /
      0.65 *
      math.max(0.4, math.exp(-math.max(0, age) / 26));

  /// The new-releases radar: followers find a song in its first two weeks.
  static double releaseRadarLift(int year, int age) =>
      year >= releaseRadarYear && age >= 0 && age < 2 ? 0.15 : 0;

  /// Whether the discovery mixes picked [s] in [week]: songs few people
  /// skip, a few weeks out (docs K119).
  static bool discoverPick(World w, Song s, int week) {
    if (GameTime.yearOf(week) < discoverYear || s.releasedWeek < 0) {
      return false;
    }
    final age = week - (s.isSingle ? s.singleWeek : s.releasedWeek);
    if (age < discoverFrom || age > discoverTo) return false;
    final keep = 1 - skipRate(s);
    return keyedUnit(w.seed, week, s.id, RngPurpose.discover) <
        0.03 * keep * keep;
  }

  /// The discovery mixes' lift on [s] in [week]: each pick lasts a few
  /// weeks.
  static double discoverLift(World w, Song s, int week) {
    var lift = 0.0, f = 0.4;
    for (var j = 0; j < 6; j++) {
      if (discoverPick(w, s, week - j)) lift += f;
      f *= 0.7;
    }
    return lift;
  }

  // ----------------------------------------------------------------- pitch

  /// Whether [s] can still be pitched: unreleased (the usual way, docs
  /// K101) or out for up to [pitchWindowWeeks].
  static bool canPitch(World w, Song s) =>
      streamingOpen(w) &&
      s.status != SongStatus.scrapped &&
      s.pitchWeek < 0 &&
      s.playlistBoost < 0.05 &&
      (s.releasedWeek < 0 ||
          w.week - math.max(s.releasedWeek, s.singleWeek) <= pitchWindowWeeks);

  /// The week the editors answer [s]'s pitch: the pitch week, or the
  /// release week for a song pitched before it came out (-1: not yet).
  static int pitchAnswerWeek(Song s) => s.pitchWeek < 0 || s.releasedWeek < 0
      ? -1
      : math.max(s.pitchWeek, s.releasedWeek);

  /// Pitches [s] to the editors; they answer at the end of the week (or
  /// the week it comes out).
  static void pitch(World w, Song s) {
    if (!canPitch(w, s)) throw ActionException('Cannot pitch');
    s.pitchWeek = w.week;
    w.dirtySongs.add(s.id);
  }

  /// The editors' answer: good songs by known artists in the playlist era
  /// get in more often; a big list now and then.
  static double pitchChance(World w, Song s) {
    final a = w.artists[s.primaryArtistId];
    final pl = w.config.playlistShare(GameTime.yearOf(w.week));
    final q01 = s.quality / 100;
    return ((0.25 + 0.5 * q01 * q01) *
            (0.7 + 0.3 * a.fame) *
            (0.5 + 0.5 * math.min(1.0, pl / 0.3)))
        .clamp(0.0, 0.8);
  }

  /// Answers this week's pitches (before the week is played, so a song
  /// that got in is heard this week).
  static void answerPitches(World w) {
    final p = w.player;
    if (p == null) return;
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (pitchAnswerWeek(s) != w.week) continue;
      // The campaign already landed it on a list this week.
      if (s.playlistWeek == w.week) continue;
      final r = RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.pitch);
      if (!r.chance(pitchChance(w, s))) continue;
      final big = r.chance(0.15 + 0.35 * s.quality / 100);
      if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
      s.weeksBelowCutoff = 0;
      s.playlistAdd = big ? PlaylistAdd.big : PlaylistAdd.mid;
      s.playlistWeek = w.week;
      s.playlistBoost =
          big ? w.config.playlistBigBoost : w.config.playlistMidBoost;
      w.dirtySongs.add(s.id);
    }
  }

  // ------------------------------------------------------------------- AI

  /// A star's lead single: fans throw streaming parties, and now and then
  /// the team buys streams too (and may get caught).
  static void starRelease(World w, Artist a, Song s) {
    if (!streamingOpen(w)) return;
    s.versionBoost += 0.15 * a.devotion;
    final r = RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.bots + 1);
    if (GameTime.yearOf(w.week) >= 2012 && r.chance(0.12)) {
      buyBots(w, a, s, r.chance(0.5) ? BotPackage.medium : BotPackage.large);
    }
  }
}
