import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/scope.dart';
import '../ui/palette.dart';

/// An album's rollout steps, done or not (docs K165).
class RolloutChecklist extends StatelessWidget {
  const RolloutChecklist({super.key, required this.status});
  final RolloutStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String label(RolloutStep s) => switch (s) {
          RolloutStep.leadSingle => l.rolloutLeadSingle,
          RolloutStep.secondSingle => l.rolloutSecondSingle,
          RolloutStep.announced => l.rolloutAnnounced,
          RolloutStep.video => l.rolloutVideo,
          RolloutStep.teaser => l.rolloutTeaser,
          RolloutStep.pitch => l.rolloutPitch,
        };
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final s in RolloutStep.values)
        if (status.counts(s))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status.has(s)
                  ? AppColors.mint.withValues(alpha: 0.15)
                  : Colors.transparent,
              border: Border.all(
                  color: status.has(s) ? AppColors.mint : AppColors.textMuted),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  status.has(s)
                      ? Icons.check_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 14,
                  color: status.has(s) ? AppColors.mint : AppColors.textMuted),
              const SizedBox(width: 4),
              Text(label(s), style: const TextStyle(fontSize: 12)),
            ]),
          ),
    ]);
  }
}
