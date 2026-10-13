import 'package:simulation_core/simulation_core.dart';

/// Who fills the UK top 40 (songs and albums) by home country, 2005–2012.
/// Usage: dart run bin/uk_probe.dart [seed]
void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 42;
  final w = WorldGen.create(seed: seed, startYear: 2005);
  final sim = Simulator(w);
  for (final chart in [Charts.ukSongs, Charts.ukAlbums]) {
    final count = <HomeCountry, int>{};
    var total = 0;
    final w2 = chart == Charts.ukSongs
        ? w
        : WorldGen.create(seed: seed, startYear: 2005);
    final s2 = chart == Charts.ukSongs ? sim : Simulator(w2);
    while (w2.week < GameTime.firstWeekOf(2013)) {
      final r = s2.step();
      for (final e in r.charts[chart].take(40)) {
        final artist = chart == Charts.ukSongs
            ? w2.songs[e.entityId].primaryArtistId
            : w2.albums[e.entityId].artistId;
        final home = w2.artists[artist].homeCountry;
        count[home] = (count[home] ?? 0) + 1;
        total++;
      }
    }
    print('${Charts.all[chart].key}: ${[
      for (final h in HomeCountry.values)
        '${h.name} ${(100 * (count[h] ?? 0) / total).round()}%'
    ].join('  ')}');
  }
}
