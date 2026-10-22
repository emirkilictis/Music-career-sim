import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/event_lines.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/celebration.dart';
import '../widgets/removal_alert.dart';
import '../widgets/common.dart';
import '../widgets/event_icon.dart';
import '../widgets/week_transition.dart';
import 'career_tab.dart';
import 'charts_tab.dart';
import 'dashboard_tab.dart';
import 'releases_tab.dart';
import 'skip_summary_screen.dart';
import 'studio_tab.dart';

/// Pushes [page] with the open career available to it.
Future<T?> pushInCareer<T>(BuildContext context, Widget page) {
  final state = Scope.read<CareerState>(context);
  return Navigator.of(context).push<T>(MaterialPageRoute(
      builder: (_) => Scope<CareerState>(value: state, child: page)));
}

/// The in-career frame: header (week, money), five tabs and the
/// "Next week" / "Skip" controls.
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
    // Feedback B1: a short "Week 12 → 13" card while the week is played.
    ValueNotifier<WeekOutcome?>? outcome;
    Future<void>? shown;
    if (context.settingsRead.weekTransition) {
      final o = outcome = ValueNotifier(null);
      final from = state.week;
      shown = showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, __, ___) => WeekTransition(fromWeek: from, outcome: o),
      );
    }
    try {
      final lines = await state.nextWeek();
      outcome?.value = WeekOutcome(state.week, state.lastMoneyDelta,
          recoupedCents: state.lastRecouped);
      await shown;
      if (!mounted) return;
      // The biggest moment gets its own screen (feedback E6).
      final big =
          lines.where((l) => isCelebration(l, state.before)).firstOrNull;
      if (big != null) {
        await showCelebration(context, big, state);
        if (!mounted) return;
      }
      // Bought streams removed: its own alert (docs K95, F65).
      for (final r in lines.where((l) => l.event is BotsCaught)) {
        await showRemovalAlert(context, r);
        if (!mounted) return;
      }
      final major = lines.where((l) => l.event.isMajor && l != big).toList();
      if (major.isNotEmpty) {
        await _showNews(context.fmt.weekInMonth(state.lastWeekPlayed), major);
      } else if (lines.isNotEmpty) {
        showInfo(context, context.fmt.event(lines.first),
            icon: Icons.notifications_none_rounded);
      }
    } catch (e) {
      outcome?.value = const WeekOutcome.failed();
      await shown;
      if (mounted) showError(context, e);
    } finally {
      outcome?.dispose();
    }
  }

  /// Feedback B2: skip a few weeks or a year. A skip never stops; what
  /// happened is told at the end (docs K203).
  Future<void> _skipMenu() async {
    final l = context.l10n;
    Widget option(IconData icon, String title, String hint, int value) =>
        ListTile(
          leading: IconBubble(icon, color: AppColors.lilac),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(hint),
          onTap: () => Navigator.pop(context, value),
        );
    final choice = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(l.skipAhead,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            for (final n in const [2, 4, 8, 26])
              option(Icons.fast_forward_rounded, l.skipWeeksOption(n),
                  l.skipWeeksHint, n),
            option(Icons.event_repeat_rounded, l.skipYearOption, l.skipYearHint,
                GameTime.weeksPerYear),
          ],
        ),
      ),
    );
    if (choice != null && mounted) await _skip(choice);
  }

  Future<void> _skip(int weeks) async {
    final state = widget.state;
    final l = context.l10n;
    final progress = ValueNotifier<int>(0);
    final title = weeks == GameTime.weeksPerYear
        ? l.skippingYear
        : l.skippingWeeks(weeks);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, n, __) =>
              Column(mainAxisSize: MainAxisSize.min, children: [
            PillBar(value: n / weeks, height: 12),
            const SizedBox(height: 12),
            Text(l.weeksPlayed(n),
                style: TextStyle(color: AppColors.textMuted)),
          ]),
        ),
      ),
    );
    try {
      final (report, lines) =
          await state.skip(weeks, SkipStop.never, (n) => progress.value = n);
      if (!mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (c) => SkipSummaryScreen(
            report: report, lines: playerNews(lines), state: state),
      ));
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
                    ArtistAvatar(
                        name: p.name, seed: p.id, size: 40, artistId: p.id),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(fmt.week(career.week),
                              style: TextStyle(
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
                child: IndexedStack(index: _tab, children: [
                  DashboardTab(
                    onOpenTab: (i) => setState(() => _tab = i),
                    onNextWeek: _nextWeek,
                  ),
                  const StudioTab(),
                  const ReleasesTab(),
                  const ChartsTab(),
                  const CareerScreen(embedded: true),
                ]),
              ),
            ]),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: AppColors.bg,
                // Slim strip: the content gets the room (E4).
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Row(children: [
                  Expanded(
                    child: GradientButton(
                      height: 46,
                      label: l.nextWeek,
                      icon: Icons.skip_next_rounded,
                      busy: career.busy,
                      onPressed: career.busy ? null : _nextWeek,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: career.busy ? null : _skipMenu,
                      icon: const Icon(Icons.fast_forward_rounded, size: 20),
                      label: Text(l.skip),
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

/// Money in a thin accent frame.
class MoneyPill extends StatelessWidget {
  const MoneyPill({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          gradient: AppColors.sunset,
          borderRadius: BorderRadius.circular(AppShape.r(30)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppShape.r(30)),
          ),
          child: Text(text,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      );
}

