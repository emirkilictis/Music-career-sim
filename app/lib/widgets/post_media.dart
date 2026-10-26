import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/format.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import 'art.dart';
import 'common.dart';

/// The picture under a feed post (docs K211): the release's cover, a
/// chart graphic, a big number, a review score or a teaser's sound clip.
class PostMediaCard extends StatelessWidget {
  const PostMediaCard(
      {super.key,
      required this.item,
      required this.artistName,
      required this.week,
      this.dark = true,
      this.round = true});
  final SocialItemView item;
  final String artistName;

  /// The game's week now (whether Streamify is open).
  final int week;
  final bool dark, round;

  static const _green = Color(0xFF1ED760);

  @override
  Widget build(BuildContext context) {
    final i = item;
    final radius = BorderRadius.circular(round ? 16 : 0);
    final line = dark ? const Color(0xFF2F3336) : const Color(0xFFB9CBE3);
    final child = switch (i.media) {
      PostMedia.none => null,
      PostMedia.release => _release(context),
      PostMedia.chart => _chart(context),
      PostMedia.stat => _stat(context),
      PostMedia.score => _score(context),
      PostMedia.snippet => _snippet(context),
    };
    if (child == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration:
          BoxDecoration(borderRadius: radius, border: Border.all(color: line)),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }

  Widget _cover(double size) => CoverArt(
      seed: item.isAlbum
          ? albumCoverSeed(item.albumId)
          : songCoverSeed(item.songId, item.coverAlbumId),
      songId: item.isAlbum ? null : item.songId,
      albumId: item.coverAlbumId >= 0 ? item.coverAlbumId : null,
      size: size,
      radius: 0);

  Color get _text => dark ? const Color(0xFFE7E9EA) : const Color(0xFF111111);
  Color get _muted => dark ? const Color(0xFF71767B) : const Color(0xFF666666);

  /// A link card: the cover and what it is.
  Widget _release(BuildContext context) {
    final l = context.l10n;
    final open = MusicPlatform.streamify.openIn(GameTime.yearOf(week));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cover(96),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: _text, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(
                item.isAlbum
                    ? l.postMediaAlbum(artistName)
                    : l.postMediaSingle(artistName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _muted, fontSize: 13)),
            if (open) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
                decoration: BoxDecoration(
                    color: _green, borderRadius: BorderRadius.circular(99)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.play_arrow_rounded, size: 16, color: Colors.black),
                  SizedBox(width: 2),
                  Text(platformName,
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }

  /// A chart graphic, as fan accounts post a debut: the rank huge, the
  /// cover beside it.
  Widget _chart(BuildContext context) {
    final l = context.l10n;
    final i = item;
    final rank = i.topic == FanTopic.numberOne ? 1 : math.max(1, i.number);
    final label = switch (i.topic) {
      FanTopic.numberOne => l.postMediaNewNo1,
      FanTopic.topTen => l.postMediaTopTen,
      _ => l.postMediaYearEnd,
    };
    final accent =
        rank == 1 ? const Color(0xFFFFC83D) : const Color(0xFF8AB4FF);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF0E1A33), Color(0xFF05070D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Row(children: [
        _cover(104),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontFamily: AppFonts.condensed,
                    color: accent,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('#$rank',
                  style: const TextStyle(
                      fontFamily: AppFonts.condensed,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 54,
                      height: 1)),
            ),
            const SizedBox(height: 4),
            Text(i.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            Text(artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }

  /// A big number: a first week's units or the billions club.
  Widget _stat(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final i = item;
    final billions = i.topic == FanTopic.billionsClub;
    final value = billions ? '${fmt.number(1e9)}+' : fmt.number(i.number);
    final caption =
        billions ? l.postMediaBillions(platformName) : l.postMediaFirstWeek;
    return Container(
      color: const Color(0xFF111114),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        _cover(72),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontFamily: AppFonts.condensed,
                      color: billions ? _green : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 34,
                      height: 1.05)),
            ),
            Text(caption.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppFonts.condensed,
                    color: Colors.white70,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5)),
            const SizedBox(height: 4),
            Text('${i.title} · $artistName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }

  /// The critic's score in its square, beside the cover.
  Widget _score(BuildContext context) {
    final l = context.l10n;
    final score = item.number / 10;
    final good = score >= 7.5;
    final box = good ? const Color(0xFF2E9E5B) : const Color(0xFFD9483B);
    return Container(
      color: const Color(0xFFF7F5F0),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        _cover(80),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.criticName.toUpperCase(),
                style: const TextStyle(
                    fontFamily: AppFonts.serif,
                    color: Color(0xFF111111),
                    fontVariations: [FontVariation.weight(700)],
                    letterSpacing: 1.5,
                    fontSize: 13)),
            const SizedBox(height: 4),
            Text(item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppFonts.serif,
                    color: Color(0xFF111111),
                    fontStyle: FontStyle.italic,
                    fontSize: 14)),
            Text(artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF555555), fontSize: 12)),
          ]),
        ),
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: box, borderRadius: BorderRadius.circular(round ? 8 : 0)),
          child: Text(score.toStringAsFixed(1),
              style: const TextStyle(
                  fontFamily: AppFonts.condensed,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28)),
        ),
      ]),
    );
  }

  /// A teaser's sound clip: a play button and a waveform.
  Widget _snippet(BuildContext context) {
    final l = context.l10n;
    final seed = item.likes * 31 + item.week;
    return Container(
      color: const Color(0xFF16181C),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.black, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 28,
              child: CustomPaint(
                  size: const Size(double.infinity, 28),
                  painter: _WavePainter(seed)),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(l.postMediaSnippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ),
              const Text('0:15',
                  style: TextStyle(color: Colors.white54, fontSize: 12.5)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    final paint = Paint()
      ..color = const Color(0xFF1D9BF0)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    const step = 6.0;
    final n = (size.width / step).floor();
    for (var k = 0; k < n; k++) {
      // A louder middle, as a hook would be.
      final shape = math.sin(math.pi * k / math.max(1, n - 1));
      final h =
          size.height * (0.15 + 0.85 * shape * (0.35 + 0.65 * r.nextDouble()));
      final x = k * step + step / 2;
      canvas.drawLine(Offset(x, (size.height - h) / 2),
          Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.seed != seed;
}
