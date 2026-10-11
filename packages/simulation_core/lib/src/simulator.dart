import 'dart:math' as math;

import 'actions.dart';
import 'ai.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'rng.dart';
import 'world.dart';

/// Summary of one simulated week (what the UI/CLI needs; not the whole world).
class WeekResult {
  WeekResult({
    required this.week,
    required this.songChart,
    required this.albumChart,
    required this.albumDebuts,
    required this.newNumberOneSongs,
    required this.newNumberOneAlbums,
    required this.activeSongs,
    required this.activeAlbums,
    required this.dormantSongs,
    required this.streamsPerAttention,
    required this.microseconds,
  });

  final int week;
  final List<ChartEntry> songChart;
  final List<ChartEntry> albumChart;

  /// Albums released this week (ids), with first-week numbers on the album.
  final List<int> albumDebuts;
  final List<int> newNumberOneSongs;
  final List<int> newNumberOneAlbums;
  final int activeSongs;
  final int activeAlbums;
  final int dormantSongs;
  final double streamsPerAttention;
  final int microseconds;
}

/// Runs the weekly pipeline (docs/simulation.md §2).
class Simulator {
  Simulator(this.world);

  final World world;

  WeekResult step() {
    final sw = Stopwatch()..start();
    final w = world;
    final c = w.config;
    final era = c.era.forWeek(w.week);
    final rules = c.era.rulesForWeek(w.week);

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

    // 5. Raw demand for active songs.
    final ids = w.activeSongIds;
    final n = ids.length;
    final attention = List<double>.filled(n, 0);
    final dlDemand = List<double>.filled(n, 0);
    final radioDemand = List<double>.filled(n, 0);
    var sumA = 0.0, sumD = 0.0, sumR = 0.0, sumSinglesA = 0.0;
    for (var i = 0; i < n; i++) {
      final s = w.songs[ids[i]];
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
        final n = w.albums[s.albumId].songIds.length;
        if (n > 10) trackShare = math.pow(10 / n, 0.6).toDouble();
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

      // Chart feedback favours the very top (playlists, radio adds, press).
      final chartShape = s.lastPos > 0 ? 1 - (s.lastPos - 1) / 100 : 0.0;
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
      final att = (fanPart + casPart + pubPart) * qMult * noise * trackShare;
      s.lastAttention = att;
      s.lastReach = (casPart + pubPart) * qMult * trackShare;
      attention[i] = att;
      sumA += att;
      if (s.isSingle) sumSinglesA += att;

      final fresh = math.exp(-promoAge / 6.0);
      dlDemand[i] = att * (0.25 + fresh) * (s.isSingle ? 1.0 : 0.5);
      sumD += dlDemand[i];

      final radioLife = (1 - math.exp(-(promoAge + 1) / (s.riseWeeks + 3))) *
          math.exp(-promoAge / (s.lifeWeeks + 10));
      radioDemand[i] = s.radioAppeal *
          radioLife *
          (s.isSingle ? 1.0 : 0.03) *
          (0.2 + p.fame) *
          p.labelReach *
          (1 + 8 * chartBoost);
      sumR += radioDemand[i];
    }

    // Dormant catalog attention: active artists + frozen retired total.
    var dormantA = w.retiredDormantAttention;
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      if (a.sumDormantRate > 0) dormantA += a.sumDormantRate * a.catalogFactor;
    }
    sumA += dormantA;
    sumD += dormantA * 0.1;

    // 6. Normalise against the market (rest of market = smoothed multiple).
    if (w.emaAttention == 0) {
      w.emaAttention = sumA;
      w.emaDownloadDemand = sumD;
      w.emaRadioDemand = sumR;
    }
    final spa = era.streamsWeekly /
        (sumA + c.outsideAttentionRatio * w.emaAttention + 1);
    final dpa = era.downloadsWeekly /
        (sumD + c.outsideDownloadRatio * w.emaDownloadDemand + 1);
    final rpr = era.radioWeekly /
        (sumR + c.outsideAttentionRatio * w.emaRadioDemand + 1e-9);
    final ppa = era.physicalSinglesWeekly /
        (sumSinglesA * (1 + c.outsideAttentionRatio) + 1);
    w.spaIndex += spa;
    w.dpaIndex += 0.1 * dpa;
    w.emaAttention = 0.9 * w.emaAttention + 0.1 * sumA;
    w.emaDownloadDemand = 0.9 * w.emaDownloadDemand + 0.1 * sumD;
    w.emaRadioDemand = 0.9 * w.emaRadioDemand + 0.1 * sumR;

    // 7. Consumption per active song.
    for (var i = 0; i < n; i++) {
      final s = w.songs[ids[i]];
      final p = w.artists[s.primaryArtistId];
      s.weekStreams = attention[i] * spa;
      s.weekDownloads = dlDemand[i] * dpa;
      s.weekRadio = radioDemand[i] * rpr;
      s.weekPhysical = s.isSingle ? attention[i] * ppa : 0;
      s.weekPoints = s.weekPhysical +
          (rules.countsDownloads ? s.weekDownloads : 0) +
          s.weekStreams * rules.streamFactor / c.songChartStreamDivisor +
          s.weekRadio / c.songChartRadioDivisor;
      s.lifetimeStreams += s.weekStreams;
      s.lifetimeDownloads += s.weekDownloads;
      s.lifetimeRadio += s.weekRadio;
      p.lifetimeStreams += s.weekStreams;
      p.lifetimeDownloads += s.weekDownloads;
      if (!p.isRetired) {
        p.weekPoints += s.weekPoints;
        p.weekReach += s.lastReach;
        p.weekStreams += s.weekStreams;
      }
    }

    // 8. Dormant catalog per active artist (retired artists accrue lazily).
    for (final id in w.activeArtistIds) {
      final a = w.artists[id];
      final f = a.catalogFactor;
      a.catalogIndexStreams += f * spa;
      a.catalogIndexDownloads += f * 0.1 * dpa;
      if (a.sumDormantRate > 0) {
        final st = a.sumDormantRate * f * spa;
        a.weekStreams += st;
        a.weekPoints += st / 400;
        a.lifetimeStreams += st;
        a.lifetimeDownloads += a.sumDormantRate * f * 0.1 * dpa;
      }
      a.catalogSettleSpa = w.spaIndex;
      a.catalogSettleDpa = w.dpaIndex;
    }

    // 9. Albums.
    final debuts = <int>[];
    for (final albumId in w.activeAlbumIds) {
      final al = w.albums[albumId];
      final p = w.artists[al.artistId];
      final age = w.week - al.releaseWeek;
      // Good albums hold their sales; weak ones fall off faster.
      final q01 = al.quality / 100;
      final secondWeek = c.albumSecondWeekRatio * (0.55 + 0.9 * q01);
      final decay = 1 - (1 - c.albumWeeklyDecay) * (1.6 - 1.2 * q01);
      final superCurve = age == 0 ? 1.0 : secondWeek * math.pow(decay, age - 1);
      // Devoted fanbases buy more (and buy variants).
      final superRate = c.superfanBuyRate * p.devotionBuyFactor;
      final superPart = p.coreFans *
          superRate *
          era.superfanFactor *
          superCurve *
          (1 + al.hypeAtRelease) *
          (0.5 + al.quality / 100);
      // Collector copies: each variant released this week (beyond the
      // standard edition) sells extra copies to devoted fans, with
      // diminishing returns per additional variant.
      var variantSum = 0.0;
      final vw = al.variantWeeks;
      for (var k = 1; k < vw.length; k++) {
        if (vw[k] == age) variantSum += math.pow(c.variantDecay, k - 1);
      }
      final collectorPart = variantSum == 0
          ? 0.0
          : p.coreFans *
              c.collectorRate *
              p.devotionCollectorFactor *
              era.collectorFactor *
              variantSum *
              (1 + al.hypeAtRelease);
      var songReach = 0.0, songStreams = 0.0, songDownloads = 0.0;
      for (final sid in al.songIds) {
        final s = w.songs[sid];
        if (s.status == SongStatus.active) {
          songReach += s.lastReach;
          songStreams += s.weekStreams;
          songDownloads += s.weekDownloads;
        }
      }
      songStreams += al.sumDormantRate * p.catalogFactor * spa;
      final casPart = songReach *
              c.casualBuyRate *
              era.casualPurchaseRate *
              (age == 0 ? 1.5 : 1.0) +
          (age == 0 ? p.casual * 0.003 * era.casualPurchaseRate : 0.0) +
          p.casual *
              c.albumCatalogRate *
              era.casualPurchaseRate *
              (0.5 + al.quality / 100);
      final noise =
          RandomStream.keyed(w.seed, w.week, al.id, RngPurpose.albumNoise)
              .logNormal(0.08);
      al.weekPure = (superPart + collectorPart + casPart) * noise;
      al.weekTea = songDownloads / c.trackEquivalentAlbum;
      al.weekSea = songStreams / c.streamEquivalentAlbum;
      al.weekUnits = rules.albumUsesUnits
          ? al.weekPure + al.weekTea + al.weekSea
          : al.weekPure;
      al.lifetimePure += al.weekPure;
      al.lifetimeUnits += al.weekUnits;
      p.lifetimeAlbumPure += al.weekPure;
      p.lifetimeAlbumUnits += al.weekUnits;
      p.weekPoints += al.weekUnits * 0.5;
      if (p.eraOpen && p.eraAlbumId == al.id) p.eraUnits += al.weekUnits;
      if (age == 0) {
        al.firstWeekUnits = al.weekUnits;
        al.firstWeekPure = al.weekPure;
        if (al.chartsOnAlbumChart) debuts.add(al.id);
      }
    }

    // 10. Charts.
    final newNo1Songs = <int>[];
    final newNo1Albums = <int>[];
    w.songChart = _buildSongChart(newNo1Songs);
    w.albumChart = _buildAlbumChart(newNo1Albums);

    // 11. Lifecycle transitions.
    _songTransitions();
    _albumTransitions();

    // 12. Artist post-step. Popularity is relative to this week's #1 so it
    // does not inflate as markets grow.
    final topPoints = w.songChart.isEmpty ? 1.0 : w.songChart.first.points;
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
      if (a.eraOpen && w.week - a.eraStartWeek >= c.eraLengthWeeks)
        Eras.close(w, a);
    }
    _playerIncome();

    final result = WeekResult(
      week: w.week,
      songChart: w.songChart,
      albumChart: w.albumChart,
      albumDebuts: debuts,
      newNumberOneSongs: newNo1Songs,
      newNumberOneAlbums: newNo1Albums,
      activeSongs: w.activeSongIds.length,
      activeAlbums: w.activeAlbumIds.length,
      dormantSongs: w.dormantSongCount,
      streamsPerAttention: spa,
      microseconds: sw.elapsedMicroseconds,
    );
    w.week++;
    return result;
  }

  List<ChartEntry> _buildSongChart(List<int> newNo1) {
    final w = world;
    final c = w.config;
    final cands = List<int>.of(w.activeSongIds)
      ..sort((x, y) {
        final d = w.songs[y].weekPoints.compareTo(w.songs[x].weekPoints);
        return d != 0 ? d : x.compareTo(y);
      });
    final chart = <ChartEntry>[];
    final charted = <int>{};
    for (final id in cands) {
      if (chart.length >= c.songChartSize) break;
      final s = w.songs[id];
      if (s.weekPoints <= 0) break;
      final pos = chart.length + 1;
      if (s.weeksOn >= c.recurrentWeeks && pos > c.recurrentPosition) continue;
      final last = s.lastPos;
      s.weeksOn++;
      if (s.peakPos == 0 || pos < s.peakPos) s.peakPos = pos;
      if (pos == 1) {
        s.weeksAtNo1++;
        final p = w.artists[s.primaryArtistId];
        p.weeksAtNo1++;
        if (s.weeksAtNo1 == 1) {
          newNo1.add(id);
          p.no1Singles++;
          for (final f in s.featuredArtistIds) {
            w.artists[f].no1SinglesFeatured++;
          }
        }
      }
      s.lastPos = pos;
      charted.add(id);
      chart.add(ChartEntry(
          position: pos,
          entityId: id,
          points: s.weekPoints,
          lastPos: last,
          peak: s.peakPos,
          weeksOn: s.weeksOn));
    }
    for (final id in w.activeSongIds) {
      if (!charted.contains(id)) w.songs[id].lastPos = 0;
    }
    w.songCutoff = chart.isEmpty ? 0 : chart.last.points;
    return chart;
  }

  List<ChartEntry> _buildAlbumChart(List<int> newNo1) {
    final w = world;
    final c = w.config;
    final cands =
        w.activeAlbumIds.where((id) => w.albums[id].chartsOnAlbumChart).toList()
          ..sort((x, y) {
            final d = w.albums[y].weekUnits.compareTo(w.albums[x].weekUnits);
            return d != 0 ? d : x.compareTo(y);
          });
    final chart = <ChartEntry>[];
    final charted = <int>{};
    for (final id in cands) {
      if (chart.length >= c.albumChartSize) break;
      final al = w.albums[id];
      if (al.weekUnits <= 0) break;
      final pos = chart.length + 1;
      final last = al.lastPos;
      al.weeksOn++;
      if (al.peakPos == 0 || pos < al.peakPos) al.peakPos = pos;
      if (al.weeksOn == 1) al.debutPos = pos;
      if (pos == 1) {
        al.weeksAtNo1++;
        if (al.weeksAtNo1 == 1) {
          newNo1.add(id);
          w.artists[al.artistId].no1Albums++;
        }
      }
      al.lastPos = pos;
      charted.add(id);
      chart.add(ChartEntry(
          position: pos,
          entityId: id,
          points: al.weekUnits,
          lastPos: last,
          peak: al.peakPos,
          weeksOn: al.weeksOn));
    }
    for (final id in w.activeAlbumIds) {
      if (!charted.contains(id)) w.albums[id].lastPos = 0;
    }
    w.albumCutoff = chart.isEmpty ? 0 : chart.last.points;
    return chart;
  }

  void _songTransitions() {
    final w = world;
    final c = w.config;
    final threshold = c.dormantShareOfCutoff * w.songCutoff;
    final toDormant = <int>[];
    for (final id in w.activeSongIds) {
      final s = w.songs[id];
      final promoAge = w.week - (s.isSingle ? s.singleWeek : s.releasedWeek);
      if (promoAge < c.activeMinAgeWeeks) continue;
      if (s.weekPoints < threshold) {
        s.weeksBelowCutoff++;
        if (s.weeksBelowCutoff >= 4) toDormant.add(id);
      } else {
        s.weeksBelowCutoff = 0;
      }
    }
    for (final id in toDormant) {
      Lifecycle.makeSongDormant(w, w.songs[id]);
    }
  }

  void _albumTransitions() {
    final w = world;
    final c = w.config;
    final threshold = c.albumDormantShareOfCutoff * w.albumCutoff;
    final toDormant = <int>[];
    for (final id in w.activeAlbumIds) {
      final al = w.albums[id];
      if (w.week - al.releaseWeek < c.activeMinAgeWeeks) continue;
      if (al.weekUnits < threshold) {
        al.weeksBelowCutoff++;
        if (al.weeksBelowCutoff >= 6) toDormant.add(id);
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
