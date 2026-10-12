import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/scope.dart';

extension FmtContext on BuildContext {
  Fmt get fmt => Fmt(l10n);
}

/// Shows a rule violation or failure as a snackbar.
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.fmt.error(error))));
}

void showInfo(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// A titled card section.
class Section extends StatelessWidget {
  const Section(
      {super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(title, style: t.titleMedium)),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// A big number with a small label under it.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(label,
            style: t.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Stat tiles in a wrapping grid (2 per row on phones).
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles});
  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth > 520 ? 4 : 2;
      final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
      return Wrap(
        spacing: 12,
        runSpacing: 14,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

/// Labeled 0..1 bar (fame, energy).
class MeterRow extends StatelessWidget {
  const MeterRow(
      {super.key,
      required this.label,
      required this.value,
      required this.text,
      this.color});
  final String label;
  final double value;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 96, child: Text(label, style: t.bodyMedium)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
            width: 52,
            child: Text(text, textAlign: TextAlign.right, style: t.bodySmall)),
      ]),
    );
  }
}

/// Placeholder for empty lists.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
}

/// Chart position badge: "#3", or "–" when off the chart.
class PosBadge extends StatelessWidget {
  const PosBadge(this.pos, {super.key, this.highlight = false});
  final int pos;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final top = pos == 1;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: top
            ? const Color(0xFFE6B422)
            : highlight
                ? s.primaryContainer
                : s.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(pos > 0 ? '$pos' : '–',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: top ? Colors.black : s.onSurface)),
    );
  }
}
