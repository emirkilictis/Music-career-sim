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
import 'dart:math' as math;

import 'package:game/game.dart';

void main(List<String> args) {
  final startYear = args.isNotEmpty ? int.parse(args[0]) : 2010;
  final tier =
      args.length > 1 ? StartTier.values.byName(args[1]) : StartTier.unknown;
  final diff =
      args.length > 2 ? Difficulty.values.byName(args[2]) : Difficulty.normal;
  final years = args.length > 3 ? int.parse(args[3]) : 4;
  final kind =
      ArtistKind.values.byName(Platform.environment['PROBE_KIND'] ?? 'solo');
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
            genre: int.parse(Platform.environment['PROBE_GENRE'] ?? '0'),
            startYear: startYear,
            difficulty: diff,
            tier: tier,
            kind: kind,
            members: kind.isGroup ? const ['Ava', 'Bo', 'Cy', 'Dee'] : const [],
            premium: tier != StartTier.unknown,
            realNames: Platform.environment['PROBE_REAL'] != '0',
            seed: seed),
        slotId: 'p');
    var lastSingle = -100, lastAlbum = s.week;
    for (var y = 0; y < years; y++) {
      final money0 = s.player.moneyCents;
      final songRev0 = _songRevenue(s);
      var spent = 0, noms = 0, wins = 0;
      var maxUs = 0.0, maxGlobal = 0.0, maxWeekStreams = 0.0, maxRival = 0.0;
      for (var wk = 0; wk < GameTime.weeksPerYear; wk++) {
        spent += _week(s, (k) => lastSingle = k, () => lastSingle, (k) {
          lastAlbum = k;
        }, () => lastAlbum);
        if (y == years - 1 && wk == 20) Simulator.debugParts = {};
        final r = s.advanceWeek();
        if (y == years - 1 && wk == 20) {
          final d = Simulator.debugParts!;
          final pl = s.world.player!;
          var dormant = 0.0;
          for (var k = 0; k < regionCount; k++) {
            dormant += pl.sumDormantRate * pl.catalogFactor * pl.regionShare[k];
          }
          print('   parts ${d.map((k, v) => MapEntry(k, _k(v)))} '
              'dormant ${_k(dormant)} weekStreams ${_k(pl.weekStreams)}');
          Simulator.debugParts = null;
        }
        final ws = s.world.playerSongIds
            .fold(0.0, (t, id) => t + s.world.songs[id].weekStreams);
        if (ws > maxWeekStreams) maxWeekStreams = ws;
        for (final id in s.world.activeArtistIds) {
          final a = s.world.artists[id];
          if (a.tier != ArtistTier.player && a.weekStreams > maxRival) {
            maxRival = a.weekStreams;
          }
        }
        for (final e in r.events) {
          if (e is AwardNominated) noms += e.categories.length;
          if (e is AlbumFirstWeek &&
              Platform.environment['PROBE_LOG'] == '$seed') {
            final a = s.world.player!;
            final al = s.world.albums[e.albumId];
            print('   album wk1 US ${_k(e.usUnits)} pure ${_k(e.usPure)} '
                'global ${_k(e.globalUnits)} | fans ${_k(a.coreFans)} '
                'casual ${_k(a.casual)} fame ${a.fame.toStringAsFixed(2)} '
                'hypeAtRel ${al.hypeAtRelease.toStringAsFixed(2)} '
                'devotion ${a.devotion.toStringAsFixed(2)} '
                'share ${[for (final x in a.regionShare) x.toStringAsFixed(2)]}');
          }
          if (e is AlbumFirstWeek) {
            if (e.usUnits > maxUs) maxUs = e.usUnits;
            if (e.globalUnits > maxGlobal) maxGlobal = e.globalUnits;
          }
          if (e is AwardResults) wins += e.won.length;
          if (e is LabelOffer && e.label.index > s.player.label.index) {
            try {
              s.signLabel(e.label);
            } on GameException {/* still under contract */}
          }
        }
      }
      // Best US peaks of songs released this year.
      final yr = s.year - 1;
      var best = 999, top40 = 0, top10 = 0, no1 = 0;
      for (final song in s.songs) {
        if (song.releasedWeek < 0 || GameTime.yearOf(song.releasedWeek) != yr) {
          continue;
        }
        for (final c in song.charts) {
          if (c.chartId != us) continue;
          if (c.peak < best) best = c.peak;
          if (c.peak <= 40) top40++;
          if (c.peak <= 10) top10++;
          if (c.peak == 1) no1++;
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
        no1,
        noms,
        wins,
        maxUs,
        maxGlobal,
        maxWeekStreams,
        for (var k = 0; k < regionCount; k++)
          p.lifetimeStreams.byRegion[k],
        maxRival,
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

    int sum(int i) => rows[y].fold(0, (t, r) => t + r[i].toInt());
    int lo(int i) =>
        rows[y].map((r) => r[i].toInt()).reduce((a, b) => a < b ? a : b);
    String peaks(int i) =>
        rows[y].map((r) => r[i] >= 999 ? '-' : '${r[i]}').join(',');
    print('${y + 1}  ${_k(med(0)).padLeft(7)} ${_k(med(1)).padLeft(7)} '
        '${_k(med(2)).padLeft(7)} ${_k(med(3)).padLeft(7)} '
        '${_k(med(4)).padLeft(7)}  ${(lo(5) >= 999 ? '-' : '${lo(5)}').padLeft(4)} '
        '${med(6).toStringAsFixed(0).padLeft(4)} ${med(7).toStringAsFixed(0).padLeft(4)}'
        ' #1s ${med(11).toStringAsFixed(0)}'
        ' awards ${sum(12)}/${sum(13)}'
        '  fame ${med(9).toStringAsFixed(0)}% label ${med(10).toStringAsFixed(0)}'
        '  US song peaks [${peaks(5)}] album [${peaks(8)}]');
    double mx(int i) => rows[y].map((r) => r[i].toDouble()).reduce(math.max);
    print('     max album wk1 US ${_k(mx(14))} global ${_k(mx(15))}'
        '  max weekly streams ${_k(mx(16))} (monthly listeners '
        '${_k(mx(16) * 0.45 * 4.3 / 12)})  life streams NA/EU/other '
        '${_k(med(17))}/${_k(med(18))}/${_k(med(19))}  top rival week '
        '${_k(mx(20))}');
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

  // A heavy player posts three times a week (docs K105 probe).
  if (heavy && s.year >= 2004) {
    for (final k in [PostKind.studio, PostKind.fans, PostKind.hotTake]) {
      try {
        s.post(k);
      } on GameException {/* limit */}
    }
  }

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
    final left = s.player.moneyCents ~/ 4 - s.player.campaignCosts[c.index];
    final radio = _radio(s, left);
    final before = s.player.moneyCents;
    try {
      s.releaseSingle(best.id, campaign: c, radio: radio);
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
      if (heavy) {
        // Eight collector editions, one a week (docs K105 probe).
        s.releaseAlbum('Album ${s.year}', tracks,
            campaign: c,
            variantWeeks: const [0, 0, 1, 2, 3, 4, 5, 6],
            variantFormats: const [
              null,
              EditionFormat.signed,
              EditionFormat.vinyl,
              EditionFormat.cd,
              EditionFormat.deluxe,
              EditionFormat.signed,
              EditionFormat.vinyl,
              EditionFormat.cd,
            ]);
      } else {
        s.releaseAlbum('Album ${s.year}', tracks, campaign: c);
      }
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

/// The biggest radio push the label allows within [budget] (docs K84).
RadioPush _radio(GameSession s, int budget) {
  final costs = s.radioPushCosts;
  for (final r in RadioPush.values.reversed) {
    if (r.index > s.maxRadioPush.index) continue;
    if (costs[r]! <= budget) return r;
  }
  return RadioPush.none;
}

final heavy = Platform.environment['PROBE_HEAVY'] == '1';

String _k(double v) => v.abs() >= 1e6
    ? '${(v / 1e6).toStringAsFixed(1)}M'
    : v.abs() >= 1e3
        ? '${(v / 1e3).toStringAsFixed(0)}K'
        : v.toStringAsFixed(0);
