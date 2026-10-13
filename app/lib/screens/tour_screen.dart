import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';

/// Plans a tour (docs K63): where to play, and each size with what it
/// would bring as things stand.
class TourScreen extends StatefulWidget {
  const TourScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  final Set<Region> _regions = {...Region.values};
  List<TourPlanView> _plans = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = [
      for (final r in Region.values)
        if (_regions.contains(r)) r
    ];
    final plans = order.isEmpty
        ? const <TourPlanView>[]
        : await widget.state.read(Cmd.tourPlans(order));
    if (mounted) setState(() => _plans = plans);
  }

  Future<void> _start(TourPlanView p) async {
    try {
      await widget.state.act(Cmd.startTour(p.kind, p.regions));
      if (!mounted) return;
      showInfo(context, context.l10n.tourStarted, icon: Icons.stadium_rounded);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return Scaffold(
      appBar: AppBar(title: Text(l.tourPlan)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.tourWhere,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final r in Region.values)
              FilterChip(
                label: Text(fmt.region(r)),
                selected: _regions.contains(r),
                onSelected: (on) {
                  setState(() => on ? _regions.add(r) : _regions.remove(r));
                  _load();
                },
              ),
          ]),
          const SizedBox(height: 8),
          Text(l.tourHint(Tours.energyPerWeek.round()),
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          for (final p in _plans) ...[
            _PlanCard(
                plan: p, busy: widget.state.busy, onStart: () => _start(p)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.plan, required this.busy, required this.onStart});
  final TourPlanView plan;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final e = plan.estimate;
    final net = plan.netCents;
    return Section(
      title: fmt.tourKind(plan.kind),
      icon: switch (plan.kind) {
        TourKind.club => Icons.nightlife_rounded,
        TourKind.theater => Icons.theater_comedy_rounded,
        TourKind.arena => Icons.sports_basketball_rounded,
        TourKind.stadium => Icons.stadium_rounded,
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            l.tourSpec(fmt.compact(plan.kind.capacity),
                fmt.money(plan.kind.priceCents), plan.weeks),
            style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        if (!plan.available && plan.kind.minFans > 0)
          Text(l.tourNeedsFans(fmt.compact(plan.kind.minFans)),
              style: TextStyle(
                  color: AppColors.coral, fontWeight: FontWeight.w700))
        else ...[
          Text(
              l.tourEstimate((e.fill * 100).round(), fmt.compact(e.tickets),
                  fmt.compact(e.fans)),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(l.tourNet('${net >= 0 ? '+' : '−'}${fmt.money(net.abs())}'),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: net >= 0 ? AppColors.mint : AppColors.coral)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: busy || !plan.available ? null : onStart,
              icon: const Icon(Icons.directions_bus_rounded),
              label: Text(l.tourStart),
            ),
          ),
        ],
      ]),
    );
  }
}
