import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A drawn face for an artist or a fan without a photo (docs K212): flat
/// shapes on the avatar's color, picked from the seed (skin, hair, its
/// color, clothes, glasses, an earring), so the same seed always gives
/// the same person. Nobody real: no photos, no likenesses.
class AvatarFacePainter extends CustomPainter {
  AvatarFacePainter(this.seed, this.background);
  final int seed;
  final Color background;

  static const _skins = [
    Color(0xFFF6D7C3),
    Color(0xFFEFC3A0),
    Color(0xFFE0A97A),
    Color(0xFFC98B5B),
    Color(0xFFA86B42),
    Color(0xFF8A5333),
    Color(0xFF6B3F27),
    Color(0xFF4E2D1C),
  ];

  static const _hairs = [
    Color(0xFF16120F),
    Color(0xFF16120F),
    Color(0xFF3A2418),
    Color(0xFF3A2418),
    Color(0xFF6B4630),
    Color(0xFF9A4A22),
    Color(0xFFD7B36A),
    Color(0xFFEDE3CC),
    Color(0xFFE2609E),
    Color(0xFF4F7FE6),
    Color(0xFF9E9E9E),
    Color(0xFF7C4DCC),
  ];

  static const _clothes = [
    Color(0xFF1B1B1F),
    Color(0xFFF3EFE6),
    Color(0xFFE8552B),
    Color(0xFF2346A8),
    Color(0xFFD9A62E),
    Color(0xFF1F7A55),
    Color(0xFFB8324A),
    Color(0xFF5B2E6E),
    Color(0xFF2C8C99),
    Color(0xFF6E6E73),
  ];

  /// Seeded traits: a different hash for each.
  int _pick(int trait, int n) {
    var z = (seed + trait * 0x45D9F3B) * 0x9E3779B1 + 0x7F4A7C15;
    z = (z ^ (z >> 15)) * 0x2C1B3C6D;
    z = (z ^ (z >> 12)) * 0x297A2D39;
    return ((z ^ (z >> 15)) & 0x7fffffff) % n;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final skin = _skins[_pick(1, _skins.length)];
    final hairColor = _hairs[_pick(2, _hairs.length)];
    var cloth = _clothes[_pick(3, _clothes.length)];
    // Clothes never vanish into the background.
    if ((cloth.computeLuminance() - background.computeLuminance()).abs() <
        0.08) {
      cloth = _clothes[(_clothes.indexOf(cloth) + 3) % _clothes.length];
    }
    final style = _pick(4, 10);
    final glasses = _pick(5, 9);
    final earring = _pick(6, 5) == 0;
    final shade = Color.lerp(skin, Colors.black, 0.18)!;
    final ink = Color.lerp(skin, Colors.black, 0.75)!;
    final hair = Paint()..color = hairColor;

    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final head = Rect.fromCenter(
        center: Offset(0.5 * s, 0.44 * s), width: 0.36 * s, height: 0.43 * s);

    // Hair that falls behind the head.
    switch (style) {
      case 1: // long
        canvas.drawRRect(
            RRect.fromRectAndCorners(
                Rect.fromLTRB(0.29 * s, 0.30 * s, 0.71 * s, 0.84 * s),
                topLeft: Radius.circular(0.2 * s),
                topRight: Radius.circular(0.2 * s)),
            hair);
      case 3: // afro
        canvas.drawCircle(Offset(0.5 * s, 0.37 * s), 0.27 * s, hair);
      case 5: // bob
        canvas.drawRRect(
            RRect.fromRectAndCorners(
                Rect.fromLTRB(0.28 * s, 0.24 * s, 0.72 * s, 0.62 * s),
                topLeft: Radius.circular(0.2 * s),
                topRight: Radius.circular(0.2 * s),
                bottomLeft: Radius.circular(0.04 * s),
                bottomRight: Radius.circular(0.04 * s)),
            hair);
      case 6: // ponytail
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(0.74 * s, 0.50 * s),
                width: 0.13 * s,
                height: 0.30 * s),
            hair);
    }

    // Shoulders and neck.
    final body = Path()
      ..moveTo(0.10 * s, s)
      ..cubicTo(0.10 * s, 0.80 * s, 0.25 * s, 0.74 * s, 0.5 * s, 0.74 * s)
      ..cubicTo(0.75 * s, 0.74 * s, 0.90 * s, 0.80 * s, 0.90 * s, s)
      ..close();
    canvas.drawRect(Rect.fromLTRB(0.43 * s, 0.56 * s, 0.57 * s, 0.78 * s),
        Paint()..color = shade);
    canvas.drawPath(body, Paint()..color = cloth);
    // A collar line.
    canvas.drawPath(
        Path()
          ..moveTo(0.42 * s, 0.745 * s)
          ..quadraticBezierTo(0.5 * s, 0.83 * s, 0.58 * s, 0.745 * s),
        Paint()..color = shade);

    // Ears and the head.
    final skinPaint = Paint()..color = skin;
    canvas.drawCircle(Offset(0.32 * s, 0.46 * s), 0.045 * s, skinPaint);
    canvas.drawCircle(Offset(0.68 * s, 0.46 * s), 0.045 * s, skinPaint);
    canvas.drawOval(head, skinPaint);
    if (earring) {
      canvas.drawCircle(Offset(0.315 * s, 0.515 * s), 0.018 * s,
          Paint()..color = const Color(0xFFF2C94C));
    }

    // Hair on top of the head.
    void cap({double depth = 0.42, double fringe = 0}) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, s, head.top + head.height * depth));
      canvas.drawOval(head.inflate(0.025 * s), hair);
      canvas.restore();
      if (fringe > 0) {
        canvas.drawOval(
            Rect.fromLTRB(head.left + 0.02 * s, head.top + 0.01 * s,
                head.center.dx + 0.04 * s, head.top + head.height * fringe),
            hair);
      }
    }

    switch (style) {
      case 0: // short
        cap(depth: 0.34, fringe: 0.36);
      case 1:
        cap(depth: 0.36, fringe: 0.4);
      case 2: // bun
        cap(depth: 0.32);
        canvas.drawCircle(Offset(0.5 * s, 0.17 * s), 0.08 * s, hair);
      case 3:
        cap(depth: 0.3);
      case 4: // buzz
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(0, 0, s, head.top + head.height * 0.3));
        canvas.drawOval(
            head, Paint()..color = hairColor.withValues(alpha: 0.75));
        canvas.restore();
      case 5:
        cap(depth: 0.36, fringe: 0.34);
      case 6:
        cap(depth: 0.33);
      case 7: // bald
        break;
      case 8: // curls
        for (var k = 0; k < 6; k++) {
          final a = math.pi * (1.05 + 0.9 * k / 5);
          canvas.drawCircle(
              Offset(0.5 * s + math.cos(a) * 0.17 * s,
                  0.40 * s + math.sin(a) * 0.20 * s),
              0.075 * s,
              hair);
        }
      case 9: // spikes
        cap(depth: 0.26);
        final crest = Path()..moveTo(head.left + 0.03 * s, head.top + 0.08 * s);
        for (var k = 0; k < 5; k++) {
          final x =
              head.left + 0.03 * s + (k + 0.5) * (head.width - 0.06 * s) / 5;
          crest.lineTo(x, head.top - 0.06 * s);
          crest.lineTo(x + (head.width - 0.06 * s) / 10, head.top + 0.06 * s);
        }
        crest.close();
        canvas.drawPath(crest, hair);
    }

    // The face: eyes, brows, a small smile.
    final eyeY = 0.47 * s;
    final eye = Paint()..color = ink;
    if (glasses == 0) {
      // Sunglasses.
      final lens = Paint()..color = const Color(0xFF111111);
      for (final x in [0.42, 0.58]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(x * s, eyeY),
                    width: 0.12 * s,
                    height: 0.075 * s),
                Radius.circular(0.03 * s)),
            lens);
      }
      canvas.drawLine(Offset(0.47 * s, eyeY), Offset(0.53 * s, eyeY),
          lens..strokeWidth = 0.015 * s);
    } else {
      for (final x in [0.43, 0.57]) {
        canvas.drawCircle(Offset(x * s, eyeY), 0.024 * s, eye);
      }
      final brow = Paint()
        ..color = Color.lerp(hairColor, ink, 0.4)!
        ..strokeWidth = 0.018 * s
        ..strokeCap = StrokeCap.round;
      for (final x in [0.43, 0.57]) {
        canvas.drawLine(Offset((x - 0.035) * s, eyeY - 0.055 * s),
            Offset((x + 0.035) * s, eyeY - 0.06 * s), brow);
      }
      if (glasses == 1) {
        final frame = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.014 * s
          ..color = const Color(0xFF1B1B1F);
        for (final x in [0.43, 0.57]) {
          canvas.drawCircle(Offset(x * s, eyeY), 0.055 * s, frame);
        }
        canvas.drawLine(
            Offset(0.485 * s, eyeY), Offset(0.515 * s, eyeY), frame);
      }
    }
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(0.5 * s, 0.555 * s),
            width: 0.10 * s,
            height: 0.05 * s),
        0.15 * math.pi,
        0.7 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.016 * s
          ..strokeCap = StrokeCap.round
          ..color = ink);
  }

  @override
  bool shouldRepaint(AvatarFacePainter old) =>
      old.seed != seed || old.background != background;
}
