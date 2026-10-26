import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/scope.dart';
import '../ui/palette.dart';
import 'art.dart';
import 'common.dart';

/// The metal of a certification (docs K209): gold, platinum or diamond.
List<Color> plaqueMetal(Certification c) => switch (c) {
      Certification.gold => const [
          Color(0xFF8A6A1F),
          Color(0xFFE8C766),
          Color(0xFFB8912E),
          Color(0xFFF7E19A),
          Color(0xFF9C7A26),
          Color(0xFFE8C766),
          Color(0xFF8A6A1F),
        ],
      Certification.platinum => const [
          Color(0xFF6F7A85),
          Color(0xFFE3E8ED),
          Color(0xFF9AA6B1),
          Color(0xFFFFFFFF),
          Color(0xFF85919C),
          Color(0xFFE3E8ED),
          Color(0xFF6F7A85),
        ],
      Certification.diamond => const [
          Color(0xFF5E7FA6),
          Color(0xFFE6F3FF),
          Color(0xFF9EC2EA),
          Color(0xFFFFFFFF),
          Color(0xFF7EA3CF),
          Color(0xFFE6F3FF),
          Color(0xFF5E7FA6),
        ],
    };

/// A certified record (docs K209): a metal disc with grooves and its
/// level on the label.
class PlaqueDisc extends StatelessWidget {
  const PlaqueDisc(
      {super.key, required this.level, this.multiple = 1, this.size = 120});
  final Certification level;
  final int multiple;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = switch (level) {
      Certification.gold => l.certGold,
      Certification.platinum => l.certPlatinum,
      Certification.diamond => l.certDiamond,
    };
    final dark = level == Certification.gold
        ? const Color(0xFF4A3608)
        : const Color(0xFF26313C);
    return SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size.square(size), painter: _DiscPainter(level)),
        SizedBox(
          width: size * 0.52,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              child: Text('RGA',
                  style: TextStyle(
                      fontFamily: AppFonts.condensed,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.11,
                      height: 1,
                      color: dark)),
            ),
            Container(
                height: math.max(1, size * 0.008),
                margin: EdgeInsets.symmetric(vertical: size * 0.02),
                color: dark.withValues(alpha: 0.6)),
            FittedBox(
              child: Text(
                  (multiple > 1 ? '$multiple× $name' : name).toUpperCase(),
                  style: TextStyle(
                      fontFamily: AppFonts.condensed,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.13,
                      height: 1,
                      color: dark)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DiscPainter extends CustomPainter {
  _DiscPainter(this.level);
  final Certification level;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final metal = plaqueMetal(level);
    // The shine turns around the disc, as on a real record.
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = SweepGradient(
                  colors: metal, transform: const GradientRotation(-0.6))
              .createShader(Rect.fromCircle(center: c, radius: r)));
    // Grooves.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, r * 0.006)
      ..color = Colors.black.withValues(alpha: 0.13);
    for (var k = r * 0.97; k > r * 0.42; k -= r * 0.035) {
      canvas.drawCircle(c, k, groove);
    }
    // The rim and the label.
    canvas.drawCircle(
        c,
        r - r * 0.01,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.02
          ..color = Colors.white.withValues(alpha: 0.25));
    canvas.drawCircle(
        c,
        r * 0.36,
        Paint()
          ..shader = RadialGradient(colors: [metal[3], metal[1], metal[2]])
              .createShader(Rect.fromCircle(center: c, radius: r * 0.36)));
    canvas.drawCircle(
        c,
        r * 0.36,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.012
          ..color = Colors.black.withValues(alpha: 0.2));
  }

  @override
  bool shouldRepaint(_DiscPainter old) => old.level != level;
}

/// The framed plaque (docs K209): the disc next to the cover, the
/// dedication and the date, as hung on a wall.
class PlaqueFrame extends StatelessWidget {
  const PlaqueFrame({super.key, required this.plaque});
  final PlaqueView plaque;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final p = plaque;
    final (level, multiple, week, _) = p.top;
    final metal = plaqueMetal(level);
    const serif = TextStyle(
        fontFamily: AppFonts.serif,
        color: Color(0xFFE9E4D8),
        fontSize: 16,
        height: 1.45);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [metal[0], metal[2], metal[0]],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        color: const Color(0xFF111112),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            PlaqueDisc(level: level, multiple: multiple, size: 150),
            const SizedBox(width: 18),
            CoverArt(
                seed: p.kind == EntityKind.album
                    ? albumCoverSeed(p.id)
                    : songCoverSeed(p.id, p.coverAlbumId),
                songId: p.kind == EntityKind.song ? p.id : null,
                albumId: p.coverAlbumId >= 0 ? p.coverAlbumId : null,
                size: 92),
          ]),
          const SizedBox(height: 20),
          Text.rich(
            _presented(
                l.plaquePresented(
                    '\u0001${p.artistName}\u0001',
                    fmt.number(p.topUnits),
                    fmt.plaqueFormat(p.format),
                    '\u0001${p.title}\u0001'),
                serif),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(l.plaqueFooter(l.plaqueGuild, fmt.date(week).toUpperCase()),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AppFonts.condensed,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: metal[1])),
        ]),
      ),
    );
  }

  /// The dedication with the artist and the title in bold (marked by
  /// \u0001 around them).
  static TextSpan _presented(String text, TextStyle style) {
    final parts = text.split('\u0001');
    return TextSpan(style: style, children: [
      for (final (i, s) in parts.indexed)
        TextSpan(
            text: s,
            style: i.isOdd
                ? const TextStyle(
                    fontVariations: [FontVariation.weight(700)],
                    color: Colors.white)
                : null),
    ]);
  }
}
