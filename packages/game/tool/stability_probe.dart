// How steadily songs' weekly streams move (docs K244): for every song with
// real listening, the week-over-week change, by age, for the player and
// for rivals. A real catalog song moves a percent or two a week.
//
//   dart run tool/stability_probe.dart [startYear] [years]
import 'dart:io';
import 'dart:math' as math;

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2019;
  final years = args.length > 1 ? int.parse(args[1]) : 3;
  final dir = Directory.systemTemp.createTempSync('stab');
  final g = GameSession.start(
      SaveSlots(dir),
      CareerSetup(
          name: 'Probe',
          genre: 0,
          startYear: year,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 7),
      slotId: 'p');
  final w = g.world;
  final p = w.player!;
  // Buckets: (owner, age) -> list of |weekly change|.
  final changes = <String, List<double>>{};
  final last = <int, double>{};
  var release = 0;
  for (var week = 0; week < 52 * years; week++) {
    // A single every 10 weeks, an album every year.
    if (week % 10 == 0) {
      p.creativeEnergy = 100;
      p.burnoutUntilWeek = -1;
      final s = g.writeSong(budget: BudgetTier.high);
      g.releaseSingle(s.id, campaign: Campaign.standard);
      release++;
    }
    if (week % 52 == 30) {
      final ids = <int>[];
      for (var i = 0; i < 10; i++) {
        p.creativeEnergy = 100;
        p.burnoutUntilWeek = -1;
        ids.add(g.writeSong(budget: BudgetTier.high).id);
      }
      g.releaseAlbum('Album $release', ids, campaign: Campaign.standard);
    }
    g.advanceWeek();
    for (final s in w.songs) {
      if (s.releasedWeek < 0) continue;
      final now = w.songWeekStreamsIn(s, ChartMarket.global);
      final before = last[s.id];
      last[s.id] = now;
      // Holiday songs surge every December, as they do (docs K136).
      if (before == null || before < 200000 || now <= 0 || s.holiday) continue;
      final age = w.week - 1 - s.releasedWeek;
      final who = s.primaryArtistId == p.id ? 'player' : 'rivals';
      final band = age <= 8
          ? 'a 0-8 wk'
          : age <= 52
              ? 'b 9-52 wk'
              : s.status == SongStatus.dormant
                  ? 'd catalog'
                  : 'c 1y+ active';
      (changes['$who $band'] ??= []).add((now / before - 1).abs());
    }
  }
  String pct(double x) => '${(x * 100).toStringAsFixed(1)}%';
  print('owner  age          weeks  median  p75    p90    >5%    >10%');
  for (final k in changes.keys.toList()..sort()) {
    final v = changes[k]!..sort();
    double q(double f) => v[math.min(v.length - 1, (v.length * f).floor())];
    final over5 = v.where((x) => x > 0.05).length / v.length;
    final over10 = v.where((x) => x > 0.10).length / v.length;
    print('${k.padRight(20)} ${v.length.toString().padLeft(6)}  '
        '${pct(q(0.5)).padLeft(6)} ${pct(q(0.75)).padLeft(6)} '
        '${pct(q(0.9)).padLeft(6)} ${pct(over5).padLeft(6)} ${pct(over10).padLeft(6)}');
  }
  g.close();
  dir.deleteSync(recursive: true);
}
