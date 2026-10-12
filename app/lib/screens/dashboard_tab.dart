import 'dart:async';

import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/event_icon.dart';
import '../core/format.dart';
import 'game_shell.dart';
import 'streamify/streamify_tab.dart';

/// Home: who you are right now, this week's news and side income.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final p = career.player;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Hero card.
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: AppColors.haze(AppColors.lilac, AppColors.pink),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                ArtistAvatar(name: p.name, seed: p.id, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 24,
                              height: 1.1,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Tag(fmt.kind(p.kind), color: AppColors.lilac),
                        Tag(fmt.genre(p.genre), color: AppColors.pink),
                        Tag(fmt.difficulty(career.difficulty),
                            color: AppColors.peach),
                      ]),
                    ],
                  ),
                ),
              ]),
              if (p.members.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(p.members.join(' · '),
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              MeterRow(label: l.fame, value: p.fame, text: fmt.percent(p.fame)),
              MeterRow(
                  label: l.popularity,
                  value: p.popularity,
                  text: fmt.percent(p.popularity),
                  colors: const [AppColors.sky, AppColors.lilac]),
              MeterRow(
                  label: l.devotion,
                  value: p.devotion,
                  text: fmt.percent(p.devotion),
                  colors: const [AppColors.pink, AppColors.peach]),
              const SizedBox(height: 16),
              StatGrid(tiles: [
                StatTile(label: l.coreFans, value: fmt.compact(p.coreFans)),
                StatTile(
                    label: l.listeners, value: fmt.compact(p.casualListeners)),
                SalesEra.of(GameTime.yearOf(career.week)) == SalesEra.streaming
                    ? StatTile(
                        label: l.streams,
                        value: fmt.compact(p.lifetimeStreams.total))
                    : StatTile(
                        label: l.singleSales,
                        value: fmt.compact(p.lifetimeSingleSales)),
                StatTile(
                    label: l.albumUnits,
                    value: fmt.compact(p.lifetimeUnits.total)),
              ]),
              if (p.anticipation > 0.01 ||
                  p.hype > 0.01 ||
                  p.comebackSupport > 0.05) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (p.anticipation > 0.01)
                    Tag(
                        l.anticipationValue(
                            fmt.percent(p.anticipation.clamp(0, 1))),
                        icon: Icons.hourglass_top_rounded,
                        color: AppColors.butter),
                  if (p.hype > 0.01)
                    Tag(l.hypeValue(fmt.percent(p.hype.clamp(0, 1))),
                        icon: Icons.bolt_rounded, color: AppColors.peach),
                  if (p.comebackSupport > 0.05)
                    Tag(l.comebackSupport,
                        icon: Icons.healing_rounded, color: AppColors.mint),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _NewsSection(),
        const SizedBox(height: 14),
        Section(
          title: l.creativeEnergy,
          icon: Icons.auto_awesome_rounded,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MeterRow(
                label: l.energy,
                value: p.creativeEnergy / 100,
                text: '${p.creativeEnergy.round()}',
                colors: p.creativeEnergy < 30
                    ? const [AppColors.coral, AppColors.peach]
                    : const [AppColors.mint, AppColors.sky]),
            const SizedBox(height: 8),
            Text(
              p.burnoutWeeksLeft > 0
                  ? l.burnoutWeeks(p.burnoutWeeksLeft)
                  : p.restingThisWeek
                      ? l.restingThisWeek
                      : l.songsLeftThisWeek(p.songsLeftThisWeek),
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: p.burnoutWeeksLeft > 0
                      ? AppColors.coral
                      : AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
                l.energyNextWeek(
                    '${p.energyNextWeek >= 0 ? '+' : '−'}${p.energyNextWeek.abs().round()}'),
                style:
                    const TextStyle(color: AppColors.textFaint, fontSize: 13)),
            if (p.creativeEnergy < 30 && p.burnoutWeeksLeft == 0) ...[
              const SizedBox(height: 6),
              Text(l.lowEnergyWarning,
                  style: const TextStyle(
                      color: AppColors.coral, fontWeight: FontWeight.w600)),
            ],
            if (!p.restingThisWeek &&
                p.songsLeftThisWeek == Actions.maxSongsPerWeek) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.beach_access_rounded,
                      color: AppColors.mint),
                  label: Text(l.restThisWeek),
                  onPressed: career.busy
                      ? null
                      : () async {
                          try {
                            await career.act(Cmd.rest());
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          }
                        },
                ),
              ),
              const SizedBox(height: 4),
              Text(l.restHint(Actions.energyRestBonus.round()),
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 12.5)),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        const _SideIncomeSection(),
        const SizedBox(height: 14),
        Section(
          title: l.platforms,
          icon: Icons.podcasts_rounded,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Material(
              color: StreamifyColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                      color: StreamifyColors.accent, shape: BoxShape.circle),
                  child:
                      const Icon(Icons.graphic_eq_rounded, color: Colors.black),
                ),
                title: const Text(platformName,
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(l.streamifyTileHint),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => pushInCareer(context, const StreamifyScreen()),
              ),
            ),
            const SizedBox(height: 10),
            Text(l.morePlatformsSoon,
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: 12.5)),
          ]),
        ),
      ],
    );
  }
}

class _NewsSection extends StatelessWidget {
  const _NewsSection();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    if (career.lastWeekPlayed < 0) {
      return Section(
          title: l.thisWeek,
          icon: Icons.notifications_none_rounded,
          child: EmptyNote(l.newsEmptyStart, icon: Icons.play_circle_outline));
    }
    final delta = career.lastMoneyDelta;
    return Section(
      title: l.weekNewsTitle(GameTime.weekOfYear(career.lastWeekPlayed)),
      icon: Icons.notifications_none_rounded,
      trailing: Tag(fmt.signedMoney(delta),
          color: delta >= 0 ? AppColors.mint : AppColors.coral),
      child: career.lastEvents.isEmpty
          ? EmptyNote(l.newsQuiet, icon: Icons.nightlight_round)
          : Column(children: [
              for (final line in career.lastEvents.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    EventIcon(line.event, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(fmt.event(line),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                ),
            ]),
    );
  }
}

class _SideIncomeSection extends StatelessWidget {
  const _SideIncomeSection();

  /// Day jobs (docs K36): pay against a little energy each week.
  Future<void> _pickJob(BuildContext context) async {
    final career = context.careerRead;
    final l = context.l10n;
    final fmt = context.fmt;
    final current = career.player.job;
    final job = await showModalBottomSheet<Job>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(l.chooseJob,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            for (final j in Job.values)
              ListTile(
                selected: j == current,
                leading: IconBubble(
                    j == Job.none
                        ? Icons.music_note_rounded
                        : Icons.work_outline_rounded,
                    color: j == Job.none ? AppColors.mint : AppColors.butter),
                title: Text(fmt.job(j),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(j == Job.none
                    ? fmt.jobPerk(j)
                    : '${l.jobTerms(fmt.money(j.wageCents), j.energyCost.round())}\n${fmt.jobPerk(j)}'),
                isThreeLine: j != Job.none,
                trailing: j == current
                    ? const Icon(Icons.check_rounded, color: AppColors.mint)
                    : null,
                onTap: () => Navigator.pop(c, j),
              ),
          ],
        ),
      ),
    );
    if (job == null || job == current || !context.mounted) return;
    try {
      await career.act(Cmd.setJob(job));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

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
            context.l10n.adReward(context.fmt.money(Actions.adRewardCents)),
            icon: Icons.paid_rounded);
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
      icon: Icons.savings_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: career.busy ? null : () => _pickJob(context),
            child: Row(children: [
              const IconBubble(Icons.work_outline_rounded,
                  color: AppColors.butter),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l.dayJob}: ${fmt.job(p.job)}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                          p.hasJob
                              ? l.jobTerms(fmt.money(p.job.wageCents),
                                  p.job.energyCost.round())
                              : l.jobPerkNone,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textFaint),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.play_circle_outline_rounded,
                color: AppColors.peach),
            label: Text(l.watchAd(fmt.money(Actions.adRewardCents),
                p.adsLeftThisWeek, Actions.maxAdsPerWeek)),
            onPressed: p.adsLeftThisWeek > 0 && !career.busy
                ? () => _watchAd(context)
                : null,
          ),
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
        const IconBubble(Icons.ondemand_video_rounded,
            color: AppColors.peach, size: 72),
        const SizedBox(height: 18),
        PillBar(value: 1 - _left / _seconds, height: 10),
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
