import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/scope.dart';
import '../ui/palette.dart';
import 'common.dart';
import 'event_icon.dart';

/// Record money by source (docs K145): one bar per source, biggest first.
class IncomeCard extends StatelessWidget {
  const IncomeCard({super.key, required this.income, required this.title});
  final IncomeBreakdown income;
  final String title;

  static Color color(IncomeSource s) => switch (s) {
        IncomeSource.streamify => platformColor(MusicPlatform.streamify),
        IncomeSource.fruitMusic => platformColor(MusicPlatform.fruitMusic),
        IncomeSource.viewTube => platformColor(MusicPlatform.viewTube),
        IncomeSource.noiseCloud => platformColor(MusicPlatform.noiseCloud),
        IncomeSource.downloads => platformColor(MusicPlatform.fruitTunes),
        IncomeSource.physical => AppColors.gold,
        IncomeSource.ringtones => AppColors.coral,
        IncomeSource.albumSales => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final total = income.total;
    final rows = income.cents.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Section(
      title: title,
      icon: Icons.payments_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(fmt.money(total.round()),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final e in rows) ...[
          Row(children: [
            Expanded(
                child: Text(fmt.incomeSource(e.key),
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(
                '${fmt.money(e.value.round())} · ${(e.value / total * 100).round()}%',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total <= 0 ? 0 : e.value / total,
              minHeight: 6,
              color: color(e.key),
              backgroundColor: AppColors.textFaint.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(l.incomeHint,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      ]),
    );
  }
}
