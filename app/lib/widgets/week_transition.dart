import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game/game.dart' hide Actions;

import '../ui/palette.dart';
import '../core/scope.dart';
import 'common.dart';

/// What the week that just ended brought, once it is known.
class WeekOutcome {
  const WeekOutcome(this.week, this.moneyDeltaCents, {this.recoupedCents = 0})
      : failed = false;
  const WeekOutcome.failed()
      : week = 0,
        moneyDeltaCents = 0,
        recoupedCents = 0,
        failed = true;

  /// Royalties that paid back the label's advance instead (docs K107).
  final int recoupedCents;

  /// The new current week.
  final int week;
  final int moneyDeltaCents;
  final bool failed;
}

/// Short "Week 12 → Week 13" card shown while a week is played, so the
/// step is felt (feedback B1). It closes itself once its animation has run
/// and [outcome] has arrived.
class WeekTransition extends StatefulWidget {
  const WeekTransition(
      {super.key, required this.fromWeek, required this.outcome});

  final int fromWeek;
  final ValueListenable<WeekOutcome?> outcome;

  static const duration = Duration(milliseconds: 1100);

  @override
  State<WeekTransition> createState() => _WeekTransitionState();
}

class _WeekTransitionState extends State<WeekTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: WeekTransition.duration)
      ..addStatusListener((_) => _maybeClose());
    widget.outcome.addListener(_maybeClose);
    _c.forward();
  }

  @override
  void dispose() {
    widget.outcome.removeListener(_maybeClose);
    _c.dispose();
    super.dispose();
  }

  void _maybeClose() {
    final o = widget.outcome.value;
    if (_closed || o == null) return;
    if (o.failed || _c.isCompleted) {
      _closed = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, widget.outcome]),
        builder: (context, _) {
          final o = widget.outcome.value;
          // The new week flips in a third of the way through, once known.
          final arrived = o != null && !o.failed && _c.value > 0.3;
          final week = arrived ? o.week : widget.fromWeek;
          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppShape.r(28)),
            child: Container(
              width: 250,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_month_rounded,
                    color: AppColors.lilac, size: 30),
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: ClipRect(
                      child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position:
                            Tween(begin: const Offset(0, 0.5), end: Offset.zero)
                                .animate(a),
                        child: child,
                      ),
                    ),
                    child: Text(
                      context.fmt.weekInMonth(week),
                      key: ValueKey(week),
                      style: const TextStyle(
                          fontFamily: AppFonts.condensed,
                          fontSize: 44,
                          height: 1.2,
                          fontWeight: FontWeight.w800),
                    ),
                  )),
                ),
                Text('${GameTime.yearOf(week)}',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                AnimatedOpacity(
                  opacity: arrived ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Column(children: [
                    Tag(fmt.signedMoney(o?.moneyDeltaCents ?? 0),
                        color: (o?.moneyDeltaCents ?? 0) >= 0
                            ? AppColors.mint
                            : AppColors.coral),
                    if ((o?.recoupedCents ?? 0) > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                          context.l10n
                              .weekRecouped(fmt.money(o!.recoupedCents)),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.textMuted)),
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                PillBar(value: _c.value, height: 6),
              ]),
            ),
          );
        },
      ),
    );
  }
}
