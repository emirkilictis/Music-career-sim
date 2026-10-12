import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/common.dart';
import 'song_detail_screen.dart';

/// Career summary: totals by region, #1s, year by year, all songs.
class CareerScreen extends StatefulWidget {
  const CareerScreen({super.key});

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  List<CareerYear> _years = const [];
  List<SongView> _songs = const [];
  int _loadedRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final career = context.career;
    if (career.revision != _loadedRevision) {
      _loadedRevision = career.revision;
      _load();
    }
  }

  Future<void> _load() async {
    final career = context.careerRead;
    final years = await career.read(Cmd.careerByYear());
    final songs = await career.read(Cmd.songs());
    if (mounted) {
      setState(() {
        _years = years;
        _songs = songs.where((s) => !s.inVault).toList()
          ..sort((a, b) =>
              b.lifetimeStreams.total.compareTo(a.lifetimeStreams.total));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final p = career.player;
    final t = Theme.of(context).textTheme;
    return Scaffold(
        appBar: AppBar(title: Text(l.careerSummary)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Section(
              title: l.careerTotals,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatGrid(tiles: [
                      StatTile(
                          label: l.streams,
                          value: fmt.compact(p.lifetimeStreams.total)),
                      StatTile(
                          label: l.albumUnits,
                          value: fmt.compact(p.lifetimeUnits.total)),
                      StatTile(
                          label: l.pureSales,
                          value: fmt.compact(p.lifetimePure.total)),
                      StatTile(
                          label: l.coreFans, value: fmt.compact(p.coreFans)),
                    ]),
                    const SizedBox(height: 16),
                    Text(l.byRegion, style: t.titleSmall),
                    const SizedBox(height: 6),
                    Table(
                      columnWidths: const {0: FlexColumnWidth(1.4)},
                      children: [
                        TableRow(children: [
                          const SizedBox(),
                          Text(l.streams, style: t.labelSmall),
                          Text(l.albumUnits, style: t.labelSmall),
                        ]),
                        for (final r in Region.values)
                          TableRow(children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(fmt.region(r)),
                            ),
                            Text(fmt.compact(p.lifetimeStreams[r])),
                            Text(fmt.compact(p.lifetimeUnits[r])),
                          ]),
                      ],
                    ),
                  ]),
            ),
            const SizedBox(height: 12),
            Section(
              title: l.numberOnes,
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in Charts.mainSongCharts)
                  Chip(
                      label: Text(
                          '${fmt.chartShort(c)}: ${p.numberOneSingles[c]}')),
                for (final c in Charts.mainAlbumCharts)
                  Chip(
                      label: Text(
                          '${fmt.chartShort(c)}: ${p.numberOneAlbums[c]}')),
              ]),
            ),
            const SizedBox(height: 12),
            Section(
              title: l.yearByYear,
              child: _years.isEmpty
                  ? EmptyNote(l.yearByYearEmpty)
                  : Table(
                      columnWidths: const {0: FlexColumnWidth(0.8)},
                      children: [
                        TableRow(children: [
                          Text(l.year, style: t.labelSmall),
                          Text(l.streams, style: t.labelSmall),
                          Text(l.albumUnits, style: t.labelSmall),
                          Text(l.fame, style: t.labelSmall),
                        ]),
                        for (final y in _years.reversed)
                          TableRow(children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('${y.year}'),
                            ),
                            Text(fmt.compact(y.streams)),
                            Text(fmt.compact(y.units)),
                            Text(fmt.percent(y.fame)),
                          ]),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Section(
              title: l.topSongs,
              child: _songs.isEmpty
                  ? EmptyNote(l.noReleasesYet)
                  : Column(children: [
                      for (final s in _songs.take(30))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.title),
                          subtitle: Text(fmt.songStatus(s)),
                          trailing: Text(fmt.compact(s.lifetimeStreams.total)),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SongDetailScreen(
                                      songId: s.id, state: career))),
                        ),
                    ]),
            ),
          ],
        ));
  }
}
