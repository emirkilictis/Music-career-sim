// How big are the biggest songs' weeks (docs F105)? Plays a world for a
// while and prints, every few weeks, the top songs' weekly streams (all
// platforms) and the top artists'.
//
//   dart run tool/top_streams_probe.dart [startYear] [weeks]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2019;
  final weeks = args.length > 1 ? int.parse(args[1]) : 104;
  final dir = Directory.systemTemp.createTempSync('top');
  final g = GameSession.start(
      SaveSlots(dir),
      CareerSetup(
          name: 'Probe', genre: 0, startYear: year, tier: StartTier.unknown, seed: 11),
      slotId: 'p');
  final w = g.world;
  var maxSong = 0.0, maxArtist = 0.0;
  for (var k = 0; k < weeks; k++) {
    g.advanceWeek();
    final songs = [for (final id in w.activeSongIds) w.songs[id]]
      ..sort((a, b) => b.weekStreams.compareTo(a.weekStreams));
    final artists = [for (final id in w.activeArtistIds) w.artists[id]]
      ..sort((a, b) => b.weekStreams.compareTo(a.weekStreams));
    if (songs.first.weekStreams > maxSong) maxSong = songs.first.weekStreams;
    if (artists.first.weekStreams > maxArtist) {
      maxArtist = artists.first.weekStreams;
    }
    if (k % 13 == 0) {
      String m(double v) => '${(v / 1e6).toStringAsFixed(0)}M';
      print('${g.year} wk${k}: songs ${[
        for (final s in songs.take(5)) m(s.weekStreams)
      ].join(' ')} | #10 ${m(songs[9].weekStreams)} #50 ${m(songs[49].weekStreams)}'
          ' | artists ${[for (final a in artists.take(3)) m(a.weekStreams)].join(' ')}');
    }
  }
  print('max song week ${(maxSong / 1e6).toStringAsFixed(0)}M, '
      'max artist week ${(maxArtist / 1e6).toStringAsFixed(0)}M');
  g.close();
  dir.deleteSync(recursive: true);
}
