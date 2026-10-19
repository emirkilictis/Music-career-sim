import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';

/// Record labels: terms, what each asks for, and signing (docs K54).
class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  List<LabelView> _labels = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final labels = await widget.state.read(Cmd.labels());
    if (mounted) setState(() => _labels = labels);
  }

  Future<void> _sign(LabelView v) async {
    final l = context.l10n;
    final fmt = context.fmt;
    // Going independent needs no deal; a label asks which shape (K107).
    final deal = v.label == Label.independent
        ? ContractDeal.standard
        : await _pickDeal(v);
    if (deal == null || !mounted) return;
    try {
      await widget.state.act(Cmd.signLabel(v.label, deal: deal));
      if (mounted) showInfo(context, l.labelSigned(fmt.labelName(v.label)));
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// The three deal shapes with [v.label] and their terms (docs K107).
  Future<ContractDeal?> _pickDeal(LabelView v) {
    final l = context.l10n;
    final fmt = context.fmt;
    return showModalBottomSheet<ContractDeal>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(l.dealTitle, style: Theme.of(c).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(l.dealHint, style: Theme.of(c).textTheme.bodySmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l.dealLeverage((v.leverage * 100).round()),
                  style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
            for (final d in ContractDeal.values)
              ListTile(
                enabled: v.canAffordDeal(d),
                leading: Icon(switch (d) {
                  ContractDeal.standard => Icons.description_outlined,
                  ContractDeal.bigAdvance => Icons.payments_outlined,
                  ContractDeal.betterSplit => Icons.pie_chart_outline_rounded,
                }),
                title: Text(switch (d) {
                  ContractDeal.standard => l.dealStandard,
                  ContractDeal.bigAdvance => l.dealBigAdvance,
                  ContractDeal.betterSplit => l.dealBetterSplit,
                }),
                subtitle: Text([
                  switch (d) {
                    ContractDeal.standard => l.dealStandardHint,
                    ContractDeal.bigAdvance => l.dealBigAdvanceHint,
                    ContractDeal.betterSplit => l.dealBetterSplitHint,
                  },
                  l.dealTerms(
                      fmt.money(v.deals[d]!.advanceCents),
                      (v.deals[d]!.artistShare * 100).round(),
                      v.deals[d]!.albums),
                  if (v.buyoutCents > 0)
                    l.dealNet(v.netFor(d) < 0
                        ? '−${fmt.money(-v.netFor(d))}'
                        : fmt.money(v.netFor(d))),
                ].join('\n')),
                isThreeLine: true,
                onTap: () => Navigator.pop(c, d),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final legend = _labels.isNotEmpty && _labels.first.legend;
    final current = _labels.where((v) => v.isCurrent).firstOrNull;
    final fmt = context.fmt;
    return Scaffold(
      appBar: AppBar(title: Text(l.labelsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.labelsHint, style: TextStyle(color: AppColors.textMuted)),
          if (current != null && current.buyoutCents > 0) ...[
            const SizedBox(height: 6),
            Text(
                l.labelsContractHint(
                    fmt.labelName(current.label), current.contractAlbumsLeft),
                style: TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w600)),
          ],
          if (current != null && current.label != Label.independent) ...[
            const SizedBox(height: 6),
            Text(
                current.unrecoupedCents > 0
                    ? l.labelUnrecouped(fmt.money(current.unrecoupedCents))
                    : l.labelRecouped,
                style: TextStyle(
                    color: current.unrecoupedCents > 0
                        ? AppColors.coral
                        : AppColors.mint,
                    fontWeight: FontWeight.w600)),
          ],
          if (legend) ...[
            const SizedBox(height: 6),
            Text(l.labelsLegendHint,
                style: TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          for (final v in _labels.reversed) ...[
            _LabelCard(
                view: v,
                busy: widget.state.busy,
                onSign: v.canSign ? () => _sign(v) : null),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _LabelCard extends StatelessWidget {
  const _LabelCard({required this.view, required this.busy, this.onSign});
  final LabelView view;
  final bool busy;
  final VoidCallback? onSign;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final x = view.label;
    Widget term(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(
                child: Text(k, style: TextStyle(color: AppColors.textMuted))),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        );
    final needs = <(String, bool)>[
      if (view.minFans > 0)
        (
          l.labelNeedsFans(fmt.compact(view.minFans)),
          !view.missing.contains(LabelRequirement.fans)
        ),
      if (view.minFame > 0)
        (
          l.labelNeedsFame((view.minFame * 100).round()),
          !view.missing.contains(LabelRequirement.fame)
        ),
      if (view.minResult != null)
        (
          l.labelNeedsEra(fmt.eraResult(view.minResult!)),
          !view.missing.contains(LabelRequirement.lastEra)
        ),
    ];
    return Section(
      title: fmt.labelName(x),
      icon: view.isCurrent ? Icons.verified_rounded : Icons.album_outlined,
      trailing: view.isCurrent
          ? Tag(l.labelCurrent, color: AppColors.mint)
          : Text(fmt.labelKind(x),
              style: TextStyle(color: AppColors.textMuted)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MeterRow(
            label: l.labelReach, value: x.reach / 1.4, text: '×${x.reach}'),
        term(l.labelYourShare,
            '${((view.isCurrent ? view.currentShare : view.deals[ContractDeal.standard]!.artistShare) * 100).round()}%'),
        term(l.labelMaxCampaign, fmt.campaign(x.maxCampaign)),
        term(l.labelCampaignShare, '${(x.campaignShare * 100).round()}%'),
        if (x.advanceCents > 0 && !view.isCurrent)
          term(l.labelAdvance,
              fmt.money(view.deals[ContractDeal.standard]!.advanceCents)),
        if (!view.isCurrent && view.buyoutCents > 0) ...[
          term(l.labelBuyout, '−${fmt.money(view.buyoutCents)}'),
          term(
              l.labelNet,
              view.netCents < 0
                  ? '−${fmt.money(-view.netCents)}'
                  : fmt.money(view.netCents)),
        ],
        term(
            l.labelContract,
            x.contractAlbums == 0
                ? l.labelNoContract
                : l.labelContractAlbums(x.contractAlbums)),
        const SizedBox(height: 8),
        if (needs.isEmpty)
          Text(l.labelNoRequirements,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13))
        else
          for (final (text, ok) in needs)
            Row(children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 18, color: ok ? AppColors.mint : AppColors.coral),
              const SizedBox(width: 6),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
            ]),
        if (!view.isCurrent) ...[
          if (view.wouldSign && !view.canAfford) ...[
            const SizedBox(height: 8),
            Text(l.labelBuyoutShort,
                style: TextStyle(color: AppColors.coral, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed: busy ? null : onSign,
            child: Text(view.buyoutCents > 0
                ? (x == Label.independent
                    ? l.labelBuyoutIndependent
                    : l.labelBuyoutSign)
                : x == Label.independent
                    ? l.labelGoIndependent
                    : l.labelSign),
          ),
        ],
      ]),
    );
  }
}
