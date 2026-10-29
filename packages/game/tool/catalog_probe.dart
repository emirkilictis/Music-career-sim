// Passive listening and the catalog's worth (docs K247): a star puts out
// an album a year (two singles each) for ten years, then rests. Prints
// each year's streams, how much came from the catalog, what the catalog
// earns and what a fund offers for it.
//
//   dart run tool/catalog_probe.dart [startYear] [albums] [restYears]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2012;
  final albums = args.length > 1 ? int.parse(args[1]) : 10;
  final rest = args.length > 2 ? int.parse(args[2]) : 3;
  for (final seed in [3]) {
    final dir = Directory.systemTemp.createTempSync('cat');
    final g = GameSession.start(
        SaveSlots(dir),
        CareerSetup(
            name: 'Probe',
            genre: 0,
            startYear: year,
            tier: StartTier.superstar,
            money: StartMoney.millionaire,
            premium: true,
            seed: seed),
        slotId: 'p');
    final w = g.world;
    final p = w.player!;
    p.skills
      ..songwriting = 80
      ..vocals = 80
      ..production = 80
      ..performance = 80
      ..charisma = 80;
    List<int> write(int k) => [
          for (var i = 0; i < k; i++)
            (() {
              p.creativeEnergy = 100;
              p.burnoutUntilWeek = -1;
              return g.writeSong(budget: BudgetTier.high).id;
            })(),
        ];
    String m(double x) => x >= 1e9
        ? '${(x / 1e9).toStringAsFixed(2)}B'
        : '${(x / 1e6).toStringAsFixed(1)}M';
    var yearStreams = 0.0, yearCatalog = 0.0;
    void week() {
      g.advanceWeek();
      for (final id in w.playerSongIds) {
        final s = w.songs[id];
        final v = w.songWeekStreamsIn(s, ChartMarket.global);
        yearStreams += v;
        if (w.week - s.releasedWeek >= 3 * 52 && s.releasedWeek >= 0) {
          yearCatalog += v;
        }
      }
    }

    void report(String what) {
      final cs = CatalogSale.songs(w, p);
      print('${GameTime.yearOf(w.week)} $what: ${m(yearStreams)} a year, '
          'catalog (3y+) ${m(yearCatalog)}; ${cs.length} catalog songs earn '
          '\$${(CatalogSale.yearCents(w, p) / 100 / 1e6).toStringAsFixed(2)}M '
          'a year, offer \$${(CatalogSale.offerCents(w, p) / 100 / 1e6).toStringAsFixed(1)}M');
      yearStreams = 0;
      yearCatalog = 0;
    }

    for (var k = 0; k < albums; k++) {
      final songs = write(12);
      g.releaseSingle(songs[0], campaign: Campaign.standard);
      for (var i = 0; i < 6; i++) {
        week();
      }
      g.releaseSingle(songs[1], campaign: Campaign.standard);
      for (var i = 0; i < 4; i++) {
        week();
      }
      g.releaseAlbum('Album $k', songs, campaign: Campaign.standard);
      for (var i = 0; i < 42; i++) {
        week();
      }
      report('album $k');
    }
    for (var y = 0; y < rest; y++) {
      for (var i = 0; i < 52; i++) {
        week();
      }
      report('rest');
    }
    g.close();
    dir.deleteSync(recursive: true);
  }
}
