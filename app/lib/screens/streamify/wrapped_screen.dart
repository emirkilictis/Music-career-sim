import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Actions;
import 'package:flutter/rendering.dart';
import 'package:game/game.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/commands.dart';
import '../../core/scope.dart';
import '../../ui/palette.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';

/// Flat blocks of loud color, one per page of the year in review.
abstract final class _C {
  static const pink = Color(0xFFFF4FA3);
  static const lime = Color(0xFFD7F75B);
  static const violet = Color(0xFF6B3CF5);
  static const orange = Color(0xFFFF6B35);
  static const blue = Color(0xFF2D46B9);
  static const ink = Color(0xFF141414);
}

/// The player's year on the streaming app (docs K123), Wrapped-style: a
/// shareable summary, then the songs, the peak, the regions and the fans.
class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key, this.year});
  final int? year;

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  WrappedView? _view;
  List<int> _years = const [];
  int? _year;
  bool _loaded = false;
  final _card = GlobalKey();
  final _shareButton = GlobalKey();

  @override
  void initState() {
    super.initState();
    _year = widget.year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final (view, years) = await context.careerRead.read(Cmd.wrapped(_year));
    if (!mounted) return;
    setState(() {
      _view = view;
      _years = years;
      _year = view?.year ?? _year;
      _loaded = true;
    });
  }

  Future<void> _share() async {
    final l = context.l10n;
    final v = _view!;
    final name = context.careerRead.player.name;
    final box = _shareButton.currentContext?.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final boundary =
        _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    // No files on the web: the image goes as bytes (docs K218).
    final bytes = png!.buffer.asUint8List();
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'wrapped.png')],
      text: l.wrappedShareText(name, v.year),
      sharePositionOrigin: origin,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = _view;
    return Scaffold(
      backgroundColor: StreamifyColors.bg,
      appBar: AppBar(
        backgroundColor: StreamifyColors.bg,
        foregroundColor: Colors.white,
        title: Text(l.wrappedTitle),
        actions: [
          if (v != null)
            IconButton(
                key: _shareButton,
                tooltip: l.share,
                onPressed: _share,
                icon: const Icon(Icons.ios_share_rounded)),
        ],
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : v == null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.wrappedNone(Wrapped.firstYear),
                      style: const TextStyle(color: StreamifyColors.muted)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    if (_years.length > 1) ...[
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final y in _years)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('$y'),
                                  selected: y == v.year,
                                  onSelected: (_) {
                                    setState(() => _year = y);
                                    _load();
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    RepaintBoundary(key: _card, child: _Summary(view: v)),
                    const SizedBox(height: 14),
                    _Block(
                      color: _C.violet,
                      label: l.wrappedTopSongs,
                      light: true,
                      child: Column(children: [
                        for (final (i, s) in v.topSongs.indexed)
                          _SongLine(rank: i + 1, song: s),
                      ]),
                    ),
                    if (v.topAlbumId >= 0) ...[
                      const SizedBox(height: 14),
                      _Block(
                        color: _C.orange,
                        label: l.wrappedTopAlbum,
                        child: Row(children: [
                          CoverArt(
                              seed: albumCoverSeed(v.topAlbumId),
                              albumId: v.topAlbumId,
                              size: 72,
                              radius: 2),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _Big(context.fmt.compact(v.topAlbumPlays),
                                l.wrappedPlays,
                                dark: true),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _Block(
                      color: _C.lime,
                      label: l.wrappedPeak,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Big(context.fmt.compact(v.peakListeners),
                                l.wrappedListeners,
                                dark: true),
                            const SizedBox(height: 4),
                            Text(context.fmt.monthYear(v.peakWeek),
                                style: const TextStyle(
                                    color: _C.ink,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                    const SizedBox(height: 14),
                    _Block(
                      color: _C.blue,
                      label: l.wrappedWhere,
                      light: true,
                      child: Column(children: [
                        for (final r in Region.values)
                          _RegionBar(
                              name: context.fmt.region(r),
                              share: v.regionShare[r.index],
                              top: r == v.topRegion),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    _Block(
                      color: _C.pink,
                      label: l.wrappedFans,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Big(context.fmt.compact(v.topFans),
                                l.wrappedFansLine,
                                dark: true),
                            const SizedBox(height: 10),
                            Text(l.wrappedNewSongs(v.newSongs),
                                style: const TextStyle(
                                    color: _C.ink,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                  ],
                ),
    );
  }
}

/// The shareable page: the year, the story, the plays, the top three.
class _Summary extends StatelessWidget {
  const _Summary({required this.view});
  final WrappedView view;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = view;
    final growth = v.growthPct;
    return Container(
      color: _C.lime,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          color: _C.ink,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(children: [
            const Icon(Icons.graphic_eq_rounded,
                color: StreamifyColors.accent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.wrappedHeader(v.year),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.5)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.careerRead.player.name,
                style: const TextStyle(
                    color: _C.ink, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Container(
              color: _C.pink,
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
              child: Text(fmt.wrappedStory(v.story).toUpperCase(),
                  style: const TextStyle(
                      color: _C.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.6)),
            ),
            const SizedBox(height: 14),
            Text(fmt.compact(v.plays),
                style: const TextStyle(
                    fontFamily: AppFonts.condensed,
                    color: _C.ink,
                    fontSize: 76,
                    height: 0.95,
                    fontWeight: FontWeight.w800)),
            Text(l.wrappedPlaysLine,
                style: const TextStyle(
                    color: _C.ink, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(l.wrappedMinutes(fmt.compact(v.minutes)),
                style: const TextStyle(color: _C.ink, fontSize: 13.5)),
            if (growth != null) ...[
              const SizedBox(height: 4),
              Text(
                  l.wrappedGrowth(
                      growth >= 0 ? '+$growth' : '$growth', v.year - 1),
                  style: const TextStyle(
                      color: _C.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 16),
            for (final (i, s) in v.topSongs.take(3).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontFamily: AppFonts.condensed,
                            color: _C.ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                  ),
                  CoverArt(
                      seed: songCoverSeed(s.songId, s.coverAlbumId),
                      songId: s.songId,
                      albumId: s.coverAlbumId,
                      size: 40,
                      radius: 2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _C.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(
      {required this.color,
      required this.label,
      required this.child,
      this.light = false});
  final Color color;
  final String label;
  final Widget child;

  /// White text on a dark block.
  final bool light;

  @override
  Widget build(BuildContext context) => Container(
        color: color,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: light ? Colors.white : _C.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.8)),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.caption, {this.dark = false});
  final String value;
  final String caption;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = dark ? _C.ink : Colors.white;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          style: TextStyle(
              fontFamily: AppFonts.condensed,
              color: c,
              fontSize: 48,
              height: 1,
              fontWeight: FontWeight.w800)),
      Text(caption,
          style:
              TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _SongLine extends StatelessWidget {
  const _SongLine({required this.rank, required this.song});
  final int rank;
  final WrappedSong song;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(
            width: 30,
            child: Text('$rank',
                style: const TextStyle(
                    fontFamily: AppFonts.condensed,
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
          ),
          CoverArt(
              seed: songCoverSeed(song.songId, song.coverAlbumId),
              songId: song.songId,
              albumId: song.coverAlbumId,
              size: 46,
              radius: 2),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800)),
              Text(
                  context.l10n
                      .wrappedSongPlays(context.fmt.compact(song.plays)),
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ]),
      );
}

class _RegionBar extends StatelessWidget {
  const _RegionBar(
      {required this.name, required this.share, required this.top});
  final String name;
  final double share;
  final bool top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: top ? FontWeight.w900 : FontWeight.w600)),
            ),
            Text('${(share * 100).round()}%',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (_, c) => Stack(children: [
              Container(height: 10, color: Colors.white24),
              Container(
                  height: 10,
                  width: c.maxWidth * share.clamp(0.0, 1.0),
                  color: top ? _C.lime : Colors.white),
            ]),
          ),
        ]),
      );
}
