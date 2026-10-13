import 'package:simulation_core/simulation_core.dart';

/// Details of AI album weeks above 1M in the US, 2003–2007.
void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 42;
  final w = WorldGen.create(seed: seed, startYear: 2002);
  final sim = Simulator(w);
  while (w.week < GameTime.firstWeekOf(2003)) {
    sim.step();
  }
  while (w.week < GameTime.firstWeekOf(2008)) {
    final r = sim.step();
    for (final e in r.charts[Charts.usAlbums].take(3)) {
      if (e.points < 1e6) continue;
      final al = w.albums[e.entityId];
      final a = w.artists[al.artistId];
      print(
          '${GameTime.yearOf(r.week)} ${(e.points / 1e6).toStringAsFixed(2)}M '
          'pure ${(al.weekPure / 1e6).toStringAsFixed(2)}M  wk${e.weeksOn} '
          '${a.tier.name} fame ${a.fame.toStringAsFixed(2)} dev ${a.devotion.toStringAsFixed(2)} '
          'fans ${(a.coreFans / 1e6).toStringAsFixed(2)}M cas ${(a.casual / 1e6).toStringAsFixed(1)}M '
          'hype ${al.hypeAtRelease.toStringAsFixed(2)} variants ${al.variantWeeks.length} q ${al.quality.round()} '
          'tracks ${al.songIds.length}');
    }
  }
}
