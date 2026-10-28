import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/scope.dart';
import '../ui/palette.dart';
import 'common.dart';

/// Net profit big, with revenue, costs and how the release did (docs K60).
class ProfitCard extends StatelessWidget {
  const ProfitCard({
    super.key,
    required this.revenueCents,
    required this.costsCents,
    required this.sold,
    this.globalPeak,
  });

  final int revenueCents;
  final int costsCents;
  final double sold;
  final int? globalPeak;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final net = revenueCents - costsCents;
    final color = net >= 0 ? AppColors.mint : AppColors.coral;
    Widget small(String label, String value, {Color? valueColor}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textFaint)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: valueColor ?? AppColors.text)),
          ],
        );
    return Section(
      title: l.profitTitle,
      icon: Icons.account_balance_wallet_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text((net >= 0 ? l.netProfit : l.netLoss).toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
                color: AppColors.textFaint)),
        Text('${net >= 0 ? '' : '−'}${fmt.money(net.abs())}',
            style: TextStyle(
                fontFamily: AppFonts.condensed,
                fontSize: 40,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 10),
        Wrap(spacing: 22, runSpacing: 10, children: [
          small(l.revenue, fmt.money(revenueCents), valueColor: AppColors.mint),
          small(l.totalCosts, fmt.money(costsCents),
              valueColor: AppColors.coral),
          small(l.unitsSold, fmt.compact(sold)),
          if (globalPeak != null)
            small(l.globalPeak, '#$globalPeak', valueColor: AppColors.gold),
        ]),
        const SizedBox(height: 8),
        Text(l.profitHint,
            style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
      ]),
    );
  }
}

/// A US certification badge (gold, platinum, diamond), or nothing below
/// gold.
class CertificationTag extends StatelessWidget {
  const CertificationTag({super.key, required this.units});
  final double units;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cert = Certification.of(units);
    if (cert == null) return const SizedBox.shrink();
    final (level, times) = cert;
    final name = switch (level) {
      Certification.gold => l.certGold,
      Certification.platinum => l.certPlatinum,
      Certification.diamond => l.certDiamond,
    };
    final color = switch (level) {
      Certification.gold => AppColors.gold,
      Certification.platinum => AppColors.sky,
      Certification.diamond => AppColors.lilac,
    };
    return Tag(
        level == Certification.diamond
            ? context.fmt.certLevel(level, times)
            : times > 1
                ? l.certMultiple(times, name)
                : name,
        color: color,
        icon: Icons.album_rounded);
  }
}
