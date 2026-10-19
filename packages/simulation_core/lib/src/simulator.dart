import 'dart:math' as math;
import 'dart:typed_data';

import 'actions.dart';
import 'ai.dart';
import 'audience.dart';
import 'awards.dart';
import 'brands.dart';
import 'social.dart';
import 'streaming_tools.dart';
import 'config/charts.dart';
import 'contracts.dart';
import 'config/era_table.dart';
import 'config/regions.dart';
import 'config/sim_config.dart';
import 'festivals.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'music_show.dart';
import 'opportunities.dart';
import 'tours.dart';
import 'word_of_mouth.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// Summary of one simulated week (what the UI/CLI needs; not the whole world).
class WeekResult {
  WeekResult({
    required this.week,
    required this.charts,
    required this.albumDebuts,
    this.scheduledOut = const [],
    required this.newNumberOnes,
    required this.viralSongs,
    required this.playlistAdds,
    this.botsCaught = const [],
    required this.activeSongs,
    required this.activeAlbums,
    required this.dormantSongs,
    required this.microseconds,
    this.newOpportunity,
    this.lapsedOpportunity,
    this.tourFinished,
    this.festivalSet,
    this.awardNominations,
    this.awardNight,
    this.brandDealsBroken = const [],
    this.rivalClashes = const [],
    this.musicShow,
  });

  final int week;

  /// Published charts by chart id (empty for charts not active yet).
  final List<List<ChartEntry>> charts;

  /// Albums released this week (ids).
  final List<int> albumDebuts;

  /// The player's scheduled releases that came out at the start of this
  /// week (docs K45).
  final List<ScheduledOut> scheduledOut;

  /// Entities reaching #1 for the first time, by chart id.
  final List<List<int>> newNumberOnes;

  /// Songs that started a viral trend this week (new or catalog).
  final List<int> viralSongs;

  /// Songs added to an editorial playlist this week (see [Song.playlistAdd]).
  final List<int> playlistAdds;

  /// Songs whose bought streams the platform caught this week (docs K95).
  final List<int> botsCaught;
  final int activeSongs;
  final int activeAlbums;
  final int dormantSongs;
  final int microseconds;

  /// An offer that came up for the player this week, and one that ran out
  /// unanswered (docs K59).
  final Opportunity? newOpportunity;
  final OpportunityOutcome? lapsedOpportunity;

  /// The player's tour that played its last week (docs K63).
  final Tour? tourFinished;

  /// The player's festival set this week (docs K77).
  final FestivalSet? festivalSet;

  /// The awards' nominations, out this week (docs K91).
  final AwardShow? awardNominations;

  /// The award show held this week, if the player was nominated.
  final AwardNight? awardNight;

  /// The player's brand deals broken this week for a missed task (K102).
  final List<DealOutcome> brandDealsBroken;

  /// Rivals' answers to the player's announced albums (docs K109).
  final List<RivalClash> rivalClashes;

  /// The K-pop music show's week, if one was held (docs K114).
  final MusicShowWeek? musicShow;

  List<ChartEntry> get songChart => charts[Charts.usSongs];
  List<ChartEntry> get albumChart => charts[Charts.usAlbums];
}

/// Runs the weekly pipeline (docs/simulation.md §2) over three regions
/// (docs/game-design.md §11.1).
class Simulator {
  Simulator(this.world);

  final World world;

  static const _r = regionCount;

  /// This week's market share factor per artist and region (docs K105);
  /// missing means 1. Applied to active songs and the dormant catalog.
  final Map<int, Float64List> _capFactor = {};
  double _cap(int artistId, int k) => _capFactor[artistId]?[k] ?? 1.0;

  /// Debugging aid for probes: the player's attention by part.
  static Map<String, double>? debugParts;

  WeekResult step() {
    final sw = Stopwatch()..start();
    final w = world;
    final c = w.config;
    final eras = w.regionalEra.forWeek(w.week);

    // The week streams and downloads start to count as album units: every
    // album collects its tracks' earlier streams and downloads at once, so
    // a 2002 album that lived on in the streaming era gets all of them.
    if (Charts.songRules(ChartMarket.global, w.week).albumUsesUnits &&
        !Charts.songRules(ChartMarket.global, w.week - 1).albumUsesUnits) {
      _retroactiveAlbumUnits();
    }

    // The player's scheduled releases due this week come out.
    final player = w.player;
    final scheduledOut = player == null
        ? const <ScheduledOut>[]
        : Actions.releaseScheduled(w, player);
    // Playlist editors answer this week's pitches (docs K97).
    StreamingTools.answerPitches(w);

    // 1–2. Scheduled AI activity.
    final clashes = AiPlanner.step(w);

    // 3. Short-video virality can revive old catalog songs (event based).
    final virals = _viralRevivals();

    // 4. Artist pre-step (active artists only).
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      a.weekPoints = 0;
      a.weekReach = 0;
      a.weekStreams = 0;
      a.hype *= 0.92;
      if (a.scheduled.isNotEmpty) Actions.buildAnnouncedBuzz(w, a);
      // Fanbases slowly drift unless renewed by successful eras.
      a.devotion = math.max(0.0, a.devotion - 0.0004 * a.kind.devotionDrift);
      a.buzz *= 0.75;
      a.flopSupport *= 0.97;
      if (!a.eraOpen && a.anticipationCap > 0) {
        a.anticipation +=
            (a.anticipationCap - a.anticipation) * c.anticipationBuildRate;
      }
      a.creativeEnergy =
          (a.creativeEnergy + Actions.weeklyEnergy(w, a)).clamp(0.0, 100.0);
    }

    // Campaign effects for this year: promotion works mostly through radio
    // before streaming playlists, mostly through playlists after.
    final year = GameTime.yearOf(w.week);
    final albumCutDl = c.albumCutDownloadShare(year);
    final videoEra = c.videoEraFactor(year);
    final campaignExposure = [
      for (final k in Campaign.values) c.campaignExposure(k, year),
    ];
    final campaignRadio = [
      for (final k in Campaign.values) c.campaignRadio(k, year),
    ];
    final noCampaign = campaignExposure[Campaign.none.index];
    // Every campaign works at full strength (the K57 fatigue was removed
    // on the player's request).
    double exposureOf(Song s) => campaignExposure[s.campaign.index];
    // Radio comes from the paid push; the campaign adds a little (K84).
    double radioOf(Song s) =>
        campaignRadio[s.campaign.index] *
        s.radioPush.factorFor(w.artists[s.primaryArtistId].fame);
    final playlistAdds = <int>[];

    // 5. Raw demand for active songs, split by region.
    final ids = w.activeSongIds;
    final n = ids.length;
    final att = Float64List(n * _r);
    final dl = Float64List(n * _r);
    final radio = Float64List(n * _r);
    final sumA = Float64List(_r), sumD = Float64List(_r);
    final sumR = Float64List(_r), sumSingles = Float64List(_r);
    final songAttention = Float64List(n);
    // Share of each song's attention from the artist's fans (docs K105).
    final fanFrac = Float64List(n);
    // How many fresh singles each artist's fans are splitting their time
    // between (docs K83): each single released in the last 26 weeks
    // weighs its fan curve now.
    // The same fresh singles also compete for the artist's radio slots and
    // new listeners (docs K84): each weighs its radio and promo curves.
    final singleLoad = <int, double>{};
    final radioLoad = <int, double>{}, promoLoad = <int, double>{};
    for (var i = 0; i < n; i++) {
      final s = w.songs[ids[i]];
      final promoAge = w.week - s.singleWeek;
      if (!s.isSingle || promoAge >= 26) continue;
      final ageRel = w.week - s.releasedWeek;
      final id = s.primaryArtistId;
      singleLoad[id] = (singleLoad[id] ?? 0) + _fanCurve(c, ageRel);
      radioLoad[id] = (radioLoad[id] ?? 0) + _radioLife(s, promoAge);
      promoLoad[id] = (promoLoad[id] ?? 0) + _promoLife(s, promoAge);
    }
    // A newcomer's singles each find their own small crowd; a star's all
    // go to the same stations and playlists. Full from 50% fame.
    double share(Map<int, double> load, Song s, int promoAge) {
      if (!s.isSingle || promoAge >= 26) return 1;
      final l = load[s.primaryArtistId] ?? 1;
      if (l <= 1) return 1;
      final fame = w.artists[s.primaryArtistId].fame;
      final x = c.selfCompetitionExponent * math.min(1.0, 2 * fame);
      return math.pow(l, -x).toDouble();
    }

    final activeIndex = <int, int>{};
    for (var i = 0; i < n; i++) {
      final s = w.songs[ids[i]];
      activeIndex[s.id] = i;
      final p = w.artists[s.primaryArtistId];
      final r =
          RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.weeklyNoise);

      final ageRel = w.week - s.releasedWeek;
      final promoAge = s.isSingle ? w.week - s.singleWeek : ageRel;
      final fanCurve = _fanCurve(c, ageRel);
      // Fans' time is shared between the artist's fresh singles: a new
      // single every few weeks gets less of it each (docs K83).
      final load = s.isSingle && promoAge < 26
          ? (singleLoad[s.primaryArtistId] ?? 1.0)
          : 1.0;
      final fanShare =
          load <= 1 ? 1.0 : math.pow(load, -c.fanShareExponent).toDouble();
      // Catalog level fades very slowly over decades (10-year time constant).
      final tail =
          c.catalogTail * (0.5 + s.longevity) * math.exp(-ageRel / 520.0);
      final life = _promoLife(s, promoAge) + tail;
      final promo = s.isSingle
          ? c.singleExposure * p.kind.singleReach
          : c.albumTrackExposure;
      // Long albums: listeners' time is split between tracks. Up to 10 tracks
      // each gets full attention; beyond that each track gets less, so 40
      // tracks add streams but nowhere near 4× (docs/game-design.md §10.2).
      var trackShare = 1.0;
      if (!s.isSingle && s.albumId >= 0) {
        final tracks = w.albums[s.albumId].songIds.length;
        if (tracks > 10) trackShare = math.pow(10 / tracks, 0.6).toDouble();
      }

      var fans = p.coreFans, cas = p.casual;
      for (final f in s.featuredArtistIds) {
        fans += 0.4 * w.artists[f].coreFans;
        cas += 0.4 * w.artists[f].casual;
      }

      // Viral trends grow for a few weeks, then fade.
      if (s.viralRamp > 0) {
        s.viralBoost *= 1.4;
        s.viralRamp--;
      } else {
        s.viralBoost *= 0.88;
      }
      final viralEra = c.viralEraFactor(GameTime.yearOf(w.week));
      // A music video on the video sites helps a song catch on.
      final videoViral = 1 + 2 * s.videoPower * (viralEra > 0 ? 1 : 0);
      // Songs people already hear catch on far more often: an unknown
      // artist rarely goes viral, and smaller when it happens (docs T12).
      final viralReach = c.viralReach(fans, cas);
      if (r.chance(c.viralWeeklyChance *
          p.kind.viral *
          viralEra *
          (0.3 + 2 * s.virality) *
          videoViral *
          viralReach)) {
        _startViral(s, r, viralEra, reach: viralReach);
        virals.add(s.id);
      }

      // Chart feedback favours the very top (playlists, radio adds, press);
      // the best position on any main song chart counts. It wears off the
      // longer a song has been on the charts (listener fatigue).
      var chartShape = 0.0;
      var weeksCharted = 0;
      for (final ch in Charts.mainSongCharts) {
        final pos = s.lastPosOn(ch);
        if (pos > 0) {
          chartShape = math.max(chartShape, 1 - (pos - 1) / 100);
          weeksCharted = math.max(weeksCharted, s.weeksOnChart(ch));
        }
      }
      final chartBoost = c.chartFeedback *
          chartShape *
          chartShape /
          (1 + weeksCharted / c.chartFatigueWeeks);
      // People already know a famous artist: a campaign adds less on top
      // of fame (half as much for a household name; docs K81).
      final campExp = _knownCampaign(exposureOf(s), p.fame);
      // The lifts on top of the campaign, kept apart for the player's
      // stream sources (docs K120).
      final hypeLift = 0.5 * p.hype;
      final womLift = WordOfMouth.lift(w, s, promoAge);
      final listLift = s.playlistBoost;
      final versionLift = s.versionBoost;
      final algoLift =
          s.autoplay.lift * StreamingTools.autoplayLift(c, s, promoAge) +
              StreamingTools.releaseRadarLift(year, promoAge) +
              StreamingTools.discoverLift(w, s, w.week) +
              StreamingTools.preSaveLift(s, p, promoAge);
      final videoLift = s.videoPower * videoEra;
      final lifts =
          hypeLift + womLift + listLift + versionLift + algoLift + videoLift;
      final stacked = c.stackedLift(lifts);
      final exposure = (c.baseExposure +
              c.fameExposure * p.fame +
              chartBoost +
              0.02 * p.buzz) *
          promo *
          p.labelReach *
          (p.tier == ArtistTier.player
              ? w.difficulty.exposure
              : w.difficulty.aiExposure) *
          campExp *
          // Hype, word of mouth, playlists, a new version, autoplay and the
          // video add up with diminishing returns instead of multiplying
          // (docs K105, K108).
          stacked;
      if (s.playlistWeek == w.week) playlistAdds.add(s.id);
      s.playlistBoost *= c.playlistFade;
      // New versions bring a wave of listening (docs K92).
      s.versionBoost *= c.versionFade;
      if (s.versionBoost < 1e-4) s.versionBoost = 0;
      final qMult = 0.35 + 0.65 * math.pow(s.quality / 100, 1.4);

      // Fans replay singles; deep cuts get less of their time, except in
      // a streaming-era album's first weeks, when fans play the whole
      // record and its cuts flood the song charts, then fall back (docs
      // F25).
      final albumEvent = s.isSingle || s.albumId < 0
          ? 1.0
          : 1 +
              c.albumEventFanBoost *
                  c.playlistShare(year) *
                  math.exp(-ageRel / c.albumEventWeeks);
      final fanPart = fans *
          s.fanAppeal *
          fanCurve *
          fanShare *
          (1 + p.hype) *
          (s.isSingle
              ? 1.0
              : c.albumTrackFanShare * albumEvent * p.kind.albumAffinity);
      final casPart = cas * s.commercial * life * (0.05 + 0.15 * promo);
      final pubPart = c.publicPool *
          s.commercial *
          life *
          exposure *
          share(promoLoad, s, promoAge);
      // A viral trend reaches people regardless of the song's age.
      final viralPart =
          c.publicPool * (0.5 + 0.5 * s.commercial) * s.viralBoost * 0.1;
      final noise = r.logNormal(0.06) *
          _momentum(s.id, s.releasedWeek, RngPurpose.momentum);
      // Not every good song connects (docs K127): beyond the fans, how far
      // a song travels is partly luck, drawn once and hidden.
      final hit = resonance(w, s);
      final a = (fanPart + (casPart + pubPart + viralPart) * hit) *
          qMult *
          noise *
          trackShare;
      s.lastAttention = a;
      songAttention[i] = a;
      // Where the player's listening came from (docs K120).
      if (p.tier == ArtistTier.player) {
        final m = qMult * noise * trackShare;
        final liftPart = pubPart * (1 - 1 / stacked);
        double of(double x) => lifts > 0 ? liftPart * x / lifts : 0.0;
        final mh = m * hit;
        s.streamSources = Float64List.fromList([
          fanPart * m,
          casPart * mh,
          of(algoLift + womLift) * mh,
          of(listLift) * mh,
          (viralPart + of(videoLift)) * mh,
          (pubPart - liftPart + of(hypeLift + versionLift)) * mh,
        ]);
      }
      final dbg = debugParts;
      if (dbg != null && p.tier == ArtistTier.player) {
        final m = qMult * noise * trackShare;
        final floorPart = fans *
            s.fanAppeal *
            c.fanCurveFloor *
            math.exp(-ageRel / 104.0) *
            fanShare *
            (1 + p.hype) *
            (s.isSingle ? 1.0 : c.albumTrackFanShare * p.kind.albumAffinity);
        dbg['songs'] = (dbg['songs'] ?? 0) + 1;
        dbg['fan'] = (dbg['fan'] ?? 0) + fanPart * m;
        dbg['fanFloor'] = (dbg['fanFloor'] ?? 0) + floorPart * m;
        dbg['cas'] = (dbg['cas'] ?? 0) + casPart * m;
        dbg['pub'] = (dbg['pub'] ?? 0) + pubPart * m;
        dbg['viral'] = (dbg['viral'] ?? 0) + viralPart * m;
      }
      final all = fanPart + casPart + pubPart + viralPart;
      fanFrac[i] = all > 0 ? fanPart / all : 0;
      s.lastReach =
          (casPart + pubPart + viralPart) * hit * qMult * trackShare;
      // What the campaign added over none at all, for the player's
      // profit/loss (docs K57).
      if (p.tier == ArtistTier.player) {
        final extra =
            campExp > noCampaign ? pubPart * (1 - noCampaign / campExp) : 0.0;
        final all = fanPart + casPart + pubPart + viralPart;
        final reached = casPart + pubPart + viralPart;
        s.campaignShareOfAttention = all > 0 ? extra / all : 0;
        s.campaignShareOfReach = reached > 0 ? extra / reached : 0;
      }

      final fresh = math.exp(-promoAge / 6.0);
      // Album buyers own the deep cuts, so few download them one by one,
      // least in the early download era (docs K50).
      // Mixtape tracks are free downloads: no sales (docs K62).
      final free = !s.isSingle &&
          s.albumId >= 0 &&
          w.albums[s.albumId].type == AlbumType.mixtape;
      final d =
          free ? 0.0 : a * (0.25 + fresh) * (s.isSingle ? 1.0 : albumCutDl);
      final rd = s.radioAppeal *
          _radioLife(s, promoAge) *
          share(radioLoad, s, promoAge) *
          (s.isSingle ? 1.0 : 0.03) *
          (0.2 + p.fame) *
          p.labelReach *
          radioOf(s) *
          (1 + 8 * chartBoost);

      for (var k = 0; k < _r; k++) {
        final share = p.regionShare[k];
        final j = i * _r + k;
        att[j] = a * share;
        dl[j] = d * share;
        radio[j] = rd * share;
        sumA[k] += att[j];
        sumD[k] += dl[j];
        sumR[k] += radio[j];
        if (s.isSingle) sumSingles[k] += att[j];
      }
    }

    _capMarketShare(
        ids, att, dl, songAttention, fanFrac, sumA, sumD, sumSingles);

    // Digital purchases pile onto the biggest hits (docs K44): each song's
    // download demand is scaled by (attention / mean)^(γ−1), so a smash
    // takes a much bigger share of the same market (the tail sells less).
    // Strongest in the iTunes boom, softer once the catalog is deep.
    final hitExp = c.downloadHitExponentFor(year);
    if (hitExp != 1 && n > 0) {
      var total = 0.0;
      for (var i = 0; i < n; i++) {
        total += songAttention[i];
      }
      final mean = total / n;
      for (var k = 0; k < _r; k++) {
        sumD[k] = 0;
      }
      for (var i = 0; i < n; i++) {
        final f = math
            .pow((songAttention[i] / (mean + 1e-9)).clamp(0.02, 1000.0),
                hitExp - 1)
            .toDouble();
        for (var k = 0; k < _r; k++) {
          final j = i * _r + k;
          dl[j] *= f;
          sumD[k] += dl[j];
        }
      }
    }

    // Dormant catalog attention: active artists + frozen retired totals.
    for (var k = 0; k < _r; k++) {
      var dormant = w.retiredDormantAttention[k];
      for (final id in w.activeArtistIds) {
        final a = w.artists[id];
        if (a.sumDormantRate > 0) {
          dormant += a.sumDormantRate *
              a.catalogFactor *
              a.regionShare[k] *
              _cap(id, k);
        }
      }
      sumA[k] += dormant;
      sumD[k] += dormant * 0.1;
    }

    // 6. Normalise each region against its market.
    final spa = Float64List(_r), dpa = Float64List(_r);
    final rpr = Float64List(_r), ppa = Float64List(_r);
    for (final region in Region.values) {
      final k = region.index;
      final rc = regionConfigs[region]!;
      final era = eras[k];
      if (w.emaAttention[k] == 0) {
        w.emaAttention[k] = sumA[k];
        w.emaDownloadDemand[k] = sumD[k];
        w.emaRadioDemand[k] = sumR[k];
      }
      spa[k] = era.streamsWeekly /
          (sumA[k] + rc.outsideAttention * w.emaAttention[k] + 1);
      dpa[k] = era.downloadsWeekly /
          (sumD[k] + rc.outsideDownloads * w.emaDownloadDemand[k] + 1);
      rpr[k] = era.radioWeekly /
          (sumR[k] + rc.outsideAttention * w.emaRadioDemand[k] + 1e-9);
      ppa[k] = era.physicalSinglesWeekly /
          (sumSingles[k] * (1 + rc.outsideAttention) + 1);
      w.spaIndex[k] += spa[k];
      w.lastSpa[k] = spa[k];
      w.lastDpa[k] = dpa[k];
      w.dpaIndex[k] += 0.1 * dpa[k];
      w.emaAttention[k] = 0.9 * w.emaAttention[k] + 0.1 * sumA[k];
      w.emaDownloadDemand[k] = 0.9 * w.emaDownloadDemand[k] + 0.1 * sumD[k];
      w.emaRadioDemand[k] = 0.9 * w.emaRadioDemand[k] + 0.1 * sumR[k];
    }

    // 7. Consumption per active song, and chart points per song chart.
    final rulesUs = Charts.songRules(ChartMarket.us, w.week);
    final rulesUk = Charts.songRules(ChartMarket.uk, w.week);
    final rulesGlobal = Charts.songRules(ChartMarket.global, w.week);
    final songPts = List.generate(Charts.count, (_) => Float64List(n));
    final streamsR = Float64List(n * _r);
    final downloadsR = Float64List(n * _r);
    double pts(ChartRules rl, double phys, double down, double st, double rad,
            {bool radioCounts = true}) =>
        phys +
        (rl.countsDownloads ? down : 0) +
        st * rl.streamFactor / c.songChartStreamDivisor +
        (radioCounts ? rad / c.songChartRadioDivisor : 0);
    final st = Float64List(_r), dw = Float64List(_r);
    final rd = Float64List(_r), ph = Float64List(_r);
    final variantSales = Float64List(_r);
    final botsCaught = <int>[];
    for (var i = 0; i < n; i++) {
      final s = w.songs[ids[i]];
      final p = w.artists[s.primaryArtistId];
      var tS = 0.0, tD = 0.0, tR = 0.0, tP = 0.0;
      _variantSales(s, p, eras, variantSales);
      // Bought streams land where the artist's audience is (docs K95).
      final bots = StreamingTools.botStreamsThisWeek(w, s);
      for (var k = 0; k < _r; k++) {
        final j = i * _r + k;
        st[k] = att[j] * spa[k] + bots * p.regionShare[k];
        dw[k] = dl[j] * dpa[k];
        rd[k] = radio[j] * rpr[k];
        ph[k] = s.isSingle ? att[j] * ppa[k] + variantSales[k] : 0;
        streamsR[j] = st[k];
        downloadsR[j] = dw[k];
        tS += st[k];
        tD += dw[k];
        tR += rd[k];
        tP += ph[k];
        s.reg[SongReg.lifeStreams + k] += st[k];
        s.reg[SongReg.lifeDownloads + k] += dw[k];
        p.reg[ArtistReg.lifeStreams + k] += st[k];
        p.reg[ArtistReg.lifeDownloads + k] += dw[k];
      }
      final wr = s.weekRegion ??= Float64List(2 * _r);
      for (var k = 0; k < _r; k++) {
        wr[k] = st[k];
        wr[_r + k] = dw[k];
      }
      s.weekStreams = tS;
      if (bots > 0 && StreamingTools.settleBots(w, s, bots)) {
        botsCaught.add(s.id);
      }
      s.weekDownloads = tD;
      s.weekRadio = tR;
      s.weekPhysical = tP;
      s.lifetimeRadio += tR;
      s.lifetimePhysical += tP;

      final na = Region.northAmerica.index, eu = Region.europe.index;
      final us = CountryShares.usOfNorthAmerica(p.homeCountry);
      final uk = CountryShares.ukOfEurope(p.homeCountry);
      songPts[Charts.usSongs][i] =
          us * pts(rulesUs, ph[na], dw[na], st[na], rd[na]);
      s.weekPtsUs = songPts[Charts.usSongs][i];
      s.weekRadioPtsUs = us * rd[na] / c.songChartRadioDivisor;
      // UK "accelerated decline" (2017+): long-running songs' streams count
      // at a reduced rate.
      final ukStreams = rulesUk.streamFactor > 0 &&
              GameTime.yearOf(w.week) >= 2017 &&
              s.weeksOnChart(Charts.ukSongs) >= 10
          ? st[eu] * 0.5
          : st[eu];
      songPts[Charts.ukSongs][i] =
          uk * pts(rulesUk, ph[eu], dw[eu], ukStreams, rd[eu]);
      songPts[Charts.globalSongs][i] =
          pts(rulesGlobal, tP, tD, tS, 0, radioCounts: false);
      songPts[Charts.platformGlobal][i] = tS;
      songPts[Charts.platformNorthAmerica][i] = st[na];
      songPts[Charts.platformEurope][i] = st[eu];
      // Radio airplay: the US audience of its plays (docs K129).
      songPts[Charts.usRadio][i] = us * rd[na];
      // A song caught with bought streams counts half for a while.
      final weight = StreamingTools.chartWeight(w, s);
      if (weight < 1) {
        for (final ch in songPts) {
          ch[i] *= weight;
        }
        s.weekPtsUs *= weight;
      }
      s.weekPoints = songPts[Charts.globalSongs][i];

      if (!p.isRetired) {
        p.weekPoints += s.weekPoints;
        p.weekReach += s.lastReach;
        p.weekStreams += tS;
      } else {
        w.dirtyArtists.add(p.id);
      }
    }

    // 8. Dormant catalog per active artist (retired artists accrue lazily).
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      for (var k = 0; k < _r; k++) {
        final f = a.catalogFactor * _cap(id, k);
        final share = a.regionShare[k];
        a.reg[ArtistReg.indexStreams + k] += f * share * spa[k];
        a.reg[ArtistReg.indexDownloads + k] += f * share * 0.1 * dpa[k];
        if (a.sumDormantRate > 0) {
          final st = a.sumDormantRate * f * share * spa[k];
          a.weekStreams += st;
          a.weekPoints += st / 400;
          a.reg[ArtistReg.lifeStreams + k] += st;
          a.reg[ArtistReg.lifeDownloads + k] +=
              a.sumDormantRate * f * share * 0.1 * dpa[k];
        }
        a.reg[ArtistReg.settleSpa + k] = w.spaIndex[k];
        a.reg[ArtistReg.settleDpa + k] = w.dpaIndex[k];
      }
    }

    // 9. Albums, per region.
    final debuts = <int>[];
    final albumIds = w.activeAlbumIds;
    final albumPts =
        List.generate(Charts.count, (_) => Float64List(albumIds.length));
    final albumRules = Charts.songRules(ChartMarket.global, w.week);
    final holiday = c.holidaySales(GameTime.weekOfYear(w.week), year);
    for (var ai = 0; ai < albumIds.length; ai++) {
      final al = w.albums[albumIds[ai]];
      final p = w.artists[al.artistId];
      final age = w.week - al.releaseWeek;
      // Good albums hold their sales; weak ones fall off faster.
      final q01 = al.quality / 100;
      // Some records have legs, others are all first week (docs K105):
      // a trait drawn once per album.
      final legs = _albumLegs(al);
      final secondWeek = c.albumSecondWeekRatio * (0.55 + 0.9 * q01) * legs;
      final decay = math.min(0.97,
          1 - (1 - c.albumWeeklyDecay) * (1.5 - 0.7 * q01) / math.sqrt(legs));
      final superCurve = age == 0 ? 1.0 : secondWeek * math.pow(decay, age - 1);
      // Devoted fanbases buy more (and buy variants).
      final superRate = c.superfanBuyRate * p.devotionBuyFactor;
      // Collector copies: each variant released this week (beyond the
      // standard edition) sells extra copies, with diminishing returns.
      var variantSum = 0.0;
      final vw = al.variantWeeks;
      final year = GameTime.yearOf(w.week);
      final tail = c.albumTail(year);
      for (var k = 1; k < vw.length; k++) {
        if (vw[k] == age) {
          variantSum +=
              math.pow(c.variantDecay, k - 1) * al.editionAppeal(k, year);
        }
      }
      final noise =
          RandomStream.keyed(w.seed, w.week, al.id, RngPurpose.albumNoise)
                  .logNormal(0.05) *
              _momentum(al.id, al.releaseWeek, RngPurpose.albumMomentum);
      // Long tracklists sell a little more (more for the money, bundles);
      // each doubling beyond 10 tracks adds [SimConfig.longAlbumBonus].
      final demand = p.tier == ArtistTier.player
          ? w.difficulty.albumDemand
          : w.difficulty.aiAlbumDemand;
      final n = al.songIds.length;
      final tracklist =
          n > 10 ? 1 + c.longAlbumBonus * math.log(n / 10) / math.ln2 : 1.0;

      // Song consumption of this album's tracks, per region.
      final reach = Float64List(_r),
          sea = Float64List(_r),
          tea = Float64List(_r);
      // Singles out before the album earn it units too, but only towards
      // its lifetime total, kept apart from its weekly sales (docs K56).
      final preSea = Float64List(_r), preTea = Float64List(_r);
      // Reach the album campaign brought through its own tracks (docs K57).
      var reachAll = 0.0, reachCampaign = 0.0;
      for (final sid in al.songIds) {
        final i = activeIndex[sid];
        if (i == null) continue;
        final s = w.songs[sid];
        final pre = isPreSingle(s, al);
        reachAll += s.lastReach;
        if (!s.isSingle) reachCampaign += s.lastReach * s.campaignShareOfReach;
        for (var k = 0; k < _r; k++) {
          reach[k] += s.lastReach * p.regionShare[k];
          // Track sales: downloads and CD singles (10 = 1 album).
          final st = streamsR[i * _r + k];
          final tr = downloadsR[i * _r + k] + s.weekPhysical * p.regionShare[k];
          if (pre) {
            preSea[k] += st;
            preTea[k] += tr;
          } else {
            sea[k] += st;
            tea[k] += tr;
          }
        }
      }

      // Album units count track sales in every era (docs K49); streams from
      // 2015. The album charts rank pure sales until units arrive (2015),
      // as Billboard did; so do era scores and popularity.
      var tPure = 0.0, tUnits = 0.0, tTea = 0.0, tSea = 0.0, tChart = 0.0;
      var buysAll = 0.0, buysFromReach = 0.0;
      final chartRegion = Float64List(_r);
      for (var k = 0; k < _r; k++) {
        final era = eras[k];
        final share = p.regionShare[k];
        final fans = p.coreFans * share;
        final casual = p.casual * share;
        final superPart = fans *
            superRate *
            p.kind.albumAffinity *
            era.superfanFactor *
            superCurve *
            (1 + al.hypeAtRelease) *
            (0.5 + q01);
        final collectorPart = variantSum == 0
            ? 0.0
            : fans *
                c.collectorRate *
                p.kind.collector *
                p.devotionCollectorFactor *
                era.collectorFactor *
                variantSum *
                (1 + al.hypeAtRelease);
        // Listeners reached by the album's songs buy it, fewer as the album
        // ages (those who wanted it already have it; docs K51).
        // Gift buying: non-fans buy records in the holidays, catalog too.
        final casPart = holiday *
                reach[k] *
                c.casualBuyRate *
                era.casualPurchaseRate *
                (age == 0 ? 1.5 : 1.0) /
                (1 + age / c.albumReachFatigueWeeks) +
            (age == 0 ? casual * 0.003 * era.casualPurchaseRate : 0.0) +
            holiday *
                casual *
                c.albumCatalogRate *
                era.casualPurchaseRate *
                (0.5 + q01);
        // A superstar's album is an event: even non-fans buy it in the
        // first weeks. Grows steeply with fame (fame³), so it lifts the
        // biggest stars without touching working artists.
        final eventPart = age > 1
            ? 0.0
            : casual *
                c.eventBuyRate *
                p.fame *
                p.fame *
                p.fame *
                era.casualPurchaseRate *
                (1 + al.hypeAtRelease) *
                (age == 0 ? 1.0 : 0.25);
        // From 2013 fans buy in week one and everyone else streams (docs
        // K79): every later week sells less, collector editions aside.
        final later = age == 0 ? 1.0 : tail;
        final bought =
            (superPart + casPart + eventPart) * later + collectorPart;
        buysAll += bought;
        buysFromReach += reach[k] *
            c.casualBuyRate *
            era.casualPurchaseRate *
            later *
            (age == 0 ? 1.5 : 1.0) /
            (1 + age / c.albumReachFatigueWeeks);
        // A mixtape is given away: nothing sold (docs K62).
        // Pre-orders ship in week one (docs K126).
        final pure = al.isMixtape
            ? 0.0
            : bought * noise * tracklist * demand +
                (age == 0
                    ? al.preOrders * share * Actions.preOrderExtra
                    : 0.0);
        final streams = sea[k] +
            al.sumDormantRate *
                p.catalogFactor *
                _cap(p.id, k) *
                share *
                spa[k];
        final t = al.isMixtape ? 0.0 : tea[k] / c.trackEquivalentAlbum;
        final se = streams / c.streamEquivalentAlbum;
        final units = albumRules.albumUsesUnits ? pure + t + se : pure + t;
        chartRegion[k] = albumRules.albumUsesUnits ? units : pure;
        tChart += chartRegion[k];
        al.weekRegion[k] = pure;
        al.weekRegion[_r + k] = units;
        al.reg[AlbumReg.lifePure + k] += pure;
        al.reg[AlbumReg.lifeUnits + k] += units;
        p.reg[ArtistReg.lifePure + k] += pure;
        p.reg[ArtistReg.lifeUnits + k] += units;
        if (age == 0) {
          al.reg[AlbumReg.firstWeekPure + k] = pure;
          al.reg[AlbumReg.firstWeekUnits + k] = units;
        }
        final preUnits = preTea[k] / c.trackEquivalentAlbum +
            (albumRules.albumUsesUnits
                ? preSea[k] / c.streamEquivalentAlbum
                : 0.0);
        al.reg[AlbumReg.lifeUnits + k] += preUnits;
        p.reg[ArtistReg.lifeUnits + k] += preUnits;
        al.preSingleUnits += preUnits;
        tPure += pure;
        tUnits += units;
        tTea += t;
        tSea += se;
      }
      al.campaignShareOfSales = buysAll > 0 && reachAll > 0
          ? buysFromReach / buysAll * reachCampaign / reachAll
          : 0;
      al.weekPure = tPure;
      al.weekTea = tTea;
      al.weekSea = tSea;
      al.weekUnits = tUnits;
      if (p.isRetired) w.dirtyArtists.add(p.id);
      p.weekPoints += tChart * 0.5;
      if (p.eraOpen && p.eraAlbumId == al.id) p.eraUnits += tChart;

      final na = Region.northAmerica.index, eu = Region.europe.index;
      albumPts[Charts.usAlbums][ai] =
          CountryShares.usOfNorthAmerica(p.homeCountry) * chartRegion[na];
      albumPts[Charts.ukAlbums][ai] =
          CountryShares.ukOfEurope(p.homeCountry) * chartRegion[eu];
      albumPts[Charts.globalAlbums][ai] = tChart;

      if (age == 0) {
        al.firstWeekUnits = tUnits;
        al.firstWeekPure = tPure;
        if (al.chartsOnAlbumChart) debuts.add(al.id);
      }
    }

    // 10. Charts.
    final newNo1 = List.generate(Charts.count, (_) => <int>[]);
    final published = List.generate(Charts.count, (_) => const <ChartEntry>[]);
    for (final def in Charts.all) {
      if (!def.activeIn(w.week)) continue;
      published[def.id] = def.kind == ChartKind.songs
          ? _buildChart(def, ids, songPts[def.id], newNo1[def.id])
          : _buildChart(def, albumIds, albumPts[def.id], newNo1[def.id]);
    }
    w.charts = published;

    // 11. Lifecycle transitions.
    _songTransitions(songPts);
    _albumTransitions(albumIds, albumPts);

    // 12. Artist post-step. Popularity is relative to this week's global #1
    // so it does not inflate as markets grow.
    final global = published[Charts.globalSongs];
    final topPoints = global.isEmpty ? 1.0 : global.first.points;
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      final target = 1 - math.exp(-a.weekPoints / (1.5 * topPoints));
      a.popularity +=
          (target > a.popularity ? 0.15 : 0.03) * (target - a.popularity);
      // The player's fame (being known) only grows: a star stays a
      // household name through a long break (docs K44). Rivals' fame
      // slowly fades with their popularity, so the field keeps renewing.
      if (a.popularity > a.fame) {
        // The player becomes known faster than the calibrated rivals: a
        // career is a game, not 30 years of waiting (docs K70).
        final rate =
            a.tier == ArtistTier.player ? c.playerFameRate : c.fameRate;
        a.fame += rate * (a.popularity - a.fame);
      } else if (a.tier != ArtistTier.player) {
        a.fame += 0.002 * (a.popularity - a.fame);
      }
      // Growth saturates: you cannot convert people who are already fans.
      final casualRoom = math.max(0.0, 1 - a.casual / c.casualCap);
      final fanRoom = c.fanRoom(a.coreFans);
      // Charisma: likeable artists turn listeners into fans more easily
      // (×0.8 at 0, ×1.0 at 50, ×1.2 at 100).
      final charm = 0.8 + 0.4 * a.skills.charisma / 100;
      a.casual += c.casualConversion * charm * a.weekReach * casualRoom -
          c.casualDecay * a.casual;
      // A household name's songs mostly reach people who already know
      // them and chose not to be fans (docs K127).
      final conv = charm *
          (1 - 0.5 * a.fame) *
          a.kind.fanConversion *
          (a.tier == ArtistTier.player ? w.difficulty.fanConversion : 1);
      a.coreFans += c.fanConversion * conv * a.weekReach * fanRoom -
          c.coreFanDecay *
              a.kind.fanDecay *
              c.rivalAgeFade(a, w.week) *
              a.coreFans;
      if (a.coreFans < 100) a.coreFans = 100;
      if (a.casual < 1000) a.casual = 1000;
      if (a.eraOpen && w.week - a.eraStartWeek >= c.eraLengthWeeks) {
        Eras.close(w, a);
      }
      // Fame changed: refresh where the audience is (frozen once retired).
      a.updateRegionShare();
    }
    _rankArtists();
    final show = MusicShow.weekly(w, GameTime.yearOf(w.week));
    _playerIncome();
    _fadeCatalogs();
    // Offers between releases (docs K59).
    OpportunityOutcome? lapsed;
    Opportunity? offered;
    Tour? toured;
    FestivalSet? festival;
    final me = w.player;
    // The awards (docs K91): an unanswered invitation means staying home.
    if (me?.opportunity?.kind == OpportunityKind.award &&
        Awards.upcoming(w) != null &&
        GameTime.weekOfYear(w.week) == Awards.ceremonyWeekOfYear) {
      lapsed = Opportunities.answer(w, me!, OpportunityChoice.decline);
    }
    final nominations = Awards.nominate(w);
    final night = Awards.hold(w);
    Social.weekly(w);
    final dealsBroken = Brands.weekly(w);
    if (me != null) {
      toured = Tours.playWeek(w, me);
      if (toured != null) {
        w.tourRecords.add(TourRecord(
          artistId: me.id,
          name: toured.name,
          startWeek: toured.startWeek,
          endWeek: toured.endWeek,
          shows: toured.shows.where((s) => s.played).length,
          tickets: toured.tickets,
          grossCents: toured.grossCents,
        ));
      }
      festival = Festivals.playWeek(w, me);
      if (Opportunities.lapseDue(w, me)) {
        lapsed = Opportunities.answer(w, me, me.opportunity!.lapse);
      }
      offered = Opportunities.roll(w, me);
      if (offered != null) {
        me.opportunity = offered;
        w.dirtyArtists.add(me.id);
      }
    }

    final result = WeekResult(
      week: w.week,
      charts: published,
      albumDebuts: debuts,
      scheduledOut: scheduledOut,
      newNumberOnes: newNo1,
      viralSongs: virals,
      playlistAdds: playlistAdds,
      botsCaught: botsCaught,
      activeSongs: w.activeSongIds.length,
      activeAlbums: w.activeAlbumIds.length,
      dormantSongs: w.dormantSongCount,
      microseconds: sw.elapsedMicroseconds,
      newOpportunity: offered,
      lapsedOpportunity: lapsed,
      tourFinished: toured,
      festivalSet: festival,
      awardNominations: nominations,
      awardNight: night,
      brandDealsBroken: dealsBroken,
      rivalClashes: clashes,
      musicShow: show,
    );
    w.week++;
    return result;
  }

  /// Collector sales of a single's physical editions this week, per region
  /// (docs K92): fans buy an edition mostly in its week; several in the
  /// same week sell less each.
  void _variantSales(Song s, Artist p, List<EraValues> eras, Float64List out) {
    out.fillRange(0, _r, 0);
    if (s.variants.isEmpty) return;
    final w = world;
    final year = GameTime.yearOf(w.week);
    var sum = 0.0;
    final sameWeek = <int, int>{};
    for (final (f, week) in s.variants) {
      final age = w.week - week;
      if (age < 0 || age > 3) continue;
      final k = sameWeek[week] = (sameWeek[week] ?? -1) + 1;
      sum += f.appeal(year) *
          math.pow(w.config.variantDecay, k) *
          const [1.0, 0.3, 0.1, 0.03][age];
    }
    if (sum == 0) return;
    for (var k = 0; k < _r; k++) {
      out[k] = p.coreFans *
          p.regionShare[k] *
          w.config.singleCollectorRate *
          p.kind.collector *
          p.devotionCollectorFactor *
          eras[k].collectorFactor *
          sum *
          (1 + p.hype);
    }
  }

  /// Ranks [entityIds] by [points] and updates per-chart stats.
  List<ChartEntry> _buildChart(
      ChartDef def, List<int> entityIds, Float64List points, List<int> newNo1) {
    final w = world;
    final c = w.config;
    // Recurrent rules can skip entries, so keep a margin of candidates.
    final need = def.recurrent ? def.size * 2 : def.size;
    var order = _topOrder(points, entityIds, need);
    if (def.recurrent && order.length < entityIds.length) {
      // Fall back to a full ranking if skipped entries could leave gaps.
      var skippable = 0;
      for (final i in order) {
        final Charted e = def.kind == ChartKind.songs
            ? w.songs[entityIds[i]]
            : w.albums[entityIds[i]];
        if (e.weeksOnChart(def.id) >= c.recurrentWeeks) skippable++;
      }
      if (order.length - skippable < def.size) {
        order = _topOrder(points, entityIds, entityIds.length);
      }
    }
    final isSongs = def.kind == ChartKind.songs;
    final chart = <ChartEntry>[];
    final charted = <int>{};
    for (final i in order) {
      if (chart.length >= def.size) break;
      final pts = points[i];
      if (pts <= 0) break;
      final id = entityIds[i];
      final Charted e = isSongs ? w.songs[id] : w.albums[id];
      final pos = chart.length + 1;
      if (def.recurrent &&
          e.weeksOnChart(def.id) >= c.recurrentWeeks &&
          pos > c.recurrentPosition) {
        continue;
      }
      final st = e.stats(def.id);
      final last = st.lastPos;
      st.weeksOn++;
      if (st.peak == 0 || pos < st.peak) st.peak = pos;
      if (st.weeksOn == 1) st.debutPos = pos;
      if (pos == 1) {
        st.weeksAtNo1++;
        _numberOne(def, id, st.weeksAtNo1 == 1, newNo1);
      }
      st.lastPos = pos;
      charted.add(id);
      chart.add(ChartEntry(
          position: pos,
          entityId: id,
          points: pts,
          lastPos: last,
          peak: st.peak,
          weeksOn: st.weeksOn));
    }
    for (final id in entityIds) {
      if (charted.contains(id)) continue;
      final Charted e = isSongs ? w.songs[id] : w.albums[id];
      e.statsOrNull(def.id)?.lastPos = 0;
    }
    w.chartCutoff[def.id] = chart.isEmpty ? 0 : chart.last.points;
    return chart;
  }

  /// Indices of the top [k] entries by points (desc, then id asc), using
  /// quickselect so only the top part is sorted.
  static List<int> _topOrder(Float64List points, List<int> ids, int k) {
    final n = points.length;
    List<int> idx;
    if (n > 2 * k && k > 0) {
      final tmp = Float64List.fromList(points);
      final threshold = _kthLargest(tmp, k);
      idx = [
        for (var i = 0; i < n; i++)
          if (points[i] >= threshold) i,
      ];
    } else {
      idx = List<int>.generate(n, (i) => i);
    }
    idx.sort((x, y) {
      final d = points[y].compareTo(points[x]);
      return d != 0 ? d : ids[x].compareTo(ids[y]);
    });
    return idx;
  }

  /// k-th largest value (1-based) via deterministic quickselect; reorders [a].
  static double _kthLargest(Float64List a, int k) {
    var lo = 0, hi = a.length - 1;
    final target = a.length - k; // index in ascending order
    while (lo < hi) {
      final mid = lo + ((hi - lo) >> 1);
      // Median of three as pivot.
      final x = a[lo], y = a[mid], z = a[hi];
      final pivot =
          x < y ? (y < z ? y : (x < z ? z : x)) : (x < z ? x : (y < z ? z : y));
      var i = lo, j = hi;
      while (i <= j) {
        while (a[i] < pivot) {
          i++;
        }
        while (a[j] > pivot) {
          j--;
        }
        if (i <= j) {
          final t = a[i];
          a[i] = a[j];
          a[j] = t;
          i++;
          j--;
        }
      }
      if (target <= j) {
        hi = j;
      } else if (target >= i) {
        lo = i;
      } else {
        break;
      }
    }
    return a[target];
  }

  void _numberOne(ChartDef def, int id, bool first, List<int> newNo1) {
    final w = world;
    if (def.kind == ChartKind.songs) {
      final s = w.songs[id];
      final p = w.artists[s.primaryArtistId];
      p.weeksAtNo1[def.id]++;
      w.dirtyArtists.add(p.id);
      if (first) {
        newNo1.add(id);
        p.no1Singles[def.id]++;
        for (final f in s.featuredArtistIds) {
          w.artists[f].no1SinglesFeatured[def.id]++;
          w.dirtyArtists.add(f);
        }
      }
    } else if (first) {
      final al = w.albums[id];
      newNo1.add(id);
      w.artists[al.artistId].no1Albums[def.id]++;
      w.dirtyArtists.add(al.artistId);
    }
  }

  /// A song stays active while it is near the cut-off of any main chart.
  void _songTransitions(List<Float64List> pts) {
    final w = world;
    final c = w.config;
    final toDormant = <int>[];
    final ids = w.activeSongIds;
    for (var i = 0; i < ids.length; i++) {
      final s = w.songs[ids[i]];
      final promoAge = w.week - (s.isSingle ? s.singleWeek : s.releasedWeek);
      if (promoAge < c.activeMinAgeWeeks) continue;
      var near = false;
      for (final ch in Charts.mainSongCharts) {
        if (pts[ch][i] >= c.dormantShareOfCutoff * w.chartCutoff[ch] &&
            w.chartCutoff[ch] > 0) {
          near = true;
          break;
        }
      }
      if (!near) {
        s.weeksBelowCutoff++;
        if (s.weeksBelowCutoff >= 4) toDormant.add(ids[i]);
      } else {
        s.weeksBelowCutoff = 0;
      }
    }
    for (final id in toDormant) {
      Lifecycle.makeSongDormant(w, w.songs[id]);
    }
  }

  void _albumTransitions(List<int> albumIds, List<Float64List> pts) {
    final w = world;
    final c = w.config;
    final toDormant = <int>[];
    for (var i = 0; i < albumIds.length; i++) {
      final al = w.albums[albumIds[i]];
      if (w.week - al.releaseWeek < c.activeMinAgeWeeks) continue;
      var near = false;
      for (final ch in Charts.mainAlbumCharts) {
        if (pts[ch][i] >= c.albumDormantShareOfCutoff * w.chartCutoff[ch] &&
            w.chartCutoff[ch] > 0) {
          near = true;
          break;
        }
      }
      if (!near) {
        al.weeksBelowCutoff++;
        if (al.weeksBelowCutoff >= 6) toDormant.add(albumIds[i]);
      } else {
        al.weeksBelowCutoff = 0;
      }
    }
    for (final id in toDormant) {
      Lifecycle.makeAlbumDormant(w, w.albums[id]);
    }
  }

  /// Starts a viral trend: it grows for three weeks, then fades. Most trends
  /// are small; a few become huge and can push a song up the charts.
  /// A single's run on the radio: builds over its first weeks, then fades.
  static double _radioLife(Song s, int promoAge) =>
      (1 - math.exp(-(promoAge + 1) / (s.riseWeeks + 3))) *
      math.exp(-promoAge / (s.lifeWeeks + 10));

  /// A song's promotion run (new listeners), before its catalog tail.
  static double _promoLife(Song s, int promoAge) =>
      (1 - math.exp(-(promoAge + 1) / s.riseWeeks)) *
      math.exp(-promoAge / s.lifeWeeks);

  /// Fans stream hard at release, then settle to a floor that fades over
  /// ~2 years.
  static double _fanCurve(SimConfig c, int ageRel) {
    final floor = c.fanCurveFloor * math.exp(-ageRel / 104.0);
    return floor +
        (1 - floor) * math.pow(0.5, ageRel / c.fanCurveHalfLifeWeeks);
  }

  /// A campaign's lift on exposure for an artist this famous: the lift
  /// above no campaign shrinks to half at full fame (docs K81).
  static double _knownCampaign(double lift, double fame) =>
      lift <= 1 ? lift : 1 + (lift - 1) * (1 - 0.5 * fame.clamp(0.0, 1.0));

  void _startViral(Song s, RandomStream r, double era, {double reach = 1}) {
    var strength = r.range(0.02, 0.08) *
        (0.5 + s.virality) *
        (0.4 + 0.6 * math.min(1.0, reach));
    if (r.chance(world.config.megaViralChance)) strength *= r.range(3, 6);
    s.viralBoost = math.max(s.viralBoost, strength * era / 2.7);
    s.viralRamp = 3;
  }

  /// Old catalog songs going viral on short-video platforms. Selection is
  /// flattened (sqrt) so lesser-known artists' songs can blow up too, and
  /// favours songs with viral potential.
  List<int> _viralRevivals() {
    final w = world;
    final c = w.config;
    final r = RandomStream.keyed(w.seed, w.week, -1, RngPurpose.viral);
    final era = c.viralEraFactor(GameTime.yearOf(w.week));
    final revived = <int>[];
    for (var attempt = 0; attempt < 2; attempt++) {
      if (!r.chance(math.min(1.0, c.viralRevivalChance * era / 2))) continue;
      var total = 0.0;
      for (final a in w.artists) {
        if (a.sumDormantRate > 0) total += math.sqrt(a.sumDormantRate);
      }
      if (total <= 0) break;
      var pick = r.nextDouble() * total;
      Artist? chosen;
      for (final a in w.artists) {
        if (a.sumDormantRate <= 0) continue;
        pick -= math.sqrt(a.sumDormantRate);
        if (pick <= 0) {
          chosen = a;
          break;
        }
      }
      if (chosen == null || chosen.dormantSongIds.isEmpty) continue;
      final ids = List.of(chosen.dormantSongIds)..sort();
      var weight = 0.0;
      for (final id in ids) {
        final v = 0.2 + w.songs[id].virality;
        weight += v * v;
      }
      var x = r.nextDouble() * weight;
      var song = w.songs[ids.last];
      for (final id in ids) {
        final v = 0.2 + w.songs[id].virality;
        x -= v * v;
        if (x <= 0) {
          song = w.songs[id];
          break;
        }
      }
      Lifecycle.reactivateSong(w, song);
      song.weeksBelowCutoff = 0;
      _startViral(song, r, era);
      revived.add(song.id);
    }
    return revived;
  }

  /// The player's albums that left the active set still earn album units
  /// from their tracks' streams (SEA) in the units era, so career totals
  /// match "every stream counts" (AI catalogs skip this for speed; they
  /// only matter for charts, which use the active set).
  void _retroactiveAlbumUnits() {
    final w = world;
    final c = w.config;
    for (final al in w.albums) {
      if (al.releaseWeek >= w.week) continue;
      final a = w.artists[al.artistId];
      for (var k = 0; k < _r; k++) {
        // A catalog album's lazy accrual starts now; its earlier streams
        // come in below with everything else.
        if (al.status == AlbumStatus.dormant) {
          al.reg[AlbumReg.indexStreams + k] = w.artistIndexStreams(a, k);
        }
        var streams = 0.0, pre = 0.0;
        for (final sid in al.songIds) {
          final s = w.songs[sid];
          final st = w.songLifetimeStreams(s, k);
          streams += st;
          if (isPreSingle(s, al)) pre += st;
        }
        // Track sales already counted week by week (docs K49).
        final units = streams / c.streamEquivalentAlbum;
        al.reg[AlbumReg.lifeUnits + k] += units;
        a.reg[ArtistReg.lifeUnits + k] += units;
        al.preSingleUnits += pre / c.streamEquivalentAlbum;
      }
      w.dirtyAlbums.add(al.id);
      w.dirtyArtists.add(a.id);
    }
  }

  /// How often each artist's catalog fades (a batch of weeks at a time).
  static const catalogFadeWeeks = 13;

  /// A catalog song this quiet stops being tracked (its listeners are
  /// gone): the fade then has nothing left to do for it.
  static const catalogGoneRate = 20000.0;

  /// Old songs fade (docs K58, K85), everyone's: people keep coming back to
  /// the hits, an album's other tracks are forgotten within a few years.
  /// A top-10 single loses 12% of its listeners a year in its first decade
  /// and 3% after (the classics stay); other singles and charting album
  /// tracks 25% a year; the rest 45%. Each song's lifetime so far is
  /// settled first, then its rate drops.
  void _fadeCatalogs() {
    final w = world;
    final c = w.config;
    // A thirteenth of the artists each week, so the work (and the songs
    // to save) is spread evenly.
    final turn = w.week % catalogFadeWeeks;
    for (final a in w.artists) {
      if (a.dormantSongIds.isEmpty || a.id % catalogFadeWeeks != turn) {
        continue;
      }
      w.settleRetired(a);
      var dropped = 0.0;
      // In id order: the list's order differs after loading a save, and
      // the sums must come out the same to the last bit.
      for (final id in a.dormantSongIds.toList()..sort()) {
        final s = w.songs[id];
        if (s.dormantRate <= 0) continue;
        final years = (w.week - s.releasedWeek) / GameTime.weeksPerYear;
        final perYear = c.catalogFadePerYear(Lifecycle.catalogWeight(s), years);
        var rate = s.dormantRate *
            math.pow(1 - perYear, catalogFadeWeeks / GameTime.weeksPerYear);
        if (rate < catalogGoneRate) rate = 0;
        final drop = s.dormantRate - rate;
        if (drop <= 0) continue;
        for (var r = 0; r < regionCount; r++) {
          s.reg[SongReg.lifeStreams + r] = w.songLifetimeStreams(s, r);
          s.reg[SongReg.lifeDownloads + r] = w.songLifetimeDownloads(s, r);
          s.reg[SongReg.indexStreams + r] = w.artistIndexStreams(a, r);
          s.reg[SongReg.indexDownloads + r] = w.artistIndexDownloads(a, r);
        }
        s.dormantRate = rate;
        dropped += drop;
        if (s.albumId >= 0) {
          final al = w.albums[s.albumId];
          Lifecycle.settleAlbum(w, al);
          al.sumDormantRate = math.max(0.0, al.sumDormantRate - drop);
        }
        w.dirtySongs.add(id);
      }
      if (dropped <= 0) continue;
      a.sumDormantRate = math.max(0.0, a.sumDormantRate - dropped);
      if (a.isRetired) {
        for (var r = 0; r < regionCount; r++) {
          w.retiredDormantAttention[r] = math.max(
              0.0,
              w.retiredDormantAttention[r] -
                  dropped * a.catalogFactor * a.regionShare[r]);
        }
      }
      w.dirtyArtists.add(a.id);
    }
  }

  /// No artist reaches more than a few per cent of a market (docs K105):
  /// each artist's listening beyond their fans in a region is compared
  /// with everyone else's (other artists and the outside market) and bent
  /// towards [SimConfig.marketShareCap]. Reach shrinks with it, so a
  /// superstar's audience stops feeding on its own size; fans flooding a
  /// new album are left alone (a record week can still take more). The
  /// back catalog counts and is bent the same way.
  void _capMarketShare(
      List<int> ids,
      Float64List att,
      Float64List dl,
      Float64List songAttention,
      Float64List fanFrac,
      Float64List sumA,
      Float64List sumD,
      Float64List sumSingles) {
    final w = world;
    final c = w.config;
    final n = ids.length;
    _capFactor.clear();
    // Per artist and region: all their listening, and the part beyond
    // their fans flooding new releases (the rest of the active songs and
    // the whole back catalog).
    final byArtist = <int, Float64List>{};
    for (var i = 0; i < n; i++) {
      final id = w.songs[ids[i]].primaryArtistId;
      final t = byArtist.putIfAbsent(id, () => Float64List(2 * _r));
      for (var k = 0; k < _r; k++) {
        final a = att[i * _r + k];
        t[k] += a;
        t[_r + k] += a * (1 - fanFrac[i]);
      }
    }
    final allDormant = Float64List(_r);
    for (var k = 0; k < _r; k++) {
      allDormant[k] = w.retiredDormantAttention[k];
    }
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      if (a.sumDormantRate <= 0) continue;
      final t = byArtist.putIfAbsent(id, () => Float64List(2 * _r));
      for (var k = 0; k < _r; k++) {
        final d = a.sumDormantRate * a.catalogFactor * a.regionShare[k];
        t[k] += d;
        t[_r + k] += d;
        allDormant[k] += d;
      }
    }
    byArtist.forEach((id, t) {
      Float64List? f;
      for (final region in Region.values) {
        final k = region.index;
        final reach = t[_r + k];
        if (reach <= 0) continue;
        final ema = w.emaAttention[k] == 0 ? sumA[k] : w.emaAttention[k];
        final rest = sumA[k] +
            allDormant[k] -
            t[k] +
            regionConfigs[region]!.outsideAttention * ema +
            1;
        final x = reach / rest;
        final dbg = debugParts;
        if (dbg != null && id == w.playerArtistId) dbg['x$k'] = x * 1e6;
        if (dbg != null && w.artists[id].tier != ArtistTier.player) {
          dbg['maxRivalX$k'] = math.max(dbg['maxRivalX$k'] ?? 0, x * 1e6);
        }
        if (x <= c.marketShareKnee) continue;
        f ??= Float64List(_r)..fillRange(0, _r, 1.0);
        f[k] = c.cappedMarketShare(x) / x;
      }
      if (f != null) _capFactor[id] = f;
    });
    for (var i = 0; _capFactor.isNotEmpty && i < n; i++) {
      final s = w.songs[ids[i]];
      final f = _capFactor[s.primaryArtistId];
      if (f == null) continue;
      final p = w.artists[s.primaryArtistId];
      final out = 1 - fanFrac[i];
      var mean = 0.0;
      for (var k = 0; k < _r; k++) {
        final j = i * _r + k;
        final cut = att[j] * out * (1 - f[k]);
        sumA[k] -= cut;
        if (s.isSingle) sumSingles[k] -= cut;
        att[j] -= cut;
        final dcut = dl[j] * out * (1 - f[k]);
        sumD[k] -= dcut;
        dl[j] -= dcut;
        mean += p.regionShare[k] * f[k];
      }
      final kept = fanFrac[i] + out * mean;
      songAttention[i] *= kept;
      s.lastAttention *= kept;
      s.lastReach *= mean;
    }
    // One song takes at most a sliver of everyone's listening (docs
    // K127): beyond its fans a smash bends like an artist does, so the
    // biggest songs of the week stay within reach of each other.
    final dbg = debugParts;
    for (var i = 0; i < n; i++) {
      final s = w.songs[ids[i]];
      final out = 1 - fanFrac[i];
      if (out <= 0) continue;
      final p = w.artists[s.primaryArtistId];
      var mean = 0.0;
      var cutAny = false;
      for (final region in Region.values) {
        final k = region.index;
        final j = i * _r + k;
        final reach = att[j] * out;
        var f = 1.0;
        if (reach > 0) {
          final ema = w.emaAttention[k] == 0 ? sumA[k] : w.emaAttention[k];
          final rest = sumA[k] +
              allDormant[k] -
              att[j] +
              regionConfigs[region]!.outsideAttention * ema +
              1;
          final x = reach / rest;
          if (dbg != null) {
            final key = p.tier == ArtistTier.player ? 'songX$k' : 'rivalSongX$k';
            dbg[key] = math.max(dbg[key] ?? 0, x * 1e6);
          }
          if (x > c.songShareKnee) {
            f = c.cappedSongShare(x) / x;
            final cut = reach * (1 - f);
            sumA[k] -= cut;
            if (s.isSingle) sumSingles[k] -= cut;
            att[j] -= cut;
            final dcut = dl[j] * out * (1 - f);
            sumD[k] -= dcut;
            dl[j] -= dcut;
            cutAny = true;
          }
        }
        mean += p.regionShare[k] * f;
      }
      if (!cutAny) continue;
      final kept = fanFrac[i] + out * mean;
      songAttention[i] *= kept;
      s.lastAttention *= kept;
      s.lastReach *= mean;
    }
  }

  /// A song's or album's run of luck (docs K106): this week's shock plus
  /// fading echoes of the last seven, so its numbers drift up or down for
  /// weeks instead of jittering around a smooth curve.
  double _momentum(int id, int released, int purpose) {
    final w = world;
    var m = 0.0, weight = 1.0;
    for (var j = 0; j < 8; j++) {
      final week = w.week - j;
      if (week < released) break;
      final u = keyedUnit(w.seed, week, id, purpose);
      m += weight * (u - 0.5);
      weight *= 0.75;
    }
    // (u − 0.5) has a deviation of 0.29; the echoes add up to about 1.5×.
    return math.exp(w.config.momentumSigma / 0.29 / 1.47 * m);
  }

  /// How much [s] connects with listeners beyond its fans (docs K127):
  /// a hidden draw per song, so quality makes a hit likely, not certain.
  static double resonance(World w, Song s) =>
      (w.config.resonanceMedian *
              RandomStream.keyed(w.seed, 0, s.id, RngPurpose.resonance)
                  .logNormal(w.config.resonanceSigma))
          .clamp(0.2, 2.5);

  /// How well [al] holds on after its first week, around 1.
  double _albumLegs(Album al) =>
      RandomStream.keyed(world.seed, 0, al.id, RngPurpose.albumLegs)
          .logNormal(world.config.albumLegsSigma)
          .clamp(0.5, 2.0);

  /// Size of the top artists chart (docs K113).
  static const artistChartSize = 100;

  /// The top artists this week by their songs' and catalog's chart points
  /// (docs K113), keeping last week's for the movement.
  void _rankArtists() {
    final w = world;
    final ranked = [
      for (final id in w.activeArtistIds)
        if (w.artists[id].weekPoints > 0) id
    ]..sort((x, y) {
        final d = w.artists[y].weekPoints.compareTo(w.artists[x].weekPoints);
        return d != 0 ? d : x.compareTo(y);
      });
    w.artistChartPrev = w.artistChart;
    w.artistChart = List.unmodifiable(ranked.take(artistChartSize));
    final mine = w.artistChart.indexOf(w.playerArtistId) + 1;
    if (mine > 0) {
      if (w.playerBestArtistRank == 0 || mine < w.playerBestArtistRank) {
        w.playerBestArtistRank = mine;
      }
      if (mine == 1) w.playerWeeksTopArtist++;
    }
  }

  void _playerIncome() {
    final p = world.player;
    if (p == null) return;
    var cents = 0.0;
    for (final id in world.activeSongIds) {
      final s = world.songs[id];
      if (s.primaryArtistId != p.id) continue;
      final songCents = s.weekStreams *
              0.35 *
              s.autoplay.royalty +
          s.weekDownloads * 70 +
          s.weekPhysical * 100;
      cents += songCents;
      s.revenueCents += songCents * p.artistShare;
      // Campaign profit/loss (docs K57): album cuts earn for the album's
      // campaign, singles for their own.
      final back = songCents * p.artistShare * s.campaignShareOfAttention;
      if (!s.isSingle && s.albumId >= 0) {
        world.albums[s.albumId].campaignReturnCents += back;
        world.dirtyAlbums.add(s.albumId);
      } else {
        s.campaignReturnCents += back;
      }
    }
    // Catalog songs keep streaming (and paying) after they leave the active
    // set.
    for (final id in world.playerSongIds) {
      final s = world.songs[id];
      if (s.status != SongStatus.dormant) continue;
      var songCents = 0.0;
      for (var r = 0; r < regionCount; r++) {
        songCents += world.songWeekStreamsRegion(s, r) *
            0.35 *
            s.autoplay.royalty;
      }
      cents += songCents;
      s.revenueCents += songCents * p.artistShare;
      world.dirtySongs.add(id);
    }
    for (final id in world.activeAlbumIds) {
      final al = world.albums[id];
      if (al.artistId != p.id) continue;
      cents += al.weekPure * 600;
      al.revenueCents += al.weekPure * 600 * p.artistShare;
      al.campaignReturnCents +=
          al.weekPure * 600 * p.artistShare * al.campaignShareOfSales;
    }
    // The manager takes a cut of everything (docs K68).
    // The advance is paid back first (docs K107).
    p.moneyCents +=
        p.manager.net(Contracts.recoup(p, cents * p.artistShare)).round();
    // The label takes no cut of the day job.
    p.moneyCents += p.job.wageCents;
    Actions.grantSkillPoints(p, Actions.skillPointsPerWeek);
    // Side benefits of some jobs (docs K36).
    final s = p.skills;
    switch (p.job) {
      case Job.musicTeacher:
        s.vocals += 0.08 * (1 - s.vocals / 100);
        s.performance += 0.05 * (1 - s.performance / 100);
      case Job.studioAssistant:
        s.production += 0.12 * (1 - s.production / 100);
      case Job.barGigs:
        Audience.addFans(world, p, 40);
        Audience.addCasual(world, p, 300);
      case Job.none || Job.cafe || Job.nightShift:
        break;
    }
  }
}
