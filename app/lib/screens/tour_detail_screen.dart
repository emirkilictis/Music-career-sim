import 'package:flutter/material.dart';

import '../core/career_state.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';
import 'tour_screen.dart';

/// The tour on the road (docs K76): its numbers so far and every night,
/// played ones with their box office.
class TourDetailScreen extends StatelessWidget {
  const TourDetailScreen({super.key, required this.state});
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return Scope<CareerState>(
      value: state,
      child: Builder(builder: (context) {
        final t = context.career.player.tour;
        if (t == null) {
          return Scaffold(appBar: AppBar(title: Text(l.tourDetails)));
        }
        final net = t.netCents;
        return Scaffold(
          appBar: AppBar(title: Text(fmt.tourName(t.name, t.kind))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                  [
                    for (final leg in t.legs)
                      '${fmt.tourMarket(leg.market)} · ${fmt.tourKind(leg.kind)}'
                  ].join('  →  '),
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(
                  [
                    fmt.tourProduction(t.production),
                    l.tourPriceFactor((t.priceFactor * 100).round()),
                    if (t.openerName != null)
                      '${l.tourOpener}: ${t.openerName}',
                  ].join(' · '),
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 12),
              Section(
                title: l.tourPlayed(t.played, t.shows.length),
                icon: Icons.stadium_outlined,
                child: StatGrid(tiles: [
                  StatTile(
                      label: l.tourStatTickets, value: fmt.compact(t.tickets)),
                  StatTile(label: l.tourStatSoldOut, value: '${t.soldOut}'),
                  StatTile(
                      label: l.tourStatGross, value: fmt.money(t.grossCents)),
                  StatTile(
                      label: l.tourStatMerch, value: fmt.money(t.merchCents)),
                  StatTile(
                      label: l.tourStatNet,
                      value: '${net >= 0 ? '+' : '−'}${fmt.money(net.abs())}',
                      color: net >= 0 ? AppColors.mint : AppColors.coral),
                  StatTile(
                      label: l.tourStatFans, value: '+${fmt.compact(t.fans)}'),
                ]),
              ),
              const SizedBox(height: 12),
              Section(
                title: l.tourSchedule,
                icon: Icons.event_note_rounded,
                child: Column(children: [
                  for (final s in t.shows) TourShowRow(show: s),
                ]),
              ),
            ],
          ),
        );
      }),
    );
  }
}
