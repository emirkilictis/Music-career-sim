import 'dart:math' as math;
import 'dart:typed_data';

import 'actions.dart';
import 'ai.dart';
import 'config/charts.dart';
import 'config/era_table.dart';
import 'config/regions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'rng.dart';
import 'world.dart';

/// Summary of one simulated week (what the UI/CLI needs; not the whole world).
class WeekResult {
  WeekResult({
    required this.week,
    required this.charts,
    required this.albumDebuts,
    required this.newNumberOnes,
    required this.activeSongs,
    required this.activeAlbums,
    required this.dormantSongs,
    required this.microseconds,
  });

  final int week;

  /// Published charts by chart id (empty for charts not active yet).
  final List<List<ChartEntry>> charts;

  /// Albums released this week (ids).
  final List<int> albumDebuts;

  /// Entities reaching #1 for the first time, by chart id.
  final List<List<int>> newNumberOnes;
  final int activeSongs;
  final int activeAlbums;
  final int dormantSongs;
  final int microseconds;

  List<ChartEntry> get songChart => charts[Charts.usSongs];
  List<ChartEntry> get albumChart => charts[Charts.usAlbums];
}

/// Runs the weekly pipeline (docs/simulation.md §2) over three regions
/// (docs/game-design.md §11.1).
class Simulator {
  Simulator(this.world);

  final World world;

  static const _r = regionCount;

  WeekResult step() {
    final sw = Stopwatch()..start();
    final w = world;
    final c = w.config;
    final eras = w.regionalEra.forWeek(w.week);

    // 1–2. Scheduled AI activity.
    AiPlanner.step(w);

    // 3. Viral reactivation of a dormant catalog song (event based).
    _viralReactivation();

    // 4. Artist pre-step (active artists only).
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      a.weekPoints = 0;
      a.weekReach = 0;
      a.weekStreams = 0;
      a.hype *= 0.92;
      // Fanbases slowly drift unless renewed by successful eras.
      a.devotion = math.max(0.0, a.devotion - 0.0002);
      a.buzz *= 0.75;
      a.flopSupport *= 0.97;
      if (!a.eraOpen && a.anticipationCap > 0) {
        a.anticipation +=
            (a.anticipationCap - a.anticipation) * c.anticipationBuildRate;
      }
      if (a.lastWriteWeek != w.week) {
        a.creativeEnergy = math.min(100, a.creativeEnergy + 12);
      }
    }

    // 5. Raw demand for active songs, split by region.
    final ids = w.activeSongIds;
    final n = ids.length;
    final att = Float64List(n * _r);
    final dl = Float64List(n * _r);
    final radio = Float64List(n * _r);
    final sumA = Float64List(_r), sumD = Float64List(_r);
    final sumR = Float64List(_r), sumSingles = Float64List(_r);
    final activeIndex = <int, int>{};
    for (var i = 0; i < n; i++) {
      final s = w.songs[ids[i]];
      activeIndex[s.id] = i;
      final p = w.artists[s.primaryArtistId];
      final r =
          RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.weeklyNoise);

      final ageRel = w.week - s.releasedWeek;
      final promoAge = s.isSingle ? w.week - s.singleWeek : ageRel;
      // Fans stream hard at release, then settle to a floor that fades over ~2 years.
      final fanFloor = c.fanCurveFloor * math.exp(-ageRel / 104.0);
      final fanCurve = fanFloor +
          (1 - fanFloor) * math.pow(0.5, ageRel / c.fanCurveHalfLifeWeeks);
      final tail = c.catalogTail * (0.5 + s.longevity);
      final life = (1 - math.exp(-(promoAge + 1) / s.riseWeeks)) *
              math.exp(-promoAge / s.lifeWeeks) +
          tail;
      final promo = s.isSingle ? c.singleExposure : c.albumTrackExposure;
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

      // Viral spark.
      s.viralBoost *= 0.85;
      if (r.chance(c.viralWeeklyChance * (0.3 + 2 * s.virality))) {
        s.viralBoost += r.range(0.02, 0.10) * (0.5 + s.virality);
      }

      // Chart feedback favours the very top (playlists, radio adds, press);
      // the best position on any main song chart counts.
      var chartShape = 0.0;
      for (final ch in Charts.mainSongCharts) {
        final pos = s.lastPosOn(ch);
        if (pos > 0) chartShape = math.max(chartShape, 1 - (pos - 1) / 100);
      }
      final chartBoost = c.chartFeedback * chartShape * chartShape;
      final exposure = (c.baseExposure +
              c.fameExposure * p.fame +
              chartBoost +
              s.viralBoost +
              0.02 * p.buzz) *
          promo *
          p.labelReach *
          (1 + 0.5 * p.hype);
      final qMult = 0.35 + 0.65 * math.pow(s.quality / 100, 1.4);

      final fanPart = fans * s.fanAppeal * fanCurve * (1 + p.hype);
      final casPart = cas * s.commercial * life * (0.05 + 0.15 * promo);
      final pubPart = c.publicPool * s.commercial * life * exposure;
      final noise = r.logNormal(0.10);
      final a = (fanPart + casPart + pubPart) * qMult * noise * trackShare;
      s.lastAttention = a;
      s.lastReach = (casPart + pubPart) * qMult * trackShare;

      final fresh = math.exp(-promoAge / 6.0);
      final d = a * (0.25 + fresh) * (s.isSingle ? 1.0 : 0.5);
      final radioLife = (1 - math.exp(-(promoAge + 1) / (s.riseWeeks + 3))) *
          math.exp(-promoAge / (s.lifeWeeks + 10));
      final rd = s.radioAppeal *
          radioLife *
          (s.isSingle ? 1.0 : 0.03) *
          (0.2 + p.fame) *
          p.labelReach *
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

    // Dormant catalog attention: active artists + frozen retired totals.
    for (var k = 0; k < _r; k++) {
      var dormant = w.retiredDormantAttention[k];
      for (final id in w.activeArtistIds) {
        final a = w.artists[id];
        if (a.sumDormantRate > 0) {
          dormant += a.sumDormantRate * a.catalogFactor * a.regionShare[k];
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
    for (var i = 0; i < n; i++) {
      final s = w.songs[ids[i]];
      final p = w.artists[s.primaryArtistId];
      var tS = 0.0, tD = 0.0, tR = 0.0, tP = 0.0;
      for (var k = 0; k < _r; k++) {
        final j = i * _r + k;
        st[k] = att[j] * spa[k];
        dw[k] = dl[j] * dpa[k];
        rd[k] = radio[j] * rpr[k];
        ph[k] = s.isSingle ? att[j] * ppa[k] : 0;
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
      s.weekDownloads = tD;
      s.weekRadio = tR;
      s.weekPhysical = tP;
      s.lifetimeRadio += tR;

      final na = Region.northAmerica.index, eu = Region.europe.index;
      final us = CountryShares.usOfNorthAmerica(p.homeCountry);
      final uk = CountryShares.ukOfEurope(p.homeCountry);
      songPts[Charts.usSongs][i] =
          us * pts(rulesUs, ph[na], dw[na], st[na], rd[na]);
      songPts[Charts.ukSongs][i] =
          uk * pts(rulesUk, ph[eu], dw[eu], st[eu], rd[eu]);
      songPts[Charts.globalSongs][i] =
          pts(rulesGlobal, tP, tD, tS, 0, radioCounts: false);
      songPts[Charts.platformGlobal][i] = tS;
      songPts[Charts.platformNorthAmerica][i] = st[na];
      songPts[Charts.platformEurope][i] = st[eu];
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
      final f = a.catalogFactor;
      for (var k = 0; k < _r; k++) {
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
    for (var ai = 0; ai < albumIds.length; ai++) {
      final al = w.albums[albumIds[ai]];
      final p = w.artists[al.artistId];
      final age = w.week - al.releaseWeek;
      // Good albums hold their sales; weak ones fall off faster.
      final q01 = al.quality / 100;
      final secondWeek = c.albumSecondWeekRatio * (0.55 + 0.9 * q01);
      final decay = 1 - (1 - c.albumWeeklyDecay) * (1.6 - 1.2 * q01);
      final superCurve = age == 0 ? 1.0 : secondWeek * math.pow(decay, age - 1);
      // Devoted fanbases buy more (and buy variants).
      final superRate = c.superfanBuyRate * p.devotionBuyFactor;
      // Collector copies: each variant released this week (beyond the
      // standard edition) sells extra copies, with diminishing returns.
      var variantSum = 0.0;
      final vw = al.variantWeeks;
      for (var k = 1; k < vw.length; k++) {
        if (vw[k] == age) variantSum += math.pow(c.variantDecay, k - 1);
      }
      final noise =
          RandomStream.keyed(w.seed, w.week, al.id, RngPurpose.albumNoise)
              .logNormal(0.08);

      // Song consumption of this album's tracks, per region.
      final reach = Float64List(_r),
          sea = Float64List(_r),
          tea = Float64List(_r);
      for (final sid in al.songIds) {
        final i = activeIndex[sid];
        if (i == null) continue;
        final s = w.songs[sid];
        for (var k = 0; k < _r; k++) {
          reach[k] += s.lastReach * p.regionShare[k];
          sea[k] += streamsR[i * _r + k];
          tea[k] += downloadsR[i * _r + k];
        }
      }

      var tPure = 0.0, tUnits = 0.0, tTea = 0.0, tSea = 0.0;
      for (var k = 0; k < _r; k++) {
        final era = eras[k];
        final share = p.regionShare[k];
        final fans = p.coreFans * share;
        final casual = p.casual * share;
        final superPart = fans *
            superRate *
            era.superfanFactor *
            superCurve *
            (1 + al.hypeAtRelease) *
            (0.5 + q01);
        final collectorPart = variantSum == 0
            ? 0.0
            : fans *
                c.collectorRate *
                p.devotionCollectorFactor *
                era.collectorFactor *
                variantSum *
                (1 + al.hypeAtRelease);
        final casPart = reach[k] *
                c.casualBuyRate *
                era.casualPurchaseRate *
                (age == 0 ? 1.5 : 1.0) +
            (age == 0 ? casual * 0.003 * era.casualPurchaseRate : 0.0) +
            casual * c.albumCatalogRate * era.casualPurchaseRate * (0.5 + q01);
        final pure = (superPart + collectorPart + casPart) * noise;
        final streams =
            sea[k] + al.sumDormantRate * p.catalogFactor * share * spa[k];
        final t = tea[k] / c.trackEquivalentAlbum;
        final se = streams / c.streamEquivalentAlbum;
        final units = albumRules.albumUsesUnits ? pure + t + se : pure;
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
        tPure += pure;
        tUnits += units;
        tTea += t;
        tSea += se;
      }
      al.weekPure = tPure;
      al.weekTea = tTea;
      al.weekSea = tSea;
      al.weekUnits = tUnits;
      if (p.isRetired) w.dirtyArtists.add(p.id);
      p.weekPoints += tUnits * 0.5;
      if (p.eraOpen && p.eraAlbumId == al.id) p.eraUnits += tUnits;

      final na = Region.northAmerica.index, eu = Region.europe.index;
      albumPts[Charts.usAlbums][ai] =
          CountryShares.usOfNorthAmerica(p.homeCountry) *
              al.weekRegion[_r + na];
      albumPts[Charts.ukAlbums][ai] =
          CountryShares.ukOfEurope(p.homeCountry) * al.weekRegion[_r + eu];
      albumPts[Charts.globalAlbums][ai] = tUnits;

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
      a.fame +=
          (a.popularity > a.fame ? 0.02 : 0.002) * (a.popularity - a.fame);
      // Growth saturates: you cannot convert people who are already fans.
      final casualRoom = math.max(0.0, 1 - a.casual / c.publicPool);
      final fanRoom = math.max(0.0, 1 - a.coreFans / (0.04 * c.publicPool));
      a.casual += c.casualConversion * a.weekReach * casualRoom -
          c.casualDecay * a.casual;
      a.coreFans +=
          c.fanConversion * a.weekReach * fanRoom - c.coreFanDecay * a.coreFans;
      if (a.coreFans < 100) a.coreFans = 100;
      if (a.casual < 1000) a.casual = 1000;
      if (a.eraOpen && w.week - a.eraStartWeek >= c.eraLengthWeeks) {
        Eras.close(w, a);
      }
      // Fame changed: refresh where the audience is (frozen once retired).
      a.updateRegionShare();
    }
    _playerIncome();

    final result = WeekResult(
      week: w.week,
      charts: published,
      albumDebuts: debuts,
      newNumberOnes: newNo1,
      activeSongs: w.activeSongIds.length,
      activeAlbums: w.activeAlbumIds.length,
      dormantSongs: w.dormantSongCount,
      microseconds: sw.elapsedMicroseconds,
    );
    w.week++;
    return result;
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

  void _viralReactivation() {
    final w = world;
    final r = RandomStream.keyed(w.seed, w.week, -1, RngPurpose.viral);
    if (!r.chance(0.35)) return;
    var total = 0.0;
    for (final a in w.artists) {
      total += a.sumDormantRate;
    }
    if (total <= 0) return;
    var pick = r.nextDouble() * total;
    for (final a in w.artists) {
      pick -= a.sumDormantRate;
      if (pick <= 0 && a.dormantSongIds.isNotEmpty) {
        final ids = List.of(a.dormantSongIds)..sort();
        final s = w.songs[ids[r.nextInt(ids.length)]];
        Lifecycle.reactivateSong(w, s);
        s.viralBoost = r.range(0.03, 0.12);
        s.weeksBelowCutoff = 0;
        return;
      }
    }
  }

  void _playerIncome() {
    final p = world.player;
    if (p == null) return;
    var cents = 0.0;
    for (final id in world.activeSongIds) {
      final s = world.songs[id];
      if (s.primaryArtistId != p.id) continue;
      cents +=
          s.weekStreams * 0.35 + s.weekDownloads * 70 + s.weekPhysical * 100;
    }
    for (final id in world.activeAlbumIds) {
      final al = world.albums[id];
      if (al.artistId == p.id) cents += al.weekPure * 600;
    }
    p.moneyCents += (cents * p.artistShare).round();
  }
}
