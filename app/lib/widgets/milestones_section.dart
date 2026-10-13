import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import 'common.dart';

/// Career milestones (docs K61): the next goals with progress, and the
/// full list behind a button.
class MilestonesSection extends StatefulWidget {
  const MilestonesSection({super.key});

  @override
  State<MilestonesSection> createState() => _MilestonesSectionState();
}

class _MilestonesSectionState extends State<MilestonesSection> {
  List<MilestoneView> _all = const [];
  int _loadedRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final career = context.career;
    if (career.revision != _loadedRevision) {
      _loadedRevision = career.revision;
      _load();
    }
  }

  Future<void> _load() async {
    final all = await context.careerRead.read(Cmd.milestones());
    if (mounted) setState(() => _all = all);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final done = _all.where((m) => m.reached).length;
    final next = _all.where((m) => !m.reached).take(3).toList();
    return Section(
      title: l.milestonesTitle,
      icon: Icons.flag_outlined,
      trailing: Text(l.milestonesCount(done, _all.length),
          style: TextStyle(
              color: AppColors.textMuted, fontWeight: FontWeight.w700)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final m in next) _MilestoneRow(m),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _all.isEmpty ? null : () => _showAll(context),
            child: Text(l.milestonesAll),
          ),
        ),
      ]),
    );
  }

  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          builder: (c, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(context.l10n.milestonesTitle,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final m in _all) _MilestoneRow(m),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow(this.m);
  final MilestoneView m;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final progress = m.progress;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(m.reached ? Icons.check_circle_rounded : Icons.flag_outlined,
            color: m.reached ? AppColors.mint : AppColors.textFaint),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fmt.milestoneName(m.milestone),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (m.reached)
              Text(l.milestoneReachedOn(fmt.week(m.reachedWeek!)),
                  style: TextStyle(fontSize: 12.5, color: AppColors.textFaint))
            else if (progress != null) ...[
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppShape.r(4)),
                child: LinearProgressIndicator(
                  value: (progress.$1 / progress.$2).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceLow,
                  color: AppColors.lilac,
                ),
              ),
              const SizedBox(height: 3),
              Text('${fmt.compact(progress.$1)} / ${fmt.compact(progress.$2)}',
                  style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        Text(l.milestoneReward(m.milestone.skillPoints),
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: m.reached ? AppColors.textFaint : AppColors.gold)),
      ]),
    );
  }
}
