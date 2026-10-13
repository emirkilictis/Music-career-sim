import 'dart:async';

import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import 'album_detail_screen.dart';
import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/format.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/tour_section.dart';
import '../widgets/opportunity_card.dart';
import '../widgets/common.dart';
import '../widgets/event_icon.dart';
import 'streamify/streamify_tab.dart';
import 'game_shell.dart';

/// Home, built for focus (feedback E1): what happened this week, the one
/// thing worth doing next, three small status numbers; everything else is
/// quiet and further down. Details live in Career and in tap-to-open sheets.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, this.onOpenTab, this.onNextWeek});

  /// Switches the game's tab bar (1 = Studio, 2 = Releases).
  final void Function(int tab)? onOpenTab;
  final VoidCallback? onNextWeek;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (context.career.player.opportunity case final offer?) ...[
          OpportunityCard(offer: offer),
          const SizedBox(height: 12),
        ],
        if (context.career.player.tour != null) ...[
          const TourSection(),
          const SizedBox(height: 12),
        ],
        const _WeekCard(),
        const SizedBox(height: 12),
        _NextStepCard(onOpenTab: onOpenTab, onNextWeek: onNextWeek),
        const SizedBox(height: 12),
        const _StatusRow(),
        const SizedBox(height: 22),
        const _MoreSection(),
      ],
    );
  }
}

/// This week's news: the biggest story large, the rest small, and what
/// changed (money, fans, streams or sales).
class _WeekCard extends StatelessWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final p = career.player;
    if (career.lastWeekPlayed < 0) {
      return _Card(
        child: Row(children: [
          Icon(Icons.play_circle_outline_rounded, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
              child: Text(l.newsEmptyStart,
                  style: TextStyle(color: AppColors.textMuted))),
        ]),
      );
    }
    final lines = career.lastEvents;
    final top = lines.isEmpty ? null : lines.first;
    final b = career.before;
    final streaming =
        SalesEra.of(GameTime.yearOf(career.week)) == SalesEra.streaming;
    final changes = <Widget>[
      _Delta(fmt.signedMoney(career.lastMoneyDelta),
          up: career.lastMoneyDelta >= 0),
      if (b != null && (p.coreFans - b.coreFans).abs() >= 1)
        _Delta(
            l.fansValue(
                '${p.coreFans >= b.coreFans ? '+' : '−'}${fmt.compact((p.coreFans - b.coreFans).abs())}'),
            up: p.coreFans >= b.coreFans),
      if (b != null && streaming)
        if (p.lifetimeStreams.total - b.lifetimeStreams.total >= 1)
          _Delta(
              l.streamsValue(
                  '+${fmt.compact(p.lifetimeStreams.total - b.lifetimeStreams.total)}'),
              up: true),
      if (b != null && !streaming)
        if (p.lifetimeSingleSales - b.lifetimeSingleSales >= 1)
          _Delta(
              l.singleSalesValue(
                  '+${fmt.compact(p.lifetimeSingleSales - b.lifetimeSingleSales)}'),
              up: true),
    ];
    return _Card(
      highlight: top != null && top.event.isMajor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.fmt.weekInMonth(career.lastWeekPlayed),
            style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        const SizedBox(height: 10),
        if (top == null)
          Text(l.newsQuiet,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            EventIcon(top.event, size: 40),
            const SizedBox(width: 12),
            Expanded(
                child: Text(fmt.event(top),
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.3))),
          ]),
        for (final line in lines.skip(1).take(2))
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 52),
            child: Text(fmt.event(line),
                style: TextStyle(color: AppColors.textMuted)),
          ),
        if (lines.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 52),
            child: Text(l.moreNews(lines.length - 3),
                style: TextStyle(color: AppColors.textFaint)),
          ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: changes),
      ]),
    );
  }
}

/// The one suggested move for right now.
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({this.onOpenTab, this.onNextWeek});
  final void Function(int tab)? onOpenTab;
  final VoidCallback? onNextWeek;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final career = context.career;
    final p = career.player;
    final sinceRelease =
        p.lastReleaseWeek < 0 ? 1 << 20 : career.week - p.lastReleaseWeek;
    Future<void> rest() async {
      try {
        await career.act(Cmd.rest());
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    final (
      IconData icon,
      String title,
      String body,
      String? button,
      VoidCallback? action
    ) step = switch (p) {
      _ when p.burnoutWeeksLeft > 0 => (
          Icons.healing_rounded,
          l.stepBurnoutTitle,
          l.stepBurnoutBody(p.burnoutWeeksLeft),
          p.vaultCount > 0 ? l.goReleases : null,
          () => onOpenTab?.call(2),
        ),
      _
          when p.creativeEnergy < 30 &&
              !p.restingThisWeek &&
              p.songsWrittenThisWeek == 0 =>
        (
          Icons.beach_access_rounded,
          l.stepRestTitle,
          l.stepRestBody(Actions.energyRestBonus.round()),
          l.restNow,
          rest,
        ),
      _ when p.eraAlbumSinglesLeft > 0 && sinceRelease >= 8 => (
          Icons.queue_music_rounded,
          l.stepAlbumSingleTitle,
          l.stepAlbumSingleBody(p.eraAlbumSinglesLeft),
          l.openAlbum,
          () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      AlbumDetailScreen(albumId: p.eraAlbumId, state: career))),
        ),
      _ when p.vaultCount >= GameSession.minAlbumTracks => (
          Icons.album_rounded,
          l.stepAlbumTitle,
          l.stepAlbumBody(p.vaultCount),
          l.goReleases,
          () => onOpenTab?.call(2),
        ),
      _ when p.vaultCount > 0 && sinceRelease >= 6 => (
          Icons.music_note_rounded,
          l.stepReleaseTitle,
          p.lastReleaseWeek < 0
              ? l.stepFirstReleaseBody
              : l.stepReleaseBody(p.vaultCount),
          l.goReleases,
          () => onOpenTab?.call(2),
        ),
      _ when p.moneyCents < 100000 && !p.hasJob => (
          Icons.work_outline_rounded,
          l.stepJobTitle,
          l.stepJobBody,
          l.chooseJob,
          () => pickJob(context),
        ),
      _ when p.skillPoints >= 5 => (
          Icons.trending_up_rounded,
          l.stepSkillsTitle,
          l.stepSkillsBody(p.skillPoints),
          l.goCareer,
          () => onOpenTab?.call(4),
        ),
      _ when p.canWrite && p.creativityPenalty == 0 => (
          Icons.edit_note_rounded,
          l.stepWriteTitle,
          l.stepWriteBody(p.creativeEnergy.round()),
          l.goStudio,
          () => onOpenTab?.call(1),
        ),
      _ => (
          Icons.skip_next_rounded,
          l.stepWaitTitle,
          l.stepWaitBody,
          null,
          null,
        ),
    };
    final (icon, title, body, button, action) = step;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.nextStep,
            style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBubble(icon, color: AppColors.lilac),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(body, style: TextStyle(color: AppColors.textMuted)),
            ]),
          ),
        ]),
        if (button != null) ...[
          const SizedBox(height: 14),
          FilledButton(
            onPressed: career.busy ? null : action,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: AppColors.lilac.withValues(alpha: 0.2),
                foregroundColor: AppColors.lilac),
            child: Text(button,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}

/// Fans, fame and energy as three small tiles; tap energy for details.
class _StatusRow extends StatelessWidget {
  const _StatusRow();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final p = career.player;
    final b = career.before;

    /// The change as text, or null when it would round to nothing.
    String? delta(double now, double? was, String Function(double) f) {
      if (was == null) return null;
      final text = f((now - was).abs());
      return RegExp(r'[1-9]').hasMatch(text) ? text : null;
    }

    return Row(children: [
      Expanded(
          child: _StatusTile(
              label: l.coreFans,
              value: fmt.compact(p.coreFans),
              change: delta(p.coreFans, b?.coreFans, fmt.compact),
              up: b == null || p.coreFans >= b.coreFans)),
      const SizedBox(width: 10),
      Expanded(
          child: _StatusTile(
              label: l.fame,
              value: fmt.percent(p.fame),
              change: delta(p.fame * 100, b == null ? null : b.fame * 100,
                  (v) => v.toStringAsFixed(1)),
              up: b == null || p.fame >= b.fame)),
      const SizedBox(width: 10),
      Expanded(
          child: _StatusTile(
        label: l.energy,
        value: '${p.creativeEnergy.round()}',
        warn: p.creativeEnergy < 30 || p.burnoutWeeksLeft > 0,
        arrow: false,
        change: p.burnoutWeeksLeft > 0
            ? l.burnoutWeeks(p.burnoutWeeksLeft)
            : p.restingThisWeek
                ? l.restingThisWeek
                : null,
        onTap: () => _energySheet(context),
      )),
    ]);
  }

  void _energySheet(BuildContext context) {
    final career = context.careerRead;
    showModalBottomSheet<void>(
      context: context,
      builder: (c) =>
          Scope<CareerState>(value: career, child: const _EnergySheet()),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.value,
    this.change,
    this.up = true,
    this.arrow = true,
    this.warn = false,
    this.onTap,
  });
  final String label;
  final String value;
  final String? change;
  final bool up;

  /// Shows [change] with an up/down arrow (a delta, not a note).
  final bool arrow;
  final bool warn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppShape.r(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.r(18)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: warn ? AppColors.coral : AppColors.text)),
            const SizedBox(height: 2),
            SizedBox(
              height: 17,
              child: change == null
                  ? null
                  : Row(children: [
                      if (arrow)
                        Icon(
                            up
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 13,
                            color: up ? AppColors.mint : AppColors.coral),
                      Flexible(
                        child: Text(change!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: warn || !up
                                    ? AppColors.coral
                                    : arrow
                                        ? AppColors.mint
                                        : AppColors.textMuted)),
                      ),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Energy details and the rest option (opened from the energy tile).
class _EnergySheet extends StatelessWidget {
  const _EnergySheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final career = context.career;
    final p = career.player;
    final canRest = !p.restingThisWeek &&
        p.songsWrittenThisWeek == 0 &&
        p.burnoutWeeksLeft == 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.creativeEnergy,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            MeterRow(
                label: l.energy,
                value: p.creativeEnergy / 100,
                text: '${p.creativeEnergy.round()}',
                colors: p.creativeEnergy < 30
                    ? [AppColors.coral, AppColors.peach]
                    : [AppColors.mint, AppColors.sky]),
            const SizedBox(height: 6),
            Text(
              p.burnoutWeeksLeft > 0
                  ? l.burnoutWeeks(p.burnoutWeeksLeft)
                  : p.restingThisWeek
                      ? l.restingThisWeek
                      : p.creativityPenalty > 0
                          ? l.creativityPenalty(
                              (p.creativityPenalty * 100).round())
                          : l.creativityFull,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            Text(
                l.energyNextWeek(
                    '${p.energyNextWeek >= 0 ? '+' : '−'}${p.energyNextWeek.abs().round()}'),
                style: TextStyle(color: AppColors.textFaint)),
            if (p.creativeEnergy < 30 && p.burnoutWeeksLeft == 0) ...[
              const SizedBox(height: 8),
              Text(l.lowEnergyWarning,
                  style: TextStyle(
                      color: AppColors.coral, fontWeight: FontWeight.w600)),
            ],
            if (canRest) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46)),
                icon: Icon(Icons.beach_access_rounded, color: AppColors.mint),
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
              const SizedBox(height: 4),
              Text(l.restHint(Actions.energyRestBonus.round()),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quiet extras: day job, rewarded ad, platforms.
class _MoreSection extends StatelessWidget {
  const _MoreSection();

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
    Widget row(
            IconData icon, String title, String subtitle, VoidCallback? onTap,
            {Widget? trailing}) =>
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(icon, color: AppColors.textMuted),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, style: TextStyle(color: AppColors.textFaint)),
          trailing: trailing ??
              Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          onTap: onTap,
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Text(l.sideIncome,
            style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
      row(
        Icons.work_outline_rounded,
        '${l.dayJob}: ${fmt.job(p.job)}',
        p.hasJob
            ? l.jobTerms(fmt.money(p.job.wageCents), p.job.energyCost.round())
            : l.jobPerkNone,
        career.busy ? null : () => pickJob(context),
      ),
      row(
        Icons.play_circle_outline_rounded,
        l.watchAd(fmt.money(Actions.adRewardCents), p.adsLeftThisWeek,
            Actions.maxAdsPerWeek),
        '',
        p.adsLeftThisWeek > 0 && !career.busy ? () => _watchAd(context) : null,
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Text(l.platforms,
            style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
      // Platforms appear in their real launch years (docs K38).
      if (GameTime.yearOf(career.week) <
          Charts.all[Charts.platformGlobal].startYear)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(l.platformsLater,
              style: TextStyle(color: AppColors.textFaint)),
        )
      else
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: StreamifyColors.accent, shape: BoxShape.circle),
            child: const Icon(Icons.graphic_eq_rounded,
                color: Colors.black, size: 20),
          ),
          title: const Text(platformName,
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(l.streamifyTileHint,
              style: TextStyle(color: AppColors.textFaint)),
          trailing:
              Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          onTap: () => pushInCareer(context, const StreamifyScreen()),
        ),
    ]);
  }
}

/// A plain card; [highlight] gives the soft accent background used for big
/// news.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.highlight = false});
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          gradient: highlight
              ? AppColors.haze(AppColors.lilac, AppColors.pink)
              : null,
          borderRadius: BorderRadius.circular(AppShape.r(22)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: child,
      );
}

/// "+$12K", "+2.1K fans": green when up, red when down.
class _Delta extends StatelessWidget {
  const _Delta(this.text, {required this.up});
  final String text;
  final bool up;

  @override
  Widget build(BuildContext context) =>
      Tag(text, color: up ? AppColors.mint : AppColors.coral);
}

/// Day jobs (docs K36): pay against a little energy each week.
Future<void> pickJob(BuildContext context) async {
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
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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
                  ? Icon(Icons.check_rounded, color: AppColors.mint)
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
        IconBubble(Icons.ondemand_video_rounded,
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
