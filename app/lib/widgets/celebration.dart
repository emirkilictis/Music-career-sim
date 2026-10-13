import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Actions;
import 'package:flutter/rendering.dart';
import 'package:game/game.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/career_state.dart';
import '../core/event_lines.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import 'art.dart';
import 'common.dart';

/// The big moments worth a full screen (feedback E6): a release's first #1
/// on a chart, and the career's very first chart entry.
bool isCelebration(EventLine line, ArtistView? before) => switch (line.event) {
      NumberOne(firstForRelease: true) => true,
      ChartDebut() => before != null && !before.everCharted,
      _ => false,
    };

/// Shows the celebration, with a card the player can share (R1).
Future<void> showCelebration(
    BuildContext context, EventLine line, CareerState career) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
          child: child),
    ),
    pageBuilder: (_, __, ___) =>
        Scope<CareerState>(value: career, child: _Celebration(line: line)),
  );
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.line});
  final EventLine line;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  final _card = GlobalKey();
  final _shareButton = GlobalKey();
  late final AnimationController _confetti;

  @override
  void initState() {
    super.initState();
    // Runs once (no repeat), so the screen settles.
    _confetti = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  bool get _isNo1 => widget.line.event is NumberOne;

  int get _position => switch (widget.line.event) {
        ChartDebut(:final position) => position,
        _ => 1,
      };

  int get _chartId => switch (widget.line.event) {
        NumberOne(:final chartId) => chartId,
        ChartDebut(:final chartId) => chartId,
        _ => 0,
      };

  Future<void> _share() async {
    final l = context.l10n;
    final fmt = context.fmt;
    final box = _shareButton.currentContext?.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final boundary =
        _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/career_moment_${DateTime.now().millisecondsSinceEpoch}.png')
      ..writeAsBytesSync(png!.buffer.asUint8List());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      text: l.shareMomentText(
          widget.line.title, _position, fmt.chart(_chartId), l.appTitle),
      sharePositionOrigin: origin,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final p = career.player;
    final line = widget.line;
    final accent = _isNo1 ? AppColors.gold : AppColors.lilac;
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (_, __) =>
                  CustomPaint(painter: _ConfettiPainter(_confetti.value)),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_isNo1 ? l.celebrateNumberOne : l.celebrateFirstChart,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
                RepaintBoundary(
                  key: _card,
                  child: _MomentCard(
                    line: line,
                    position: _position,
                    chartName: fmt.chart(_chartId),
                    artistName: p.name,
                    artistId: p.id,
                    week: fmt.week(career.lastWeekPlayed),
                    mode: fmt.difficulty(career.difficulty),
                    accent: accent,
                  ),
                ),
                const SizedBox(height: 22),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  OutlinedButton.icon(
                    key: _shareButton,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        minimumSize: const Size(130, 48)),
                    onPressed: _share,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(l.share),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: const Color(0xFF1B1530),
                        minimumSize: const Size(130, 48)),
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.continueLabel),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The shareable card: cover, the position, title, artist, chart, week and
/// the game mode (so a Legend-mode record reads as one).
class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.line,
    required this.position,
    required this.chartName,
    required this.artistName,
    required this.artistId,
    required this.week,
    required this.mode,
    required this.accent,
  });
  final EventLine line;
  final int position;
  final String chartName;
  final String artistName;
  final int artistId;
  final String week;
  final String mode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final songId = line.songId;
    return Container(
      width: 310,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppShape.r(28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF2A2350), const Color(0xFF14182E)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(children: [
        CoverArt(
          seed: songId != null
              ? songCoverSeed(songId, line.albumId)
              : albumCoverSeed(line.albumId),
          songId: songId,
          albumId: line.albumId,
          size: 200,
          radius: 16,
        ),
        const SizedBox(height: 14),
        Text('#$position',
            style: TextStyle(
                fontFamily: AppFonts.condensed,
                fontSize: 72,
                height: 1,
                fontWeight: FontWeight.w800,
                color: accent)),
        const SizedBox(height: 6),
        Text(line.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(artistName,
            style: const TextStyle(
                color: Color(0xFFC9C2E6), fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(chartName.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppFonts.condensed,
                letterSpacing: 1.2,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: accent)),
        Text(week,
            style: const TextStyle(color: Color(0xFF9E97BD), fontSize: 13)),
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.graphic_eq_rounded,
              size: 16, color: Color(0xFF9E97BD)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(l.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF9E97BD),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Tag(mode, color: accent),
        ]),
      ]),
    );
  }
}

/// Falling confetti; [t] runs 0 → 1 once.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;

  static final _pieces = List.generate(90, (i) {
    final r = math.Random(i * 7919);
    return (
      x: r.nextDouble(),
      delay: r.nextDouble() * 0.35,
      speed: 0.7 + r.nextDouble() * 0.6,
      drift: (r.nextDouble() - 0.5) * 0.25,
      spin: (r.nextDouble() - 0.5) * 12,
      color: r.nextInt(7),
      w: 5 + r.nextDouble() * 5,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      AppColors.pink,
      AppColors.peach,
      AppColors.mint,
      AppColors.sky,
      AppColors.butter,
      AppColors.lilac,
      AppColors.gold,
    ];
    for (final p in _pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 60);
      final x = (p.x + p.drift * local) * size.width;
      final fade = local > 0.85 ? (1 - local) / 0.15 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.w, height: p.w * 1.6),
          Paint()..color = colors[p.color].withValues(alpha: fade));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
