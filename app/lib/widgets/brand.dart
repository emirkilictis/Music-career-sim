import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../ui/palette.dart';

/// The game's own mark (docs K214): a record on the cobalt of the app,
/// with three chart bars climbing out of it. Flat print colors, as the
/// rest of the look (docs K88); also the app icon and the splash.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.rounded = true});
  final double size;

  /// Rounded tile (in the app) or a full square (the icon file, which
  /// the phone rounds itself).
  final bool rounded;

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.square(size), painter: BrandMarkPainter(rounded: rounded));
}

class BrandMarkPainter extends CustomPainter {
  BrandMarkPainter({this.rounded = true});
  final bool rounded;

  static const cobalt = Color(0xFF4B63FF);
  static const ink = Color(0xFF111111);
  static const paper = Color(0xFFF3F1EC);
  static const butter = Color(0xFFFFD233);
  static const coral = Color(0xFFFF4B3E);
  static const pink = Color(0xFFFF7EB6);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final tile = Offset.zero & size;
    canvas.save();
    if (rounded) {
      canvas
          .clipRRect(RRect.fromRectAndRadius(tile, Radius.circular(s * 0.22)));
    } else {
      canvas.clipRect(tile);
    }
    canvas.drawRect(tile, Paint()..color = cobalt);

    // The record, up and to the left.
    final c = Offset(s * 0.42, s * 0.44);
    final r = s * 0.30;
    canvas.drawCircle(c, r, Paint()..color = ink);
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, s * 0.006)
      ..color = paper.withValues(alpha: 0.22);
    for (var k = r * 0.92; k > r * 0.45; k -= r * 0.11) {
      canvas.drawCircle(c, k, groove);
    }
    // A shine across the grooves.
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.78),
        -2.5,
        0.9,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.018
          ..color = paper.withValues(alpha: 0.55));
    canvas.drawCircle(c, r * 0.36, Paint()..color = paper);
    canvas.drawCircle(c, r * 0.08, Paint()..color = ink);

    // Three bars climbing, in front of the record.
    final bars = [(butter, 0.22), (coral, 0.34), (pink, 0.48)];
    final w = s * 0.12;
    final gap = s * 0.035;
    final base = s * 0.86;
    for (final (i, (color, h)) in bars.indexed) {
      final x = s * 0.47 + i * (w + gap);
      final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, base - s * h, w, s * h),
          topLeft: Radius.circular(s * 0.02),
          topRight: Radius.circular(s * 0.02));
      // A cobalt edge keeps the bars apart from the record.
      canvas.drawRRect(rect.inflate(s * 0.014), Paint()..color = cobalt);
      canvas.drawRRect(rect, Paint()..color = color);
    }
    canvas.drawRect(Rect.fromLTWH(s * 0.43, base, s * 0.5, s * 0.022),
        Paint()..color = paper);
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) => old.rounded != rounded;
}

/// The name, set as the mark's caption: big condensed first line, a
/// spaced small second line.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 30, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = color ?? AppColors.text;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.brandTop.toUpperCase(),
              style: TextStyle(
                  fontFamily: AppFonts.condensed,
                  fontWeight: FontWeight.w800,
                  fontSize: size,
                  height: 0.95,
                  letterSpacing: 0.5,
                  color: c)),
          Text(l.brandBottom.toUpperCase(),
              style: TextStyle(
                  fontFamily: AppFonts.condensed,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.42,
                  letterSpacing: size * 0.16,
                  color: AppColors.lilac)),
        ]);
  }
}
