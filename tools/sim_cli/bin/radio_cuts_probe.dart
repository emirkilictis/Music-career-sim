import 'package:simulation_core/simulation_core.dart';

/// Streaming-era US song chart (docs F25, F37): radio's share of chart
/// points by position, album cuts on the chart, and how many tracks of a
/// superstar album chart in its first week.
/// Usage: dart run bin/radio_cuts_probe.dart [year] [difficulty]
void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2022;
  final diff = args.length > 1
      ? Difficulty.values.byName(args[1])
      : Difficulty.normal;
  final w = WorldGen.create(
      seed: 25, startYear: year, realNames: true, difficulty: diff);
  final sim = Simulator(w);
  final pos = [1, 5, 10, 20, 40, 100];
  final radioShare = List.filled(pos.length, 0.0);
  var weeks = 0, cutEntries = 0, cutTop10 = 0, entries = 0;
  final top10Artists = <int, int>{};
  while (w.week < GameTime.firstWeekOf(year)) {
    final r = sim.step();
    if (GameTime.yearOf(r.week) != year - 1) continue;
    final chart = r.charts[Charts.usSongs];
    if (chart.length < 100) continue;
    weeks++;
    for (var i = 0; i < pos.length; i++) {
      final e = chart[pos[i] - 1];
      final s = w.songs[e.entityId];
      radioShare[i] += s.weekRadioPtsUs / s.weekPtsUs;
    }
    for (final e in chart) {
      entries++;
      final s = w.songs[e.entityId];
      if (!s.isSingle) {
        cutEntries++;
        if (e.position <= 10) cutTop10++;
      }
      if (e.position <= 10) {
        top10Artists[s.primaryArtistId] =
            (top10Artists[s.primaryArtistId] ?? 0) + 1;
      }
    }
  }
  print('${year - 1} US songs (${diff.name}): radio share of points '
      '${[for (var i = 0; i < pos.length; i++) '#${pos[i]} ${(100 * radioShare[i] / weeks).round()}%'].join(', ')}');
  print('  album cuts ${(100 * cutEntries / entries).toStringAsFixed(1)}% of '
      'entries, $cutTop10 top-10 cut entries, '
      '${top10Artists.length} artists in the top 10 over the year');

  // A superstar's 13-track album with no pre-singles.
  final p = WorldGen.addPlayer(w,
      name: 'Probe Star',
      genre: 0,
      tier: StartTier.superstar,
      money: StartMoney.millionaire);
  for (final k in SkillKind.values) {
    p.skills[k] = 100;
  }
  Actions.signLabel(w, p, Label.giant);
  final ids = <int>[];
  for (var i = 0; i < 13; i++) {
    p.creativeEnergy = 100;
    ids.add(Actions.writeSong(w, p, budget: BudgetTier.high).id);
  }
  Actions.releaseAlbum(w, p, 'Probe', ids, campaign: Campaign.global);
  for (var wk = 0; wk < 3; wk++) {
    final r = sim.step();
    final chart = r.charts[Charts.usSongs];
    final mine = [
      for (final e in chart)
        if (w.songs[e.entityId].primaryArtistId == p.id) e.position
    ];
    String us(int id) => (w.songWeekStreamsIn(w.songs[id], ChartMarket.us) / 1e6)
        .toStringAsFixed(1);
    final st = [for (final id in ids) us(id)];
    print('    US streams per track (M): $st; #1 ${us(chart[0].entityId)}M '
        '(${(chart[0].points / 1e3).round()}K pts), #10 '
        '${us(chart[9].entityId)}M (${(chart[9].points / 1e3).round()}K pts), '
        'player fans ${(p.coreFans / 1e6).toStringAsFixed(1)}M');
    print('  superstar album week ${wk + 1}: ${mine.length}/13 tracks on the '
        'Hot 100 at $mine');
  }
}
