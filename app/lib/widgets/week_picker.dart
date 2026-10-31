import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/format.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import 'common.dart';

/// Month, week of the month and year (docs K257, K268): the weeks from
/// [now] to the week picked (1 to [maxWeeks]), or null. Starts at
/// [initial] weeks ahead (a week from now by default); [tooFar] says why
/// a date beyond [maxWeeks] cannot be picked.
Future<int?> pickWeeksAhead(
  BuildContext context, {
  required int now,
  required int maxWeeks,
  required String title,
  required String go,
  required String tooFar,
  int initial = 1,
}) {
  final l = context.l10n;
  final fmt = context.fmt;
  final year0 = GameTime.yearOf(now);
  final first = now + initial;
  var (month, inMonth) = Fmt.monthWeek(GameTime.weekOfYear(first));
  var year = GameTime.yearOf(first);
  final lastYear = GameTime.yearOf(now + maxWeeks);
  int weeksIn(int m) {
    var n = 0;
    for (var w = 1; w <= GameTime.weeksPerYear; w++) {
      if (Fmt.monthWeek(w).$1 == m) n++;
    }
    return n;
  }

  int target() {
    var w = 1;
    while (Fmt.monthWeek(w).$1 != month) {
      w++;
    }
    return GameTime.firstWeekOf(year) + w - 1 + inMonth - 1;
  }

  return showDialog<int>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final weeks = target() - now;
      final ok = weeks >= 1 && weeks <= maxWeeks;
      return AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            initialValue: month,
            decoration: InputDecoration(labelText: l.skipMonth),
            items: [
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(value: m, child: Text(fmt.monthName(m)))
            ],
            onChanged: (v) => set(() {
              month = v ?? month;
              inMonth = inMonth.clamp(1, weeksIn(month));
            }),
          ),
          DropdownButtonFormField<int>(
            key: ValueKey(month),
            initialValue: inMonth.clamp(1, weeksIn(month)),
            decoration: InputDecoration(labelText: l.skipWeek),
            items: [
              for (var w = 1; w <= weeksIn(month); w++)
                DropdownMenuItem(value: w, child: Text(l.skipWeekN(w)))
            ],
            onChanged: (v) => set(() => inMonth = v ?? inMonth),
          ),
          DropdownButtonFormField<int>(
            initialValue: year,
            decoration: InputDecoration(labelText: l.skipYear),
            items: [
              for (var y = year0; y <= lastYear; y++)
                DropdownMenuItem(value: y, child: Text('$y'))
            ],
            onChanged: (v) => set(() => year = v ?? year),
          ),
          const SizedBox(height: 14),
          Text(
              ok
                  ? l.skipToDateWeeks(weeks)
                  : weeks < 1
                      ? l.skipToDatePast
                      : tooFar,
              style:
                  TextStyle(color: ok ? AppColors.textMuted : AppColors.coral)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
          FilledButton(
              onPressed: ok ? () => Navigator.pop(c, weeks) : null,
              child: Text(go)),
        ],
      );
    }),
  );
}
