import 'package:simulation_core/simulation_core.dart';

/// Why a superstar's singles all reach #1 (docs F45): a superstar player
/// releases singles every 6 weeks with a global campaign; each week prints
/// the song's US points and position against the best rival song, and how
/// its attention splits between fans and new listeners.
void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2014;
  final w = WorldGen.create(
      seed: 11,
      startYear: year,
      realNames: args.length > 1 && args[1] == 'real');
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
  Actions.signLabel(w, p, Label.giant);
  for (final k in SkillKind.values) {
    p.skills[k] = 100;
  }
  print('fans ${(p.coreFans / 1e6).toStringAsFixed(1)}M casual '
      '${(p.casual / 1e6).toStringAsFixed(1)}M fame ${p.fame.toStringAsFixed(2)}');
  final rivals = [
    for (final id in w.activeArtistIds)
      if (w.artists[id].tier == ArtistTier.a) w.artists[id]
  ]..sort((a, b) => b.coreFans.compareTo(a.coreFans));
  print('top rivals: ${[
    for (final r in rivals.take(5))
      '${r.name} ${(r.coreFans / 1e6).toStringAsFixed(1)}M f${r.fame.toStringAsFixed(2)}'
  ].join(', ')}');
  for (var n = 0; n < 4; n++) {
    p.creativeEnergy = 100;
    final s = Actions.writeSong(w, p, budget: BudgetTier.high);
    Actions.releaseSingle(w, p, s,
        campaign: Campaign.global,
        radio: args.length > 2
            ? RadioPush.values.byName(args[2])
            : RadioPush.heavy);
    for (var k = 0; k < 6; k++) {
      final r = sim.step();
      final chart = r.charts[Charts.usSongs];
      final mine = chart.where((e) => e.entityId == s.id).firstOrNull;
      final rival =
          chart.where((e) => w.songs[e.entityId].primaryArtistId != p.id).first;
      final fanShare =
          s.lastAttention <= 0 ? 0 : 1 - s.lastReach / s.lastAttention;
      print('single ${n + 1} wk ${k + 1} q ${s.quality.round()} '
          'pos ${mine?.position ?? '-'} pts ${((mine?.points ?? 0) / 1e3).round()}K '
          'best rival #${rival.position} ${((rival.points) / 1e3).round()}K '
          '(${w.artists[w.songs[rival.entityId].primaryArtistId].name}) '
          'fan share ${(fanShare * 100).round()}% '
          'radio ${(s.weekRadioPtsUs / (s.weekPtsUs + 1e-9) * 100).round()}%');
    }
  }
}
