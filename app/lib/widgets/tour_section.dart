import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../screens/tour_detail_screen.dart';
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
              Text(fmt.tourName(t.name, t.kind),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(l.tourOnRoad(t.weekOfTour, t.weeks),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppShape.r(4)),
                child: LinearProgressIndicator(
                  value: (t.weekOfTour - 1) / t.weeks,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceLow,
                  color: AppColors.peach,
                ),
              ),
              if (t.thisWeek.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l.tourThisWeek,
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
                Text(
                    {for (final s in t.thisWeek) '${s.city} · ${s.venue}'}
                        .join('\n'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 6),
              Text(l.tourSoFar(fmt.compact(t.tickets), fmt.money(t.netCents)),
                  style: TextStyle(color: AppColors.textMuted)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => TourDetailScreen(state: career))),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: Text(l.tourDetails),
                ),
              ),
            ]),
    );
  }
}
