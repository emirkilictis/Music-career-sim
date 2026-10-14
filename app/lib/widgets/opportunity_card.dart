import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import 'common.dart';
import 'event_icon.dart';

/// The offer waiting for an answer, with its choices (docs K59).
class OpportunityCard extends StatelessWidget {
  const OpportunityCard({super.key, required this.offer});
  final OpportunityView offer;

  Future<void> _answer(BuildContext context, OpportunityChoice c) async {
    final career = context.careerRead;
    final fmt = context.fmt;
    try {
      final out = await career.act(Cmd.answerOpportunity(c));
      if (context.mounted) {
        showInfo(context, fmt.offerOutcome(out),
            icon: opportunityIcon(out.kind));
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final busy = context.career.busy;
    final o = offer;
    final scandal = o.kind == OpportunityKind.scandal ||
        o.kind == OpportunityKind.memberRift;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.r(22)),
        border: Border.all(
            color: (scandal ? AppColors.coral : AppColors.butter)
                .withValues(alpha: 0.6),
            width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconBubble(opportunityIcon(o.kind),
              color: scandal ? AppColors.coral : AppColors.butter),
          const SizedBox(width: 12),
          Expanded(
            child: Text(fmt.offerTitle(o.kind),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(fmt.offerBody(o), style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Text(
            o.weeksLeft <= 1
                ? l.offerAnswerSoon
                : l.offerAnswerWeeks(o.weeksLeft),
            style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textFaint,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (i, c) in o.choices.indexed)
            i == 0
                ? FilledButton(
                    onPressed: busy ? null : () => _answer(context, c),
                    child: Text(fmt.offerChoice(o.kind, c)))
                : OutlinedButton(
                    onPressed: busy ? null : () => _answer(context, c),
                    child: Text(fmt.offerChoice(o.kind, c))),
        ]),
      ]),
    );
  }
}
