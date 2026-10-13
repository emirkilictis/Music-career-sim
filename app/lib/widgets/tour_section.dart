import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../screens/tour_screen.dart';
import '../ui/palette.dart';
import 'common.dart';

/// Touring on the Career tab and the Home screen (docs K63): the tour on
/// the road, or a way to plan one.
class TourSection extends StatelessWidget {
  const TourSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final t = career.player.tour;
    return Section(
      title: l.tourSection,
      icon: Icons.stadium_outlined,
      child: t == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TourScreen(state: career))),
                icon: const Icon(Icons.map_outlined),
                label: Text(l.tourPlan),
              ),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(fmt.tourKind(t.kind),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(l.tourOnRoad(t.weekOfTour, t.weeks),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (t.weekOfTour - 1) / t.weeks,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceLow,
                  color: AppColors.peach,
                ),
              ),
              const SizedBox(height: 6),
              Text(l.tourNow(fmt.region(t.region)),
                  style: TextStyle(color: AppColors.textMuted)),
              Text(l.tourSoFar(fmt.compact(t.tickets), fmt.money(t.netCents)),
                  style: TextStyle(color: AppColors.textMuted)),
            ]),
    );
  }
}
