import 'package:simulation_core/simulation_core.dart';

/// Median weekly streams of the #1 song (US/UK/Global) in [from..to] and
/// where attention goes (singles vs album tracks).
void main(List<String> args) {
  final fanShare = args.isNotEmpty ? double.parse(args[0]) : 0.6;
  final feedback = args.length > 1 ? double.parse(args[1]) : 0.04;
  final fameExp = args.length > 2 ? double.parse(args[2]) : 0.020;
  const from = 2021, to = 2025;
  final w = WorldGen.create(
      seed: 42,
      startYear: from,
      config: SimConfig(
          albumTrackFanShare: fanShare,
          chartFeedback: feedback,
          fameExposure: fameExp));
  final sim = Simulator(w);
  final us = <double>[], uk = <double>[], gl = <double>[];
  var singles = 0.0, tracks = 0.0, active = 0;
  var n = 0;
  while (w.week < GameTime.firstWeekOf(to + 1)) {
    final r = sim.step();
    if (GameTime.yearOf(r.week) < from) continue;
    double top(int c, ChartMarket m) =>
        w.songWeekStreamsIn(w.songs[r.charts[c].first.entityId], m);
    us.add(top(Charts.usSongs, ChartMarket.us));
    uk.add(top(Charts.ukSongs, ChartMarket.uk));
    gl.add(top(Charts.globalSongs, ChartMarket.global));
    for (final id in w.activeSongIds) {
      final s = w.songs[id];
      if (s.isSingle) {
        singles += s.weekStreams;
      } else {
        tracks += s.weekStreams;
      }
    }
    active += w.activeSongIds.length;
    n++;
  }
  double med(List<double> v) => (v..sort())[v.length ~/ 2];
  String m(double v) => '${(v / 1e6).toStringAsFixed(1)}M';
  print(
      'fanShare $fanShare fb $feedback fame $fameExp: US#1 ${m(med(us))} UK#1 ${m(med(uk))} GL#1 ${m(med(gl))} '
      '| album tracks ${(100 * tracks / (singles + tracks)).round()}% of active streams '
      '| active songs ${active ~/ n}');
}
