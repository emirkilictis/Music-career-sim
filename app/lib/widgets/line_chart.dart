import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Minimal line chart for weekly history (one series, filled area).
/// [invert] draws smaller values higher (chart positions: #1 on top).
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.values,
    this.height = 140,
    this.invert = false,
    this.color,
    this.topLabel,
    this.bottomLabel,
  });

  final List<double?> values;
  final double height;
  final bool invert;
  final Color? color;
  final String? topLabel;
  final String? bottomLabel;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final style =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: s.outline);
    return SizedBox(
      height: height,
      child: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _LinePainter(
                values, invert, color ?? s.primary, s.outlineVariant),
          ),
        ),
        if (topLabel != null)
          Positioned(left: 4, top: 0, child: Text(topLabel!, style: style)),
        if (bottomLabel != null)
          Positioned(
              left: 4, bottom: 0, child: Text(bottomLabel!, style: style)),
      ]),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.invert, this.color, this.grid);
  final List<double?> values;
  final bool invert;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return;
    final lo = invert ? present.reduce(math.min) : 0.0;
    final hi = present.reduce(math.max);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    final n = values.length;
    double x(int i) => n == 1 ? size.width / 2 : size.width * i / (n - 1);
    double y(double v) {
      final t = (v - lo) / span;
      return invert ? size.height * t : size.height * (1 - t);
    }

    final line = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    Path? path;
    Path? fill;
    int? firstX;
    var lastI = 0;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) continue;
      final p = Offset(x(i), y(v));
      if (path == null) {
        path = Path()..moveTo(p.dx, p.dy);
        fill = Path()
          ..moveTo(p.dx, size.height)
          ..lineTo(p.dx, p.dy);
        firstX = i;
      } else {
        path.lineTo(p.dx, p.dy);
        fill!.lineTo(p.dx, p.dy);
      }
      lastI = i;
    }
    if (path == null) return;
    if (!invert && firstX != null) {
      fill!
        ..lineTo(x(lastI), size.height)
        ..close();
      canvas.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.35),
                color.withValues(alpha: 0.02)
              ],
            ).createShader(Offset.zero & size));
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.color != color || old.invert != invert;
}
