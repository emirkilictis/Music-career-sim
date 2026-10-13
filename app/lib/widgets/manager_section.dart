import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import 'common.dart';

/// The player's manager on the Career tab (docs K68).
class ManagerSection extends StatelessWidget {
  const ManagerSection({super.key});

  Future<void> _choose(BuildContext context) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final p = career.player;
    final pick = await showModalBottomSheet<Manager>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l.managerChoose,
                  style: Theme.of(c).textTheme.titleLarge),
            ),
            for (final m in Manager.values)
              ListTile(
                enabled: m != p.manager && p.coreFans >= m.minFans,
                leading: Icon(m == p.manager
                    ? Icons.check_circle_rounded
                    : Icons.badge_outlined),
                title: Text(fmt.managerName(m)),
                subtitle: Text(p.coreFans < m.minFans
                    ? l.managerNeedsFans(fmt.compact(m.minFans))
                    : fmt.managerTerms(m)),
                onTap: () => Navigator.pop(c, m),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (pick == null || !context.mounted) return;
    try {
      await career.act(Cmd.hireManager(pick));
      if (context.mounted) {
        showInfo(
            context,
            pick == Manager.none
                ? l.managerLetGo
                : l.managerHired(fmt.managerName(pick)),
            icon: Icons.badge_rounded);
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final m = context.career.player.manager;
    return Section(
      title: l.managerSection,
      icon: Icons.badge_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(fmt.managerName(m),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(fmt.managerTerms(m), style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: context.career.busy ? null : () => _choose(context),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text(l.managerChoose),
          ),
        ),
      ]),
    );
  }
}
