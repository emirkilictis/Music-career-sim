import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/bar_chart.dart';
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

  /// Picks bonus tracks from the vault and re-releases the album as a
  /// deluxe edition (docs K115).
  Future<void> _deluxe(AlbumView a) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final vault = await widget.state.read(Cmd.vault());
    if (!mounted) return;
    final picked = await showModalBottomSheet<List<int>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        final chosen = <int>{};
        return StatefulBuilder(
          builder: (c, set) => SafeArea(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(l.deluxeTitle,
                      style: Theme.of(c).textTheme.titleLarge),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                      l.deluxeHint(fmt.money(EditionFormat.deluxe.costCents)),
                      style: Theme.of(c).textTheme.bodySmall),
                ),
                if (vault.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.deluxeEmpty),
                  )
                else
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      for (final s in vault)
                        CheckboxListTile(
                          value: chosen.contains(s.id),
                          onChanged:
                              !chosen.contains(s.id) && chosen.length >= 6
                                  ? null
                                  : (v) => set(() => v == true
                                      ? chosen.add(s.id)
                                      : chosen.remove(s.id)),
                          title: Text(s.title),
                          subtitle: Text(fmt.songGrade(s)),
                        ),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: chosen.isEmpty
                        ? null
                        : () => Navigator.pop(c, chosen.toList()),
                    child: Text(l.deluxeRelease(chosen.length)),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    try {
      await widget.state.act(Cmd.releaseDeluxe(a.id, picked));
      if (mounted) {
        showInfo(context, l.deluxeOut(a.title),
            icon: Icons.library_add_check_rounded);
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Records the album again under the player's own name, with songs from
  /// the vault if they like, into a draft (docs K139).
  Future<void> _rerecord(AlbumView a) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final vault = [
      for (final s in await widget.state.read(Cmd.vault()))
        if (s.rerecordOf < 0) s
    ];
    if (!mounted) return;
    final name = TextEditingController(
        text: l.rerecordDefault(a.title, a.artistName));
    final picked = await showModalBottomSheet<(String, List<int>)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        final chosen = <int>[];
        return StatefulBuilder(
          builder: (c, set) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(c).size.height * 0.85),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(l.rerecordTitle,
                        style: Theme.of(c).textTheme.titleLarge),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                        l.rerecordHint(fmt.money(a.rerecordCostCents),
                            a.rerecordEnergy.round()),
                        style: Theme.of(c).textTheme.bodySmall),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: name,
                      maxLength: 60,
                      decoration: InputDecoration(labelText: l.rerecordName),
                    ),
                  ),
                  if (vault.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(l.rerecordVault,
                          style: Theme.of(c).textTheme.bodySmall),
                    ),
                    Flexible(
                      child: ListView(shrinkWrap: true, children: [
                        for (final s in vault)
                          CheckboxListTile(
                            value: chosen.contains(s.id),
                            onChanged:
                                !chosen.contains(s.id) && chosen.length >= 6
                                    ? null
                                    : (v) => set(() => v == true
                                        ? chosen.add(s.id)
                                        : chosen.remove(s.id)),
                            title: Text(s.title),
                            subtitle: Text(fmt.songGrade(s)),
                          ),
                      ]),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(c, (name.text, List.of(chosen))),
                      child: Text(l.rerecordGo),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
    name.dispose();
    if (picked == null || !mounted) return;
    try {
      await widget.state.act(Cmd.rerecordAlbum(a.id, picked.$1, picked.$2));
      if (mounted) {
        showInfo(context, l.rerecordSaved(picked.$1.trim()),
            icon: Icons.album_rounded);
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
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
    final lastWeeks = [
      for (final w in _sales.skip(_sales.length > 12 ? _sales.length - 12 : 0))
        w.units ?? 0.0,
    ];
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
            subtitle: '${a.artistName}'
                '${a.partnerName.isEmpty ? '' : ' & ${a.partnerName}'}'
                ' · ${fmt.albumType(a.type)}'
                '${a.isDeluxe ? ' · ${l.deluxeTag}' : ''}'
                '${a.isRerecord ? ' · ${l.rerecordTag}' : ''}'
                '${a.isLive ? ' · ${l.liveTag}' : ''}',
          ),
          if (a.canDeluxe) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _deluxe(a),
              icon: const Icon(Icons.library_add_rounded),
              label: Text(l.deluxeButton),
            ),
          ],
          if (!a.isPlayer)
            ArtistLink(
                artistId: a.artistId, name: a.artistName, state: widget.state),
          if (a.usLifetimeUnits >= Certification.gold.units) ...[
            const SizedBox(height: 10),
            Center(child: CertificationTag(units: a.usLifetimeUnits)),
          ],
          if (a.isPlayer) ...[
            const SizedBox(height: 14),
            ProfitCard(
              revenueCents: a.revenueCents,
              costsCents: a.costsCents,
              sold: a.lifetimeUnits.total,
              globalPeak: a.charts
                  .where((c) => c.chartId == Charts.globalAlbums)
                  .firstOrNull
                  ?.peak,
            ),
          ],
          // A streaming exclusive (docs K135).
          if (a.isPlayer && a.exclusiveFeeCents > 0) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.lock_clock_outlined,
                  size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    l.exclusiveLine(fmt.money(a.exclusiveFeeCents),
                        fmt.week(a.exclusiveUntil)),
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ]),
          ],
          // Who owns the masters; re-recordings (docs K139).
          if (a.isPlayer && a.type != AlbumType.mixtape) ...[
            const SizedBox(height: 10),
            _Line(
              icon: Icons.copyright_rounded,
              text: a.masterShare < 1
                  ? l.mastersLabel((a.masterShare * 100).round())
                  : l.mastersOwn,
            ),
            if (a.isRerecord && a.originalTitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              _Line(
                  icon: Icons.replay_rounded,
                  text: l.rerecordOfLine(a.originalTitle)),
            ],
            if (a.replacedWeek >= 0) ...[
              const SizedBox(height: 6),
              _Line(
                  icon: Icons.swap_horiz_rounded,
                  text: l.rerecordedLine(fmt.week(a.replacedWeek))),
            ],
            if (a.rerecordBlock == RerecordBlock.tooSoon) ...[
              const SizedBox(height: 6),
              _Line(
                  icon: Icons.schedule_rounded,
                  text: l.rerecordFrom(fmt.week(a.rerecordFrom))),
            ],
            if (a.canRerecord) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _rerecord(a),
                icon: const Icon(Icons.replay_rounded),
                label: Text(l.rerecordButton),
              ),
            ],
          ],
          // Anniversary reissues (docs K149).
          if (a.anniversaryDue > 0) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await widget.state.act(Cmd.reissueAnniversary(a.id));
                  if (context.mounted) {
                    showInfo(context,
                        l.anniversaryDone(a.anniversaryDue, a.title),
                        icon: Icons.cake_outlined);
                  }
                  _load();
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
              icon: const Icon(Icons.cake_outlined),
              label: Text(l.anniversaryButton(a.anniversaryDue,
                  fmt.money(Anniversaries.costCents()))),
            ),
            const SizedBox(height: 4),
            Text(l.anniversaryHint,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ],
          for (final n in a.anniversariesMarked) ...[
            const SizedBox(height: 6),
            _Line(icon: Icons.cake_outlined, text: l.anniversaryLine(n)),
          ],
          // The whole album on the app's Marquee (docs K147).
          if (a.marqueeCostCents case final cost?) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await widget.state.act(Cmd.runAlbumMarquee(a.id));
                  if (context.mounted) {
                    showInfo(context, l.marqueeOn(a.title),
                        icon: Icons.campaign_outlined);
                  }
                  _load();
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
              icon: const Icon(Icons.campaign_outlined),
              label: Text('${l.marqueeAlbum} · ${fmt.money(cost)}'),
            ),
          ] else if (a.isPlayer && a.onMarquee) ...[
            const SizedBox(height: 10),
            _Line(icon: Icons.campaign_outlined, text: l.marqueeAlbumRan),
          ],
          // Bundled copies (docs K144).
          if (a.isPlayer && a.bundle != AlbumBundle.none) ...[
            const SizedBox(height: 10),
            _Line(
                icon: Icons.inventory_2_outlined,
                text: l.bundleLine(fmt.bundle(a.bundle),
                    fmt.compact(a.bundleUnits))),
          ],
          // Pre-orders shipped in week one (docs K126).
          if (a.isPlayer && a.preOrders >= 1) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.local_shipping_outlined,
                  size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    l.preOrdersShipped(
                        fmt.compact(a.preOrders), fmt.compact(a.firstWeekPure)),
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ]),
          ],
          if (lastWeeks.length > 1) ...[
            const SizedBox(height: 12),
            Section(
              title: l.salesLastWeeks(lastWeeks.length),
              icon: Icons.bar_chart_rounded,
              child: WeeklyBars(values: lastWeeks),
            ),
          ],
          if (a.criticScore >= 0) ...[
            const SizedBox(height: 14),
            Section(
              title: l.reviewsTitle,
              icon: Icons.rate_review_outlined,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The consensus (docs K112).
                    Row(children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        color: a.metascore >= 75
                            ? const Color(0xFF2E9E5B)
                            : a.metascore >= 50
                                ? const Color(0xFFE0B020)
                                : AppColors.coral,
                        child: Text('${a.metascore}',
                            style: const TextStyle(
                                fontFamily: AppFonts.condensed,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.metascoreLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              Text(l.metascoreHint,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textMuted)),
                            ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    for (final e in a.reviews.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(
                              child: Text(fmt.outlet(e.key),
                                  style:
                                      TextStyle(color: AppColors.textMuted))),
                          if (e.key == Outlet.rollingPage)
                            _Stars(fmt.stars(e.value))
                          else
                            Text(fmt.outletScore(e.key, e.value),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text(fmt.criticScore(a.criticScore),
                          style: TextStyle(
                              fontFamily: AppFonts.condensed,
                              fontSize: 40,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: a.criticScore >= 8
                                  ? AppColors.gold
                                  : a.criticScore >= 6
                                      ? AppColors.text
                                      : AppColors.coral)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text('“${fmt.criticBlurb(a.criticScore)}”',
                            style: const TextStyle(
                                fontStyle: FontStyle.italic, fontSize: 15)),
                      ),
                    ]),
                  ]),
            ),
          ],
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
              if (a.preSingleUnits >= 1)
                StatTile(
                    label: l.preSingleSales,
                    value: fmt.compact(a.preSingleUnits)),
              if (a.trackStreams >= 1)
                StatTile(label: l.streams, value: fmt.compact(a.trackStreams)),
              for (final r in Region.values)
                StatTile(
                    label: fmt.region(r),
                    value: fmt.compact(a.lifetimeUnits[r])),
            ]),
          ),
          if (a.isPlayer &&
              (a.campaignCostCents > 0 || a.campaignReturnCents > 0)) ...[
            const SizedBox(height: 12),
            CampaignResult(
                campaign: a.campaign,
                costCents: a.campaignCostCents,
                returnCents: a.campaignReturnCents),
          ],
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
          if (_tracks.any((t) => t.isSingle)) ...[
            const SizedBox(height: 12),
            Section(
              title: l.albumSingles,
              icon: Icons.music_note_outlined,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        l.albumSinglesTotal(fmt.compact(_tracks
                            .where((t) => t.isSingle)
                            .fold(0.0, (sum, t) => sum + t.singleSales))),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                    for (final t in _tracks.where((t) => t.isSingle))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([
                          if (t.charts.any((c) => c.chartId == Charts.usSongs))
                            '${fmt.chartShort(Charts.usSongs)} #${t.charts.firstWhere((c) => c.chartId == Charts.usSongs).peak}',
                          if (t.lifetimeStreams.total >= 1)
                            '${fmt.compact(t.singleUnits)} ${l.singleUnits}',
                        ].join(' · ')),
                        trailing: Text(fmt.compact(t.singleSales),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SongDetailScreen(
                                    songId: t.id, state: widget.state))),
                      ),
                  ]),
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
                  title: Text(_tracks[i].featuredNames.isEmpty
                      ? _tracks[i].title
                      : '${_tracks[i].title} (feat. ${_tracks[i].featuredNames.join(', ')})'),
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
                      : a.isPlayer
                          ? GradeTag(fmt.songGrade(_tracks[i]))
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

/// Rolling Page's star rating (docs K112), drawn rather than typed.
class _Stars extends StatelessWidget {
  const _Stars(this.stars);
  final double stars;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
                stars >= i
                    ? Icons.star_rounded
                    : stars >= i - 0.5
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded,
                size: 18,
                color: AppColors.gold),
        ],
      );
}

/// A muted line with an icon.
class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text, style: TextStyle(color: AppColors.textMuted))),
      ]);
}
