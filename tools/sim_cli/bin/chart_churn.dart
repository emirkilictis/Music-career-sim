import 'package:simulation_core/simulation_core.dart';

/// Chart churn per year on the US charts: distinct #1s, #1 debuts, how long
/// #1s last, album releases and debut sizes (real reference: ~30–45
/// distinct #1 albums a year, most of them debuts; ~10–20 #1 songs).
///
///   dart run bin/chart_churn.dart [seed] [fromYear] [toYear]
void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 42;
  final from = args.length > 1 ? int.parse(args[1]) : 2010;
  final to = args.length > 2 ? int.parse(args[2]) : 2025;
  final w = WorldGen.create(seed: seed, startYear: from);
  final sim = Simulator(w);
  final albumNo1 = <int, Map<int, int>>{}, songNo1 = <int, Set<int>>{};
  final debutNo1 = <int, int>{}, releases = <int, int>{};
  final no1Units = <int, List<double>>{}, tenthUnits = <int, List<double>>{};
  final no1Pure = <int, List<double>>{}, no1TierA = <int, int>{};
  final debutTop10 = <int, int>{};
  while (w.week < GameTime.firstWeekOf(to + 1)) {
    final r = sim.step();
    final y = GameTime.yearOf(r.week);
    if (y < from) continue;
    releases[y] = (releases[y] ?? 0) + r.albumDebuts.length;
    final a = r.charts[Charts.usAlbums], s = r.charts[Charts.usSongs];
    if (a.isEmpty) continue;
    final m = albumNo1[y] ??= {};
    m[a.first.entityId] = (m[a.first.entityId] ?? 0) + 1;
    if (a.first.isDebut) debutNo1[y] = (debutNo1[y] ?? 0) + 1;
    for (final e in a.take(10)) {
      if (e.isDebut) debutTop10[y] = (debutTop10[y] ?? 0) + 1;
    }
    double units(ChartEntry e) => w.albumWeekUnitsUs(w.albums[e.entityId]);
    (no1Units[y] ??= []).add(units(a.first));
    final top = w.albums[a.first.entityId];
    final topArtist = w.artists[top.artistId];
    (no1Pure[y] ??= []).add(
        CountryShares.usOfNorthAmerica(topArtist.homeCountry) *
            top.weekRegion[Region.northAmerica.index]);
    if (topArtist.tier == ArtistTier.a) no1TierA[y] = (no1TierA[y] ?? 0) + 1;
    if (a.length >= 10) (tenthUnits[y] ??= []).add(units(a[9]));
    (songNo1[y] ??= {}).add(s.first.entityId);
  }
  double med(List<double>? v) {
    if (v == null || v.isEmpty) return 0;
    final s = [...v]..sort();
    return s[s.length ~/ 2];
  }

  String k(double v) => '${(v / 1000).round()}K';
  print('year | album #1s | debut #1 | longest run | releases | '
      'top10 debuts | #1 units med (pure) | #1 wks by tier A | #10 units med | song #1s');
  for (final y in albumNo1.keys) {
    final runs = albumNo1[y]!.values.toList()..sort();
    print('$y | ${albumNo1[y]!.length} | ${debutNo1[y] ?? 0} | ${runs.last} | '
        '${releases[y]} | ${debutTop10[y] ?? 0} | ${k(med(no1Units[y]))} (${k(med(no1Pure[y]))}) | ${no1TierA[y] ?? 0} | '
        '${k(med(tenthUnits[y]))} | ${songNo1[y]!.length}');
  }
}

extension on World {
  double albumWeekUnitsUs(Album al) {
    if (al.status != AlbumStatus.active) return 0;
    return CountryShares.usOfNorthAmerica(artists[al.artistId].homeCountry) *
        al.weekRegion[regionCount + Region.northAmerica.index];
  }
}
