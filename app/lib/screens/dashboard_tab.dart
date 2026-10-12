import 'dart:async';

import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/common.dart';
import '../widgets/event_icon.dart';

/// Home: who you are right now, this week's news and side income.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final p = career.player;
    final s = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Section(
          title: [
            fmt.kind(p.kind),
            fmt.genre(p.genre),
            fmt.difficulty(career.difficulty),
          ].join(' · '),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (p.members.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(p.members.join(', '),
                      style: TextStyle(color: s.outline)),
                ),
              MeterRow(label: l.fame, value: p.fame, text: fmt.percent(p.fame)),
              MeterRow(
                  label: l.popularity,
                  value: p.popularity,
                  text: fmt.percent(p.popularity)),
              MeterRow(
                  label: l.devotion,
                  value: p.devotion,
                  text: fmt.percent(p.devotion),
                  color: s.tertiary),
              const SizedBox(height: 12),
              StatGrid(tiles: [
                StatTile(label: l.coreFans, value: fmt.compact(p.coreFans)),
                StatTile(
                    label: l.listeners, value: fmt.compact(p.casualListeners)),
                StatTile(
                    label: l.streams,
                    value: fmt.compact(p.lifetimeStreams.total)),
                StatTile(
                    label: l.albumUnits,
                    value: fmt.compact(p.lifetimeUnits.total)),
              ]),
              if (p.anticipation > 0.01 ||
                  p.hype > 0.01 ||
                  p.comebackSupport > 0.05)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(spacing: 8, runSpacing: 6, children: [
                    if (p.anticipation > 0.01)
                      Chip(
                          avatar: const Icon(Icons.hourglass_top, size: 16),
                          label: Text(l.anticipationValue(
                              fmt.percent(p.anticipation.clamp(0, 1))))),
                    if (p.hype > 0.01)
                      Chip(
                          avatar: const Icon(Icons.bolt, size: 16),
                          label: Text(
                              l.hypeValue(fmt.percent(p.hype.clamp(0, 1))))),
                    if (p.comebackSupport > 0.05)
                      Chip(
                          avatar: const Icon(Icons.healing, size: 16),
                          label: Text(l.comebackSupport)),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _NewsSection(),
        const SizedBox(height: 12),
        Section(
          title: l.creativeEnergy,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MeterRow(
                label: l.energy,
                value: p.creativeEnergy / 100,
                text: '${p.creativeEnergy.round()}',
                color: p.creativeEnergy < 30 ? s.error : null),
            const SizedBox(height: 6),
            Text(
              p.burnoutWeeksLeft > 0
                  ? l.burnoutWeeks(p.burnoutWeeksLeft)
                  : l.songsLeftThisWeek(p.songsLeftThisWeek),
              style: TextStyle(color: p.burnoutWeeksLeft > 0 ? s.error : null),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        const _SideIncomeSection(),
      ],
    );
  }
}

class _NewsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    if (career.lastWeekPlayed < 0) {
      return Section(title: l.thisWeek, child: EmptyNote(l.newsEmptyStart));
    }
    return Section(
      title: l.weekNewsTitle(GameTime.weekOfYear(career.lastWeekPlayed)),
      trailing: Text(fmt.signedMoney(career.lastMoneyDelta),
          style: TextStyle(
              color: career.lastMoneyDelta >= 0
                  ? Colors.greenAccent
                  : Theme.of(context).colorScheme.error)),
      child: career.lastEvents.isEmpty
          ? EmptyNote(l.newsQuiet)
          : Column(children: [
              for (final line in career.lastEvents.take(8))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: EventIcon(line.event, size: 22),
                  title: Text(fmt.event(line)),
                ),
            ]),
    );
  }
}

class _SideIncomeSection extends StatelessWidget {
  const _SideIncomeSection();

  Future<void> _watchAd(BuildContext context) async {
    final career = context.careerRead;
    final watched = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AdDialog(),
    );
    if (watched != true || !context.mounted) return;
    try {
      await career.act(Cmd.rewardAd());
      if (context.mounted) {
        showInfo(context,
            context.l10n.adReward(context.fmt.money(Actions.adRewardCents)));
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final p = career.player;
    return Section(
      title: l.sideIncome,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.dayJob),
          subtitle: Text(l.dayJobHint(fmt.money(Actions.jobWageCents))),
          value: p.hasJob,
          onChanged: career.busy
              ? null
              : (on) async {
                  try {
                    await career.act(Cmd.setJob(on));
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          icon: const Icon(Icons.ondemand_video),
          label: Text(l.watchAd(fmt.money(Actions.adRewardCents),
              p.adsLeftThisWeek, Actions.maxAdsPerWeek)),
          onPressed: p.adsLeftThisWeek > 0 && !career.busy
              ? () => _watchAd(context)
              : null,
        ),
      ]),
    );
  }
}

/// Stand-in for a rewarded ad until an ad SDK is added (docs §20.1).
class _AdDialog extends StatefulWidget {
  const _AdDialog();

  @override
  State<_AdDialog> createState() => _AdDialogState();
}

class _AdDialogState extends State<_AdDialog> {
  static const _seconds = 3;
  int _left = _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.adTitle),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.ondemand_video, size: 56),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: 1 - _left / _seconds),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel)),
        FilledButton(
            onPressed: _left <= 0 ? () => Navigator.pop(context, true) : null,
            child: Text(_left > 0 ? '$_left' : l.collectReward)),
      ],
    );
  }
}
