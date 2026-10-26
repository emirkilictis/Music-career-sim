import 'dart:math' as math;

import '../model.dart';
import 'era_table.dart';

/// Balance knobs. Everything tunable lives here (or in [EraTable]) instead of
/// being hard-coded in the simulation, so calibration does not touch logic.
class SimConfig {
  SimConfig({
    EraTable? era,
    this.publicPool = 324e6,
    this.fanCapShare = 0.022,
    this.casualCapShare = 0.25,
    this.globalAudienceScale = 1.8,
    this.outsideAttentionRatio = 0.35,
    this.outsideDownloadRatio = 1.2,
    this.albumCatalogRate = 0.0008,
    this.fanCurveFloor = 0.12,
    this.fanCurveHalfLifeWeeks = 3.0,
    this.fanShareExponent = 0.8,
    this.selfCompetitionExponent = 0.6,
    this.singleExposure = 1.0,
    this.albumTrackExposure = 0.30,
    this.baseExposure = 0.0015,
    this.fameExposure = 0.020,
    this.fameRate = 0.02,
    this.playerFameRate = 0.03,
    this.chartFeedback = 0.12,
    this.chartFatigueWeeks = 12,
    this.albumTrackFanShare = 0.6,
    this.albumEventFanBoost = 12,
    this.albumEventWeeks = 1.5,
    this.catalogTail = 0.05,
    this.viralWeeklyChance = 0.0025,
    this.viralRevivalChance = 0.4,
    this.megaViralChance = 0.12,
    this.playlistMidBoost = 0.3,
    this.playlistBigBoost = 0.8,
    this.playlistFade = 0.85,
    // 0.005 / 0.012 until docs K127: the biggest stars took too much.
    this.marketShareKnee = 0.004,
    this.marketShareCap = 0.008,
    this.songShareKnee = 0.0025,
    this.songShareCap = 0.004,
    // 2.0 until docs K127: the player's tools stacked to ×2.4 on reach.
    this.liftCeiling = 1.2,
    // 0.35 at first: tools still broke a newcomer a year or two early.
    this.toolCeiling = 0.25,
    this.playerStreamingReach = 0.65,
    this.momentumSigma = 0.12,
    this.albumLegsSigma = 0.3,
    this.longAlbumBonus = 0.08,
    this.eventBuyRate = 0.11,
    this.superfanBuyRate = 0.07,
    this.collectorRate = 0.19,
    this.singleCollectorRate = 0.03,
    this.versionFade = 0.8,
    this.botFiltered = 0.25,
    this.autoplayLift = 0.3,
    this.resonanceSigma = 0.5,
    this.resonanceMedian = 0.75,
    this.variantDecay = 0.45,
    this.casualBuyRate = 0.012,
    this.albumSecondWeekRatio = 0.22,
    this.albumWeeklyDecay = 0.86,
    this.trackEquivalentAlbum = 10,
    this.catalogFadeEarly = 0.001,
    this.catalogFadeLate = 0.0004,
    this.catalogFadeYears = 10,
    this.catalogLevel = 2.2,
    this.streamEquivalentAlbum = 1500,
    this.downloadHitExponent = 1.45,
    this.downloadHitExponentLate = 1.15,
    this.aiAlbumHypeCap = 0.5,
    this.albumReachFatigueWeeks = 6,
    this.announceBuzzAlbum = 0.3,
    this.announceBuzzEp = 0.15,
    this.announceBuzzSingle = 0.1,
    this.announceBuildRate = 0.35,
    this.songChartStreamDivisor = 125,
    // 900 until docs F37: radio counts twice as much on the song charts.
    this.songChartRadioDivisor = 450,
    this.songChartSize = 100,
    this.albumChartSize = 200,
    this.recurrentWeeks = 20,
    this.recurrentPosition = 50,
    this.activeMinAgeWeeks = 26,
    this.dormantShareOfCutoff = 0.75,
    this.albumDormantShareOfCutoff = 0.8,
    this.anticipationBuildRate = 0.023,
    this.anticipationCapBase = 0.9,
    this.eraLengthWeeks = 52,
    this.fanConversion = 0.0008,
    this.casualConversion = 0.006,
    this.casualDecay = 0.006,
    this.coreFanDecay = 0.002,
    this.tierACount = 30,
    this.tierBCount = 300,
    this.newArtistsPerYear = 30,
    this.realStarPushYears = 6,
    this.burnInYears = 3,
    this.catalogStartYear = 2002,
  }) : era = era ?? EraTable.usDefault();

  final EraTable era;

  /// General public that can be reached by exposure (people, worldwide).
  final double publicPool;

  /// The biggest audience an artist can build, as shares of [publicPool]
  /// (docs K105): about the biggest real stars' (7M core fans, 80M
  /// casual listeners). Growth slows the closer an artist gets.
  final double fanCapShare;
  final double casualCapShare;
  double get fanCap => fanCapShare * publicPool;
  double get casualCap => casualCapShare * publicPool;

  /// Fan counts are worldwide; presets were calibrated on US audiences, so
  /// they are scaled up by this factor (≈ 1 / typical US share of an artist).
  final double globalAudienceScale;

  /// Unsimulated rest of the market, as a multiple of the simulated attention
  /// (smoothed). Larger = simulated songs get a smaller share.
  final double outsideAttentionRatio;

  /// Like [outsideAttentionRatio] for downloads (catalog downloads are large).
  final double outsideDownloadRatio;

  /// Slow catalog album sales from casual listeners (per casual listener/week).
  final double albumCatalogRate;

  final double fanCurveFloor;
  final double fanCurveHalfLifeWeeks;

  /// How fully fans split their time between an artist's fresh singles
  /// (docs K83): each gets load^-x of its fan plays (1 = a fixed budget).
  final double fanShareExponent;

  /// How much an artist's fresh singles take radio slots and new listeners
  /// from each other (docs K84): load^-x each, x growing with fame (full
  /// from 50%).
  final double selfCompetitionExponent;
  final double singleExposure;
  final double albumTrackExposure;
  final double baseExposure;
  final double fameExposure;

  /// Weekly step of fame toward popularity while it is higher: rivals and
  /// the player (docs K70).
  final double fameRate;
  final double playerFameRate;
  final double chartFeedback;

  /// Chart feedback halves after this many weeks on the charts.
  final double chartFatigueWeeks;

  /// Share of fan attention that non-single album tracks get.
  final double albumTrackFanShare;

  /// Extra fan listening of a new album's cuts in the streaming era (×
  /// playlist share; fades with [albumEventWeeks]) (docs F25).
  final double albumEventFanBoost;
  final double albumEventWeeks;

  /// Long-term catalog level as a fraction of a song's peak-period audience.
  final double catalogTail;
  final double viralWeeklyChance;

  /// Weekly chance (×2 attempts, × era factor) that an old catalog song goes
  /// viral on short-video platforms (docs/game-design.md §7.3).
  final double viralRevivalChance;

  /// How much an artist's audience helps a new song catch on online
  /// (docs T12): √(audience / 1M), audience = core fans + casual / 5, from
  /// 0.1 for an unknown to 1.3 for a star.
  double viralReach(double coreFans, double casual) =>
      math.sqrt((coreFans + casual / 5) / 1e6).clamp(0.1, 1.3).toDouble();

  /// Share of viral trends that become huge.
  final double megaViralChance;

  /// Strength of online virality by year: nothing before video sites
  /// (2005; a pre-internet hit grows on radio instead), a little on video
  /// sites, more with early short-video apps, then the full short-video
  /// era. Halved from 2018 (docs K204): a newcomer's viral #1 within two
  /// years was the rule, not the lucky exception.
  double viralEraFactor(int year) => year < 2005
      ? 0.0
      : year < 2013
          ? 0.15
          : year < 2018
              ? 0.4
              : year < 2020
                  ? 0.5
                  : 0.6;

  /// How much a music video does by year: music TV (2000–04), music TV
  /// plus video sites (2005–12), then video sites in the streaming era.
  double videoEraFactor(int year) => year < 2005
      ? 1.0
      : year < 2013
          ? 1.15
          : 0.9;

  /// Album sales after the first week against the 2000s (docs K79): as
  /// listening moves online fans buy at release and the rest stream it.
  /// Later weeks sell 75% as much in 2010, 69% in 2011, 62% in 2012, then
  /// 55% in 2013, 45% in 2014, 35% in 2015 and 28% from 2016.
  double albumTail(int year) => year < 2010
      ? 1.0
      : year < 2013
          ? 0.75 - 0.065 * (year - 2010)
          : math.max(0.28, 0.55 - 0.1 * (year - 2013));

  /// Download demand of an album cut (not a single) relative to a single:
  /// low in the early download era, when buyers took whole albums.
  double albumCutDownloadShare(int year) => year < 2009
      ? 0.2
      : year < 2013
          ? 0.35
          : 0.5;

  /// Share of promotion that works through streaming playlists rather than
  /// radio: radio era before 2010, playlist era from 2018.
  double playlistShare(int year) => year < 2010
      ? 0.05
      : year >= 2018
          ? 0.9
          : 0.05 + 0.85 * (year - 2010) / 8;

  /// How much of the player's reach to new listeners is left in [year]
  /// at [fame] (docs K204): the playlist era gave the player tools and
  /// lifts the rivals do not have, and an unknown became the world's
  /// second-biggest artist in six years. Full drag once playlists lead
  /// (2018), none in the radio era; it is the climb it slows, so it
  /// fades as the player becomes known.
  double playerReach(int year, double fame) =>
      1 -
      (1 - playerStreamingReach) *
          playlistShare(year) /
          0.9 *
          (1 - fame.clamp(0.0, 1.0));

  /// The player's reach at full playlist era (docs K204).
  final double playerStreamingReach;

  /// Campaign multiplier on a song's exposure (new listeners) in [year].
  double campaignExposure(Campaign k, int year) =>
      math.max(0.1, 1 + k.strength * (0.5 + 0.5 * playlistShare(year)));

  /// Campaign multiplier on a song's radio play in [year]: strongest in the
  /// radio era, weaker once playlists take over. Since docs K84 the paid
  /// radio push does most of it ([RadioPush]); the campaign adds a third
  /// of what it used to.
  double campaignRadio(Campaign k, int year) =>
      math.max(0.1, 1 + 0.35 * k.strength * (0.5 + (1 - playlistShare(year))));

  /// Extra exposure from a mid / big editorial playlist add; fades weekly.
  final double playlistMidBoost;
  final double playlistBigBoost;
  final double playlistFade;

  /// An artist's listening in a region, as a share of everyone else's
  /// (simulated and outside), is untouched up to [marketShareKnee] and
  /// bends towards [marketShareCap] beyond it (docs K105): listeners'
  /// time is shared, so even the biggest star takes a few per cent.
  final double marketShareKnee;
  final double marketShareCap;

  /// The same bend for one song's listening beyond its fans (docs K127).
  final double songShareKnee;
  final double songShareCap;

  /// Spread of a song's weekly run of luck (log scale; docs K105).
  final double momentumSigma;

  /// Spread of how well albums hold on after week one (log scale).
  final double albumLegsSigma;

  /// Gift buying (docs K105): non-fans buy far more records from
  /// Thanksgiving to Christmas and fewer in January; less so once
  /// listening moves to streaming.
  double holidaySales(int weekOfYear, int year) {
    final peak = switch (weekOfYear) {
      47 => 0.6,
      48 => 0.3,
      49 => 0.45,
      50 => 0.6,
      51 => 0.9,
      52 => 0.15,
      1 || 2 || 3 => -0.2,
      _ => 0.0,
    };
    final amp =
        year < 2010 ? 1.0 : (year < 2016 ? 1 - 0.07 * (year - 2009) : 0.55);
    return 1 + peak * amp;
  }

  /// Most that stacked lifts on a song's exposure can add (docs K105).
  final double liftCeiling;

  /// Exposure multiplier for lifts adding up to [x]: about 1 + [x] for
  /// one lift, bending towards 1 + [liftCeiling] when many stack up.
  double stackedLift(double x) =>
      x <= 0 ? 1.0 : 1 + liftCeiling * (1 - math.exp(-x / liftCeiling));

  /// Most that the streaming app's tools together can add to a song's
  /// exposure (docs K216): every tool used at once earned ×2.5.
  final double toolCeiling;

  /// Exposure multiplier for tool lifts adding up to [x].
  double toolStack(double x) =>
      x <= 0 ? 1.0 : 1 + toolCeiling * (1 - math.exp(-x / toolCeiling));

  /// Share of new fans an artist with [fans] core fans can still win
  /// (docs K127): it shrinks with the square of the fandom's size, so a
  /// star's fandom grows by years, not weeks (linear until K127).
  double fanRoom(double fans, {double? cap}) {
    final x = fans / (cap ?? fanCap);
    if (x >= 1) return 0;
    return (1 - x) * (1 - x);
  }

  /// [x] (an artist's share of the rest of a market) after the bend.
  double cappedMarketShare(double x) {
    if (x <= marketShareKnee) return x;
    final room = marketShareCap - marketShareKnee;
    return marketShareKnee + room * _tanh((x - marketShareKnee) / room);
  }

  double cappedSongShare(double x) {
    if (x <= songShareKnee) return x;
    final room = songShareCap - songShareKnee;
    return songShareKnee + room * _tanh((x - songShareKnee) / room);
  }

  static double _tanh(double x) {
    final e = math.exp(-2 * x);
    return (1 - e) / (1 + e);
  }

  /// First-week album purchases by non-fans, per casual listener × fame³
  /// (event albums of superstars).
  final double eventBuyRate;

  /// How strongly digital track sales concentrate on hits (1 = in
  /// proportion to attention; above 1 = the biggest hits take more), in the
  /// iTunes boom (to 2008).
  final double downloadHitExponent;

  /// The same once the digital catalog is deep and streaming spreads
  /// listening (2014 on); [downloadHitExponentFor] fades between the two.
  final double downloadHitExponentLate;

  /// Weeks after which listeners reached by an album's songs buy it half
  /// as often as at release.
  final double albumReachFatigueWeeks;

  /// Highest hype a rival's album can open with.
  final double aiAlbumHypeCap;

  /// Most buzz an announced release can build, × (0.5 + fame) (docs K45).
  final double announceBuzzAlbum, announceBuzzEp, announceBuzzSingle;

  /// Share of the remaining gap to that ceiling built each announced week
  /// (~80% after 4 weeks, so announcing much earlier adds little).
  final double announceBuildRate;

  double announceBuzzCap(AlbumType type, double fame) =>
      switch (type) {
        AlbumType.album => announceBuzzAlbum,
        AlbumType.ep || AlbumType.mixtape => announceBuzzEp,
        AlbumType.single => announceBuzzSingle,
      } *
      (0.5 + fame);

  double downloadHitExponentFor(int year) {
    if (year <= 2008) return downloadHitExponent;
    if (year >= 2014) return downloadHitExponentLate;
    final t = (year - 2008) / 6;
    return downloadHitExponent +
        t * (downloadHitExponentLate - downloadHitExponent);
  }

  /// Extra album sales per doubling of the tracklist beyond 10 tracks.
  final double longAlbumBonus;

  final double superfanBuyRate;

  /// Extra copies per core fan for the 2nd variant (scaled by devotion and
  /// era collector culture); each further variant sells [variantDecay]× less.
  final double collectorRate;

  /// Fans buying a physical single edition in its week (docs K92), and how
  /// fast a version's wave of listening fades.
  final double singleCollectorRate;
  final double versionFade;

  /// Bought streams the platform quietly filters out before they count
  /// (docs K95); autoplay's extra exposure and the share of the usual
  /// royalty it pays (docs K96).
  final double botFiltered;
  final double autoplayLift;

  /// How much a song connects with listeners beyond its quality: drawn
  /// once per song, log-normal around [resonanceMedian] (docs K127).
  final double resonanceSigma, resonanceMedian;
  final double variantDecay;
  final double casualBuyRate;
  final double albumSecondWeekRatio;
  final double albumWeeklyDecay;

  final double trackEquivalentAlbum;

  /// No longer used: the player-only catalog fade of docs K58, replaced by
  /// [catalogFadePerYear] for everyone (K85).
  final double catalogFadeEarly;
  final double catalogFadeLate;
  final double catalogFadeYears;

  /// Catalog listening against a song's last weeks (docs K85): with the
  /// fade, old songs keep ~70% of all listening, as in the US streaming
  /// market (catalog ~73% of consumption in 2023).
  final double catalogLevel;

  /// Share of a catalog song's listeners lost per year (docs K85), by its
  /// catalog weight (see Lifecycle.catalogWeight): top-10 singles 12% in
  /// their first decade, then 3%; other singles and charting album tracks
  /// 25%; the rest 45%.
  double catalogFadePerYear(double weight, double years) => weight >= 1.8
      ? (years < 10 ? 0.12 : 0.03)
      : weight >= 0.5
          ? 0.25
          : 0.45;
  final double streamEquivalentAlbum;
  final double songChartStreamDivisor;
  final double songChartRadioDivisor;
  final int songChartSize;
  final int albumChartSize;
  final int recurrentWeeks;
  final int recurrentPosition;

  /// Songs younger than this stay active regardless of performance.
  final int activeMinAgeWeeks;

  /// A song becomes dormant when its chart points fall below this share of
  /// last week's last-place chart points.
  final double dormantShareOfCutoff;
  final double albumDormantShareOfCutoff;

  final double anticipationBuildRate;
  final double anticipationCapBase;
  final int eraLengthWeeks;

  final double fanConversion;
  final double casualConversion;
  final double casualDecay;
  final double coreFanDecay;

  /// Rivals' fan bases thin out faster after their first decade (docs
  /// K66): ×1 up to 10 years active, +12% a year after (×2.2 at 20 years),
  /// so the charts renew. The player is never affected.
  double rivalAgeFade(Artist a, int week) {
    if (a.tier == ArtistTier.player) return 1;
    final years = (week - a.debutWeek) / 52;
    return years <= 10 ? 1 : 1 + 0.12 * (years - 10);
  }

  final int tierACount;
  final int tierBCount;
  final int newArtistsPerYear;

  /// Years a real star's extra label reach lasts (docs K70).
  final int realStarPushYears;

  /// Years simulated silently before the start year so charts are populated.
  final int burnInYears;

  /// The world is never younger than this: later starts still simulate from
  /// here, so the catalog of older songs (which takes its share of streams)
  /// is as deep as in the calibration runs. Starting just a few years before
  /// a streaming-era year left the market to too few songs (US #1 ≈ 350M
  /// streams a week instead of ≈ 50M).
  final int catalogStartYear;

  /// First simulated year for a career starting in [startYear].
  int worldStartYear(int startYear) =>
      startYear - burnInYears < catalogStartYear
          ? startYear - burnInYears
          : catalogStartYear;
}
