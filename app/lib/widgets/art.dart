import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/images.dart';
import '../core/scope.dart';
import '../ui/palette.dart';

/// Curated color pairs for generated covers: soft and varied.
const _pairs = <(Color, Color)>[
  (Color(0xFFB9A6FF), Color(0xFF5B3FD1)),
  (Color(0xFFFFA8C5), Color(0xFF8E2C5A)),
  (Color(0xFFFFC59E), Color(0xFFC2452F)),
  (Color(0xFF9BE7C4), Color(0xFF1C6B5A)),
  (Color(0xFF9CCBFF), Color(0xFF23408E)),
  (Color(0xFFFFE29A), Color(0xFFB0532A)),
  (Color(0xFFE3B5FF), Color(0xFF2E2A7A)),
  (Color(0xFFFFB3B3), Color(0xFF3B1F4F)),
  (Color(0xFFB8F2E6), Color(0xFF5E4AE3)),
  (Color(0xFFF7D6E0), Color(0xFF6B4C9A)),
  (Color(0xFFC6E2FF), Color(0xFFE76F51)),
  (Color(0xFF1F1B2E), Color(0xFFFF8FAB)),
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

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(h);
    final (a, b) = _pairs[h % _pairs.length];
    final rect = Offset.zero & size;
    final angle = r.nextDouble() * math.pi * 2;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(math.cos(angle), math.sin(angle)),
            end: Alignment(-math.cos(angle), -math.sin(angle)),
            colors: [a, b],
          ).createShader(rect));
    final w = size.width;
    switch (h ~/ _pairs.length % 4) {
      case 0: // sun
        canvas.drawCircle(
            Offset(w * (0.25 + 0.5 * r.nextDouble()),
                w * (0.25 + 0.4 * r.nextDouble())),
            w * (0.18 + 0.14 * r.nextDouble()),
            Paint()..color = Colors.white.withValues(alpha: 0.32));
      case 1: // rings
        final c = Offset(w * r.nextDouble(), w * r.nextDouble());
        for (var i = 1; i <= 4; i++) {
          canvas.drawCircle(
              c,
              w * 0.18 * i,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = w * 0.035
                ..color = Colors.white.withValues(alpha: 0.18));
        }
      case 2: // waves
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.04
          ..color = Colors.white.withValues(alpha: 0.22);
        for (var i = 0; i < 3; i++) {
          final y = w * (0.45 + 0.15 * i);
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x <= w; x += w / 16) {
            path.lineTo(x, y + math.sin(x / w * math.pi * 3 + i) * w * 0.06);
          }
          canvas.drawPath(path, p);
        }
      case _: // horizon
        canvas.drawRect(
            Rect.fromLTWH(0, w * (0.55 + 0.2 * r.nextDouble()), w, w),
            Paint()..color = Colors.black.withValues(alpha: 0.22));
        canvas.drawCircle(Offset(w * 0.5, w * 0.6), w * 0.22,
            Paint()..color = AppColors.butter.withValues(alpha: 0.55));
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.h != h;
}

/// Round gradient avatar with initials, or the artist's uploaded photo when
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
    final (a, b) = _pairs[_hash(seed + 7) % _pairs.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [a, b]),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.36,
          color: Colors.white,
          shadows: const [Shadow(blurRadius: 8, color: Colors.black26)],
        ),
      ),
    );
  }
}

/// Cover seed of a song: its album's cover when it is on one.
int songCoverSeed(int songId, int albumId) =>
    albumId >= 0 ? albumCoverSeed(albumId) : songId * 2;

int albumCoverSeed(int albumId) => albumId * 2 + 1;
