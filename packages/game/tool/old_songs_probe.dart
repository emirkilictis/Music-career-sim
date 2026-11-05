// Old (catalog) songs on the song charts (docs K284): which ones chart in
// the weeks after a world is built.
//
//   dart run tool/old_songs_probe.dart [startYear]
import 'package:simulation_core/simulation_core.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2022;
  final w = WorldGen.create(seed: 7, startYear: year);
  final sim = Simulator(w);
  final sw = Stopwatch()..start();
  while (w.week < GameTime.firstWeekOf(year)) {
    sim.step();
  }
  print(
      'artists ${w.artists.length} dormant ${w.dormantSongCount} presim ${sw.elapsed.inSeconds}s');
  for (var k = 0; k < 4; k++) {
    sim.step();
    for (final ch in [
      Charts.platformGlobal,
      Charts.platformNorthAmerica,
      Charts.globalSongs,
      Charts.usSongs,
      Charts.ukSongs
    ]) {
      final chart = w.charts[ch];
      final old = [
        for (final e in chart)
          if (w.songs[e.entityId].status == SongStatus.dormant)
            '#${e.position} ${w.songs[e.entityId].title} (${GameTime.yearOf(w.songs[e.entityId].releasedWeek)}${w.artists[w.songs[e.entityId].primaryArtistId].isRetired ? ", retired" : ""})'
      ];
      print(
          'week ${w.week} ${Charts.all[ch].key}: ${old.length} old: ${old.take(4).join("; ")}');
    }
  }
}
