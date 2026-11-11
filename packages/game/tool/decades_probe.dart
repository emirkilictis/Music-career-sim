// Careers from the 1950s on (docs K289): a superstar's single and album
// in each start decade, the charts' #1s, the genres of the top 10 and the
// real names in the field, and how long the world takes to make.
//
//   dart run tool/decades_probe.dart [years] [startYear...]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final years = args.isNotEmpty ? int.parse(args[0]) : 3;
  final starts = args.length > 1
      ? [for (final a in args.skip(1)) int.parse(a)]
      : [1955, 1965, 1975, 1985, 2005];
  for (final start in starts) {
    final dir = Directory.systemTemp.createTempSync('decades');
    final sw = Stopwatch()..start();
    final g = GameSession.start(
        SaveSlots(dir),
        CareerSetup(
            name: 'Probe',
            genre: 0,
            startYear: start,
            tier: StartTier.superstar,
            money: StartMoney.millionaire,
            premium: true,
            seed: 11),
        slotId: 'p');
    final made = sw.elapsedMilliseconds;
    final w = g.world;
    final p = w.player!;
    final ids = <int>[];
    for (var i = 0; i < 10; i++) {
      p.creativeEnergy = 100;
      p.burnoutUntilWeek = -1;
      ids.add(g.writeSong(budget: BudgetTier.high).id);
    }
    g.releaseSingle(ids.first, campaign: Campaign.standard);
    g.advanceWeek();
    final s = w.songs[ids.first];
    final singleWeek1 = s.weekPhysical + s.weekDownloads;
    g.advanceWeeks(5, stop: SkipStop.never);
    final al = g.releaseAlbum('Probe LP', ids, campaign: Campaign.standard);
    g.advanceWeek();
    final album = w.albums[al.id];
    final albumWeek1 = album.weekPure;
    String k(num x) => x >= 1e6
        ? '${(x / 1e6).toStringAsFixed(2)}M'
        : '${(x / 1e3).toStringAsFixed(0)}K';
    final usSong = w.charts[Charts.usSongs];
    final usAlbum = w.charts[Charts.usAlbums];
    String top(ChartEntry e, bool song) {
      final a = song
          ? w.artists[w.songs[e.entityId].primaryArtistId]
          : w.artists[w.albums[e.entityId].artistId];
      return '${a.name} (${genreNames[a.genre]})';
    }

    final genres = <String, int>{};
    for (final e in usSong.take(20)) {
      final a = w.artists[w.songs[e.entityId].primaryArtistId];
      genres[genreNames[a.genre]] = (genres[genreNames[a.genre]] ?? 0) + 1;
    }
    final real = w.artists.where((a) => realStar(a.name) > 0).length;
    print('$start (world ${made}ms, base ${w.baseYear}): single wk1 '
        '${k(singleWeek1)} US #${s.statsOrNull(Charts.usSongs)?.peak ?? 0}, '
        'album wk1 ${k(albumWeek1)} US #${album.statsOrNull(Charts.usAlbums)?.peak ?? 0}');
    print('  #1 song ${top(usSong.first, true)} ${k(usSong.first.points)} pts; '
        '#1 album ${top(usAlbum.first, false)} ${k(usAlbum.first.points)}');
    print('  top 20 genres: $genres; real names $real');
    final sw2 = Stopwatch()..start();
    g.advanceWeeks(years * GameTime.weeksPerYear, stop: SkipStop.never);
    print('  +$years years in ${sw2.elapsedMilliseconds}ms → '
        '${GameTime.yearOf(w.week)}; money ${k(p.moneyCents / 100)}, '
        'fans ${k(p.coreFans)}, legacy ${g.legacy.score.round()}, '
        'feed ${Social.networkIn(GameTime.yearOf(w.week)).name}');
    final top10 = [
      for (final e in w.charts[Charts.usSongs].take(5)) top(e, true)
    ];
    print('  US top 5 then: ${top10.join(', ')}');
    g.close();
    dir.deleteSync(recursive: true);
  }
}
