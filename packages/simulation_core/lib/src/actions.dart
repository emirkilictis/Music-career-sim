import 'dart:math' as math;

import 'album_versions.dart';
import 'anniversaries.dart';
import 'artist_pick.dart';
import 'audience.dart';
import 'beefs.dart';
import 'bundles.dart';
import 'cloud.dart';
import 'config/charts.dart';
import 'config/difficulty.dart';
import 'config/regions.dart';
import 'contracts.dart';
import 'critics.dart';
import 'distribution.dart';
import 'fan_club.dart';
import 'holidays.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'names.dart';
import 'rng.dart';
import 'rollouts.dart';
import 'stream_windows.dart';
import 'streaming_tools.dart';
import 'time.dart';
import 'tours.dart';
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
  static const burnoutWeeks = 3;
  static const inspirationChance = 0.04;
  static const inspirationBonus = 20.0;

  // Side income (docs/game-design.md §20.1, K36).
  static const adRewardCents = 25000;
  static const maxAdsPerWeek = 3;

  /// Premium daily login bonus. Eligibility (Premium, once per calendar day)
  /// is decided by the app, outside the deterministic simulation.
  static const dailyBonusCents = 500000;

  /// Takes a day job (or [Job.none] to quit); the wage is paid and its
  /// energy cost taken at the end of each week.
  static void setJob(World w, Artist a, Job job) => a.job = job;

  /// Skill points the player earns each week, and the skill ceiling.
  static const skillPointsPerWeek = 3;
  static const maxSkill = 100.0;

  /// Spends one skill point: +1 on [kind], up to [maxSkill].
  static void spendSkillPoint(Artist a, SkillKind kind) {
    if (a.skillPoints <= 0) throw ActionException('No skill points');
    if (a.skills[kind] >= maxSkill) throw ActionException('Skill is maxed');
    spendSkillPoints(a, kind, 1);
  }

  /// Points still useful for [kind]: what it lacks to [maxSkill].
  static int skillRoomFor(Artist a, SkillKind kind) =>
      math.max(0, (maxSkill - a.skills[kind]).ceil());

  /// Points the artist could still use on all skills (docs F34).
  static int skillRoom(Artist a) =>
      SkillKind.values.fold(0, (t, k) => t + skillRoomFor(a, k));

  /// Adds earned points, never more than the skills can still use: once
  /// every skill is at [maxSkill] points stop piling up (docs F34).
  static void grantSkillPoints(Artist a, int points) {
    a.skillPoints = math.min(a.skillPoints + points, skillRoom(a));
  }

  /// Spends up to [count] points on [kind]; returns how many were spent.
  static int spendSkillPoints(Artist a, SkillKind kind, int count) {
    final n = math.min(count, math.min(a.skillPoints, skillRoomFor(a, kind)));
    if (n <= 0) return 0;
    a.skills[kind] = math.min(maxSkill, a.skills[kind] + n);
    a.skillPoints -= n;
    return n;
  }

  /// Spends every point, always on the lowest skill (docs F34).
  static int spreadSkillPoints(Artist a) {
    var spent = 0;
    while (a.skillPoints > 0) {
      SkillKind? low;
      for (final k in SkillKind.values) {
        if (a.skills[k] < maxSkill &&
            (low == null || a.skills[k] < a.skills[low])) {
          low = k;
        }
      }
      if (low == null) break;
      spent += spendSkillPoints(a, low, 1);
    }
    return spent;
  }

  /// Energy gained at the end of a week (before the job's cost).
  static const energyRegenWriting = 14.0, energyRegenIdle = 24.0;
  static const energyRestBonus = 20.0;

  /// Shoots a music video for [s] (docs K52). Its strength comes from the
  /// budget and the artist's performance and charisma on camera.
  static void shootVideo(World w, Artist a, Song s, VideoBudget budget) {
    if (s.videoBudget >= 0) throw ActionException('Already has a video');
    if (a.tier == ArtistTier.player) {
      if (budget.costCents > a.moneyCents) {
        throw ActionException('Not enough money');
      }
      a.moneyCents -= budget.costCents;
    }
    final craft = 0.6 +
        0.25 * a.skills.performance / 100 +
        0.15 * a.skills.charisma / 100;
    s.videoBudget = budget.index;
    s.videoPower = budget.basePower * craft;
    s.videoWeek = w.week;
    s.streamsAtVideo = s.releasedWeek < 0
        ? 0
        : [for (var r = 0; r < regionCount; r++) w.songLifetimeStreams(s, r)]
            .fold(0.0, (t, x) => t + x);
    w.dirtySongs.add(s.id);
  }

  /// Puts out another version of a released song (docs K92, F26): a remix,
  /// a sped-up or slowed version, an a cappella or instrumental. It is
  /// counted with the song and brings a wave of listening; each further
  /// version in the same couple of months brings less. A sped-up or slowed
  /// version can start a short-video trend.
  static void releaseVersion(World w, Artist a, Song s, SongVersion v) {
    if (s.releasedWeek < 0 || s.status == SongStatus.scrapped) {
      throw ActionException('Only released songs get versions');
    }
    if (s.versions.any((x) => x.$1 == v)) {
      throw ActionException('That version is already out');
    }
    if (a.tier == ArtistTier.player) {
      if (v.costCents > a.moneyCents) throw ActionException('Not enough money');
      a.moneyCents -= v.costCents;
      s.productionCostCents += v.costCents;
    }
    if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
    s.weeksBelowCutoff = 0;
    final year = GameTime.yearOf(w.week);
    // Each more version within two months brings half the last one's
    // wave (0.7 until docs K216).
    // The player's versions count with their other tools (docs K216).
    final recent = s.versions.where((x) => w.week - x.$2 < 8).length;
    if (a.tier != ArtistTier.player) {
      s.versionBoost += v.boost(year) * math.pow(0.5, recent);
    }
    s.versions.add((v, w.week));
    if (v.trendy) {
      final r = RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.viral + 50);
      final era = w.config.viralEraFactor(year);
      if (year >= 2020 && r.chance(0.12 * (0.5 + s.virality))) {
        s.viralBoost = math.max(
            s.viralBoost, r.range(0.02, 0.06) * (0.5 + s.virality) * era / 2.7);
        s.viralRamp = 3;
      }
    }
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// Puts out a physical edition of a single (docs K92, F26): a CD, a 7"
  /// vinyl, a cassette or a signed CD. Fans buy it mostly in its week; the
  /// sales count on the charts.
  static void releaseVariant(World w, Artist a, Song s, SingleFormat f) {
    if (!s.isSingle || s.releasedWeek < 0) {
      throw ActionException('Only singles get physical editions');
    }
    if (s.variants.any((x) => x.$1 == f)) {
      throw ActionException('That edition is already out');
    }
    if (a.tier == ArtistTier.player) {
      if (f.costCents > a.moneyCents) throw ActionException('Not enough money');
      a.moneyCents -= f.costCents;
      s.productionCostCents += f.costCents;
    }
    if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
    s.weeksBelowCutoff = 0;
    s.variants.add((f, w.week));
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// Throws away an unreleased song (docs K48). Its recording cost is not
  /// refunded.
  static void scrapSong(World w, Song s) {
    if (s.status != SongStatus.vault) {
      throw ActionException('Only unreleased songs can be scrapped');
    }
    s.status = SongStatus.scrapped;
    w.dirtySongs.add(s.id);
  }

  /// Takes this week off: no more writing this week, extra energy at its
  /// end. Not possible after writing this week.
  static void rest(World w, Artist a) {
    if (a.lastWriteWeek == w.week && a.songsWrittenThisWeek > 0) {
      throw ActionException('Already wrote this week');
    }
    a.restWeek = w.week;
  }

  /// End-of-week energy change for [a] (docs K20, K36).
  static double weeklyEnergy(World w, Artist a) {
    final wrote = a.lastWriteWeek == w.week && a.songsWrittenThisWeek > 0;
    return (wrote ? energyRegenWriting : energyRegenIdle) +
        (a.restWeek == w.week ? energyRestBonus : 0) -
        a.job.energyCost -
        (a.tour != null ? Tours.energyPerWeek : 0);
  }

  /// Core fans a collaborator wants before working with you: none up to
  /// skill 45, then doubling every 7 skill points (5K at 45, ~80K at 73,
  /// ~650K at 94). Rounded to two significant digits.
  static int requiredFans(Collaborator c) {
    if (c.skill <= 45) return 0;
    final v = 5000 * math.pow(2, (c.skill - 45) / 7);
    final mag = math.pow(10, (math.log(v) / math.ln10).floor() - 1);
    return ((v / mag).round() * mag).round();
  }

  /// Whether [c] works with [a]: enough fans, or enough fame.
  static bool collaboratorAvailable(Collaborator c, Artist a) =>
      a.coreFans >= requiredFans(c) || a.fame >= c.minFame;

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

  /// Quality bonus of studio time for AI artists (label budgets).
  static double budgetBonus(BudgetTier b) => switch (b) {
        BudgetTier.low => 0,
        BudgetTier.medium => 3,
        BudgetTier.high => 6,
      };

  /// Quality bonus of the studio time the player pays for: money is a real
  /// lever (playtest finding A4).
  static double playerBudgetBonus(BudgetTier b) => switch (b) {
        BudgetTier.low => 0,
        BudgetTier.medium => 5,
        BudgetTier.high => 10,
      };

  /// The player's quality ceiling per studio budget (docs F35).
  static double budgetCeiling(BudgetTier b) => switch (b) {
        BudgetTier.low => 68,
        BudgetTier.medium => 82,
        BudgetTier.high => 100,
      };

  /// No weekly limit (docs K46): creativity is the limit. Each song uses
  /// [energyCostPerSong] of it, and the lower it is, the weaker the song.
  static bool canWrite(World w, Artist a) =>
      w.week >= a.burnoutUntilWeek && a.restWeek != w.week;

  /// Creativity at or above this writes at full strength: a whole song's
  /// worth, so the whole bar is usable (docs K237; was 50, which left the
  /// lower 40 unused).
  static const creativityFull = energyCostPerSong;

  /// Share of the song's quality lost at creativity 0.
  static const creativityPenaltyMax = 0.5;

  /// Share of quality lost by a song written at creativity [c]: none at
  /// 20+, 25% at 10, half at 0. A share, not points, so even a maxed-out
  /// artist writes weak songs when spent (docs K46, K237).
  static double creativityPenalty(double c) => c >= creativityFull
      ? 0
      : (creativityFull - c) / creativityFull * creativityPenaltyMax;

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
    List<int>? genres,
    bool holiday = false,
  }) {
    final songGenres = genres ?? [a.genre];
    if (songGenres.isEmpty ||
        songGenres.length > maxSongGenres ||
        songGenres.toSet().length != songGenres.length ||
        songGenres.any((g) => g < 0 || g >= genreNames.length)) {
      throw SongwritingException('A song has 1–$maxSongGenres distinct genres');
    }
    if (!aiMode && !canWrite(w, a)) {
      throw SongwritingException(w.week < a.burnoutUntilWeek
          ? 'Burnout: cannot write until week ${a.burnoutUntilWeek}'
          : 'Resting this week');
    }
    if (a.lastWriteWeek != w.week) {
      a.lastWriteWeek = w.week;
      a.songsWrittenThisWeek = 0;
    }
    final index = a.songsWrittenThisWeek % 64;

    var paidCents = 0;
    if (!aiMode) {
      for (final c in [producer, cowriter]) {
        if (c != null && !collaboratorAvailable(c, a)) {
          throw SongwritingException('${c.name} needs more fans');
        }
      }
      final cost = budgetCostCents(budget) +
          (producer?.feeCents ?? 0) +
          (cowriter?.feeCents ?? 0);
      if (cost > a.moneyCents) throw SongwritingException('Not enough money');
      a.moneyCents -= cost;
      paidCents = cost;
    }
    // Counted only once the song is really written (a refusal costs nothing).
    a.songsWrittenThisWeek++;

    final r = RandomStream.keyed(
        w.seed, w.week, a.id * 64 + index, RngPurpose.songQuality);

    // Skill component.
    final own = a.skills.songwriting;
    final co = cowriter?.skill;
    final writing =
        co == null ? own : 0.6 * math.max(own, co) + 0.4 * math.min(own, co);
    final prod = producer?.skill ?? producerSkill ?? a.skills.production * 0.8;
    final wq = a.kind.qualityWeights;
    final skill = topCraft(wq.writing * writing +
        wq.production * prod +
        wq.vocals * a.skills.vocals +
        wq.perf * a.skills.performance);

    final genreFit =
        (producer != null && songGenres.contains(producer.genre)) ? 3.0 : 0.0;
    // The player's luck is a little narrower so the team and budget show
    // (playtest finding A4); AI songs keep the calibrated spread.
    final luck = r.nextNormal() * (aiMode ? 8.0 : 6.0);
    final inspired = r.chance(inspirationChance);
    final energyBefore = a.creativeEnergy;
    final energyPenalty = aiMode ? 0.0 : creativityPenalty(energyBefore);

    final raw = skill +
        (a.tier == ArtistTier.player
            ? w.difficulty.qualityBonus + noviceBonus(skill)
            : 0) +
        (aiMode ? budgetBonus(budget) : playerBudgetBonus(budget)) +
        genreFit +
        luck +
        (inspired ? inspirationBonus : 0);
    // The studio sets how far the player's craft can carry a song: a cheap
    // home recording stops around a B however good the artist, the top
    // grades need studio money (docs F35). Past the ceiling only a third
    // of the rest counts (an inspired bedroom song can still reach an A).
    final ceiling = aiMode ? 100.0 : budgetCeiling(budget);
    final studio = raw <= ceiling ? raw : ceiling + 0.3 * (raw - ceiling);
    // Soft ceiling: an A+ stays rare even for the best (docs K81); low
    // creativity then takes its share.
    final quality =
        (softCeiling(studio) * (1 - energyPenalty)).clamp(1.0, 100.0);

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
    final estimateNoise = math.max(3.0, 9.0 - prod / 20.0);
    final grade =
        (quality + r.nextNormal() * estimateNoise).round().clamp(1, 100);

    final song = Song(
      id: w.songs.length,
      title: title ??
          Names.song(RandomStream.keyed(
              w.seed, w.week, a.id * 64 + index, RngPurpose.names)),
      genre: songGenres.first,
      extraGenres: songGenres.sublist(1),
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
    song.gradeSpread = (1.5 * estimateNoise).round();
    // Holiday songs (docs K136): the player's choice; now and then a
    // rival records one too.
    song.holiday = holiday ||
        (a.tier != ArtistTier.player &&
            Holidays.writingSeason(GameTime.weekOfYear(w.week)) &&
            keyedUnit(w.seed, w.week, song.id, RngPurpose.holiday) <
                Holidays.aiShare);
    song.productionCostCents = paidCents;
    w.songs.add(song);
    w.dirtySongs.add(song.id);
    if (a.id == w.playerArtistId) w.playerSongIds.add(song.id);

    if (!aiMode) {
      a.creativeEnergy = math.max(0, a.creativeEnergy - energyCostPerSong);
      // Only a song written on fumes burns out (docs K237): the fifth
      // song from a full bar lands on 0 and is fine.
      if (energyBefore < energyCostPerSong) {
        a.burnoutUntilWeek = w.week + burnoutWeeks;
      }
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

  /// How much more a campaign costs for a big audience (docs K57): reaching
  /// a superstar's ~9M listeners costs about 4× a newcomer's, 18M about 7×.
  static double campaignSizeFactor(Artist a) => math
      .pow(math.max(1.0, (Audience.engaged(a) + 0.25 * a.casual) / 1.5e6), 0.8)
      .toDouble();

  /// Craft beyond 80 counts half (docs K81): a master writes great songs,
  /// not perfect ones every time, so maxed skills land among the best
  /// rivals instead of far above them.
  static double topCraft(double skill) =>
      skill <= 80 ? skill : 80 + 0.5 * (skill - 80);

  /// Quality from the studio's raw score: as is up to 80, then bending
  /// towards 100 (docs K81). A maxed artist with a top studio averages
  /// ~88 (A) and reaches an A+ (90) about one song in five.
  static double softCeiling(double raw) =>
      raw <= 80 ? raw : 80 + 20 * (1 - math.exp(-(raw - 80) / 40));

  /// A beginner's first songs get a lift that fades as their craft grows
  /// (docs T13): +0.45 per point below 50 (about +7 at the free start's
  /// ~33), nothing from 50 up.
  static double noviceBonus(double skill) =>
      skill >= 50 ? 0 : 0.45 * (50 - skill);

  /// What the player pays for [campaign]: its price grows with their
  /// audience, and their label pays the rest.
  static int campaignCostFor(Artist a, Campaign campaign) =>
      (campaign.costCents *
              campaignSizeFactor(a) *
              (a.tier == ArtistTier.player ? a.label.campaignShare : 1.0))
          .round();

  /// What the player pays for a radio push (docs K84): its price grows
  /// with the square root of the audience (a superstar's heavy push is
  /// about 2.6× a newcomer's), the label pays its campaign share.
  static int radioPushCostFor(Artist a, RadioPush push) => (push.costCents *
          math.sqrt(campaignSizeFactor(a)) *
          (a.tier == ArtistTier.player ? a.label.campaignShare : 1.0))
      .round();

  /// The biggest radio push a label can arrange: heavy rotation needs at
  /// least a mid-size label, a blitz a major (docs K128).
  static RadioPush maxRadioPush(Label l) => l.index >= Label.major.index
      ? RadioPush.blitz
      : l.index >= Label.mid.index
          ? RadioPush.heavy
          : RadioPush.standard;

  /// Weeks after a single comes out its radio push can still be raised
  /// (docs K128): stations add a song early or not at all.
  static const radioUpgradeWeeks = 8;

  /// What raising [s]'s radio push to [to] costs now: the difference.
  static int radioUpgradeCost(Artist a, Song s, RadioPush to) =>
      math.max(0, radioPushCostFor(a, to) - radioPushCostFor(a, s.radioPush));

  static bool canUpgradeRadio(World w, Artist a, Song s) =>
      s.isSingle &&
      s.status == SongStatus.active &&
      w.week - s.singleWeek < radioUpgradeWeeks &&
      s.radioPush.rank < maxRadioPush(a.label).rank;

  /// Works a released single to another radio format (docs K134), free
  /// while stations are still deciding.
  static void setRadioFormat(World w, Artist a, Song s, RadioFormat f) {
    if (!s.isSingle ||
        s.status != SongStatus.active ||
        w.week - s.singleWeek >= radioUpgradeWeeks) {
      throw ActionException('Radio format not possible');
    }
    s.radioFormat = f;
    w.dirtySongs.add(s.id);
  }

  /// Raises a released single's radio push (docs K128).
  static void upgradeRadio(World w, Artist a, Song s, RadioPush to) {
    if (!canUpgradeRadio(w, a, s) ||
        to.rank <= s.radioPush.rank ||
        to.rank > maxRadioPush(a.label).rank) {
      throw ActionException('Radio push not possible');
    }
    final cost = radioUpgradeCost(a, s, to);
    if (cost > a.moneyCents) throw ActionException('Not enough money');
    a.moneyCents -= cost;
    s.campaignCostCents += cost;
    s.radioPush = to;
    w.dirtySongs.add(s.id);
  }

  /// A long break makes the return an event (docs K87): after two years
  /// without a release, fans and press are hungry, most of all for a
  /// group's reunion.
  static const comebackWeeks = 104;

  static void _comeback(World w, Artist a) {
    if (a.lastReleaseWeek < 0 || w.week - a.lastReleaseWeek < comebackWeeks) {
      return;
    }
    final group = a.kind.isGroup;
    a.hype += (group ? 0.35 : 0.2) * (0.5 + a.fame);
    if (group) a.devotion = math.min(1.0, a.devotion + 0.03);
    w.dirtyArtists.add(a.id);
  }

  /// Pays the player's campaign up front (AI labels run theirs implicitly)
  /// and returns what was paid.
  static int _payRadio(Artist a, RadioPush radio) {
    if (a.tier != ArtistTier.player) return 0;
    final cost = radioPushCostFor(a, radio);
    a.moneyCents -= cost;
    return cost;
  }

  static int _payCampaign(Artist a, Campaign campaign) {
    if (a.tier != ArtistTier.player) return 0;
    final cost = campaignCostFor(a, campaign);
    if (cost > a.moneyCents) {
      throw ActionException('Not enough money for the campaign');
    }
    a.moneyCents -= cost;
    return cost;
  }

  // ------------------------------------------------------------- labels

  /// Why [label] would turn the artist down (empty: it signs them). In
  /// Legend mode labels ask for less and look past a bad era.
  static List<LabelRequirement> labelMissing(World w, Artist a, Label label) {
    final legend = w.difficulty == Difficulty.legend;
    final scale = legend ? 0.4 : 1.0;
    return [
      if (a.coreFans < label.minFans * scale) LabelRequirement.fans,
      if (a.fame < label.minFame * scale) LabelRequirement.fame,
      if (!legend &&
          label.minResult != null &&
          a.lastEraResult != null &&
          a.lastEraResult!.index < label.minResult!.index)
        LabelRequirement.lastEra,
    ];
  }

  /// What leaving the current label costs while albums are still owed
  /// (docs K78): for each album owed, its part of the advance back and the
  /// label's cut of what the artist's audience would buy (50¢ a core fan).
  /// Half in Legend mode; nothing once the contract is done.
  static int buyoutCents(World w, Artist a) {
    final l = a.label;
    if (a.contractAlbumsLeft <= 0 || l.contractAlbums == 0) return 0;
    // The deal signed (docs K107); saves before it hold the label's terms.
    final albums = a.contractAlbums > 0 ? a.contractAlbums : l.contractAlbums;
    final advance =
        a.contractAlbums > 0 ? a.contractAdvanceCents : l.advanceCents;
    final perAlbum =
        advance / albums + (1 - a.artistShare) * Audience.engaged(a) * 50;
    final scale = w.difficulty == Difficulty.legend ? 0.5 : 1.0;
    return (a.contractAlbumsLeft * perAlbum * scale).round();
  }

  /// Signs with [label] (or leaves to go independent) on [deal]'s terms
  /// (docs K107): its reach and money split apply from now on, the
  /// advance is paid at once and paid back from royalties. Leaving before
  /// the albums owed are delivered pays [buyoutCents] (the new label's
  /// advance goes towards it); what the old label never recouped is its
  /// loss.
  static void signLabel(World w, Artist a, Label label,
      {bool buyout = false, ContractDeal deal = ContractDeal.standard}) {
    final t = Contracts.terms(w, a, label, deal);
    if (buyout) a.moneyCents -= buyoutCents(w, a);
    a.label = label;
    // A label distributes its artists (docs K157).
    a.distributor = Distributor.selfRelease;
    a.labelReach = label.reach;
    a.artistShare = t.artistShare;
    a.contractAlbumsLeft = t.albums;
    a.contractAlbums = t.albums;
    a.contractAdvanceCents = t.advanceCents;
    a.unrecoupedCents = t.advanceCents;
    a.moneyCents += t.advanceCents;
    w.dirtyArtists.add(a.id);
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
      {Campaign campaign = Campaign.standard,
      RadioPush radio = RadioPush.none,
      bool prepaid = false,
      int paidCents = 0,
      double buzz = 0}) {
    if (!prepaid && a.tier == ArtistTier.player) {
      final total = campaignCostFor(a, campaign) + radioPushCostFor(a, radio);
      if (total > a.moneyCents) {
        throw ActionException('Not enough money for the campaign');
      }
    }
    s.campaignCostCents =
        prepaid ? paidCents : _payCampaign(a, campaign) + _payRadio(a, radio);
    s.radioPush = radio;
    s.campaignReturnCents = 0;
    s.campaignPower = 1;
    _comeback(w, a);
    _convertAnticipation(a, album: false);
    a.hype += buzz;
    s.isSingle = true;
    s.singleWeek = w.week;
    // A free upload comes out officially (docs K148).
    Cloud.goOfficial(w, s);
    if (s.status == SongStatus.vault) {
      s.releasedWeek = w.week;
      Lifecycle.activateSong(w, s);
    } else if (s.status == SongStatus.dormant) {
      Lifecycle.reactivateSong(w, s);
    }
    _promote(w, s, campaign);
    a.lastReleaseWeek = w.week;
    // A diss track (docs K229).
    if (s.dissTarget != -1) Beefs.onRelease(w, a, s);
  }

  /// Releases an album/EP. Songs not yet released become album tracks;
  /// previously released singles are attached to the album.
  /// Manufacturing/setup cost per extra variant for the player.
  static const variantCostCents = 4000000;

  /// What the player pays for the extra editions [formats] (index 0 is
  /// the standard edition and free; missing formats cost a classic one).
  static int editionsCostCents(int count, List<int> formats) {
    var sum = 0;
    for (var k = 1; k < count; k++) {
      final f = k < formats.length ? formats[k] : -1;
      sum += f < 0 ? variantCostCents : EditionFormat.values[f].costCents;
    }
    return sum;
  }

  static Album releaseAlbum(World w, Artist a, String title, List<int> songIds,
      {AlbumType type = AlbumType.album,
      List<int> variantWeeks = const [0],
      List<int> variantFormats = const [],
      int scheduleId = -1,
      bool payForVariants = false,
      Campaign campaign = Campaign.standard,
      bool prepaid = false,
      int paidCents = 0,
      double buzz = 0,
      bool announced = false,
      bool exclusive = false,
      int windowWeeks = 0,
      AlbumBundle bundle = AlbumBundle.none,
      int liveTour = -1,
      List<int> hits = const [],
      int announceWeek = -1}) {
    final paid = prepaid ? paidCents : _payCampaign(a, campaign);
    _comeback(w, a);
    // A live album or a best-of leaves the anticipation for the next
    // record (K146, K161).
    final studio = type == AlbumType.album && liveTour < 0 && hits.isEmpty;
    _convertAnticipation(a, album: studio);
    a.hype += buzz;
    if (!announced && a.tier == ArtistTier.player) {
      final shock = surpriseShock(w, a, type, songIds);
      if (shock > 0) {
        a.hype += w.config.announceBuzzCap(type, a.fame) * shock;
        a.surpriseWeek = w.week;
      }
    }
    // A best-of is judged on all its songs (docs K161).
    final judged = [...songIds, ...hits];
    final quality = judged.isEmpty
        ? 0.0
        : judged.map((id) => w.songs[id].quality).reduce((x, y) => x + y) /
            judged.length;
    final album = Album(
      id: w.albums.length,
      title: title,
      artistId: a.id,
      type: type,
      releaseWeek: w.week,
      songIds: List.of(songIds),
      quality: quality,
    )..hitIds.addAll(hits);
    // Rivals' event albums: their comeback hype is capped, so a 1M+ week
    // stays rare as in reality (a few a year at most); the player's is not
    // (docs K42).
    album.scheduleId = scheduleId;
    album.hypeAtRelease = a.tier == ArtistTier.player
        ? a.hype
        : math.min(a.hype, w.config.aiAlbumHypeCap);
    // Critics review it: mostly the true quality, a little taste. A rave
    // lifts the opening, a pan holds it back (docs K55).
    final rc =
        RandomStream.keyed(w.seed, w.week, album.id, RngPurpose.criticReview);
    album.criticScore =
        (((quality - 10) / 9 + rc.nextNormal() * 0.5).clamp(1.0, 10.0) * 10)
                .round() /
            10;
    // The consensus counts, not one outlet (docs K112).
    album.hypeAtRelease = math.max(0.0,
        album.hypeAtRelease + (Critics.metascore(w, album) / 10 - 6.5) * 0.04);
    album.campaign = campaign;
    album.campaignCostCents = paid;
    // Formats follow their editions when the weeks are sorted.
    final order = List.generate(variantWeeks.length, (i) => i)
      ..sort((x, y) {
        final d = variantWeeks[x].compareTo(variantWeeks[y]);
        return d != 0 ? d : x.compareTo(y);
      });
    album.variantWeeks = [for (final i in order) variantWeeks[i]];
    album.variantFormats = [
      for (final i in order)
        if (i < variantFormats.length) variantFormats[i] else -1,
    ];
    if (album.variantFormats.every((f) => f < 0)) album.variantFormats = [];
    w.dirtyAlbums.add(album.id);
    if (payForVariants && variantWeeks.length > 1) {
      a.moneyCents -= editionsCostCents(variantWeeks.length, variantFormats);
    }
    w.albums.add(album);
    for (final id in songIds) {
      final s = w.songs[id];
      s.albumId = album.id;
      Cloud.goOfficial(w, s);
      w.dirtySongs.add(s.id);
      if (s.status == SongStatus.vault) {
        s.releasedWeek = w.week;
        Lifecycle.activateSong(w, s);
        // Earlier singles keep their own campaign; new tracks get the album's.
        s.campaignPower = 1;
        _promote(w, s, campaign);
      } else if (s.status == SongStatus.dormant) {
        Lifecycle.reactivateSong(w, s);
      }
    }
    _creditPreSingles(w, a, album);
    World.insertSorted(w.activeAlbumIds, album.id);
    a.lastReleaseWeek = w.week;
    if (type == AlbumType.mixtape) _mixtapeBuzz(w, a);
    // A streaming exclusive (docs K135): paid now, off the other services
    // for two weeks.
    if (exclusive && StreamingTools.canGoExclusive(w, a, type)) {
      final fee = StreamingTools.exclusiveFeeCents(a);
      a.moneyCents += fee;
      album
        ..exclusiveUntil = w.week + StreamingTools.exclusiveWeeks
        ..exclusiveFeeCents = fee
        ..revenueCents += fee;
    }
    // Off the streaming services for its first weeks (docs K174).
    if (windowWeeks > 0 &&
        album.exclusiveUntil < 0 &&
        StreamWindows.can(w, type)) {
      album.windowUntil = w.week + windowWeeks;
    }
    // Bundles (docs K144): copies counted in the first week; merch pays
    // its margin now, ticket copies pay nothing.
    if (bundle != AlbumBundle.none && Bundles.can(w, a, type, bundle)) {
      final units = Bundles.units(w, a, bundle);
      album
        ..bundle = bundle
        ..bundleUnits = units;
      if (bundle == AlbumBundle.merch) {
        final margin = (units * Bundles.merchMarginCents).round();
        a.moneyCents += margin;
        album.revenueCents += margin;
      }
    }
    album.liveTour = liveTour;
    // How well it was rolled out opens it bigger (docs K165).
    if (a.tier == ArtistTier.player &&
        Rollouts.counts(type, live: liveTour >= 0, hits: hits.isNotEmpty)) {
      Rollouts.apply(w, a, album, announceWeek);
    }
    // The fan club orders every new record ahead (docs K164).
    if (a.tier == ArtistTier.player && liveTour < 0 && hits.isEmpty) {
      album.preOrders += FanClubs.albumCopies(w, type);
    }
    // A live album or a best-of opens no era and is not an album the
    // label is owed (docs K146, K161).
    if (studio) {
      if (a.contractAlbumsLeft > 0) a.contractAlbumsLeft--;
      Eras.open(w, a, album);
    }
    return album;
  }

  /// Bonus tracks a deluxe edition can add (docs K115).
  static const maxDeluxeTracks = AlbumVersions.maxTracks;

  /// Whether [al] already had a deluxe re-release.
  static bool hasDeluxe(Album al) {
    for (var k = 0; k < al.variantWeeks.length; k++) {
      if (al.variantWeeks[k] > 0 &&
          k < al.variantFormats.length &&
          al.variantFormats[k] == EditionFormat.deluxe.index) {
        return true;
      }
    }
    return false;
  }

  /// Re-releases [al] as a deluxe edition with unreleased [songIds] as
  /// bonus tracks (docs K115): a version called "Deluxe".
  static void releaseDeluxe(World w, Artist a, Album al, List<int> songIds) {
    if (songIds.isEmpty)
      throw ActionException('1–$maxDeluxeTracks bonus tracks');
    releaseAlbumVersion(w, a, al,
        name: 'Deluxe', songIds: songIds, format: EditionFormat.deluxe);
  }

  /// Puts out a new version of [al] (docs K225): edition [format] called
  /// [name] with unreleased [songIds] as bonus tracks, out today. Fans buy
  /// the edition this week and the album is talked about again, less so
  /// for each version shortly before. An [anniversary] edition (docs
  /// K149, K226) is remastered too: every track is played again.
  static AlbumVersion releaseAlbumVersion(World w, Artist a, Album al,
      {String name = '',
      List<int> songIds = const [],
      EditionFormat format = EditionFormat.digital,
      bool anniversary = false}) {
    final why = AlbumVersions.block(w, a, al);
    if (why != null) throw ActionException('No new version: ${why.name}');
    if (songIds.length > AlbumVersions.maxTracks ||
        songIds.toSet().length != songIds.length) {
      throw ActionException('Up to ${AlbumVersions.maxTracks} bonus tracks');
    }
    for (final id in songIds) {
      final s = w.songs[id];
      if (s.primaryArtistId != a.id || s.status != SongStatus.vault) {
        throw ActionException('Only unreleased songs');
      }
    }
    final due = Anniversaries.due(w, al);
    if (anniversary && due < 0) throw ActionException('No anniversary now');
    final cost = AlbumVersions.costCents(format, anniversary: anniversary);
    if (a.tier == ArtistTier.player) {
      if (a.moneyCents < cost) throw ActionException('Not enough money');
      a.moneyCents -= cost;
      // The edition's own cost is counted with the album's editions.
      al.campaignCostCents += cost - format.costCents;
    }
    // Fans count the versions shortly before this one.
    final hype = AlbumVersions.nextHype(w, al);
    final tired = AlbumVersions.tiresFans(w, al);
    final fresh = AlbumVersions.recent(w, al) == 0;
    if (al.status == AlbumStatus.dormant) Lifecycle.reactivateAlbum(w, al);
    al.weeksBelowCutoff = 0;
    for (final id in songIds) {
      final s = w.songs[id];
      s.albumId = al.id;
      s.releasedWeek = w.week;
      s.campaignPower = 1;
      Lifecycle.activateSong(w, s);
      _promote(w, s, Campaign.standard);
      al.songIds.add(id);
    }
    if (anniversary) {
      al.anniversaries |= 1 << due;
      for (final id in al.songIds) {
        if (songIds.contains(id)) continue;
        final s = w.songs[id];
        if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
        s.weeksBelowCutoff = 0;
        s.versionBoost += Anniversaries.remasterBoost;
        w.dirtySongs.add(id);
      }
    }
    // The edition sells to collectors this week; every edition before it
    // is already out, so it goes last.
    final k = al.variantWeeks.length;
    al.variantFormats = [
      for (var j = 0; j < k; j++)
        j < al.variantFormats.length ? al.variantFormats[j] : -1,
      format.index,
    ];
    al.variantWeeks = [...al.variantWeeks, w.week - al.releaseWeek];
    final v = AlbumVersion(
        edition: k,
        week: w.week,
        name: name.trim(),
        songIds: List.of(songIds),
        anniversary: anniversary ? due : -1);
    al.versions.add(v);
    a.hype += hype;
    if (tired) {
      a.devotion = math.max(0.0, a.devotion - 0.02);
    } else if (fresh) {
      a.devotion = math.min(1.0, a.devotion + 0.01);
    }
    if (songIds.isNotEmpty || anniversary) a.lastReleaseWeek = w.week;
    w.dirtyAlbums.add(al.id);
    w.dirtyArtists.add(a.id);
    return v;
  }

  /// Singles out before the album bring it their sales so far (10 track
  /// sales = 1 unit; streams from the units era): lifetime units only, kept
  /// apart from its weeks (docs K56). Their later weeks come in the weekly
  /// step.
  static void _creditPreSingles(World w, Artist a, Album album) {
    final c = w.config;
    final streamsCount =
        Charts.songRules(ChartMarket.global, w.week).albumUsesUnits;
    for (final id in album.songIds) {
      final s = w.songs[id];
      if (!isPreSingle(s, album)) continue;
      for (var k = 0; k < regionCount; k++) {
        var units = (w.songLifetimeDownloads(s, k) +
                s.lifetimePhysical * a.regionShare[k]) /
            c.trackEquivalentAlbum;
        if (streamsCount) {
          units += w.songLifetimeStreams(s, k) / c.streamEquivalentAlbum;
        }
        album.reg[AlbumReg.lifeUnits + k] += units;
        a.reg[ArtistReg.lifeUnits + k] += units;
        album.preSingleUnits += units;
      }
    }
    w.dirtyArtists.add(a.id);
  }

  /// A free mixtape gets people talking and listening (docs K62): most in
  /// hip-hop, most of all in its mixtape years (2007–2016).
  static void _mixtapeBuzz(World w, Artist a) {
    final year = GameTime.yearOf(w.week);
    final f = (a.genre == hipHopGenre ? 1.5 : 1.0) *
        (year >= 2007 && year <= 2016 ? 1.4 : 1.0);
    a.buzz += 0.4 * f;
    a.hype += 0.05 * f;
    Audience.addCasual(w, a, a.casual * 0.03 * f);
    w.dirtyArtists.add(a.id);
  }

  /// [genreNames] index of hip-hop.
  static const hipHopGenre = 1;

  /// Releases set for a later week (docs K45), longest allowed lead time.
  static const maxScheduleWeeks = 26;

  /// Scheduled releases due this week come out (before the week is played,
  /// like a release made by hand). Returns what came out.
  static List<ScheduledOut> releaseScheduled(World w, Artist a) {
    final out = <ScheduledOut>[];
    final due = a.scheduled.where((sr) => sr.releaseWeek <= w.week).toList();
    for (final sr in due) {
      a.scheduled.remove(sr);
      if (sr.isAlbum) {
        final free = [
          for (final id in sr.songIds)
            if (w.songs[id].albumId < 0) id
        ];
        if (free.isEmpty) continue;
        for (final id in free) {
          w.songs[id].preSaves = sr.preSaves;
        }
        final al = releaseAlbum(w, a, sr.title, free,
            type: sr.type,
            variantWeeks: sr.variantWeeks,
            variantFormats: sr.variantFormats,
            scheduleId: sr.id,
            campaign: sr.campaign,
            prepaid: true,
            paidCents: sr.paidCents -
                editionsCostCents(sr.variantWeeks.length, sr.variantFormats),
            buzz: sr.buzz,
            announced: !sr.isSurprise,
            exclusive: sr.exclusive,
            windowWeeks: sr.windowWeeks,
            bundle: sr.bundle,
            announceWeek: sr.isSurprise ? -1 : sr.announceWeek)
          ..preOrders += sr.preOrders;
        out.add((scheduleId: sr.id, isAlbum: true, id: al.id));
      } else {
        final s = w.songs[sr.songIds.single];
        if (s.isSingle) continue;
        s.preSaves = sr.preSaves;
        releaseSingle(w, a, s,
            campaign: sr.campaign,
            radio: sr.radioPush,
            prepaid: true,
            paidCents: sr.paidCents,
            buzz: sr.buzz);
        out.add((scheduleId: sr.id, isAlbum: false, id: s.id));
      }
    }
    return out;
  }

  /// Years before another surprise drop shocks as much as the first.
  static const surpriseMemoryWeeks = 3 * GameTime.weeksPerYear;

  /// How much of a full announcement's buzz an album or EP dropped without
  /// one gets at once (docs K124): only with nothing from it out before,
  /// and only for a known name (none below fame 0.25, up to 0.6 from
  /// 0.75). The press soon tires of the trick: a second one within three
  /// years makes less noise.
  static double surpriseShock(
      World w, Artist a, AlbumType type, List<int> songIds) {
    if (type != AlbumType.album && type != AlbumType.ep) return 0;
    for (final id in songIds) {
      if (w.songs[id].status != SongStatus.vault) return 0;
    }
    final x = ((a.fame - 0.25) / 0.5).clamp(0.0, 1.0);
    final known = x * x * (3 - 2 * x);
    if (known <= 0) return 0;
    final fresh = w.week - a.surpriseWeek >= surpriseMemoryWeeks;
    return 0.6 * known * (fresh ? 1.0 : 0.4);
  }

  /// Pre-saves start on the streaming apps (docs K121).
  static const preSaveYear = 2017;

  /// A long campaign keeps building: the buzz ceiling rises by up to
  /// this much over [longLeadWeeks] of announcement (docs K126).
  static const longLeadBonus = 0.3;
  static const longLeadWeeks = 26;

  /// The ceiling of an announced release's buzz [weeks] after the
  /// announcement.
  static double announceCap(World w, Artist a, AlbumType type, int weeks) =>
      w.config.announceBuzzCap(type, a.fame) *
      (1 + longLeadBonus * math.min(1.0, math.max(0, weeks) / longLeadWeeks));

  /// Fans' copies of an album out of [songIds] expected in its first
  /// week before hype (the superfan part of the album sales).
  static double expectedFanCopies(World w, Artist a, List<int> songIds) {
    if (songIds.isEmpty) return 0;
    var q = 0.0;
    for (final id in songIds) {
      q += w.songs[id].quality;
    }
    final q01 = q / songIds.length / 100;
    final eras = w.regionalEra.forWeek(w.week);
    final c = w.config;
    var sum = 0.0;
    for (var k = 0; k < eras.length; k++) {
      sum += Audience.engaged(a) * a.regionShare[k] * eras[k].superfanFactor;
    }
    return sum *
        c.superfanBuyRate *
        a.devotionBuyFactor *
        a.kind.albumAffinity *
        (0.5 + q01) *
        w.difficulty.albumDemand;
  }

  /// Pre-orders reach at most this share of the fans' expected copies;
  /// each week of announcement takes [preOrderRate] (more with buzz) of
  /// what is left. Every pre-order adds [preOrderExtra] of a copy to the
  /// first week: fans who commit early buy who might not have (docs K126).
  static const preOrderCeiling = 0.75;
  static const preOrderRate = 0.07;
  static const preOrderExtra = 0.6;

  /// Announced releases build buzz until they come out; fans already feel
  /// it (half of it lifts the artist's hype in the meantime).
  static void buildAnnouncedBuzz(World w, Artist a) {
    final c = w.config;
    for (final sr in a.scheduled) {
      if (!sr.announcedBy(w.week) || w.week >= sr.releaseWeek) continue;
      final cap = announceCap(w, a, sr.type, w.week - sr.announceWeek);
      if (sr.buzz < cap) sr.buzz += (cap - sr.buzz) * c.announceBuildRate;
      a.hype = math.max(a.hype, 0.5 * sr.buzz);
      // Album pre-orders (docs K126): fans order the record ahead, a few
      // more every week the campaign runs.
      if (sr.type == AlbumType.album || sr.type == AlbumType.ep) {
        final most = preOrderCeiling * expectedFanCopies(w, a, sr.songIds);
        if (sr.preOrders < most) {
          sr.preOrders += (most - sr.preOrders) *
              preOrderRate *
              (0.5 + math.min(1.0, sr.buzz / cap));
        }
      }
      // Pre-saves on the streaming apps (docs K121): fans first, more as
      // the buzz grows, up to most of the fans and some listeners.
      if (GameTime.yearOf(w.week) >= preSaveYear) {
        final fans = Audience.engaged(a);
        final most = fans * 0.6 + a.casual * 0.05;
        sr.preSaves = math.min(
            most,
            sr.preSaves +
                (fans * 0.05 + a.casual * 0.003) *
                    (0.5 + sr.buzz) *
                    // A countdown page on the profile (docs K185).
                    ArtistPicks.preSaveFactor(w, sr.id));
      }
    }
  }

  /// Stored anticipation (after a closed era) becomes hype when the artist
  /// returns. Comeback singles ride it without using it up; the album
  /// that opens the new era takes all of it (a long-awaited album is the
  /// event, e.g. a comeback single two months before the album).
  static void _convertAnticipation(Artist a, {required bool album}) {
    if (a.eraOpen || a.anticipation <= 0) return;
    if (a.tier != ArtistTier.player) {
      // Rivals: their first comeback release uses it up (calibrated).
      a.hype += a.anticipation;
      a.anticipation = 0;
      a.anticipationCap = 0;
      return;
    }
    a.hype = math.max(a.hype, a.anticipation);
    if (album) {
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
      baseline += Audience.engaged(a) *
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
    // The last era carries over as how it did against its own
    // expectation, not as raw units: markets shrink and grow (a 2006 CD
    // smash says little about 2013 sales; docs K53).
    // People expect what the last album did (docs K245): its units next
    // to what the fanbase alone would buy now, so a market that shrank or
    // grew since is allowed for. The longer the break, the less the last
    // album counts (K3: a comeback after years is judged afresh). Before,
    // the last era counted as its score against its own expectation, so
    // after a weak album any good one was a 5× smash.
    final level = a.lastEraUnits > 0
        ? (a.lastEraUnits / baseline).clamp(0.5, 8.0)
        : 1.0;
    final gap = w.week - a.eraStartWeek;
    final weight = a.lastEraUnits <= 0
        ? 0.0
        : (0.8 - 0.1 * math.max(0, gap - 104) / 52).clamp(0.3, 0.8);
    a.eraExpected = baseline * ((1 - weight) + weight * level);
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
        // Bigger labels drop a player after a flop (not in Legend mode).
        if (a.tier == ArtistTier.player &&
            a.label.dropsAfterFlop &&
            w.difficulty != Difficulty.legend) {
          Actions.signLabel(w, a, Label.independent);
        }
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
            (a.tier == ArtistTier.player ? w.difficulty.devotionGain : 1) *
            switch (result) {
              EraResult.smash => 0.2,
              EraResult.success => 0.09,
              _ => 0.02,
            };
    }
    a.devotion = a.devotion.clamp(0.0, 1.0);
  }
}

/// What a label asks for that the artist does not have yet.
enum LabelRequirement { fans, fame, lastEra }
