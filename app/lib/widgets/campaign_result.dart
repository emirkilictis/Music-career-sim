import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/scope.dart';
import '../ui/palette.dart';
import 'common.dart';

/// What a campaign cost and what it brought in, estimated (docs K57).
class CampaignResult extends StatelessWidget {
  const CampaignResult({
    super.key,
    required this.campaign,
    required this.costCents,
    required this.returnCents,
    this.power = 1,
  });

  final Campaign campaign;
  final int costCents;
  final int returnCents;

  /// Share of the campaign's effect that landed (fatigue).
  final double power;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final net = returnCents - costCents;
    return Section(
      title: l.campaignResultTitle(fmt.campaign(campaign)),
      icon: Icons.campaign_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StatGrid(tiles: [
          StatTile(label: l.campaignCost, value: fmt.money(costCents)),
          StatTile(label: l.campaignReturn, value: fmt.money(returnCents)),
          StatTile(
              label: net >= 0 ? l.campaignProfit : l.campaignLoss,
              value: '${net >= 0 ? '+' : '−'}${fmt.money(net.abs())}',
              color: net >= 0 ? AppColors.mint : AppColors.coral),
        ]),
        const SizedBox(height: 6),
        Text(
            power < 0.99
                ? '${l.campaignReturnHint} '
                    '${l.campaignFatigued((power * 100).round())}'
                : l.campaignReturnHint,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
      ]),
    );
  }
}
