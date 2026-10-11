import 'era_table.dart';

/// Balance knobs. Everything tunable lives here (or in [EraTable]) instead of
/// being hard-coded in the simulation, so calibration does not touch logic.
class SimConfig {
  SimConfig({
    EraTable? era,
    this.publicPool = 180e6,
    this.outsideAttentionRatio = 0.35,
    this.outsideDownloadRatio = 1.2,
    this.albumCatalogRate = 0.0008,
    this.fanCurveFloor = 0.12,
    this.fanCurveHalfLifeWeeks = 3.0,
    this.singleExposure = 1.0,
    this.albumTrackExposure = 0.30,
    this.baseExposure = 0.0015,
    this.fameExposure = 0.020,
    this.chartFeedback = 0.04,
    this.catalogTail = 0.05,
    this.viralWeeklyChance = 0.0025,
    this.superfanBuyRate = 0.09,
    this.collectorRate = 0.12,
    this.variantDecay = 0.6,
    this.casualBuyRate = 0.012,
    this.albumSecondWeekRatio = 0.22,
    this.albumWeeklyDecay = 0.86,
    this.trackEquivalentAlbum = 10,
    this.streamEquivalentAlbum = 1500,
    this.songChartStreamDivisor = 125,
    this.songChartRadioDivisor = 900,
    this.songChartSize = 100,
    this.albumChartSize = 200,
    this.recurrentWeeks = 20,
    this.recurrentPosition = 50,
    this.activeMinAgeWeeks = 26,
    this.dormantShareOfCutoff = 0.75,
    this.albumDormantShareOfCutoff = 0.30,
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
    this.burnInYears = 3,
  }) : era = era ?? EraTable.usDefault();

  final EraTable era;

  /// General public that can be reached by exposure (people).
  final double publicPool;

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
  final double chartFeedback;

  /// Long-term catalog level as a fraction of a song's peak-period audience.
  final double catalogTail;
  final double viralWeeklyChance;

  final double superfanBuyRate;

  /// Extra copies per core fan for the 2nd variant (scaled by devotion and
  /// era collector culture); each further variant sells [variantDecay]× less.
  final double collectorRate;
  final double variantDecay;
  final double casualBuyRate;
  final double albumSecondWeekRatio;
  final double albumWeeklyDecay;

  final double trackEquivalentAlbum;
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

  final int tierACount;
  final int tierBCount;
  final int newArtistsPerYear;

  /// Years simulated silently before the start year so charts are populated.
  final int burnInYears;
}
