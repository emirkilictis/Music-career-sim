import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/image_pickers.dart';
import '../core/images.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/artist_link.dart';
import '../widgets/history_tables.dart';
import '../widgets/line_chart.dart';
import 'releases_tab.dart';
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
  List<AlbumSalesWeek> _sales = const [];
  List<ChartWeek> _run = const [];

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
    final sales = await st.read(Cmd.albumSales(widget.albumId));
    final run = await st.read(Cmd.chartRun(EntityKind.album, widget.albumId));
    if (mounted) {
      setState(() {
        _album = album;
        _tracks = tracks;
        _history = history;
        _sales = sales;
        _run = run;
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
            onCoverTap: a.isPlayer
                ? () => editImage(context, ImageStore.albumKey(a.id))
                : null,
            title: a.title,
            subtitle: '${a.artistName} · ${fmt.albumType(a.type)}',
          ),
          if (!a.isPlayer)
            ArtistLink(
                artistId: a.artistId, name: a.artistName, state: widget.state),
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
          if (a.variantWeeks.length > 1) ...[
            const SizedBox(height: 12),
            Section(
              title: l.editions,
              icon: Icons.library_music_outlined,
              child: Column(children: [
                for (var k = 0; k < a.variantWeeks.length; k++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CoverArt(
                        seed: albumCoverSeed(a.id) + k,
                        albumId: a.id,
                        imageKey: k == 0
                            ? null
                            : ImageStore.editionKey(
                                ImageStore.albumKey(a.id), k),
                        size: 48),
                    title: Text(k == 0
                        ? l.editionStandard
                        : a.variantFormats[k] == null
                            ? l.editionN(k + 1)
                            : '${l.editionN(k + 1)} · ${fmt.editionFormat(a.variantFormats[k])}'),
                    subtitle: Text(l.editionWeek(
                        fmt.week(a.releaseWeek + a.variantWeeks[k]))),
                    trailing:
                        a.isPlayer ? const Icon(Icons.edit_outlined) : null,
                    onTap: !a.isPlayer
                        ? null
                        : () => editImage(
                            context,
                            k == 0
                                ? ImageStore.albumKey(a.id)
                                : ImageStore.editionKey(
                                    ImageStore.albumKey(a.id), k)),
                  ),
              ]),
            ),
          ],
          if (a.weekUnits > 0) ...[
            const SizedBox(height: 12),
            Section(
              title: l.lastWeekSales,
              icon: Icons.bar_chart_rounded,
              child: StatGrid(tiles: [
                StatTile(label: l.globalUnits, value: fmt.compact(a.weekUnits)),
                StatTile(label: l.usUnits, value: fmt.compact(a.weekUsUnits)),
                if (a.isPlayer)
                  StatTile(
                      label: l.lastWeekPure, value: fmt.compact(a.weekPure)),
                if (_sales.isNotEmpty &&
                    _sales.last.positions[Charts.usAlbums] != null)
                  StatTile(
                      label: l.lastWeekPosition,
                      value: '#${_sales.last.positions[Charts.usAlbums]}'),
              ]),
            ),
          ],
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
          const SizedBox(height: 12),
          Section(
            title: l.chartRunTitle,
            icon: Icons.timeline_rounded,
            child: ChartRunTable(run: _run),
          ),
          if (_sales.isNotEmpty) ...[
            const SizedBox(height: 12),
            Section(
              title: l.weeklySales,
              icon: Icons.table_rows_outlined,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!a.isPlayer)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(l.weeklySalesRivalHint,
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ),
                    AlbumSalesTable(weeks: _sales, full: a.isPlayer),
                  ]),
            ),
          ],
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
                  subtitle: Text(_tracks[i].isSingle
                      ? l.typeSingle
                      : _tracks[i].scheduledSingleWeek >= 0
                          ? l.scheduledSingleTag(
                              fmt.week(_tracks[i].scheduledSingleWeek))
                          : fmt.songMain(_tracks[i], widget.state.week)),
                  // Another single from the album in one tap.
                  trailing: a.isPlayer &&
                          !_tracks[i].isSingle &&
                          _tracks[i].scheduledSingleWeek < 0
                      ? OutlinedButton(
                          onPressed: widget.state.busy
                              ? null
                              : () async {
                                  if (await releaseSingleFlow(
                                      context, widget.state, _tracks[i])) {
                                    _load();
                                  }
                                },
                          child: Text(l.makeSingle),
                        )
                      : Text(fmt.songMain(_tracks[i], widget.state.week)),
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
