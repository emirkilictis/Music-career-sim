import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:game/game.dart' show Word64, jsNumbers;

import '../core/images.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import 'avatar_face.dart';
import 'stored_image.dart';

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
  // The JavaScript build has no 64-bit ints: the same steps on halves
  // (docs K236), so a cover looks the same in every browser.
  if (jsNumbers) {
    final w = Word64.of(seed)
      ..mul(Word64(0, 0x9E3779B1))
      ..add(Word64(0, 0x7F4A7C15))
      ..xorSar(15)
      ..mul(Word64(0, 0x2C1B3C6D))
      ..xorSar(12)
      ..mul(Word64(0, 0x297A2D39))
      ..xorSar(15);
    return w.lo & 0x7fffffff;
  }
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
  static Map<int, (String, int)> labels = const {};
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
    final identity =
        albumId != null && albumId! >= 0 ? albumCoverSeed(albumId!) : seed;
    final label =
        labels[songId == null ? seed : songId! * 2] ?? labels[identity];
    final title = label?.$1 ?? '';
    final h = _hash(identity);
    final variation = songId != null
        ? _hash(songId! + 17)
        : imageKey != null
            ? _stableTextHash(imageKey!)
            : 0;
    final photo = label == null
        ? null
        : store?.artistPhoto(label.$2, ArtistPhoto.general);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppShape.r(radius ?? size * 0.12)),
      child: SizedBox.square(
        dimension: size,
        child: path != null
            ? _Photo(path: path, size: size)
            : Stack(fit: StackFit.expand, children: [
                CustomPaint(painter: _CoverPainter(h, variation, title)),
                if (h % 5 == 0 && photo != null) ...[
                  for (var i = 0; i < 3; i++)
                    Positioned(
                      left: size * (.07 + i * .27),
                      top: size * (.15 + (i == 1 ? -.03 : .06)),
                      width: size * .38,
                      height: size * .60,
                      child: Transform.rotate(
                          angle: (i - 1) * .09,
                          child: Container(
                              padding: EdgeInsets.all(size * .012),
                              color: _paper,
                              child: ClipRect(
                                  child:
                                      _Photo(path: photo, size: size * .6)))),
                    ),
                  Positioned(
                      left: size * .08,
                      right: size * .08,
                      bottom: size * .07,
                      child: Text(title.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'BarlowCondensed',
                              fontWeight: FontWeight.w800,
                              fontSize: size * .095,
                              color: _paper))),
                ],
              ]),
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
    return storedImage(path,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: px,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }
}

int _stableTextHash(String value) {
  var h = 0;
  for (final c in value.codeUnits) {
    h = ((h * 31) + c) & 0x7fffffff;
  }
  return h;
}

/// Five distinct art directions. Album identity controls palette/direction;
/// edition and single variations alter composition without changing the family.
class _CoverPainter extends CustomPainter {
  _CoverPainter(this.h, this.variation, this.title);
  final int h, variation;
  final String title;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = math.Random(h + variation);
    final rect = Offset.zero & size;
    const palettes = [
      (Color(0xFF171B26), Color(0xFFF3DFC0), Color(0xFFBE684B)),
      (Color(0xFFDEDAD0), Color(0xFF1E2928), Color(0xFF9A382B)),
      (Color(0xFF1A232D), Color(0xFFCCDAE0), Color(0xFF6E8DB4)),
      (Color(0xFF34232C), Color(0xFFF2D9B1), Color(0xFFE58A61)),
      (Color(0xFFDFDBCA), Color(0xFF293C38), Color(0xFF6B8060)),
      (Color(0xFF181519), Color(0xFFF0E2DE), Color(0xFF9D6484)),
    ];
    final (bg, ink, accent) = palettes[(h ~/ 7) % palettes.length];
    Paint fill(Color c) => Paint()..color = c;
    void text(String value, double x, double y, double font, Color color,
        {double width = .84, String family = 'BarlowCondensed'}) {
      final p = TextPainter(
          text: TextSpan(
              text: value,
              style: TextStyle(
                  fontFamily: family,
                  fontSize: w * font,
                  height: .95,
                  fontWeight: FontWeight.w800,
                  color: color)),
          textDirection: TextDirection.ltr,
          maxLines: 3,
          ellipsis: '…')
        ..layout(maxWidth: w * width);
      p.paint(canvas, Offset(w * x, w * y));
    }

    void landscape(Rect frame, int index) {
      canvas.save();
      canvas.clipRect(frame);
      canvas.drawRect(
          frame,
          Paint()
            ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bg, accent, ink]).createShader(frame));
      canvas.drawCircle(
          Offset(frame.center.dx + frame.width * .15,
              frame.top + frame.height * .33),
          frame.width * .15,
          fill(ink.withValues(alpha: .7)));
      for (var layer = 0; layer < 3; layer++) {
        final path = Path()..moveTo(frame.left, frame.bottom);
        for (var i = 0; i <= 12; i++) {
          path.lineTo(
              frame.left + frame.width * i / 12,
              frame.top +
                  frame.height *
                      (.53 +
                          layer * .13 +
                          .10 * math.sin(i * .65 + index + layer)));
        }
        path
          ..lineTo(frame.right, frame.bottom)
          ..close();
        canvas.drawPath(path, fill(Color.lerp(accent, bg, .4 + layer * .25)!));
      }
      canvas.restore();
    }

    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, fill(bg));
    switch (h % 5) {
      case 0: // Contact-sheet collage; replaced with artist photography if available.
        for (var i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(
              w * (.09 + i * .27), w * (.15 + r.nextDouble() * .08));
          canvas.rotate((i - 1) * .09);
          final frame = Rect.fromLTWH(0, 0, w * .38, w * .59);
          canvas.drawRect(frame.inflate(w * .014), fill(ink));
          landscape(frame, i);
          canvas.restore();
        }
        text(title.toUpperCase(), .08, .80, .095, ink);
      case 1: // Oversized editorial typography, deliberately cropped.
        canvas.drawRect(Rect.fromLTWH(w * .67, 0, w * .33, w), fill(accent));
        final words = title.trim().isEmpty
            ? ['SIDE', 'A']
            : title.toUpperCase().split(RegExp(r'\s+'));
        for (var i = 0; i < math.min(words.length, 4); i++) {
          text(words[i], .055, .08 + i * .19, .21, ink, width: .90);
        }
        canvas.drawLine(
            Offset(w * .06, w * .90),
            Offset(w * .93, w * .90),
            Paint()
              ..color = ink
              ..strokeWidth = w * .006);
      case 2: // Minimal still-life: one luminous sculptural object, much space.
        final center = Offset(w * (.45 + (variation % 7) * .015), w * .43);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(-.4 + (h % 9) * .1);
        final object = Rect.fromCenter(
            center: Offset.zero, width: w * .27, height: w * .48);
        canvas.drawOval(
            object,
            Paint()
              ..shader = LinearGradient(
                  colors: [accent, bg, ink, accent],
                  stops: const [0, .35, .62, 1]).createShader(object));
        canvas.restore();
        text(title.toUpperCase(), .10, .79, .075, ink, width: .8);
      case 3: // Analog landscape with a film border, light leaks, small serif title.
        final frame = Rect.fromLTWH(w * .055, w * .055, w * .89, w * .77);
        landscape(frame, variation % 5);
        canvas.drawRect(
            frame,
            Paint()
              ..shader = LinearGradient(colors: [
                accent.withValues(alpha: .35),
                Colors.transparent,
                bg.withValues(alpha: .3)
              ]).createShader(frame));
        text(title, .075, .87, .065, ink, family: 'LibreBaskerville');
      case _: // Fluid abstract fields, different from geometric poster covers.
        for (var i = 0; i < 6; i++) {
          final cx = w * (r.nextDouble() * 1.4 - .2), cy = w * r.nextDouble();
          final oval = Rect.fromCenter(
              center: Offset(cx, cy),
              width: w * (.5 + r.nextDouble()),
              height: w * (.25 + r.nextDouble() * .5));
          canvas.save();
          canvas.translate(cx, cy);
          canvas.rotate(r.nextDouble() * 3);
          canvas.translate(-cx, -cy);
          canvas.drawOval(
              oval,
              Paint()
                ..shader = RadialGradient(colors: [
                  (i.isEven ? accent : ink).withValues(alpha: .85),
                  bg.withValues(alpha: 0)
                ]).createShader(oval));
          canvas.restore();
        }
        text(title.toUpperCase(), .08, .08, .11, ink);
    }
    final points = <Offset>[
      for (var i = 0; i < 600; i++)
        Offset(r.nextDouble() * w, r.nextDouble() * w)
    ];
    canvas.drawPoints(
        PointMode.points,
        points,
        Paint()
          ..color = ink.withValues(alpha: .10)
          ..strokeWidth = math.max(.5, w / 350));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.h != h || old.variation != variation || old.title != title;
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
      this.photo = ArtistPhoto.general,
      this.square = false});
  final String name;
  final int seed;
  final double size;
  final int? artistId;
  final ArtistPhoto photo;

  /// A square picture (2000s profile pages) instead of a round one.
  final bool square;

  /// Drawn faces (docs K212) or initials; a setting.
  static bool faces = true;

  /// Member counts of the open career's bands and groups (docs K212),
  /// kept up to date by the career.
  static Map<int, int> groupSizes = const {};

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) =>
        p.isNotEmpty && RegExp(r'^[\p{L}\d]', unicode: true).hasMatch(p));
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase());
    return letters.isEmpty ? '?' : letters.join();
  }

  @override
  Widget build(BuildContext context) {
    final path = artistId == null
        ? null
        : _images(context)?.artistPhoto(artistId!, photo);
    if (path != null) {
      final photo = _Photo(path: path, size: size);
      return square ? ClipRect(child: photo) : ClipOval(child: photo);
    }
    final (bg, fg, _) = _schemes[_hash(seed + 7) % _schemes.length];
    if (faces) {
      final face = CustomPaint(
          size: Size.square(size),
          painter: AvatarFacePainter(seed, bg,
              members: artistId == null ? 1 : groupSizes[artistId] ?? 1));
      return square ? ClipRect(child: face) : ClipOval(child: face);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          shape: square ? BoxShape.rectangle : BoxShape.circle, color: bg),
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
