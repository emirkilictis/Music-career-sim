import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/scope.dart';
import '../ui/palette.dart';

extension FmtContext on BuildContext {
  Fmt get fmt => Fmt(l10n);
}

/// Shows a rule violation or failure as a snackbar.
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(Icons.info_outline, color: AppColors.coral, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(context.fmt.error(error))),
      ]),
    ));
}

void showInfo(BuildContext context, String text, {IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon ?? Icons.check_circle_outline,
            color: AppColors.mint, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    ));
}

/// A titled card section.
class Section extends StatelessWidget {
  const Section(
      {super.key,
      required this.title,
      required this.child,
      this.trailing,
      this.icon,
      this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18)});
  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.r(22)),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted)),
                ),
                if (trailing != null)
                  Flexible(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: trailing!),
                  ),
              ]),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ));
  }
}

/// A big number with a small label under it.
class StatTile extends StatelessWidget {
  const StatTile(
      {super.key, required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: color ?? AppColors.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Stat tiles in a wrapping grid (2 per row on phones).
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 520 ? 4 : 2;
      final w = (c.maxWidth - 14 * (perRow - 1)) / perRow;
      return Wrap(
        spacing: 14,
        runSpacing: 16,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

/// Labeled 0..1 pill bar (fame, energy) with a soft gradient fill.
class MeterRow extends StatelessWidget {
  const MeterRow(
      {super.key,
      required this.label,
      required this.value,
      required this.text,
      this.colors});
  final String label;
  final double value;
  final String text;

  /// Gradient of the fill; the signature lilac → pink when null.
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(
            width: 92,
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textMuted))),
        Expanded(child: PillBar(value: value, colors: colors)),
        const SizedBox(width: 12),
        SizedBox(
            width: 44,
            child: Text(text,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

class PillBar extends StatelessWidget {
  const PillBar(
      {super.key, required this.value, this.colors, this.height = 10});
  final double value;

  /// Gradient of the fill; the signature lilac → pink when null.
  final List<Color>? colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final v = value.clamp(0.0, 1.0);
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppShape.r(height)),
        ),
        alignment: Alignment.centerLeft,
        child: v <= 0
            ? null
            : Container(
                width: (c.maxWidth * v).clamp(height, c.maxWidth),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: colors ?? [AppColors.lilac, AppColors.pink]),
                  borderRadius: BorderRadius.circular(AppShape.r(height)),
                ),
              ),
      );
    });
  }
}

/// Placeholder for empty lists.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.textFaint, size: 30),
            const SizedBox(height: 8),
          ],
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted)),
        ]),
      );
}

/// Small rounded label.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, Color? color, this.icon}) : _color = color;
  final String text;
  final Color? _color;
  final IconData? icon;

  Color get color => _color ?? AppColors.lilac;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppShape.r(20)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      );
}

/// Big pill button with the signature gradient.
class GradientButton extends StatelessWidget {
  const GradientButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.busy = false,
      this.height = 54});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.sunset,
          borderRadius: BorderRadius.circular(AppShape.r(height)),
          boxShadow: [
            BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppShape.r(height)),
            onTap: onPressed,
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: AppColors.onAccent))
                  else if (icon != null)
                    Icon(icon, color: AppColors.onAccent),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.onAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon bubble used for news and list leading icons.
class IconBubble extends StatelessWidget {
  const IconBubble(this.icon, {super.key, required this.color, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppShape.r(size * 0.36)),
        ),
        child: Icon(icon, color: color, size: size * 0.52),
      );
}

/// Chart position badge: "#3", or "–" when off the chart.
class PosBadge extends StatelessWidget {
  const PosBadge(this.pos, {super.key, this.highlight = false});
  final int pos;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final top = pos == 1;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: top
            ? AppColors.gold
            : highlight
                ? AppColors.accentSoft
                : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppShape.r(12)),
      ),
      child: Text(pos > 0 ? '#$pos' : '–',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: AppFonts.condensed,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: top ? Colors.black : AppColors.text)),
    );
  }
}

/// The team's letter grade for a song.
class GradeTag extends StatelessWidget {
  const GradeTag(this.grade, {super.key});
  final String grade;

  @override
  Widget build(BuildContext context) {
    final color = switch (grade[0]) {
      'A' => AppColors.mint,
      'B' => AppColors.sky,
      'C' => AppColors.butter,
      'D' => AppColors.peach,
      _ => AppColors.coral,
    };
    return Container(
      width: 34,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppShape.r(10)),
      ),
      child: Text(grade,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w900, fontSize: 14)),
    );
  }
}
