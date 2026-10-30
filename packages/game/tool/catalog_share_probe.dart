// The back catalog's share of all streams over the decades (docs K265):
// new songs' streams, catalog streams, and the top new song, a year apart.
//
//   dart run tool/catalog_share_probe.dart [startYear] [years]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2020;
  final years = args.length > 1 ? int.parse(args[1]) : 20;
  final dir = Directory.systemTemp.createTempSync('cshare');
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
  String m(double x) => '${(x / 1e6).toStringAsFixed(0)}M';
  for (var y = 0; y < years; y++) {
    var fresh = 0.0, all = 0.0, top = 0.0;
    for (var k = 0; k < 52; k++) {
      g.advanceWeek();
      if (k % 13 != 6) continue;
      for (final id in w.activeSongIds) {
        final s = w.songs[id].weekStreams;
        fresh += s;
        if (s > top) top = s;
      }
      for (final id in w.activeArtistIds) {
        all += w.artists[id].weekStreams;
      }
    }
    final catalog = all - fresh;
    print('${g.year - 1}: new ${m(fresh / 4)}/wk, catalog ${m(catalog / 4)}/wk'
        ' (${(catalog / all * 100).round()}%), top new song ${m(top)}');
  }
  g.close();
  dir.deleteSync(recursive: true);
}
