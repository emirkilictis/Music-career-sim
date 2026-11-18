// Scans new careers for odd stream numbers (docs K304): a released song
// at 0, two songs falling by the same share, one song by the same share
// week after week, singles opening with the same plays.
//
//   dart run tool/stream_bug_scan.dart
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final dir = Directory.systemTemp.createTempSync('scan');
  for (final (year, tier) in [
    (2024, StartTier.unknown),
    (2024, StartTier.risingStar),
    (2024, StartTier.superstar),
    (2016, StartTier.values[2]),
  ]) {
    for (final seed in [3, 7]) {
      final g = GameSession.start(
          SaveSlots(Directory('${dir.path}/$year$seed${tier.name}')),
          CareerSetup(
              name: 'Scan',
              genre: 0,
              startYear: year,
              tier: tier,
              money: StartMoney.millionaire,
              premium: true,
              seed: seed),
          slotId: 'p');
      final singles = <int>[];
      final last = <int, double>{};
      final lastChange = <int, double>{};
      var zeros = 0, sameAcross = 0, sameRun = 0, weeks = 0;
      final opens = <double>[];
      void week() {
        g.advanceWeek();
        weeks++;
        final changes = <String, int>{};
        for (final id in singles) {
          final c = g.streamCounter(EntityKind.song, id).rows.single;
          if (c.daily <= 0) zeros++;
          final before = last[id];
          if (before == null) opens.add(c.daily);
          if (before != null && before > 0) {
            final ch = c.daily / before - 1;
            final k = ch.toStringAsFixed(4);
            changes[k] = (changes[k] ?? 0) + 1;
            if (lastChange[id] != null &&
                (lastChange[id]! - ch).abs() < 1e-5) {
              sameRun++;
            }
            lastChange[id] = ch;
          }
          last[id] = c.daily;
        }
        sameAcross += changes.values.where((n) => n > 1).length;
      }

      for (var n = 0; n < 5; n++) {
        int? id;
        var tries = 0;
        while (id == null && tries++ < 20) {
          try {
            id = g.writeSong(budget: BudgetTier.high).id;
          } on Object {
            week();
          }
        }
        if (id == null) break;
        for (final c in Campaign.values.reversed) {
          try {
            g.releaseSingle(id, campaign: c);
            singles.add(id);
            break;
          } on Object {
            continue;
          }
        }
        for (var i = 0; i < 8; i++) {
          week();
        }
      }
      print('$year ${tier.name} seed $seed: weeks $weeks zeros $zeros '
          'sameAcross $sameAcross sameRun $sameRun '
          'opens ${opens.map((x) => x.round()).toList()}');
      g.close();
    }
  }
}
