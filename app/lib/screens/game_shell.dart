import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/event_lines.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/event_icon.dart';
import 'career_tab.dart';
import 'charts_tab.dart';
import 'dashboard_tab.dart';
import 'releases_tab.dart';
import 'studio_tab.dart';

/// Pushes [page] with the open career available to it.
Future<T?> pushInCareer<T>(BuildContext context, Widget page) {
  final state = Scope.read<CareerState>(context);
  return Navigator.of(context).push<T>(MaterialPageRoute(
      builder: (_) => Scope<CareerState>(value: state, child: page)));
}

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
          context.l10n.dailyBonus(context.fmt.money(Actions.dailyBonusCents)),
          icon: Icons.card_giftcard_rounded);
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
        showInfo(context, context.fmt.event(lines.first),
            icon: Icons.notifications_none_rounded);
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
            PillBar(value: n / GameTime.weeksPerYear, height: 12),
            const SizedBox(height: 12),
            Text(l.weeksPlayed(n),
                style: const TextStyle(color: AppColors.textMuted)),
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
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  EventIcon(line.event, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Text(fmt.event(line),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600))),
                ]),
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
        final paper = _tab == 3;
        return Scaffold(
          backgroundColor: paper ? PaperColors.ink : null,
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              if (!paper)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    ArtistAvatar(name: p.name, seed: p.id, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(fmt.week(career.week),
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    MoneyPill(text: fmt.money(p.moneyCents)),
                  ]),
                ),
              Expanded(
                child: IndexedStack(index: _tab, children: const [
                  DashboardTab(),
                  StudioTab(),
                  ReleasesTab(),
                  ChartsTab(),
                  CareerScreen(embedded: true),
                ]),
              ),
            ]),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: AppColors.bg,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(children: [
                  Expanded(
                    child: GradientButton(
                      label: l.nextWeek,
                      icon: Icons.skip_next_rounded,
                      busy: career.busy,
                      onPressed: career.busy ? null : _nextWeek,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: career.busy ? null : _skipYear,
                      icon: const Icon(Icons.fast_forward_rounded, size: 20),
                      label: Text(l.skipYear),
                    ),
                  ),
                ]),
              ),
              NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home_rounded),
                      label: l.tabHome),
                  NavigationDestination(
                      icon: const Icon(Icons.mic_none_rounded),
                      selectedIcon: const Icon(Icons.mic_rounded),
                      label: l.tabStudio),
                  NavigationDestination(
                      icon: const Icon(Icons.album_outlined),
                      selectedIcon: const Icon(Icons.album_rounded),
                      label: l.tabReleases),
                  NavigationDestination(
                      icon: const Icon(Icons.format_list_numbered_rounded),
                      label: l.tabCharts),
                  NavigationDestination(
                      icon: const Icon(Icons.person_outline_rounded),
                      selectedIcon: const Icon(Icons.person_rounded),
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

/// Money with a thin gradient ring.
class MoneyPill extends StatelessWidget {
  const MoneyPill({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          gradient: AppColors.sunset,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(text,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ),
      );
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
                    value: fmt.signedMoney(report.moneyDeltaCents),
                    color: report.moneyDeltaCents >= 0
                        ? AppColors.mint
                        : AppColors.coral),
                StatTile(
                    label: l.coreFans,
                    value:
                        '${report.coreFansDelta >= 0 ? '+' : ''}${fmt.compact(report.coreFansDelta)}'),
              ]),
              if (highlights.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(l.highlights,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                for (final line in highlights.take(12))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EventIcon(line.event, size: 32),
                          const SizedBox(width: 10),
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
