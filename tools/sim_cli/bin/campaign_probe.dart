import 'package:simulation_core/simulation_core.dart';

/// Effect of campaign levels on a new single (12 weeks), median over seeds.
void main() {
  for (final tier in [StartTier.localBuzz, StartTier.risingStar]) {
    for (final year in [2005, 2014, 2022]) {
      for (final k in Campaign.values) {
        final streams = <double>[], radio = <double>[], dl = <double>[];
        var adds = 0;
        for (var seed = 1; seed <= 8; seed++) {
          final w = WorldGen.create(seed: seed, startYear: year);
          final sim = Simulator(w);
          while (w.week < GameTime.firstWeekOf(year)) {
            sim.step();
          }
          final p = WorldGen.addPlayer(w,
              name: 'P', genre: 0, tier: tier, money: StartMoney.millionaire);
          final s = Actions.writeSong(w, p, producerSkill: 75, aiMode: true);
          Actions.releaseSingle(w, p, s, campaign: k);
          if (s.playlistAdd != PlaylistAdd.none) adds++;
          var st = 0.0, ra = 0.0, d = 0.0;
          for (var i = 0; i < 12; i++) {
            sim.step();
            st += s.weekStreams;
            ra += s.weekRadio;
            d += s.weekDownloads;
          }
          streams.add(st);
          radio.add(ra);
          dl.add(d);
        }
        double med(List<double> v) => (v..sort())[v.length ~/ 2];
        print('${tier.name.padRight(10)} $year ${k.name.padRight(9)} '
            'streams ${(med(streams) / 1e6).toStringAsFixed(1)}M '
            'dl ${(med(dl) / 1e3).toStringAsFixed(0)}K '
            'radio ${(med(radio) / 1e6).toStringAsFixed(0)}M playlist adds $adds/8');
      }
    }
  }
}
