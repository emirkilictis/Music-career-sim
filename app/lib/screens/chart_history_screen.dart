import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:game/game.dart';
import 'package:share_plus/share_plus.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'album_detail_screen.dart';
import 'song_detail_screen.dart';

/// How the list is ordered.
enum _Sort { peak, weeks, newest }

/// The player's chart career (docs K232, K299), as a chart magazine's
/// artist page shows it: the artist's picture, the #1s, entries and top
/// 10s on the chart picked, then every release's run on it, the biggest
/// first. Songs (features too) and albums, on every chart they reached;
/// the top of the page is shared as one picture.
class ChartHistoryScreen extends StatefulWidget {
  const ChartHistoryScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<ChartHistoryScreen> createState() => _ChartHistoryScreenState();
}

class _ChartHistoryScreenState extends State<ChartHistoryScreen> {
  ChartHistoryView? _v;
  int _chart = Charts.usSongs;
  _Sort _sort = _Sort.peak;
  final _card = GlobalKey();
  final _shareButton = GlobalKey();

  /// Rows on the shared picture.
  static const _shareRows = 5;

  @override
  void initState() {
    super.initState();
    widget.state.read(Cmd.chartHistory()).then((v) {
      if (mounted) setState(() => _v = v);
    });
  }

  /// The charts the player reached, songs first, then albums.
  List<int> _charts(ChartHistoryView v) => [
        for (final c in Charts.all)
          if (!c.retired &&
              (c.kind == ChartKind.songs ? v.songs : v.albums)
                  .any((e) => e.on(c.id) != null))
            c.id
      ]..sort((a, b) {
          final ka = Charts.all[a].kind.index, kb = Charts.all[b].kind.index;
          return ka != kb ? ka.compareTo(kb) : a.compareTo(b);
        });

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
    // No files on the web: the image goes as bytes (docs K218).
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(png!.buffer.asUint8List(),
            mimeType: 'image/png', name: 'chart-career.png')
      ],
      text: l.historyShareText(
          widget.state.player.name, fmt.chart(_chart), l.appTitle),
      sharePositionOrigin: origin,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = _v;
    if (v == null) {
      return Scaffold(
          appBar: AppBar(title: Text(l.chartHistory)),
          body: const Center(child: CircularProgressIndicator()));
    }
    final charts = _charts(v);
    final chart = charts.contains(_chart)
        ? _chart
        : (charts.isEmpty ? Charts.usSongs : charts.first);
    final albums = Charts.all[chart].kind == ChartKind.albums;
    final on = [
      for (final e in albums ? v.albums : v.songs)
        if (e.on(chart) != null) e
    ];
    switch (_sort) {
      case _Sort.newest:
        break;
      case _Sort.peak:
        on.sort((a, b) {
          final x = a.on(chart)!, y = b.on(chart)!;
          if (x.peak != y.peak) return x.peak.compareTo(y.peak);
          if (x.weeksAtNo1 != y.weeksAtNo1) {
            return y.weeksAtNo1.compareTo(x.weeksAtNo1);
          }
          return y.weeksOn.compareTo(x.weeksOn);
        });
      case _Sort.weeks:
        on.sort(
            (a, b) => b.on(chart)!.weeksOn.compareTo(a.on(chart)!.weeksOn));
    }
    final no1 = on.where((e) => e.on(chart)!.peak == 1).length;
    final top10 = on.where((e) => e.on(chart)!.peak <= 10).length;
    final weeksAt1 = on.fold(0, (t, e) => t + e.on(chart)!.weeksAtNo1);
    final weeks = on.fold(0, (t, e) => t + e.on(chart)!.weeksOn);
    final p = widget.state.player;
    Widget row(ChartHistoryEntry e) =>
        _Row(entry: e, chart: chart, state: widget.state);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.chartHistory),
        actions: [
          // Biggest first, longest run first, newest first.
          PopupMenuButton<_Sort>(
            tooltip: l.historySort,
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              for (final s in _Sort.values)
                PopupMenuItem(
                  value: s,
                  child: Text(switch (s) {
                    _Sort.newest => l.historySortNewest,
                    _Sort.peak => l.historySortPeak,
                    _Sort.weeks => l.historySortWeeks,
                  }),
                ),
            ],
          ),
          if (on.isNotEmpty)
            IconButton(
              key: _shareButton,
              tooltip: l.share,
              onPressed: _share,
              icon: const Icon(Icons.ios_share_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // The shared picture: the artist, the totals and the top runs.
          RepaintBoundary(
            key: _card,
            child: ColoredBox(
              color: AppColors.bg,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(artistId: p.id, name: p.name, chart: fmt.chart(chart)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(children: [
                        for (final (value, label) in [
                          ('$no1', l.historyNo1Hits),
                          ('${on.length}', l.historyTotalEntries),
                          ('$top10', l.historyTop10Hits),
                        ]) ...[
                          if (label != l.historyNo1Hits)
                            const SizedBox(width: 10),
                          Expanded(child: _BigStat(value: value, label: label)),
                        ],
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                          [
                            l.historyWeeksOnLine(weeks),
                            if (weeksAt1 > 0) l.historyWeeksAt1Line(weeksAt1),
                          ].join(' · '),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12.5)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: DropdownButtonFormField<int>(
                        initialValue: chart,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14)),
                        items: [
                          for (final c in charts.isEmpty ? [chart] : charts)
                            DropdownMenuItem(
                                value: c,
                                child: Text(fmt.chart(c),
                                    overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (c) => setState(() => _chart = c!),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final e in on.take(_shareRows)) row(e),
                  ]),
            ),
          ),
          if (on.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyNote(l.historyEmpty),
            ),
          for (final e in on.skip(_shareRows)) row(e),
        ],
      ),
    );
  }
}

/// The artist's picture across the page, the name and the chart on it.
class _Hero extends StatelessWidget {
  const _Hero({required this.artistId, required this.name, required this.chart});
  final int artistId;
  final String name;
  final String chart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = c.maxWidth;
      return SizedBox(
        width: size,
        height: size * 0.9,
        child: Stack(fit: StackFit.expand, children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: ArtistAvatar(
                name: name,
                seed: artistId,
                artistId: artistId,
                size: size,
                square: true),
          ),
          // Dark at the foot, so the name reads on any picture.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.55, 1.0],
                colors: [Color(0x00000000), Color(0xDD000000)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(chart.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: AppFonts.condensed,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 2,
                          color: Colors.white70)),
                  Text(name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: AppFonts.condensed,
                          fontWeight: FontWeight.w800,
                          fontSize: 40,
                          height: 1.0,
                          color: Colors.white)),
                ]),
          ),
        ]),
      );
    });
  }
}

/// One of the three totals under the picture.
class _BigStat extends StatelessWidget {
  const _BigStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppShape.r(14)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontFamily: AppFonts.condensed,
                fontWeight: FontWeight.w800,
                fontSize: 34,
                height: 1.0,
                color: AppColors.text)),
        const SizedBox(height: 6),
        Container(width: 40, height: 3, color: AppColors.line),
        const SizedBox(height: 6),
        Text(label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
                fontFamily: AppFonts.condensed,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.6,
                color: AppColors.mint)),
      ]),
    );
  }
}

/// One release's run on a chart: its cover (marked #1 if it got there),
/// title, who and how long, and its peak large.
class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.chart, required this.state});
  final ChartHistoryEntry entry;
  final int chart;
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = entry;
    final r = e.on(chart)!;
    final album = e.kind == EntityKind.album;
    final hits = e.hits[chart];
    final top = r.peak == 1;
    final details = [
      [
        e.feature ? l.historyFeature(e.artistName) : e.artistName,
        l.historyWeeks(r.weeksOn),
      ].join(' • '),
      [
        '${GameTime.yearOf(e.releaseWeek)}',
        if (r.weeksAtNo1 > 0) l.historyWeeksAt1Short(r.weeksAtNo1),
        if (r.debutPos > 0) l.historyDebut(r.debutPos),
        if (album && hits != null && hits.$1 > 0)
          l.historyAlbumHits(hits.$3, hits.$2, hits.$1),
      ].join(' · '),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShape.r(14)),
            side: BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => album
                      ? AlbumDetailScreen(albumId: e.id, state: state)
                      : SongDetailScreen(songId: e.id, state: state))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Stack(children: [
                CoverArt(
                    seed: album
                        ? albumCoverSeed(e.id)
                        : songCoverSeed(e.id, e.coverAlbumId),
                    songId: album ? null : e.id,
                    albumId: e.coverAlbumId >= 0 ? e.coverAlbumId : null,
                    size: 60,
                    radius: 6),
                if (top)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      color: AppColors.mint,
                      child: const Text('#1',
                          style: TextStyle(
                              fontFamily: AppFonts.condensed,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.black)),
                    ),
                  ),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 2),
                      for (final (i, line) in details.indexed)
                        if (line.isNotEmpty)
                          Text(line,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: i == 0 ? 13.5 : 12)),
                    ]),
              ),
              const SizedBox(width: 10),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('#${r.peak}',
                    style: TextStyle(
                        fontFamily: AppFonts.condensed,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        height: 1.0,
                        color: top
                            ? AppColors.mint
                            : r.peak <= 10
                                ? AppColors.text
                                : AppColors.textMuted)),
                Text(l.historyPeakLabel.toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
