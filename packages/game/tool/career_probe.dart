// How hard is a career for a sensible player (docs K70)? Plays several
// worlds with a fixed, reasonable strategy and prints what each year
// brought: money, income from songs, fans, hits.
//
//   dart run tool/career_probe.dart [startYear] [tier] [difficulty] [years]
//
// Strategy: spend skill points on writing skills, take ads, keep a day job
// while poor, write whenever creativity is full enough, hire the best
// collaborators the budget allows, release the best vault song as a single
// every 6 weeks with the best campaign worth a quarter of the money, an
// album once a year with 10+ songs, sign any bigger label that offers.
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final startYear = args.isNotEmpty ? int.parse(args[0]) : 2010;
  final tier =
      args.length > 1 ? StartTier.values.byName(args[1]) : StartTier.unknown;
  final diff =
      args.length > 2 ? Difficulty.values.byName(args[2]) : Difficulty.normal;
  final years = args.length > 3 ? int.parse(args[3]) : 4;
  final us = Charts.all.indexWhere((c) => c.key == 'chart.us.songs');
  final usAlb = Charts.all.indexWhere((c) => c.key == 'chart.us.albums');
  final dir = Directory.systemTemp.createTempSync('probe');
  final rows = List.generate(years, (_) => <List<num>>[]);
  final seeds =
      Platform.environment['PROBE_SEEDS']?.split(',').map(int.parse).toList() ??
          [11, 22, 33, 44, 55, 66];
  for (final seed in seeds) {
    final slots = SaveSlots(Directory('${dir.path}/$seed'));
    final s = GameSession.start(
        slots,
        CareerSetup(
            name: 'Probe Star',
            genre: 0,
            startYear: startYear,
            difficulty: diff,
            tier: tier,
            premium: tier != StartTier.unknown,
            realNames: Platform.environment['PROBE_REAL'] != '0',
            seed: seed),
        slotId: 'p');
    var lastSingle = -100, lastAlbum = s.week;
    for (var y = 0; y < years; y++) {
      final money0 = s.player.moneyCents;
      final songRev0 = _songRevenue(s);
      var spent = 0;
      for (var wk = 0; wk < GameTime.weeksPerYear; wk++) {
        spent += _week(s, (k) => lastSingle = k, () => lastSingle, (k) {
          lastAlbum = k;
        }, () => lastAlbum);
        final r = s.advanceWeek();
        for (final e in r.events) {
          if (e is LabelOffer && e.label.index > s.player.label.index) {
            try {
              s.signLabel(e.label);
            } on GameException {/* still under contract */}
          }
        }
      }
      // Best US peaks of songs released this year.
      final yr = s.year - 1;
      var best = 999, top40 = 0, top10 = 0;
      for (final song in s.songs) {
        if (song.releasedWeek < 0 || GameTime.yearOf(song.releasedWeek) != yr) {
          continue;
        }
        for (final c in song.charts) {
          if (c.chartId != us) continue;
          if (c.peak < best) best = c.peak;
          if (c.peak <= 40) top40++;
          if (c.peak <= 10) top10++;
        }
      }
      if (Platform.environment['PROBE_LOG'] == '$seed') {
        final p = s.player;
        print('-- seed $seed year ${y + 1} label ${p.label.name} '
            'fame ${(p.fame * 100).round()}% fans ${(p.coreFans / 1e3).round()}K '
            'skills ${[
          for (final k in SkillKind.values) p.skills[k]!.round()
        ]}');
        for (final song in s.songs) {
          if (song.releasedWeek < 0 ||
              GameTime.yearOf(song.releasedWeek) != yr ||
              !song.isSingle) {
            continue;
          }
          final pk = song.charts
              .where((c) => c.chartId == us)
              .map((c) => c.peak)
              .fold(999, (a, b) => a < b ? a : b);
          print('   wk ${song.releasedWeek - GameTime.firstWeekOf(yr) + 1} '
              'grade ${song.grade} ${song.campaign.name} '
              'peak ${pk == 999 ? '-' : pk} '
              'streams ${(song.lifetimeStreams.total / 1e6).toStringAsFixed(1)}M');
        }
      }
      var bestAlb = 999;
      for (final al in s.albums) {
        for (final c in al.charts) {
          if (c.chartId == usAlb && c.peak < bestAlb) bestAlb = c.peak;
        }
      }
      final p = s.player;
      rows[y].add([
        p.moneyCents / 100,
        (p.moneyCents - money0) / 100,
        (_songRevenue(s) - songRev0) / 100,
        spent / 100,
        p.coreFans,
        best,
        top40,
        top10,
        bestAlb,
        p.fame * 100,
        p.label.index,
      ]);
    }
    s.close();
  }
  dir.deleteSync(recursive: true);
  print(
      'start $startYear ${tier.name} ${diff.name}, ${seeds.length} worlds; medians '
      '(best peaks: min over worlds)');
  print('yr   money   Δmoney  songRev   spent    fans  bestUS top40 top10 '
      'bestAlbum');
  for (var y = 0; y < years; y++) {
    double med(int i) {
      final v = [for (final r in rows[y]) r[i].toDouble()]..sort();
      return v[v.length ~/ 2];
    }

    int lo(int i) =>
        rows[y].map((r) => r[i].toInt()).reduce((a, b) => a < b ? a : b);
    String peaks(int i) =>
        rows[y].map((r) => r[i] >= 999 ? '-' : '${r[i]}').join(',');
    print('${y + 1}  ${_k(med(0)).padLeft(7)} ${_k(med(1)).padLeft(7)} '
        '${_k(med(2)).padLeft(7)} ${_k(med(3)).padLeft(7)} '
        '${_k(med(4)).padLeft(7)}  ${(lo(5) >= 999 ? '-' : '${lo(5)}').padLeft(4)} '
        '${med(6).toStringAsFixed(0).padLeft(4)} ${med(7).toStringAsFixed(0).padLeft(4)}'
        '  fame ${med(9).toStringAsFixed(0)}% label ${med(10).toStringAsFixed(0)}'
        '  US song peaks [${peaks(5)}] album [${peaks(8)}]');
  }
}

int _songRevenue(GameSession s) =>
    s.songs.fold(0, (t, x) => t + x.revenueCents);

/// One week of play; returns what was spent on songs and campaigns.
int _week(GameSession s, void Function(int) setSingle, int Function() single,
    void Function(int) setAlbum, int Function() album) {
  var spent = 0;
  var p = s.player;
  while (p.skillPoints > 0) {
    final order = [
      SkillKind.songwriting,
      SkillKind.vocals,
      SkillKind.production,
      SkillKind.performance,
      SkillKind.charisma,
    ]..sort((a, b) => p.skills[a]!.compareTo(p.skills[b]!));
    var done = false;
    for (final k in order) {
      try {
        s.spendSkillPoint(k);
        done = true;
        break;
      } on GameException {/* maxed */}
    }
    if (!done) break;
    p = s.player;
  }
  while (s.player.adsLeftThisWeek > 0) {
    s.rewardAd();
  }
  // Move up to the biggest label that would sign (a small one at once:
  // more reach for a share of the money).
  if (Platform.environment['PROBE_LABEL'] != '0') {
    for (final l in s.labels.reversed) {
      if (l.canSign && l.label.index > s.player.label.index) {
        s.signLabel(l.label);
        break;
      }
    }
  }
  p = s.player;
  final want = p.moneyCents < 2000000 ? Job.cafe : Job.none;
  if (p.job != want) s.setJob(want);

  // Write while creativity keeps songs at full strength.
  for (var i = 0; i < 3; i++) {
    p = s.player;
    if (p.burnoutWeeksLeft > 0 || !p.canWrite || p.creativeEnergy < 55) break;
    final money = p.moneyCents;
    final budget = money > 10000000
        ? BudgetTier.high
        : money > 1000000
            ? BudgetTier.medium
            : BudgetTier.low;
    CollaboratorView? pick(CollaboratorRole role) {
      for (final c in s.collaborators(role)) {
        if (c.available && c.feeCents <= money * 0.12) return c;
      }
      return null;
    }

    final prod = pick(CollaboratorRole.producer);
    final cow = pick(CollaboratorRole.songwriter);
    try {
      final before = s.player.moneyCents;
      s.writeSong(budget: budget, producerId: prod?.id, cowriterId: cow?.id);
      spent += before - s.player.moneyCents;
    } on GameException {
      break;
    }
  }

  final vault = s.vault.toList()
    ..sort((a, b) => b.estimatedGrade.compareTo(a.estimatedGrade));
  // A single every 6 weeks.
  if (s.week - single() >= 6 && vault.length >= 2) {
    final best = vault.first;
    final c = _campaign(s, s.player.moneyCents ~/ 4);
    final before = s.player.moneyCents;
    try {
      s.releaseSingle(best.id, campaign: c);
      spent += before - s.player.moneyCents;
      setSingle(s.week);
    } on GameException {/* skip */}
  }
  // An album a year, once there are enough songs.
  final free = s.songs
      .where((x) =>
          x.albumId < 0 &&
          (x.inVault || x.isSingle) &&
          s.week - x.writtenWeek < 80)
      .toList()
    ..sort((a, b) => b.estimatedGrade.compareTo(a.estimatedGrade));
  if (s.week - album() >= 52 && free.length >= 10) {
    final tracks = free.take(12).map((x) => x.id).toList();
    final c = _campaign(s, s.player.moneyCents ~/ 3);
    final before = s.player.moneyCents;
    try {
      s.releaseAlbum('Album ${s.year}', tracks, campaign: c);
      spent += before - s.player.moneyCents;
      setAlbum(s.week);
    } on GameException catch (e) {
      stderr.writeln('album refused: $e');
    }
  }
  return spent;
}

Campaign _campaign(GameSession s, int budget) {
  final p = s.player;
  for (final k in Campaign.values.reversed) {
    if (k.index > p.label.maxCampaign.index) continue;
    if (p.campaignCosts[k.index] <= budget) return k;
  }
  return Campaign.none;
}

String _k(double v) => v.abs() >= 1e6
    ? '${(v / 1e6).toStringAsFixed(1)}M'
    : v.abs() >= 1e3
        ? '${(v / 1e3).toStringAsFixed(0)}K'
        : v.toStringAsFixed(0);
