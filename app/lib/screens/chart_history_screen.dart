import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/media_tile.dart';
import 'album_detail_screen.dart';
import 'song_detail_screen.dart';

/// Where a chart is.
enum _Market { us, uk, global }

/// How the list is ordered.
enum _Sort { newest, peak, weeks }

/// The player's whole chart history (docs K232): songs (features too) and
/// albums on the US, UK or global charts, with totals on top, each run's
/// peak, weeks, weeks at #1 and debut, and for albums how many #1s and top
/// 10s came from them.
class ChartHistoryScreen extends StatefulWidget {
  const ChartHistoryScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<ChartHistoryScreen> createState() => _ChartHistoryScreenState();
}

class _ChartHistoryScreenState extends State<ChartHistoryScreen> {
  ChartHistoryView? _v;
  bool _albums = false;
  _Market _market = _Market.us;
  _Sort _sort = _Sort.newest;

  @override
  void initState() {
    super.initState();
    widget.state.read(Cmd.chartHistory()).then((v) {
      if (mounted) setState(() => _v = v);
    });
  }

  int get _chart => switch ((_market, _albums)) {
        (_Market.us, false) => Charts.usSongs,
        (_Market.uk, false) => Charts.ukSongs,
        (_Market.global, false) => Charts.globalSongs,
        (_Market.us, true) => Charts.usAlbums,
        (_Market.uk, true) => Charts.ukAlbums,
        (_Market.global, true) => Charts.globalAlbums,
      };

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
    final chart = _chart;
    final all = _albums ? v.albums : v.songs;
    final on = [
      for (final e in all)
        if (e.on(chart) != null) e
    ];
    switch (_sort) {
      case _Sort.newest:
        break;
      case _Sort.peak:
        on.sort((a, b) {
          final d = a.on(chart)!.peak.compareTo(b.on(chart)!.peak);
          return d != 0 ? d : b.on(chart)!.weeksOn.compareTo(a.on(chart)!.weeksOn);
        });
      case _Sort.weeks:
        on.sort((a, b) => b.on(chart)!.weeksOn.compareTo(a.on(chart)!.weeksOn));
    }
    final no1 = on.where((e) => e.on(chart)!.peak == 1).length;
    final top10 = on.where((e) => e.on(chart)!.peak <= 10).length;
    final weeksAt1 = on.fold(0, (t, e) => t + e.on(chart)!.weeksAtNo1);
    final weeks = on.fold(0, (t, e) => t + e.on(chart)!.weeksOn);
    return Scaffold(
      appBar: AppBar(title: Text(l.chartHistory)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: false,
                  label: Text(l.historySongs),
                  icon: const Icon(Icons.music_note_rounded)),
              ButtonSegment(
                  value: true,
                  label: Text(l.historyAlbums),
                  icon: const Icon(Icons.album_rounded)),
            ],
            selected: {_albums},
            onSelectionChanged: (x) => setState(() => _albums = x.first),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in _Market.values)
              ChoiceChip(
                label: Text(switch (m) {
                  _Market.us => l.historyUs,
                  _Market.uk => l.historyUk,
                  _Market.global => l.historyGlobal,
                }),
                selected: m == _market,
                onSelected: (_) => setState(() => _market = m),
              ),
          ]),
          const SizedBox(height: 4),
          Text(fmt.chart(chart),
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 12),
          StatGrid(tiles: [
            StatTile(label: l.historyEntries, value: '${on.length}'),
            StatTile(label: l.historyTop10s, value: '$top10'),
            StatTile(label: l.historyNo1s, value: '$no1'),
            StatTile(label: l.historyWeeksAt1, value: '$weeksAt1'),
            StatTile(label: l.historyWeeksOn, value: '$weeks'),
            if (_albums)
              StatTile(
                  label: l.historyNo1Songs,
                  value: '${on.fold(0, (t, e) => t + (e.hits[chart]?.$3 ?? 0))}'),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, children: [
            for (final s in _Sort.values)
              ChoiceChip(
                label: Text(switch (s) {
                  _Sort.newest => l.historySortNewest,
                  _Sort.peak => l.historySortPeak,
                  _Sort.weeks => l.historySortWeeks,
                }),
                selected: s == _sort,
                onSelected: (_) => setState(() => _sort = s),
              ),
          ]),
          const SizedBox(height: 8),
          if (on.isEmpty)
            EmptyNote(l.historyEmpty)
          else
            for (final e in on) _Row(entry: e, chart: chart, state: widget.state),
        ],
      ),
    );
  }
}

/// One release's run on a chart.
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
    final lines = [
      [
        '${GameTime.yearOf(e.releaseWeek)}',
        if (e.feature) l.historyFeature(e.artistName),
      ].join(' · '),
      [
        l.historyWeeks(r.weeksOn),
        if (r.weeksAtNo1 > 0) l.historyWeeksAt1Short(r.weeksAtNo1),
        if (r.debutPos > 0) l.historyDebut(r.debutPos),
      ].join(' · '),
      if (album && hits != null && hits.$1 > 0)
        l.historyAlbumHits(hits.$3, hits.$2, hits.$1),
    ];
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => album
                  ? AlbumDetailScreen(albumId: e.id, state: state)
                  : SongDetailScreen(songId: e.id, state: state))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CoverArt(
              seed: album
                  ? albumCoverSeed(e.id)
                  : songCoverSeed(e.id, e.coverAlbumId),
              songId: album ? null : e.id,
              albumId: e.coverAlbumId >= 0 ? e.coverAlbumId : null,
              size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15.5)),
                  for (final (i, line) in lines.indexed)
                    Text(line,
                        style: TextStyle(
                            color: i == 2 && (hits?.$3 ?? 0) > 0
                                ? AppColors.gold
                                : AppColors.textMuted,
                            fontWeight:
                                i == 2 ? FontWeight.w700 : FontWeight.w400,
                            fontSize: 12.5)),
                ]),
          ),
          const SizedBox(width: 8),
          PeakTag(r.peak),
        ]),
      ),
    );
  }
}
