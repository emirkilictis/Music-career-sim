import 'dart:math' as math;

import 'lifecycle.dart';
import 'model.dart';
import 'rng.dart';
import 'names.dart';
import 'time.dart';
import 'world.dart';

class ActionException implements Exception {
  ActionException(this.message);
  final String message;
  @override
  String toString() => 'ActionException: $message';
}

class SongwritingException implements Exception {
  SongwritingException(this.message);
  final String message;
  @override
  String toString() => 'SongwritingException: $message';
}

/// Player and AI actions. The same API will back the app UI.
/// Rules: docs/game-design.md §4 (songwriting) and §5 (eras).
abstract final class Actions {
  static const energyCostPerSong = 20.0;
  static const maxSongsPerWeek = 3;
  static const burnoutWeeks = 3;
  static const inspirationChance = 0.04;
  static const inspirationBonus = 20.0;

  // Side income (docs/game-design.md §20.1).
  /// Weekly wage of the day job. The job only pays: it costs no energy,
  /// songwriting slots or anything else.
  static const jobWageCents = 35000;
  static const adRewardCents = 25000;
  static const maxAdsPerWeek = 3;

  /// Premium daily login bonus. Eligibility (Premium, once per calendar day)
  /// is decided by the app, outside the deterministic simulation.
  static const dailyBonusCents = 500000;

  /// Takes or quits the day job; the wage is paid at the end of each week.
  static void setJob(World w, Artist a, bool on) => a.hasJob = on;

  static int adsLeftThisWeek(World w, Artist a) =>
      maxAdsPerWeek - (a.lastAdWeek == w.week ? a.adsWatchedThisWeek : 0);

  /// Pays the reward for a watched (opt-in) rewarded ad; the app calls this
  /// after the ad finished. Always available, at most [maxAdsPerWeek] a week.
  static void claimAdReward(World w, Artist a) {
    if (adsLeftThisWeek(w, a) <= 0) {
      throw ActionException('Ad limit reached for this week');
    }
    if (a.lastAdWeek != w.week) {
      a.lastAdWeek = w.week;
      a.adsWatchedThisWeek = 0;
    }
    a.adsWatchedThisWeek++;
    a.moneyCents += adRewardCents;
  }

  /// Credits the Premium daily login bonus to the career being played.
  static void grantDailyBonus(World w, Artist a) =>
      a.moneyCents += dailyBonusCents;

  static int budgetCostCents(BudgetTier b) => switch (b) {
        BudgetTier.low => 30000,
        BudgetTier.medium => 300000,
        BudgetTier.high => 1500000,
      };

  static double budgetBonus(BudgetTier b) => switch (b) {
        BudgetTier.low => 0,
        BudgetTier.medium => 3,
        BudgetTier.high => 6,
      };

  static bool canWrite(World w, Artist a) {
    if (w.week < a.burnoutUntilWeek) return false;
    final writtenThisWeek =
        a.lastWriteWeek == w.week ? a.songsWrittenThisWeek : 0;
    return writtenThisWeek < maxSongsPerWeek;
  }

  /// Writes and records a song into the artist's vault.
  ///
  /// [producerSkill] lets AI artists use an implicit label producer instead of
  /// a hired [producer]. AI artists pass [aiMode] to skip money and energy.
  static Song writeSong(
    World w,
    Artist a, {
    Collaborator? producer,
    Collaborator? cowriter,
    BudgetTier budget = BudgetTier.medium,
    double? producerSkill,
    List<int> featured = const [],
    bool aiMode = false,
    String? title,
  }) {
    if (!aiMode && !canWrite(w, a)) {
      throw SongwritingException(w.week < a.burnoutUntilWeek
          ? 'Burnout: cannot write until week ${a.burnoutUntilWeek}'
          : 'Weekly songwriting limit reached');
    }
    if (a.lastWriteWeek != w.week) {
      a.lastWriteWeek = w.week;
      a.songsWrittenThisWeek = 0;
    }
    final index = a.songsWrittenThisWeek++;

    if (!aiMode) {
      for (final c in [producer, cowriter]) {
        if (c != null && c.minFame > a.fame) {
          throw SongwritingException('${c.name} needs more fame');
        }
      }
      final cost = budgetCostCents(budget) +
          (producer?.feeCents ?? 0) +
          (cowriter?.feeCents ?? 0);
      if (cost > a.moneyCents) throw SongwritingException('Not enough money');
      a.moneyCents -= cost;
    }

    final r = RandomStream.keyed(
        w.seed, w.week, a.id * 64 + index, RngPurpose.songQuality);

    // Skill component.
    final own = a.skills.songwriting;
    final co = cowriter?.skill;
    final writing =
        co == null ? own : 0.6 * math.max(own, co) + 0.4 * math.min(own, co);
    final prod = producer?.skill ?? producerSkill ?? a.skills.production * 0.8;
    final wq = a.kind.qualityWeights;
    final skill = wq.writing * writing +
        wq.production * prod +
        wq.vocals * a.skills.vocals +
        wq.perf * a.skills.performance;

    final genreFit =
        (producer != null && producer.genre == a.genre) ? 3.0 : 0.0;
    final luck = r.nextNormal() * 8.0;
    final inspired = r.chance(inspirationChance);
    final energyBefore = a.creativeEnergy;
    final energyPenalty =
        (!aiMode && energyBefore < 30) ? (30 - energyBefore) * 0.5 : 0.0;

    final raw = skill +
        (a.tier == ArtistTier.player ? w.difficulty.qualityBonus : 0) +
        budgetBonus(budget) +
        genreFit +
        luck +
        (inspired ? inspirationBonus : 0) -
        energyPenalty;
    // Soft ceiling: 100 stays rare even for top artists.
    final quality =
        (raw <= 85 ? raw : 85 + 15 * (1 - math.exp(-(raw - 85) / 15)))
            .clamp(1.0, 100.0);

    // Traits: partly tied to quality, partly random → different kinds of hits.
    final t = RandomStream.keyed(
        w.seed, w.week, a.id * 64 + index, RngPurpose.songTraits);
    final q01 = quality / 100.0;
    double mix(double weight, double u) =>
        (weight * q01 + (1 - weight) * u).clamp(0.02, 1.0);
    final commercial = mix(0.55, t.nextDouble());
    final fanAppeal = mix(0.5, t.nextDouble());
    final radioAppeal =
        (0.5 * commercial + 0.3 * a.skills.vocals / 100 + 0.2 * t.nextDouble())
            .clamp(0.02, 1.0);
    final virality = (math.pow(t.nextDouble(), 1.6) * (0.5 + 0.5 * q01))
        .toDouble()
        .clamp(0.0, 1.0);
    final longevity = mix(0.6, t.nextDouble());

    // The team's estimate: better producers estimate better.
    final estimateNoise = 14.0 - prod / 10.0;
    final grade =
        (quality + r.nextNormal() * estimateNoise).round().clamp(1, 100);

    final song = Song(
      id: w.songs.length,
      title: title ??
          Names.song(RandomStream.keyed(
              w.seed, w.week, a.id * 64 + index, RngPurpose.names)),
      genre: a.genre,
      primaryArtistId: a.id,
      featuredArtistIds: List.of(featured),
      writtenWeek: w.week,
      quality: quality,
      commercial: commercial,
      fanAppeal: fanAppeal,
      radioAppeal: radioAppeal,
      virality: virality,
      longevity: longevity,
      estimatedGrade: grade,
    );
    w.songs.add(song);
    w.dirtySongs.add(song.id);
    if (a.id == w.playerArtistId) w.playerSongIds.add(song.id);

    if (!aiMode) {
      a.creativeEnergy = math.max(0, a.creativeEnergy - energyCostPerSong);
      if (a.creativeEnergy <= 0) a.burnoutUntilWeek = w.week + burnoutWeeks;
      _grow(a,
          songwriting: 0.6,
          vocals: 0.15,
          production: producer == null ? 0.35 : 0.1);
    }
    return song;
  }

  static void _grow(Artist a,
      {double songwriting = 0, double vocals = 0, double production = 0}) {
    final s = a.skills;
    s.songwriting += songwriting * (1 - s.songwriting / 100);
    s.vocals += vocals * (1 - s.vocals / 100);
    s.production += production * (1 - s.production / 100);
  }

  /// Pays the player's campaign up front (AI labels run theirs implicitly).
  static void _payCampaign(Artist a, Campaign campaign) {
    if (a.tier != ArtistTier.player) return;
    if (campaign.costCents > a.moneyCents) {
      throw ActionException('Not enough money for the campaign');
    }
    a.moneyCents -= campaign.costCents;
  }

  /// Applies the campaign to a song and rolls for an editorial playlist add
  /// (only meaningful in the playlist era).
  static void _promote(World w, Song s, Campaign campaign) {
    s.campaign = campaign;
    w.dirtySongs.add(s.id);
    final pl = w.config.playlistShare(GameTime.yearOf(w.week));
    final r = RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.playlist);
    final q01 = s.quality / 100;
    final chance = campaign.playlistOdds *
        pl *
        (0.3 + 0.7 * q01) *
        (s.isSingle ? 1.0 : 0.35);
    if (!r.chance(chance)) return;
    final big = r.chance(0.2 + 0.4 * q01);
    s.playlistAdd = big ? PlaylistAdd.big : PlaylistAdd.mid;
    s.playlistWeek = w.week;
    s.playlistBoost =
        big ? w.config.playlistBigBoost : w.config.playlistMidBoost;
  }

  /// Releases a vault song as a single, or promotes an album track to single.
  static void releaseSingle(World w, Artist a, Song s,
      {Campaign campaign = Campaign.standard}) {
    _payCampaign(a, campaign);
    _convertAnticipation(a);
    s.isSingle = true;
    s.singleWeek = w.week;
    if (s.status == SongStatus.vault) {
      s.releasedWeek = w.week;
      Lifecycle.activateSong(w, s);
    } else if (s.status == SongStatus.dormant) {
      Lifecycle.reactivateSong(w, s);
    }
    _promote(w, s, campaign);
    a.lastReleaseWeek = w.week;
  }

  /// Releases an album/EP. Songs not yet released become album tracks;
  /// previously released singles are attached to the album.
  /// Manufacturing/setup cost per extra variant for the player.
  static const variantCostCents = 4000000;

  static Album releaseAlbum(World w, Artist a, String title, List<int> songIds,
      {AlbumType type = AlbumType.album,
      List<int> variantWeeks = const [0],
      bool payForVariants = false,
      Campaign campaign = Campaign.standard}) {
    _payCampaign(a, campaign);
    _convertAnticipation(a);
    final quality = songIds.isEmpty
        ? 0.0
        : songIds.map((id) => w.songs[id].quality).reduce((x, y) => x + y) /
            songIds.length;
    final album = Album(
      id: w.albums.length,
      title: title,
      artistId: a.id,
      type: type,
      releaseWeek: w.week,
      songIds: List.of(songIds),
      quality: quality,
    );
    album.hypeAtRelease = a.hype;
    album.campaign = campaign;
    album.variantWeeks = (List.of(variantWeeks)..sort());
    w.dirtyAlbums.add(album.id);
    if (payForVariants && variantWeeks.length > 1) {
      a.moneyCents -= variantCostCents * (variantWeeks.length - 1);
    }
    w.albums.add(album);
    for (final id in songIds) {
      final s = w.songs[id];
      s.albumId = album.id;
      w.dirtySongs.add(s.id);
      if (s.status == SongStatus.vault) {
        s.releasedWeek = w.week;
        Lifecycle.activateSong(w, s);
        // Earlier singles keep their own campaign; new tracks get the album's.
        _promote(w, s, campaign);
      } else if (s.status == SongStatus.dormant) {
        Lifecycle.reactivateSong(w, s);
      }
    }
    World.insertSorted(w.activeAlbumIds, album.id);
    a.lastReleaseWeek = w.week;
    if (type == AlbumType.album) Eras.open(w, a, album);
    return album;
  }

  /// First release after a closed era turns stored anticipation into hype.
  static void _convertAnticipation(Artist a) {
    if (!a.eraOpen && a.anticipation > 0) {
      a.hype += a.anticipation;
      a.anticipation = 0;
      a.anticipationCap = 0;
    }
  }
}

/// Era scoring and anticipation (docs/game-design.md §5–§6).
abstract final class Eras {
  static void open(World w, Artist a, Album album) {
    if (a.eraOpen) close(w, a);
    final eras = w.regionalEra.forWeek(w.week);
    final c = w.config;
    // Expectations rise with the fanbase's devotion, so a devoted fanbase
    // has to deliver more to count as a success.
    var baseline = 2000.0;
    for (var k = 0; k < eras.length; k++) {
      final share = a.regionShare[k];
      baseline += a.coreFans *
              share *
              c.superfanBuyRate *
              math.sqrt(a.devotionBuyFactor) *
              eras[k].superfanFactor *
              2.2 +
          a.casual * share * c.casualBuyRate * eras[k].casualPurchaseRate * 2.0;
    }
    a.eraOpen = true;
    a.eraAlbumId = album.id;
    a.eraStartWeek = w.week;
    a.eraUnits = 0;
    a.eraExpected =
        a.lastEraUnits > 0 ? 0.55 * a.lastEraUnits + 0.45 * baseline : baseline;
    a.anticipation = 0;
    a.anticipationCap = 0;
    a.flopSupport = 0;
  }

  static EraResult resultFor(double score) {
    if (score < 0.5) return EraResult.flop;
    if (score < 0.85) return EraResult.disappointing;
    if (score < 1.15) return EraResult.normal;
    if (score <= 2.0) return EraResult.success;
    return EraResult.smash;
  }

  static void close(World w, Artist a) {
    if (!a.eraOpen) return;
    final score = a.eraUnits / math.max(a.eraExpected, 1.0);
    final result = resultFor(score);
    a.eraOpen = false;
    a.lastEraUnits = a.eraUnits;
    a.lastEraResult = result;
    final c = w.config;
    switch (result) {
      case EraResult.flop:
        a.anticipationCap = 0;
        a.anticipation = 0;
        a.flopSupport = 1.0;
        a.devotion -= 0.12;
      case EraResult.disappointing:
        a.anticipationCap = c.anticipationCapBase * 0.08 * (0.5 + a.fame);
        a.devotion -= 0.05;
      case EraResult.normal || EraResult.success || EraResult.smash:
        final g = 0.2 +
            0.8 * ((score - 0.85) / 1.15).clamp(0.0, 1.0) +
            (score > 2.0 ? 0.5 * math.min(score - 2.0, 1.0) : 0.0);
        a.anticipationCap = c.anticipationCapBase * g * (0.5 + a.fame);
        a.devotion += (1 - a.devotion) *
            a.kind.devotionGain *
            switch (result) {
              EraResult.smash => 0.25,
              EraResult.success => 0.12,
              _ => 0.03,
            };
    }
    a.devotion = a.devotion.clamp(0.0, 1.0);
  }
}
