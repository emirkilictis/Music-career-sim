import 'package:simulation_core/simulation_core.dart';

/// Pure album sales over a year for a superstar album, by era and mode
/// (docs F17/F19): first week vs the rest, and the reach-driven part.
void main(List<String> args) {
  for (final diff in [Difficulty.normal, Difficulty.legend]) {
    for (final year in [2006, 2016, 2024]) {
      final w = WorldGen.create(seed: 7, startYear: year, difficulty: diff);
      final sim = Simulator(w);
      while (w.week < GameTime.firstWeekOf(year)) {
        sim.step();
      }
      final p = WorldGen.addPlayer(w,
          name: 'Star',
          genre: 0,
          tier: StartTier.superstar,
          money: StartMoney.millionaire);
      p.moneyCents = 1 << 40;
      p.coreFans = 6e6;
      p.casual = 4e7;
      p.fame = 0.8;
      p.devotion = 0.5;
      final lead = Actions.writeSong(w, p, producerSkill: 90, aiMode: true);
      Actions.releaseSingle(w, p, lead, campaign: Campaign.global);
      for (var i = 0; i < 6; i++) {
        sim.step();
      }
      final songs = [
        lead.id,
        for (var i = 0; i < 11; i++)
          Actions.writeSong(w, p, producerSkill: 90, aiMode: true).id,
      ];
      final al =
          Actions.releaseAlbum(w, p, 'LP', songs, campaign: Campaign.global);
      final pure = <double>[];
      final reachW = <double>[];
      for (var i = 0; i < 52; i++) {
        sim.step();
        pure.add(al.weekPure);
        reachW.add(al.songIds
            .map((id) => w.songs[id].lastReach)
            .fold(0.0, (a, b) => a + b));
      }
      final total = pure.fold(0.0, (a, b) => a + b);
      String m(double v) => '${(v / 1e6).toStringAsFixed(2)}M';
      print(
          '${diff.name.padRight(6)} $year first ${m(pure[0])} wk2 ${m(pure[1])} '
          'wk5 ${m(pure[4])} wk12 ${m(pure[11])} wk30 ${m(pure[29])} wk52 ${m(pure[51])} '
          'year ${m(total)} ratio ${(total / pure[0]).toStringAsFixed(2)} '
          'reach wk1 ${m(reachW[0])} wk30 ${m(reachW[29])}');
    }
  }
}
