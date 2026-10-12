import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/event_lines.dart';
import '../core/scope.dart';
import '../widgets/common.dart';
import '../widgets/event_icon.dart';
import 'career_tab.dart';
import 'charts_tab.dart';
import 'dashboard_tab.dart';
import 'releases_tab.dart';
import 'studio_tab.dart';

/// The in-career frame: header (week, money), five tabs and the
/// "Next week" / "Skip year" controls.
class GameShell extends StatefulWidget {
  const GameShell({super.key, required this.state});
  final CareerState state;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _dailyBonus());
  }

  /// Premium daily login bonus, once per calendar day (docs §20.2).
  Future<void> _dailyBonus() async {
    final premium = context.settingsRead.premium;
    if (!premium) return;
    final granted = await widget.state.act(Cmd.dailyBonus(premium));
    if (granted && mounted) {
      showInfo(context,
          context.l10n.dailyBonus(context.fmt.money(Actions.dailyBonusCents)));
    }
  }

  @override
  void dispose() {
    widget.state.dispose();
    super.dispose();
  }

  Future<void> _nextWeek() async {
    final state = widget.state;
    try {
      final lines = await state.nextWeek();
      if (!mounted) return;
      final major = lines.where((l) => l.event.isMajor).toList();
      if (major.isNotEmpty) {
        await _showNews(
            context.l10n
                .weekNewsTitle(GameTime.weekOfYear(state.lastWeekPlayed)),
            major);
      } else if (lines.isNotEmpty) {
        showInfo(context, context.fmt.event(lines.first));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _skipYear() async {
    final state = widget.state;
    final l = context.l10n;
    final progress = ValueNotifier<int>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(l.skippingYear),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, n, __) =>
              Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: n / GameTime.weeksPerYear),
            const SizedBox(height: 12),
            Text(l.weeksPlayed(n)),
          ]),
        ),
      ),
    );
    try {
      final (report, lines) = await state.skipYear((n) => progress.value = n);
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (c) => _YearSummaryDialog(report: report, lines: lines),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        showError(context, e);
      }
    } finally {
      progress.dispose();
    }
  }

  Future<void> _showNews(String title, List<EventLine> lines) {
    final fmt = context.fmt;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(title, style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final line in lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: EventIcon(line.event),
                title: Text(fmt.event(line)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scope<CareerState>(
      value: state,
      child: Builder(builder: (context) {
        final l = context.l10n;
        final fmt = context.fmt;
        final career = context.career;
        final p = career.player;
        final tabs = [
          const DashboardTab(),
          const StudioTab(),
          const ReleasesTab(),
          const ChartsTab(),
          const CareerTab(),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(fmt.week(career.week),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: const Icon(Icons.attach_money, size: 18),
                  label: Text(fmt.money(p.moneyCents).replaceFirst('\$', '')),
                ),
              ),
            ],
          ),
          body: IndexedStack(index: _tab, children: tabs),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        onPressed: career.busy ? null : _nextWeek,
                        icon: career.busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.skip_next_rounded),
                        label: Text(l.nextWeek),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      onPressed: career.busy ? null : _skipYear,
                      child: Text(l.skipYear),
                    ),
                  ]),
                ),
              ),
              NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home),
                      label: l.tabHome),
                  NavigationDestination(
                      icon: const Icon(Icons.mic_none),
                      selectedIcon: const Icon(Icons.mic),
                      label: l.tabStudio),
                  NavigationDestination(
                      icon: const Icon(Icons.album_outlined),
                      selectedIcon: const Icon(Icons.album),
                      label: l.tabReleases),
                  NavigationDestination(
                      icon: const Icon(Icons.leaderboard_outlined),
                      selectedIcon: const Icon(Icons.leaderboard),
                      label: l.tabCharts),
                  NavigationDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(Icons.person),
                      label: l.tabCareer),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _YearSummaryDialog extends StatelessWidget {
  const _YearSummaryDialog({required this.report, required this.lines});
  final YearReport report;
  final List<EventLine> lines;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final highlights = lines.where((x) => x.event.isMajor).toList();
    return AlertDialog(
      title: Text(report.stoppedEarly
          ? l.yearStoppedTitle(report.weeks)
          : l.yearSummaryTitle(GameTime.yearOf(report.fromWeek))),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              StatGrid(tiles: [
                StatTile(
                    label: l.streams, value: fmt.compact(report.streamsGained)),
                StatTile(
                    label: l.albumUnits,
                    value: fmt.compact(report.unitsGained)),
                StatTile(
                    label: l.money,
                    value: fmt.signedMoney(report.moneyDeltaCents)),
                StatTile(
                    label: l.coreFans,
                    value:
                        '${report.coreFansDelta >= 0 ? '+' : ''}${fmt.compact(report.coreFansDelta)}'),
              ]),
              if (highlights.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l.highlights,
                    style: Theme.of(context).textTheme.titleSmall),
                for (final line in highlights.take(12))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EventIcon(line.event, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(fmt.event(line))),
                        ]),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context), child: Text(l.ok)),
      ],
    );
  }
}
