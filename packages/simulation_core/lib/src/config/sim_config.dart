import 'dart:math' as math;

import '../model.dart';
import 'era_table.dart';

/// Balance knobs. Everything tunable lives here (or in [EraTable]) instead of
/// being hard-coded in the simulation, so calibration does not touch logic.
class SimConfig {
  SimConfig({
    EraTable? era,
    this.publicPool = 324e6,
    this.globalAudienceScale = 1.8,
    this.outsideAttentionRatio = 0.35,
    this.outsideDownloadRatio = 1.2,
    this.albumCatalogRate = 0.0008,
    this.fanCurveFloor = 0.12,
    this.fanCurveHalfLifeWeeks = 3.0,
    this.singleExposure = 1.0,
    this.albumTrackExposure = 0.30,
    this.baseExposure = 0.0015,
    this.fameExposure = 0.020,
    this.fameRate = 0.02,
    this.playerFameRate = 0.04,
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
    this.longAlbumBonus = 0.08,
    this.eventBuyRate = 0.11,
    this.superfanBuyRate = 0.07,
    this.collectorRate = 0.19,
    this.variantDecay = 0.6,
    this.casualBuyRate = 0.012,
    this.albumSecondWeekRatio = 0.22,
    this.albumWeeklyDecay = 0.86,
    this.trackEquivalentAlbum = 10,
    this.catalogFadeEarly = 0.001,
    this.catalogFadeLate = 0.0004,
    this.catalogFadeYears = 10,
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
  /// era.
  double viralEraFactor(int year) => year < 2005
      ? 0.0
      : year < 2013
          ? 0.15
          : year < 2018
              ? 0.4
              : year < 2020
                  ? 1.0
                  : 1.2;

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

  /// Campaign multiplier on a song's exposure (new listeners) in [year].
  double campaignExposure(Campaign k, int year) =>
      math.max(0.1, 1 + k.strength * (0.5 + 0.5 * playlistShare(year)));

  /// Campaign multiplier on a song's radio play in [year]: strongest in the
  /// radio era, weaker once playlists take over.
  double campaignRadio(Campaign k, int year) =>
      math.max(0.1, 1 + k.strength * (0.5 + (1 - playlistShare(year))));

  /// Extra exposure from a mid / big editorial playlist add; fades weekly.
  final double playlistMidBoost;
  final double playlistBigBoost;
  final double playlistFade;

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
  final double variantDecay;
  final double casualBuyRate;
  final double albumSecondWeekRatio;
  final double albumWeeklyDecay;

  final double trackEquivalentAlbum;

  /// Weekly fade of the player's catalog songs (docs K58): about 5% a year
  /// in a song's first [catalogFadeYears] years, 2% a year after.
  final double catalogFadeEarly;
  final double catalogFadeLate;
  final double catalogFadeYears;
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
