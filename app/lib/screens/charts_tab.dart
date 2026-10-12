import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../widgets/common.dart';
import 'album_detail_screen.dart';
import 'song_detail_screen.dart';

/// The latest published charts (docs/game-design.md §11.1).
class ChartsTab extends StatefulWidget {
  const ChartsTab({super.key});

  @override
  State<ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<ChartsTab> {
  int _chart = Charts.usSongs;
  List<int> _active = const [Charts.usSongs];
  ChartView? _view;
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
    final active = await career.read(Cmd.activeCharts());
    final chart = active.contains(_chart) ? _chart : Charts.usSongs;
    final view = await career.read(Cmd.chart(chart));
    if (!mounted) return;
    setState(() {
      _active = active;
      _chart = chart;
      _view = view;
    });
  }

  void _select(int chart) {
    setState(() => _chart = chart);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.career;
    final view = _view;
    final s = Theme.of(context).colorScheme;
    return Column(children: [
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            for (final id in _active)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(fmt.chartShort(id)),
                  selected: _chart == id,
                  onSelected: (_) => _select(id),
                ),
              ),
          ],
        ),
      ),
      if (view != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(children: [
            Expanded(
                child: Text(fmt.chart(view.def.id),
                    style: Theme.of(context).textTheme.titleMedium)),
            Text(fmt.week(view.week), style: TextStyle(color: s.outline)),
          ]),
        ),
      Expanded(
        child: view == null
            ? const Center(child: CircularProgressIndicator())
            : view.rows.isEmpty
                ? EmptyNote(l.chartEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: view.rows.length,
                    itemBuilder: (context, i) {
                      final r = view.rows[i];
                      final move = r.isNew
                          ? Text(l.chartNew,
                              style: const TextStyle(
                                  color: Colors.lightBlueAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11))
                          : r.lastPos == 0
                              ? Text(l.chartReentry,
                                  style: const TextStyle(fontSize: 11))
                              : r.lastPos > r.position
                                  ? const Icon(Icons.arrow_drop_up,
                                      color: Colors.greenAccent)
                                  : r.lastPos < r.position
                                      ? const Icon(Icons.arrow_drop_down,
                                          color: Colors.redAccent)
                                      : const Icon(Icons.remove, size: 14);
                      return ListTile(
                        tileColor: r.isPlayer ? s.primaryContainer : null,
                        leading: PosBadge(r.position, highlight: r.isPlayer),
                        title: Text(r.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(r.artistName,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(height: 22, child: move),
                            Text(l.chartPeakWeeks(r.peak, r.weeksOn),
                                style:
                                    TextStyle(fontSize: 11, color: s.outline)),
                          ],
                        ),
                        onTap: r.isPlayer
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        view.def.kind == ChartKind.songs
                                            ? SongDetailScreen(
                                                songId: r.entityId,
                                                state: career)
                                            : AlbumDetailScreen(
                                                albumId: r.entityId,
                                                state: career)))
                            : null,
                      );
                    },
                  ),
      ),
    ]);
  }
}
