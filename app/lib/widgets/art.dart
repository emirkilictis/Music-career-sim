import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../core/images.dart';
import '../core/scope.dart';
import '../ui/palette.dart';

// Flat print inks for generated covers (docs K90): no pastel gradients,
// a background, an ink and an accent that always read against each other.
const _ink = Color(0xFF141414);
const _paper = Color(0xFFF2EFE8);
const _orange = Color(0xFFFF5A1F);
const _cobalt = Color(0xFF1F4BD8);
const _red = Color(0xFFD7263D);
const _mustard = Color(0xFFE8B21E);
const _green = Color(0xFF0F7B4F);
const _pink = Color(0xFFFF7EB6);
const _plum = Color(0xFF3B1E54);
const _teal = Color(0xFF0E6E73);
const _brick = Color(0xFF9C3B22);
const _lime = Color(0xFFC8E02B);
const _sky = Color(0xFF6FB7E8);
const _olive = Color(0xFF5E5E1C);

/// (background, ink, accent).
const _schemes = <(Color, Color, Color)>[
  (_paper, _ink, _orange),
  (_ink, _paper, _orange),
  (_orange, _ink, _paper),
  (_cobalt, _paper, _mustard),
  (_red, _paper, _ink),
  (_mustard, _ink, _red),
  (_green, _paper, _pink),
  (_ink, _mustard, _red),
  (_pink, _ink, _cobalt),
  (_plum, _orange, _paper),
  (_teal, _paper, _mustard),
  (_paper, _cobalt, _red),
  (_brick, _paper, _ink),
  (_lime, _ink, _cobalt),
  (_paper, _red, _ink),
  (_ink, _pink, _paper),
  (_sky, _ink, _orange),
  (_olive, _paper, _orange),
];

int _hash(int seed) {
  var z = seed * 0x9E3779B1 + 0x7F4A7C15;
  z = (z ^ (z >> 15)) * 0x2C1B3C6D;
  z = (z ^ (z >> 12)) * 0x297A2D39;
  return (z ^ (z >> 15)) & 0x7fffffff;
}

/// Generated cover art for a release until the player uploads one
/// (docs/game-design.md §18). The same seed always gives the same cover.
///
/// Pass [songId] / [albumId] so an uploaded cover (song first, then its
/// album) replaces the generated art.
class CoverArt extends StatelessWidget {
  const CoverArt(
      {super.key,
      required this.seed,
      this.size = 48,
      this.radius,
      this.songId,
      this.albumId,
      this.imageKey});
  final int seed;
  final double size;
  final double? radius;
  final int? songId;
  final int? albumId;

  /// Any other stored image (e.g. a scheduled album's cover).
  final String? imageKey;

  @override
  Widget build(BuildContext context) {
    final store = _images(context);
    String? own() => songId != null
        ? store!.songCover(songId!, albumId ?? -1)
        : albumId != null
            ? store!.albumCover(albumId!)
            : null;
    // Another stored image first (e.g. an edition's own cover), then the
    // release's.
    final path = store == null
        ? null
        : (imageKey == null ? null : store.path(imageKey!)) ?? own();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppShape.r(radius ?? size * 0.12)),
      child: SizedBox.square(
        dimension: size,
        child: path != null
            ? _Photo(path: path, size: size)
            : CustomPaint(painter: _CoverPainter(_hash(seed))),
      ),
    );
  }
}

/// The open career's images, if the app provides them here.
ImageStore? _images(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<Scope<ImageStore>>()?.notifier;

/// A stored image, decoded at display size.
class _Photo extends StatelessWidget {
  const _Photo({required this.path, required this.size});
  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.file(File(path),
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: px,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.h);
  final int h;

  /// Number of motifs; picked from other bits of the hash than the colors
  /// so any palette meets any motif (E5).
  static const motifs = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(h);
    final (bg, fg, ac) = _schemes[h % _schemes.length];
    final rect = Offset.zero & size;
    final w = size.width;
    Paint fill(Color c) => Paint()..color = c;
    Paint line(Color c, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = c;
    Offset at(double x, double y) => Offset(w * x, w * y);
    double rnd(double lo, double hi) => lo + (hi - lo) * r.nextDouble();

    canvas.clipRect(rect);
    canvas.drawRect(rect, fill(bg));

    switch ((h >> 5) % motifs) {
      case 0: // a big sun, often cropped by the edge, and a small moon
        final c = at(rnd(0.2, 0.8), rnd(0.2, 0.7));
        canvas.drawCircle(c, w * rnd(0.28, 0.42), fill(fg));
        canvas.drawCircle(
            at(rnd(0.15, 0.85), rnd(0.75, 0.88)), w * 0.06, fill(ac));
      case 1: // target rings, solid, from a corner
        final c = at(r.nextBool() ? 0.15 : 0.85, r.nextBool() ? 0.15 : 0.85);
        final colors = [fg, bg, ac, bg];
        for (var i = 7; i >= 1; i--) {
          canvas.drawCircle(c, w * 0.15 * i, fill(colors[i % 4]));
        }
      case 2: // bands like a flag, across or down
        canvas.save();
        if (r.nextBool()) {
          canvas.translate(w, 0);
          canvas.rotate(math.pi / 2);
        }
        final n = 3 + r.nextInt(3);
        final weights = [for (var i = 0; i < n; i++) rnd(0.5, 1.5)];
        final total = weights.fold(0.0, (a, b) => a + b);
        final colors = [bg, fg, ac, fg, bg];
        var y = 0.0;
        for (var i = 0; i < n; i++) {
          final hgt = w * weights[i] / total;
          canvas.drawRect(Rect.fromLTWH(0, y, w, hgt), fill(colors[i]));
          y += hgt;
        }
        canvas.restore();
      case 3: // a dot grid with one dot out of line
        final n = 5 + r.nextInt(3);
        final step = w / n;
        final odd = r.nextInt(n * n);
        for (var i = 0; i < n * n; i++) {
          canvas.drawCircle(Offset(step * (i % n + 0.5), step * (i ~/ n + 0.5)),
              step * (i == odd ? 0.46 : 0.3), fill(i == odd ? ac : fg));
        }
      case 4: // a diagonal split, the circle changing color across it
        final half = Path()
          ..moveTo(0, w * rnd(0.2, 0.8))
          ..lineTo(w, w * rnd(0.2, 0.8))
          ..lineTo(w, w)
          ..lineTo(0, w)
          ..close();
        canvas.drawPath(half, fill(fg));
        final c = at(rnd(0.35, 0.65), 0.5);
        final rad = w * rnd(0.22, 0.32);
        canvas.drawCircle(c, rad, fill(ac));
        canvas.save();
        canvas.clipPath(half);
        canvas.drawCircle(c, rad, fill(bg));
        canvas.restore();
      case 5: // arches rising from the bottom
        final cx = w * rnd(0.3, 0.7);
        final colors = [fg, ac, bg, fg, ac];
        for (var i = 0; i < 5; i++) {
          canvas.drawCircle(
              Offset(cx, w), w * (0.62 - 0.12 * i), fill(colors[i]));
        }
      case 6: // Bauhaus tiles: quarter circles in a 2×2 grid
        final t = w / 2;
        for (var i = 0; i < 4; i++) {
          final o = Offset(t * (i % 2), t * (i ~/ 2));
          final dark = (i + (h >> 13)) % 2 == 0;
          canvas.drawRect(o & Size(t, t), fill(dark ? fg : bg));
          final corner = o +
              Offset(t * r.nextInt(2).toDouble(), t * r.nextInt(2).toDouble());
          canvas.save();
          canvas.clipRect(o & Size(t, t));
          canvas.drawCircle(
              corner, t, fill(r.nextInt(3) == 0 ? ac : (dark ? bg : fg)));
          canvas.restore();
        }
      case 7: // a thick frame with one small block
        canvas.drawRect(Rect.fromLTWH(w * 0.12, w * 0.12, w * 0.76, w * 0.76),
            line(fg, w * 0.07));
        final s = w * rnd(0.12, 0.2);
        canvas.drawRect(
            Rect.fromLTWH(
                w * rnd(0.22, 0.78) - s / 2, w * rnd(0.22, 0.78) - s / 2, s, s),
            fill(ac));
      case 8: // equalizer bars, the tallest in the accent
        final n = 7 + r.nextInt(5);
        final gap = w * 0.025;
        final bw = (w * 0.84 - gap * (n - 1)) / n;
        final heights = [for (var i = 0; i < n; i++) rnd(0.15, 0.75)];
        final top = heights.indexOf(heights.reduce(math.max));
        for (var i = 0; i < n; i++) {
          canvas.drawRect(
              Rect.fromLTWH(w * 0.08 + i * (bw + gap), w * (0.88 - heights[i]),
                  bw, w * heights[i]),
              fill(i == top ? ac : fg));
        }
      case 9: // thick waves
        for (var i = 0; i < 4; i++) {
          final p = line(i == 1 ? ac : fg, w * 0.07);
          final y = w * (0.2 + 0.2 * i);
          final phase = rnd(0, math.pi);
          final path = Path()..moveTo(-w * 0.1, y);
          for (var x = -w * 0.1; x <= w * 1.1; x += w / 24) {
            path.lineTo(
                x, y + math.sin(x / w * math.pi * 4 + phase) * w * 0.05);
          }
          canvas.drawPath(path, p);
        }
      case 10: // eclipse: a crescent and a thin ring
        final c = at(rnd(0.35, 0.65), rnd(0.4, 0.6));
        canvas.drawCircle(c, w * 0.4, line(fg, w * 0.012));
        canvas.drawCircle(c, w * 0.3, fill(ac));
        canvas.drawCircle(c + at(rnd(0.05, 0.1), -0.05), w * 0.27, fill(bg));
      case 11: // a checkered strip under a disc
        final n = 8;
        final s = w / n;
        final y = w * rnd(0.55, 0.7);
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < n; col++) {
            if ((row + col).isEven) {
              canvas.drawRect(
                  Rect.fromLTWH(col * s, y + row * s, s, s), fill(fg));
            }
          }
        }
        canvas.drawCircle(at(rnd(0.3, 0.7), 0.3), w * 0.16, fill(ac));
      case 12: // peaks in front of each other
        canvas.drawCircle(at(rnd(0.6, 0.8), 0.25), w * 0.1, fill(ac));
        final back = Path()
          ..moveTo(-w * 0.1, w)
          ..lineTo(w * rnd(0.3, 0.5), w * rnd(0.2, 0.35))
          ..lineTo(w * 1.0, w)
          ..close();
        canvas.drawPath(back, fill(fg));
        final front = Path()
          ..moveTo(w * 0.35, w)
          ..lineTo(w * rnd(0.65, 0.8), w * rnd(0.45, 0.6))
          ..lineTo(w * 1.2, w)
          ..close();
        canvas.drawPath(front, fill(ac));
      case _: // a record sliding out of its sleeve
        final c = at(rnd(0.58, 0.68), 0.5);
        canvas.drawCircle(c, w * 0.38, fill(fg));
        for (var i = 1; i <= 3; i++) {
          canvas.drawCircle(c, w * (0.18 + 0.06 * i),
              line(bg.withValues(alpha: 0.25), w * 0.006));
        }
        canvas.drawCircle(c, w * 0.12, fill(bg));
        canvas.drawCircle(c, w * 0.015, fill(fg));
        canvas.drawRect(
            Rect.fromLTWH(0, w * 0.08, w * 0.5, w * 0.84), fill(ac));
    }

    // A hairline edge so a black or paper cover keeps its shape on a
    // background of the same color.
    final dim = bg.computeLuminance() < 0.05;
    final pale = bg.computeLuminance() > 0.7;
    if (dim || pale) {
      final edge = math.max(1.0, w / 160);
      canvas.drawRect(
          rect.deflate(edge / 2),
          line(
              dim
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.1),
              edge));
    }

    // A light print grain so the flat inks don't look rendered.
    if (w >= 40) {
      final count = math.min(3000, (w * w / 28).round());
      final dark = <Offset>[];
      final light = <Offset>[];
      for (var i = 0; i < count; i++) {
        (i.isEven ? dark : light)
            .add(Offset(r.nextDouble() * w, r.nextDouble() * w));
      }
      final dot = math.max(1.0, w / 180);
      canvas.drawPoints(
          PointMode.points,
          dark,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.08)
            ..strokeWidth = dot);
      canvas.drawPoints(
          PointMode.points,
          light,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.08)
            ..strokeWidth = dot);
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.h != h;
}

/// Round flat-color avatar with initials, or the artist's uploaded photo when
/// [artistId] has one (for [photo]'s place, else the general photo).
class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar(
      {super.key,
      required this.name,
      required this.seed,
      this.size = 44,
      this.artistId,
      this.photo = ArtistPhoto.general});
  final String name;
  final int seed;
  final double size;
  final int? artistId;
  final ArtistPhoto photo;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }

  @override
  Widget build(BuildContext context) {
    final path = artistId == null
        ? null
        : _images(context)?.artistPhoto(artistId!, photo);
    if (path != null) {
      return ClipOval(child: _Photo(path: path, size: size));
    }
    final (bg, fg, _) = _schemes[_hash(seed + 7) % _schemes.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.36,
          color: fg,
        ),
      ),
    );
  }
}

/// The background ink of a generated cover, for pages tinted by their art.
Color coverColor(int seed) => _schemes[_hash(seed) % _schemes.length].$1;

/// The background of an artist's generated avatar.
Color avatarColor(int seed) => _schemes[_hash(seed + 7) % _schemes.length].$1;

/// Cover seed of a song: its album's cover when it is on one.
int songCoverSeed(int songId, int albumId) =>
    albumId >= 0 ? albumCoverSeed(albumId) : songId * 2;

int albumCoverSeed(int albumId) => albumId * 2 + 1;
