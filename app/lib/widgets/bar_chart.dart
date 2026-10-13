import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../ui/palette.dart';
import 'common.dart';

/// Weekly bars with their value on top and the best week highlighted
/// (docs K60): the latest [values] last, labelled by weeks ago.
class WeeklyBars extends StatelessWidget {
  const WeeklyBars(
      {super.key, required this.values, this.slots = 12, this.height = 120});
  final List<double> values;

  /// Columns drawn; weeks before the first value stay empty, so a new
  /// release's bars keep their width.
  final int slots;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final max = values.fold(0.0, (m, v) => v > m ? v : m);
    final peak = values.indexOf(max);
    final n = values.length;
    return SizedBox(
      height: height + 50,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var k = n; k < slots; k++) const Expanded(child: SizedBox()),
        for (var i = 0; i < n; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child:
                  Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(fmt.compact(values[i]),
                      style: TextStyle(
                          fontFamily: AppFonts.condensed,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: i == peak
                              ? AppColors.lilac
                              : AppColors.textMuted)),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(AppShape.r(3)),
                    ),
                    child: FractionallySizedBox(
                      heightFactor:
                          max <= 0 ? 0 : (values[i] / max).clamp(0.02, 1.0),
                      widthFactor: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppShape.r(3)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: i == peak
                                ? [AppColors.pink, AppColors.lilac]
                                : [
                                    AppColors.sky,
                                    AppColors.sky.withValues(alpha: 0.55)
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                      i == n - 1 ? l.nowShort : l.weeksAgoShort(n - 1 - i),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: i == n - 1
                              ? AppColors.text
                              : AppColors.textFaint)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
