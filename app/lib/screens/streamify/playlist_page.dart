import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../../core/commands.dart';
import '../../core/format.dart';
import '../../core/scope.dart';
import '../../ui/palette.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import '../game_shell.dart';
import '../song_detail_screen.dart';
import 'artist_page.dart';

/// Colors of each Top 50 playlist cover.
(Color, Color) top50Colors(int chartId) => switch (chartId) {
      Charts.platformGlobal => (
          const Color(0xFF2BD97C),
          const Color(0xFF0B5C4A)
        ),
      Charts.platformNorthAmerica => (
          const Color(0xFF5B8CFF),
          const Color(0xFF1B2A6B)
        ),
      _ => (const Color(0xFFFF7AA8), const Color(0xFF5B1A44)),
    };

String top50Region(BuildContext context, int chartId) {
  final l = context.l10n;
  return switch (chartId) {
    Charts.platformGlobal => l.regionGlobal,
    Charts.platformNorthAmerica => l.regionNorthAmerica,
    _ => l.regionEurope,
  };
}

/// Square "Top 50" playlist cover.
class Top50Cover extends StatelessWidget {
  const Top50Cover({super.key, required this.chartId, this.size = 150});
  final int chartId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (a, b) = top50Colors(chartId);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [a, b]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.graphic_eq_rounded,
              color: Colors.white, size: size * 0.13),
          const Spacer(),
          Text('Top 50',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.2,
                  height: 1)),
          SizedBox(height: size * 0.03),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: size * 0.04, vertical: size * 0.015),
            color: Colors.black.withValues(alpha: 0.35),
            child: Text(top50Region(context, chartId).toUpperCase(),
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontSize: size * 0.075)),
          ),
        ],
      ),
    );
  }
}

/// A Top 50 chart shown as a streaming playlist.
class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key, required this.chartId});
  final int chartId;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  ChartView? _view;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final v = await context.careerRead.read(Cmd.chart(widget.chartId));
    if (mounted) setState(() => _view = v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final view = _view;
    final (a, _) = top50Colors(widget.chartId);
    final region = top50Region(context, widget.chartId);
    final career = context.careerRead;
    return Scaffold(
      backgroundColor: StreamifyColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: view == null
          ? const Center(
              child: CircularProgressIndicator(color: StreamifyColors.accent))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [a.withValues(alpha: 0.75), StreamifyColors.bg],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(boxShadow: [
                            BoxShadow(blurRadius: 30, color: Colors.black54),
                          ]),
                          child: Top50Cover(chartId: widget.chartId, size: 210),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(l.top50Title(region),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(l.top50Description(region),
                          style: const TextStyle(color: StreamifyColors.muted)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.graphic_eq_rounded,
                            color: StreamifyColors.accent, size: 18),
                        const SizedBox(width: 6),
                        Text(
                            '$platformName · ${l.songsCount(view.rows.length)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        const Spacer(),
                        Container(
                          width: 54,
                          height: 54,
                          decoration: const BoxDecoration(
                              color: StreamifyColors.accent,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.black, size: 34),
                        ),
                      ]),
                    ],
                  ),
                ),
                for (final r in view.rows)
                  InkWell(
                    onTap: () => r.isPlayer
                        ? Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SongDetailScreen(
                                    songId: r.entityId, state: career)))
                        : pushInCareer(
                            context, ArtistPage(artistId: r.artistId)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      child: Row(children: [
                        SizedBox(
                          width: 30,
                          child: Column(children: [
                            Text('${r.position}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: StreamifyColors.muted)),
                            Icon(
                              r.isNew || r.lastPos > r.position
                                  ? Icons.arrow_drop_up_rounded
                                  : r.lastPos < r.position
                                      ? Icons.arrow_drop_down_rounded
                                      : Icons.remove_rounded,
                              size: r.lastPos == r.position ? 10 : 18,
                              color: r.isNew || r.lastPos > r.position
                                  ? StreamifyColors.accent
                                  : r.lastPos < r.position
                                      ? const Color(0xFFF15E6C)
                                      : StreamifyColors.muted,
                            ),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        CoverArt(
                            seed: songCoverSeed(r.entityId, r.albumId),
                            songId: r.entityId,
                            albumId: r.albumId,
                            size: 48,
                            radius: 2),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15.5,
                                        color: r.isPlayer
                                            ? StreamifyColors.accent
                                            : Colors.white)),
                                Text(r.artistName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: StreamifyColors.muted,
                                        fontSize: 13)),
                              ]),
                        ),
                        Text(context.fmt.compact(r.weekValue * Streamify.share),
                            style: const TextStyle(
                                color: StreamifyColors.muted, fontSize: 13)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
