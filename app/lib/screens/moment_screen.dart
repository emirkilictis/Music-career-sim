import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';

/// A moment played through (docs K256): an interview's questions one by
/// one, a choice on stage, a crisis in two steps. Each answer shows how
/// it went before the next.
class MomentScreen extends StatefulWidget {
  const MomentScreen({super.key, required this.state, required this.moment});
  final CareerState state;
  final MomentView moment;

  /// Opens [moment].
  static Future<void> open(
          BuildContext context, CareerState state, MomentView moment) =>
      Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => MomentScreen(state: state, moment: moment)));

  @override
  State<MomentScreen> createState() => _MomentScreenState();
}

class _MomentScreenState extends State<MomentScreen> {
  late MomentView _m = widget.moment;

  /// The answer just given and how it went (null: choosing).
  (int, MomentOutcome)? _done;
  bool _busy = false;
  bool _over = false;

  Future<void> _answer(int i) async {
    setState(() => _busy = true);
    try {
      final career = widget.state;
      final out = await career.act(Cmd.answerMoment(i));
      final next = await career.read(Cmd.moment());
      if (!mounted) return;
      setState(() {
        _done = (i, out);
        _busy = false;
        if (next == null) {
          _over = true;
        } else {
          _m = next;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final m = _m;
    final done = _done;
    final (title, icon, color) = switch (m.kind) {
      MomentKind.interview => (
          l.momentInterviewTitle,
          Icons.mic_rounded,
          AppColors.butter
        ),
      MomentKind.concert => (
          l.momentConcertTitle,
          Icons.stadium_rounded,
          AppColors.mint
        ),
      MomentKind.crisis => (
          l.momentCrisisTitle,
          Icons.local_fire_department_rounded,
          AppColors.coral
        ),
    };
    // While showing an answer's result, the scene is the one answered.
    final scene = done?.$2.scene ?? m.scene;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          IconBubble(icon, color: color),
          const SizedBox(width: 12),
          if (m.steps > 1)
            Text(
                l.momentStep(
                    done == null ? m.step + 1 : _stepOf(done), m.steps),
                style: TextStyle(
                    color: AppColors.textMuted, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 18),
        Text(fmt.momentPrompt(scene, m),
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, height: 1.25)),
        const SizedBox(height: 22),
        if (done == null)
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: _busy ? null : () => _answer(i),
                child: Text(fmt.momentAnswer(scene, i, m),
                    style: const TextStyle(fontSize: 15.5)),
              ),
            )
        else ...[
          // What the player said, then how it went.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppShape.r(14)),
            ),
            child: Text('“${fmt.momentAnswer(scene, done.$1, m)}”',
                style: const TextStyle(
                    fontSize: 16, fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 14),
          _Result(out: done.$2, song: m.songTitle),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => _over
                ? Navigator.pop(context)
                : setState(() => _done = null),
            child: Text(_over ? l.momentDone : l.momentNext),
          ),
        ],
      ]),
    );
  }

  /// The step a shown answer was: the one before the moment's step now
  /// (or the last, once it is over).
  int _stepOf((int, MomentOutcome) done) => _over ? _m.steps : _m.step;
}

/// How an answer went: landed or backfired, a crisis's own result, what
/// changed, a clip going viral.
class _Result extends StatelessWidget {
  const _Result({required this.out, required this.song});
  final MomentOutcome out;

  /// The song a stage moment is about.
  final String song;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    String pct(double x) =>
        '${x >= 0 ? '+' : ''}${(x * 100).toStringAsFixed(1)}';
    final changes = <(String, String, bool)>[
      if (out.hype.abs() >= 0.001)
        (l.momentChangeHype, pct(out.hype), out.hype > 0),
      if (out.devotion.abs() >= 0.001)
        (l.momentChangeDevotion, pct(out.devotion), out.devotion > 0),
      if (out.popularity.abs() >= 0.001)
        (l.momentChangePopularity, pct(out.popularity), out.popularity > 0),
      if (out.fans >= 1) (l.momentChangeFans, '+${fmt.compact(out.fans)}', true),
      if (out.energy <= -1)
        (l.momentChangeEnergy, out.energy.round().toString(), false),
      if (out.moneyCents != 0)
        (l.momentChangeMoney, fmt.money(out.moneyCents), out.moneyCents > 0),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (out.crisis case final c?)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(fmt.offerOutcome(c),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        )
      else
        Text(out.good ? l.momentGood : l.momentBad,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: out.good ? AppColors.mint : AppColors.coral)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (label, value, up) in changes)
          Tag('$label $value',
              color: up ? AppColors.mint : AppColors.coral),
      ]),
      if (out.viralSongId >= 0) ...[
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.trending_up_rounded, color: AppColors.mint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l.momentViral(song),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ],
    ]);
  }
}

/// A card on Home for a moment waiting for answers (docs K256).
class MomentCard extends StatelessWidget {
  const MomentCard({super.key, required this.moment});
  final MomentView moment;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (text, icon, color) = switch (moment.kind) {
      MomentKind.interview => (
          l.momentCardInterview,
          Icons.mic_rounded,
          AppColors.butter
        ),
      MomentKind.concert => (
          l.momentCardConcert,
          Icons.stadium_rounded,
          AppColors.mint
        ),
      MomentKind.crisis => (
          l.momentCardCrisis,
          Icons.local_fire_department_rounded,
          AppColors.coral
        ),
    };
    return InkWell(
      onTap: () => MomentScreen.open(context, context.careerRead, moment),
      borderRadius: BorderRadius.circular(AppShape.r(22)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppShape.r(22)),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Row(children: [
          IconBubble(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}
