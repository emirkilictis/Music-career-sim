import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/image_pickers.dart';
import '../core/images.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/artist_link.dart';
import '../widgets/history_tables.dart';
import '../widgets/line_chart.dart';
import 'releases_tab.dart';

/// One song: numbers, chart records, weekly history.
class SongDetailScreen extends StatefulWidget {
  const SongDetailScreen(
      {super.key, required this.songId, required this.state});
  final int songId;
  final CareerState state;

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  SongView? _song;
  List<HistoryPoint> _history = const [];
  List<ChartWeek> _run = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final song = await widget.state.read(Cmd.song(widget.songId));
    final history = await widget.state.read(Cmd.songHistory(widget.songId));
    final run =
        await widget.state.read(Cmd.chartRun(EntityKind.song, widget.songId));
    if (mounted) {
      setState(() {
        _song = song;
        _history = history;
        _run = run;
      });
    }
  }

  Future<void> _release(SongView s) async {
    if (await releaseSingleFlow(context, widget.state, s)) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final s = _song;
    if (s == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }
    final streams = [for (final h in _history) h.value];
    final sales = [for (final h in _history) h.sales];
    final hasStreams = s.lifetimeStreams.total >= 1;
    final salesFirst =
        SalesEra.of(GameTime.yearOf(widget.state.week)) != SalesEra.streaming;
    final saleTiles = [
      StatTile(label: l.singleSales, value: fmt.compact(s.singleSales)),
      StatTile(label: l.downloads, value: fmt.compact(s.lifetimeDownloads)),
      if (s.lifetimePhysical >= 1)
        StatTile(label: l.cdSingles, value: fmt.compact(s.lifetimePhysical)),
      StatTile(label: l.radioAudience, value: fmt.compact(s.lifetimeRadio)),
    ];
    final streamTiles = [
      if (hasStreams) ...[
        StatTile(label: l.thisWeekStreams, value: fmt.compact(s.weekStreams)),
        StatTile(label: l.streams, value: fmt.compact(s.lifetimeStreams.total)),
        StatTile(label: l.singleUnits, value: fmt.compact(s.singleUnits)),
        for (final r in Region.values)
          StatTile(
              label: fmt.region(r), value: fmt.compact(s.lifetimeStreams[r])),
      ],
    ];
    Widget chart(String title, List<double> v) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Section(
            title: title,
            child: LineChart(
                values: v,
                topLabel: fmt.compact(v.reduce((a, b) => a > b ? a : b))),
          ),
        );
    final streamChart = streams.length > 1 && streams.any((x) => x >= 1)
        ? chart(l.weeklyStreams, streams)
        : null;
    final salesChart = sales.length > 1 && sales.any((x) => x >= 1)
        ? chart(l.weeklySingleSales, sales)
        : null;
    final usPos = [
      for (final h in _history) h.positions[Charts.usSongs]?.toDouble()
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReleaseHeader(
            coverSeed: songCoverSeed(s.id, s.albumId),
            songId: s.id,
            albumId: s.albumId,
            onCoverTap: s.isPlayer
                ? () => editImage(context, ImageStore.songKey(s.id))
                : null,
            title: s.title,
            subtitle: '${s.artistName} · ${fmt.songStatus(s)}',
            trailing: s.isPlayer ? GradeTag(fmt.grade(s.estimatedGrade)) : null,
          ),
          if (!s.isPlayer)
            ArtistLink(
                artistId: s.artistId, name: s.artistName, state: widget.state),
          const SizedBox(height: 14),
          Section(
            title: fmt.genres(s.genres),
            icon: Icons.sell_outlined,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (s.releasedWeek >= 0)
                        l.releasedOn(fmt.week(s.releasedWeek)),
                      if (s.releasedWeek >= 0) fmt.campaign(s.campaign),
                      if (s.playlistAdd != PlaylistAdd.none) l.onPlaylist,
                    ].join(' · '),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                  if (s.scheduledSingleWeek >= 0) ...[
                    const SizedBox(height: 12),
                    Tag(l.scheduledSingleTag(fmt.week(s.scheduledSingleWeek)),
                        icon: Icons.event_rounded),
                  ] else if (s.isPlayer &&
                      (s.inVault || (!s.isSingle && s.albumId >= 0))) ...[
                    const SizedBox(height: 12),
                    GradientButton(
                      onPressed: () => _release(s),
                      icon: Icons.music_note_rounded,
                      label: l.releaseAsSingle,
                    ),
                  ],
                ]),
          ),
          if (!s.inVault) ...[
            const SizedBox(height: 12),
            Section(
              title: l.numbers,
              child: StatGrid(
                  tiles: salesFirst
                      ? [...saleTiles, ...streamTiles]
                      : [...streamTiles, ...saleTiles]),
            ),
            const SizedBox(height: 12),
            _ChartRecords(records: s.charts),
            const SizedBox(height: 12),
            Section(
              title: l.chartRunTitle,
              icon: Icons.timeline_rounded,
              child: ChartRunTable(run: _run),
            ),
            ...[
              if (salesFirst) salesChart,
              streamChart,
              if (!salesFirst) salesChart,
            ].whereType<Widget>(),
            if (usPos.whereType<double>().length > 1) ...[
              const SizedBox(height: 12),
              Section(
                title: l.positionOn(fmt.chart(Charts.usSongs)),
                child: LineChart(
                  values: usPos,
                  invert: true,
                  color: Theme.of(context).colorScheme.tertiary,
                  topLabel:
                      '#${usPos.whereType<double>().reduce((a, b) => a < b ? a : b).round()}',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Peak, weeks and #1 weeks per chart.
class _ChartRecords extends StatelessWidget {
  const _ChartRecords({required this.records});
  final List<ChartRecord> records;

  @override
  Widget build(BuildContext context) => ChartRecords(records: records);
}

class ChartRecords extends StatelessWidget {
  const ChartRecords({super.key, required this.records});
  final List<ChartRecord> records;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return Section(
      title: l.chartHistory,
      child: records.isEmpty
          ? EmptyNote(l.neverCharted)
          : Column(children: [
              for (final r in records)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: PosBadge(r.peak, highlight: true),
                  title: Text(fmt.chart(r.chartId)),
                  subtitle: Text(l.chartRecordLine(
                      r.debutPos, r.weeksOn, r.weeksAtNo1, r.lastPos)),
                ),
            ]),
    );
  }
}

/// Big cover with title and artist, centered (detail pages).
class ReleaseHeader extends StatelessWidget {
  const ReleaseHeader(
      {super.key,
      required this.coverSeed,
      required this.title,
      required this.subtitle,
      this.trailing,
      this.songId,
      this.albumId,
      this.onCoverTap});
  final int coverSeed;
  final int? songId;
  final int? albumId;

  /// Opens the cover picker (the player's own releases).
  final VoidCallback? onCoverTap;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  blurRadius: 30, offset: Offset(0, 12), color: Colors.black54),
            ],
          ),
          child: GestureDetector(
            onTap: onCoverTap,
            child: Stack(children: [
              CoverArt(
                  seed: coverSeed,
                  size: 190,
                  radius: 18,
                  songId: songId,
                  albumId: albumId),
              if (onCoverTap != null)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.photo_camera_outlined,
                        color: Colors.white, size: 18),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ]),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
      ]);
}
