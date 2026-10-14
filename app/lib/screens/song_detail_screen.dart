import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/profit_card.dart';
import '../widgets/campaign_result.dart';
import '../widgets/image_pickers.dart';
import '../core/images.dart';
import '../ui/palette.dart';
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

  Future<void> _shootVideo(SongView s) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final money = widget.state.player.moneyCents;
    final budget = await showModalBottomSheet<VideoBudget>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(l.shootVideo, style: Theme.of(c).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.videoHint, style: Theme.of(c).textTheme.bodySmall),
          ),
          for (final b in VideoBudget.values)
            ListTile(
              enabled: b.costCents <= money,
              leading: Icon(switch (b) {
                VideoBudget.low => Icons.videocam_outlined,
                VideoBudget.medium => Icons.movie_creation_outlined,
                VideoBudget.high => Icons.theaters_rounded,
              }),
              title: Text(fmt.videoBudget(b)),
              subtitle: Text(switch (b) {
                VideoBudget.low => l.videoLowHint,
                VideoBudget.medium => l.videoMediumHint,
                VideoBudget.high => l.videoHighHint,
              }),
              trailing: Text(fmt.money(b.costCents)),
              onTap: () => Navigator.pop(c, b),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (budget == null || !mounted) return;
    try {
      await widget.state.act(Cmd.shootVideo(s.id, budget));
      if (mounted) showInfo(context, l.videoShot(s.title));
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _scrap(SongView s) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.scrapSongTitle(s.title)),
        content: Text(l.scrapSongBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.scrapSong)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.state.act(Cmd.scrapSong(s.id));
      if (!mounted) return;
      Navigator.pop(context);
      showInfo(context, l.songScrapped(s.title));
    } catch (e) {
      if (mounted) showError(context, e);
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
    final salesFirst =
        SalesEra.of(GameTime.yearOf(widget.state.week)) != SalesEra.streaming;
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
            coverSeed: songCoverSeed(s.id, s.coverAlbumId),
            songId: s.id,
            albumId: s.coverAlbumId,
            onCoverTap: s.isPlayer
                ? () => editImage(context, ImageStore.songKey(s.id))
                : null,
            title: s.title,
            subtitle: '${s.artistName} · ${fmt.songStatus(s)}',
            trailing: s.isPlayer ? GradeTag(fmt.songGrade(s)) : null,
          ),
          if (!s.isPlayer)
            ArtistLink(
                artistId: s.artistId, name: s.artistName, state: widget.state),
          if (s.usSingleUnits >= Certification.gold.units) ...[
            const SizedBox(height: 10),
            Center(child: CertificationTag(units: s.usSingleUnits)),
          ],
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
                      if (s.isSingle && s.releasedWeek >= 0)
                        fmt.radioPush(s.radioPush),
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
                  if (s.isPlayer && s.video == null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _shootVideo(s),
                      icon: const Icon(Icons.videocam_rounded),
                      label: Text(l.shootVideo),
                    ),
                  ] else if (s.video != null) ...[
                    const SizedBox(height: 8),
                    Tag(l.hasVideo(fmt.videoBudget(s.video!)),
                        icon: Icons.videocam_rounded),
                  ],
                  if (s.isPlayer &&
                      s.inVault &&
                      s.scheduledSingleWeek < 0 &&
                      s.scheduledAlbumWeek < 0)
                    TextButton.icon(
                      onPressed: () => _scrap(s),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.coral),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(l.scrapSong),
                    ),
                ]),
          ),
          if (!s.inVault) ...[
            const SizedBox(height: 12),
            _SongNumbers(song: s, salesFirst: salesFirst),
            if (s.isPlayer) ...[
              const SizedBox(height: 12),
              ProfitCard(
                revenueCents: s.revenueCents,
                costsCents: s.costsCents,
                sold: s.singleUnits,
                globalPeak: s.charts
                    .where((c) => c.chartId == Charts.globalSongs)
                    .firstOrNull
                    ?.peak,
              ),
            ],
            if (s.isPlayer &&
                (s.campaignCostCents > 0 || s.campaignReturnCents > 0)) ...[
              const SizedBox(height: 12),
              CampaignResult(
                  campaign: s.campaign,
                  costCents: s.campaignCostCents,
                  returnCents: s.campaignReturnCents),
            ],
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

/// The song's numbers (F46): four headline figures for the era, where its
/// streams come from as one bar, the rest folded away.
class _SongNumbers extends StatefulWidget {
  const _SongNumbers({required this.song, required this.salesFirst});
  final SongView song;
  final bool salesFirst;

  @override
  State<_SongNumbers> createState() => _SongNumbersState();
}

class _SongNumbersState extends State<_SongNumbers> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final s = widget.song;
    final streams = s.lifetimeStreams.total;
    final hasStreams = streams >= 1;
    StatTile tile(String label, double v) =>
        StatTile(label: label, value: fmt.compact(v));
    final head = widget.salesFirst || !hasStreams
        ? [
            tile(l.singleSales, s.singleSales),
            tile(l.radioAudience, s.lifetimeRadio),
            if (hasStreams) tile(l.streams, streams),
            tile(l.singleUnits, s.singleUnits),
          ]
        : [
            tile(l.streams, streams),
            tile(l.thisWeekStreams, s.weekStreams),
            tile(l.singleUnits, s.singleUnits),
            tile(l.singleSales, s.singleSales),
          ];
    Widget row(String label, double v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
                child:
                    Text(label, style: TextStyle(color: AppColors.textMuted))),
            Text(fmt.compact(v),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        );
    final regionColors = [AppColors.lilac, AppColors.pink, AppColors.sky];
    return Section(
      title: l.numbers,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StatGrid(tiles: head),
        if (hasStreams) ...[
          const SizedBox(height: 18),
          Text(l.streamsByRegion,
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in Region.values)
                      if (s.lifetimeStreams[r] > 0)
                        Expanded(
                            flex: (s.lifetimeStreams[r] / streams * 1000)
                                .round()
                                .clamp(1, 1000),
                            child:
                                ColoredBox(color: regionColors[r.index % 3])),
                  ]),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 4, children: [
            for (final r in Region.values)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: regionColors[r.index % 3],
                        shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                    '${fmt.region(r)} '
                    '${(s.lifetimeStreams[r] / streams * 100).round()}%',
                    style: const TextStyle(fontSize: 13)),
              ]),
          ]),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _more = !_more),
            icon: Icon(
                _more ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            label: Text(_more ? l.fewerNumbers : l.moreNumbers),
          ),
        ),
        if (_more) ...[
          if (hasStreams)
            for (final r in Region.values)
              row(fmt.region(r), s.lifetimeStreams[r]),
          row(l.downloads, s.lifetimeDownloads),
          if (s.lifetimePhysical >= 1) row(l.cdSingles, s.lifetimePhysical),
          if (!widget.salesFirst && hasStreams)
            row(l.radioAudience, s.lifetimeRadio),
          if (widget.salesFirst && hasStreams)
            row(l.thisWeekStreams, s.weekStreams),
        ],
      ]),
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
            borderRadius: BorderRadius.circular(AppShape.r(18)),
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
