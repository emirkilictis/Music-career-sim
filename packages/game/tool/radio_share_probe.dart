// How much of the US song chart is radio (docs K265): the top 10 each
// week, radio's share of their points, and the top song's streams.
//
//   dart run tool/radio_share_probe.dart [startYear] [weeks]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2014;
  final weeks = args.length > 1 ? int.parse(args[1]) : 26;
  final dir = Directory.systemTemp.createTempSync('radio');
  final g = GameSession.start(
      SaveSlots(dir),
      CareerSetup(
          name: 'Probe',
          genre: 0,
          startYear: year,
          tier: StartTier.unknown,
          seed: 11),
      slotId: 'p');
  final w = g.world;
  var top1 = 0.0, top10 = 0.0, n = 0;
  var topStreams = 0.0, topRadioShareStreams = 0.0;
  for (var k = 0; k < weeks; k++) {
    g.advanceWeek();
    final songs = [for (final id in w.activeSongIds) w.songs[id]]
      ..sort((a, b) => b.weekPtsUs.compareTo(a.weekPtsUs));
    double r(s) => s.weekPtsUs > 0 ? s.weekRadioPtsUs / s.weekPtsUs : 0;
    top1 += r(songs.first);
    top10 += songs.take(10).map(r).fold(0.0, (a, b) => a + b) / 10;
    final byStreams = [...songs]
      ..sort((a, b) => b.weekStreams.compareTo(a.weekStreams));
    topStreams += byStreams.first.weekStreams;
    topRadioShareStreams += songs.first.weekStreams;
    n++;
  }
  String pct(double x) => '${(x / n * 100).toStringAsFixed(0)}%';
  String m(double x) => '${(x / n / 1e6).toStringAsFixed(1)}M';
  print('$year: radio share of US #1 ${pct(top1)}, of top 10 ${pct(top10)};'
      ' most streamed song ${m(topStreams)}/wk, US #1 streams ${m(topRadioShareStreams)}/wk');
  g.close();
  dir.deleteSync(recursive: true);
}
