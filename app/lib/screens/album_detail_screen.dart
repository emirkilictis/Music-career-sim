import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/image_pickers.dart';
import '../core/images.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/line_chart.dart';
import 'song_detail_screen.dart';

/// One album or EP: first week, regional sales, charts, tracks, history.
class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen(
      {super.key, required this.albumId, required this.state});
  final int albumId;
  final CareerState state;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  AlbumView? _album;
  List<SongView> _tracks = const [];
  List<HistoryPoint> _history = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = widget.state;
    final album = await st.read(Cmd.album(widget.albumId));
    final tracks = [
      for (final id in album.trackIds) await st.read(Cmd.song(id))
    ];
    final history = await st.read(Cmd.albumHistory(widget.albumId));
    if (mounted) {
      setState(() {
        _album = album;
        _tracks = tracks;
        _history = history;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final a = _album;
    if (a == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    final units = [for (final h in _history) h.value];
    return Scaffold(
      appBar: AppBar(title: Text(a.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReleaseHeader(
            coverSeed: albumCoverSeed(a.id),
            albumId: a.id,
            onCoverTap: () => editImage(context, ImageStore.albumKey(a.id)),
            title: a.title,
            subtitle: '${a.artistName} · ${fmt.albumType(a.type)}',
          ),
          const SizedBox(height: 14),
          Section(
            title: l.details,
            icon: Icons.info_outline_rounded,
            child: Text(
              '${l.releasedOn(fmt.week(a.releaseWeek))} · ${fmt.campaign(a.campaign)}'
              '${a.variantWeeks.length > 1 ? ' · ${l.editionsCount(a.variantWeeks.length)}' : ''}',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(height: 12),
          Section(
            title: l.firstWeek,
            child: StatGrid(tiles: [
              StatTile(
                  label: l.usUnits, value: fmt.compact(a.firstWeekUsUnits)),
              StatTile(
                  label: l.usPureSales, value: fmt.compact(a.firstWeekUsPure)),
              StatTile(
                  label: l.ukUnits, value: fmt.compact(a.firstWeekUkUnits)),
              StatTile(
                  label: l.globalUnits, value: fmt.compact(a.firstWeekUnits)),
            ]),
          ),
          const SizedBox(height: 12),
          Section(
            title: l.totalSales,
            child: StatGrid(tiles: [
              StatTile(
                  label: l.albumUnits,
                  value: fmt.compact(a.lifetimeUnits.total)),
              StatTile(
                  label: l.pureSales, value: fmt.compact(a.lifetimePure.total)),
              for (final r in Region.values)
                StatTile(
                    label: fmt.region(r),
                    value: fmt.compact(a.lifetimeUnits[r])),
            ]),
          ),
          const SizedBox(height: 12),
          ChartRecords(records: a.charts),
          if (units.length > 1) ...[
            const SizedBox(height: 12),
            Section(
              title: l.weeklyUnits,
              child: LineChart(
                  values: units,
                  topLabel: fmt.compact(units.reduce((x, y) => x > y ? x : y))),
            ),
          ],
          const SizedBox(height: 12),
          Section(
            title: l.tracklist,
            child: Column(children: [
              for (var i = 0; i < _tracks.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text('${i + 1}'),
                  title: Text(_tracks[i].title),
                  subtitle: Text(_tracks[i].isSingle ? l.typeSingle : ''),
                  trailing: Text(fmt.songMain(_tracks[i], widget.state.week)),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SongDetailScreen(
                              songId: _tracks[i].id, state: widget.state))),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
