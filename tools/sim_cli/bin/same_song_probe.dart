import 'package:simulation_core/simulation_core.dart';

/// The same player and songs in a real-names and a made-up world (docs
/// K70): peak weekly streams and US peaks of a single every 6 weeks.
void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2010;
  for (final real in [true, false]) {
    final peaks = <double>[];
    var charted = 0, top40 = 0, fans = 0.0, spa = 0.0, dorm = 0.0, n = 0;
    for (final seed in [11, 22, 33, 44]) {
      final w = WorldGen.create(seed: seed, startYear: year, realNames: real);
      final sim = Simulator(w);
      while (w.week < GameTime.firstWeekOf(year)) {
        sim.step();
        spa += w.lastSpa[Region.northAmerica.index];
        n++;
        var d = w.retiredDormantAttention[Region.northAmerica.index];
        for (final id in w.activeArtistIds) {
          final a = w.artists[id];
          d += a.sumDormantRate *
              a.catalogFactor *
              a.regionShare[Region.northAmerica.index];
        }
        dorm += d;
      }
      final p = WorldGen.addPlayer(w,
          name: 'Probe Star',
          genre: 0,
          tier: StartTier.localBuzz,
          money: StartMoney.millionaire);
      for (final k in SkillKind.values) {
        p.skills[k] = 65;
      }
      final singles = <Song>[];
      for (var wk = 0; wk < 52 * 3; wk++) {
        if (wk % 6 == 0) {
          p.creativeEnergy = 100;
          final s = Actions.writeSong(w, p, producerSkill: 75);
          Actions.releaseSingle(w, p, s, campaign: Campaign.standard);
          singles.add(s);
        }
        sim.step();
        spa += w.lastSpa[Region.northAmerica.index];
        n++;
        var d = w.retiredDormantAttention[Region.northAmerica.index];
        for (final id in w.activeArtistIds) {
          final a = w.artists[id];
          d += a.sumDormantRate *
              a.catalogFactor *
              a.regionShare[Region.northAmerica.index];
        }
        dorm += d;
      }
      for (final s in singles) {
        final st = s.statsOrNull(Charts.usSongs);
        if (st != null && st.peak > 0) {
          charted++;
          if (st.peak <= 40) top40++;
        }
        peaks.add(w.songLifetimeStreams(s, Region.northAmerica.index));
      }
      fans += p.coreFans;
    }
    peaks.sort();
    print('${real ? 'REAL' : 'FAKE'} 4 worlds × 26 singles: charted US '
        '$charted, top 40 $top40, NA lifetime streams median '
        '${(peaks[peaks.length ~/ 2] / 1e6).toStringAsFixed(1)}M p90 '
        '${(peaks[peaks.length * 9 ~/ 10] / 1e6).toStringAsFixed(1)}M, '
        'fans after 3 years ${(fans / 4 / 1e3).round()}K; NA streams per '
        'attention ${(spa / n).toStringAsFixed(3)}, dormant NA attention '
        '${(dorm / n / 1e6).toStringAsFixed(1)}M');
  }
}
