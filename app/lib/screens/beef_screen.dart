import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'releases_tab.dart';

/// Beefs (docs K229): the one on now (heat, the public, every diss) with
/// its moves, or rivals to go at; the haters; past beefs.
class BeefScreen extends StatefulWidget {
  const BeefScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<BeefScreen> createState() => _BeefScreenState();
}

class _BeefScreenState extends State<BeefScreen> {
  BeefsView? _v;
  List<DissTargetView> _targets = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await widget.state.read(Cmd.beefs());
    final t = await widget.state.read(Cmd.dissTargets());
    if (mounted) {
      setState(() {
        _v = v;
        _targets = t;
      });
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _post(int rivalId) => _run(() async {
        await widget.state.act(Cmd.dissPost(rivalId));
        if (mounted) {
          showInfo(context, context.l10n.beefPosted,
              icon: Icons.local_fire_department_rounded);
        }
      });

  /// Writes a diss track at [target] and offers to put it out now.
  Future<void> _track(int target) => _run(() async {
        final career = widget.state;
        final song = await career.act(Cmd.writeSong(
            budget: BudgetTier.medium,
            genres: [career.player.genre],
            dissTarget: target));
        if (!mounted) return;
        showInfo(context, context.l10n.beefTrackWritten(song.title),
            icon: Icons.music_note_rounded);
        await releaseSingleFlow(context, career, song);
      });

  Future<void> _haters() => _run(() async {
        final backlash = await widget.state.act(Cmd.dissHaters());
        if (mounted) {
          final l = context.l10n;
          showInfo(context, backlash ? l.beefHatersBacklash : l.beefHatersDone,
              icon: backlash
                  ? Icons.warning_amber_rounded
                  : Icons.favorite_rounded);
        }
      });

  Future<void> _peace() => _run(() async {
        await widget.state.act(Cmd.makePeace());
        if (mounted) {
          showInfo(context, context.l10n.beefPeaceMade,
              icon: Icons.handshake_rounded);
        }
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = _v;
    return Scaffold(
      appBar: AppBar(title: Text(l.beefTitle)),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(l.beefIntro, style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 14),
                if (v.active case final b?)
                  _ActiveBeef(
                    beef: b,
                    player: widget.state.player.name,
                    playerId: widget.state.player.id,
                    busy: _busy,
                    canPost: v.canPost && v.postsLeft > 0,
                    onPost: () => _post(b.rivalId),
                    onTrack: () => _track(b.rivalId),
                    onPeace: _peace,
                  )
                else
                  Section(
                    title: l.beefPickRival,
                    icon: Icons.local_fire_department_rounded,
                    child: Column(children: [
                      if (!v.canPost || v.postsLeft <= 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(l.beefNoPosts,
                              style: TextStyle(color: AppColors.textMuted)),
                        ),
                      for (final t in _targets)
                        _Target(
                          target: t,
                          busy: _busy,
                          canPost: v.canPost && v.postsLeft > 0,
                          onPost: () => _post(t.artistId),
                          onTrack: () => _track(t.artistId),
                        ),
                    ]),
                  ),
                const SizedBox(height: 12),
                Section(
                  title: l.beefHaters,
                  icon: Icons.thumb_down_alt_rounded,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.beefHatersHint,
                            style: TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          FilledButton.tonal(
                            onPressed: _busy || !v.canPost || v.postsLeft <= 0
                                ? null
                                : _haters,
                            child: Text(l.beefDissPost),
                          ),
                          OutlinedButton(
                            onPressed:
                                _busy ? null : () => _track(Beefs.haters),
                            child: Text(l.beefDissTrack),
                          ),
                        ]),
                      ]),
                ),
                if (v.past.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Section(
                    title: l.beefPast,
                    icon: Icons.history_rounded,
                    child: Column(children: [
                      for (final b in v.past)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ArtistAvatar(
                              name: b.rivalName,
                              seed: b.rivalId,
                              artistId: b.rivalId,
                              size: 40),
                          title: Text(b.rivalName),
                          subtitle: Text(context.fmt.week(b.startWeek)),
                          trailing: _EndTag(b.end),
                        ),
                    ]),
                  ),
                ],
              ],
            ),
    );
  }
}

/// The beef on now: the two sides, the heat, the public and the moves.
class _ActiveBeef extends StatelessWidget {
  const _ActiveBeef({
    required this.beef,
    required this.player,
    required this.playerId,
    required this.busy,
    required this.canPost,
    required this.onPost,
    required this.onTrack,
    required this.onPeace,
  });
  final BeefView beef;
  final String player;
  final int playerId;
  final bool busy;
  final bool canPost;
  final VoidCallback onPost;
  final VoidCallback onTrack;
  final VoidCallback onPeace;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final b = beef;
    final you = (b.opinion * 100).round();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.r(20)),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ArtistAvatar(name: player, seed: playerId, artistId: playerId),
          const SizedBox(width: 12),
          Text('VS',
              style: TextStyle(
                  color: AppColors.coral,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(width: 12),
          ArtistAvatar(name: b.rivalName, seed: b.rivalId, artistId: b.rivalId),
        ]),
        const SizedBox(height: 10),
        Text(l.beefWith(b.rivalName),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(
            l.beefStartedBy(fmt.week(b.startWeek),
                b.playerStarted ? l.beefYou : b.rivalName),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        const SizedBox(height: 14),
        Text(l.beefHeat, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        PillBar(
            value: b.heat,
            colors: [AppColors.gold, AppColors.coral],
            height: 12),
        const SizedBox(height: 12),
        Text(l.beefOpinion,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppShape.r(6)),
          child: SizedBox(
            height: 14,
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: you, child: ColoredBox(color: AppColors.mint)),
              Expanded(
                  flex: 100 - you, child: ColoredBox(color: AppColors.coral)),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Text(l.beefOpinionSplit(you, 100 - you, b.rivalName),
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: busy || !canPost ? null : onPost,
            icon: const Icon(Icons.chat_bubble_rounded),
            label: Text(l.beefDissPost),
          ),
          FilledButton.tonalIcon(
            onPressed: busy ? null : onTrack,
            icon: const Icon(Icons.music_note_rounded),
            label: Text(l.beefDissTrack),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : onPeace,
            icon: const Icon(Icons.handshake_rounded),
            label: Text(l.beefPeace),
          ),
        ]),
        if (b.moves.isNotEmpty) ...[
          const Divider(height: 28),
          for (final m in b.moves)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(
                    m.kind == BeefMoveKind.track
                        ? Icons.music_note_rounded
                        : Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: m.byPlayer ? AppColors.mint : AppColors.coral),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(switch ((m.kind, m.byPlayer)) {
                    (BeefMoveKind.tweet, true) => l.beefMoveTweetMine,
                    (BeefMoveKind.tweet, false) =>
                      l.beefMoveTweetTheirs(b.rivalName),
                    (BeefMoveKind.track, true) => l.beefMoveTrackMine(m.title),
                    (BeefMoveKind.track, false) =>
                      l.beefMoveTrackTheirs(b.rivalName, m.title),
                  }),
                ),
                Text(fmt.week(m.week),
                    style:
                        TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
              ]),
            ),
        ],
      ]),
    );
  }
}

/// A rival to go at, and how it would look.
class _Target extends StatelessWidget {
  const _Target(
      {required this.target,
      required this.busy,
      required this.canPost,
      required this.onPost,
      required this.onTrack});
  final DissTargetView target;
  final bool busy;
  final bool canPost;
  final VoidCallback onPost;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = target;
    final blocked = t.block != null && t.block != DissBlock.noPost;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        ArtistAvatar(name: t.name, seed: t.artistId, artistId: t.artistId),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
                t.block == DissBlock.cooldown
                    ? l.beefCooldown
                    : t.block == DissBlock.busy
                        ? l.beefBusy
                        : t.punch < 0
                            ? l.beefBully
                            : t.punch > 0
                                ? l.beefBrave
                                : context.fmt.percent(t.fame),
                style: TextStyle(
                    color: t.punch < 0 ? AppColors.coral : AppColors.textMuted,
                    fontSize: 12.5)),
          ]),
        ),
        IconButton(
          tooltip: l.beefDissPost,
          onPressed: busy || blocked || !canPost ? null : onPost,
          icon: const Icon(Icons.chat_bubble_rounded),
        ),
        IconButton(
          tooltip: l.beefDissTrack,
          onPressed: busy || blocked ? null : onTrack,
          icon: const Icon(Icons.music_note_rounded),
        ),
      ]),
    );
  }
}

class _EndTag extends StatelessWidget {
  const _EndTag(this.end);
  final BeefEnd? end;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (text, color) = switch (end) {
      BeefEnd.won => (l.beefEndWon, AppColors.mint),
      BeefEnd.lost => (l.beefEndLost, AppColors.coral),
      BeefEnd.truce => (l.beefEndTruce, AppColors.textMuted),
      BeefEnd.fizzled || null => (l.beefEndFizzled, AppColors.textMuted),
    };
    return Text(text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800));
  }
}
