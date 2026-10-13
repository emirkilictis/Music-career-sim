import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';
import 'package:intl/intl.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'album_detail_screen.dart';
import 'song_detail_screen.dart';

/// The charts as a music magazine prints them: paper white, big black
/// ranks, last week / peak / weeks columns (docs/game-design.md §11.1).
class ChartsTab extends StatefulWidget {
  const ChartsTab({super.key});

  @override
  State<ChartsTab> createState() => _ChartsTabState();
}

const _magazineCharts = [
  Charts.usSongs,
  Charts.usAlbums,
  Charts.globalSongs,
  Charts.globalAlbums,
  Charts.ukSongs,
  Charts.ukAlbums,
];

/// Saturday of a game week, for "Week of …" dates.
DateTime chartDate(int week) {
  final first = DateTime(GameTime.yearOf(week));
  final d = first.add(Duration(days: (GameTime.weekOfYear(week) - 1) * 7));
  return d.add(Duration(days: (DateTime.saturday - d.weekday) % 7));
}

class _ChartsTabState extends State<ChartsTab> {
  int _chart = Charts.usSongs;
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
    final view = await career.read(Cmd.chart(_chart));
    if (mounted) setState(() => _view = view);
  }

  void _select(int chart) {
    setState(() => _chart = chart);
    _load();
  }

  void _open(ChartRow r) {
    final career = context.careerRead;
    final songs = _view!.def.kind == ChartKind.songs;
    // Any entry opens its stats, rivals' too (docs K47).
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => songs
                ? SongDetailScreen(songId: r.entityId, state: career)
                : AlbumDetailScreen(albumId: r.entityId, state: career)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final view = _view;
    final date = view == null
        ? ''
        : DateFormat.yMMMMd(l.localeName).format(chartDate(view.week));
    return ColoredBox(
      color: PaperColors.bg,
      child: Column(children: [
        // Masthead.
        Container(
          color: PaperColors.ink,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.chartsMasthead,
                  style: const TextStyle(
                      fontFamily: AppFonts.condensed,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 3,
                      color: Colors.white70)),
              const SizedBox(height: 4),
              Text(fmt.chart(_chart).toUpperCase(),
                  style: const TextStyle(
                      fontFamily: AppFonts.condensed,
                      fontWeight: FontWeight.w800,
                      fontSize: 38,
                      height: 1.05,
                      color: Colors.white)),
              Text(l.weekOf(date).toUpperCase(),
                  style: const TextStyle(
                      fontFamily: AppFonts.condensed,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 1,
                      color: Colors.white60)),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final id in _magazineCharts)
                      _ChartTab(
                        label: fmt.chartShort(id),
                        selected: _chart == id,
                        onTap: () => _select(id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Column headers.
        Container(
          color: PaperColors.bg,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            const SizedBox(width: 54 + 60),
            const Spacer(),
            for (final h in [l.colLastWeek, l.colPeak, l.colWeeks])
              SizedBox(
                width: 38,
                child: Text(h,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: AppFonts.condensed,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.6,
                        color: PaperColors.muted)),
              ),
          ]),
        ),
        Expanded(
          child: view == null
              ? const Center(
                  child: CircularProgressIndicator(color: PaperColors.ink))
              : view.rows.isEmpty
                  ? Center(
                      child: Text(l.chartEmpty,
                          style: const TextStyle(color: PaperColors.muted)))
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: view.rows.length,
                      separatorBuilder: (_, __) => const Divider(
                          color: PaperColors.line, height: 1, indent: 16),
                      itemBuilder: (context, i) => _ChartLine(
                        row: view.rows[i],
                        albums: view.def.kind == ChartKind.albums,
                        onTap: () => _open(view.rows[i]),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _ChartTab extends StatelessWidget {
  const _ChartTab(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 3),
            ),
          ),
          child: Text(label.toUpperCase(),
              style: TextStyle(
                  fontFamily: AppFonts.condensed,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.8,
                  color: selected ? Colors.white : Colors.white54)),
        ),
      );
}

/// One chart position, magazine style.
class _ChartLine extends StatelessWidget {
  const _ChartLine(
      {required this.row, required this.albums, required this.onTap});
  final ChartRow row;
  final bool albums;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = row;
    final top = r.position == 1;
    final gain = r.lastPos > 0 ? r.lastPos - r.position : 0;
    final cover = albums
        ? albumCoverSeed(r.entityId)
        : songCoverSeed(r.entityId, r.albumId);
    Widget movement() {
      if (r.isNew) return _Badge(l.chartNew, PaperColors.ink, Colors.white);
      if (r.isReentry) {
        return _Badge(l.chartReentry, PaperColors.line, PaperColors.ink);
      }
      if (gain > 0) {
        return const Icon(Icons.arrow_drop_up_rounded,
            color: PaperColors.up, size: 26);
      }
      if (gain < 0) {
        return const Icon(Icons.arrow_drop_down_rounded,
            color: PaperColors.down, size: 26);
      }
      return const Icon(Icons.remove_rounded,
          color: PaperColors.muted, size: 16);
    }

    TextStyle num = const TextStyle(
        fontFamily: AppFonts.condensed,
        fontWeight: FontWeight.w700,
        fontSize: 17,
        color: PaperColors.ink);
    return Material(
      color: r.isPlayer ? const Color(0xFFEDE7FF) : PaperColors.card,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: top
              ? const BoxDecoration(
                  border:
                      Border(left: BorderSide(color: AppColors.gold, width: 5)))
              : null,
          padding: EdgeInsets.fromLTRB(
              top ? 11 : 16, top ? 16 : 10, 16, top ? 16 : 10),
          child: Row(children: [
            SizedBox(
              width: 54,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${r.position}',
                    style: TextStyle(
                        fontFamily: AppFonts.condensed,
                        fontWeight: FontWeight.w800,
                        fontSize: top ? 46 : 32,
                        height: 1,
                        color: PaperColors.ink)),
                const SizedBox(height: 2),
                SizedBox(height: 22, child: Center(child: movement())),
              ]),
            ),
            const SizedBox(width: 6),
            CoverArt(
                seed: cover,
                size: top ? 76 : 52,
                radius: 4,
                songId: albums ? null : r.entityId,
                albumId: albums ? r.entityId : r.albumId),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: top ? 19 : 15.5,
                          height: 1.15,
                          color: PaperColors.ink)),
                  const SizedBox(height: 2),
                  Text(r.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                          color: PaperColors.muted)),
                  if (r.isPlayer || gain >= 10) ...[
                    const SizedBox(height: 5),
                    Wrap(spacing: 6, children: [
                      if (r.isPlayer)
                        _Badge(l.you, AppColors.lilac, const Color(0xFF241A45)),
                      if (gain >= 10)
                        _Badge(l.chartGainer, const Color(0xFFDDF3E6),
                            PaperColors.up),
                    ]),
                  ],
                ],
              ),
            ),
            for (final v in [r.lastPos, r.peak, r.weeksOn])
              SizedBox(
                width: 38,
                child: Text(v > 0 ? '$v' : '–',
                    textAlign: TextAlign.center, style: num),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.bg, this.fg);
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
        child: Text(text,
            style: TextStyle(
                fontFamily: AppFonts.condensed,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                letterSpacing: 0.6,
                color: fg)),
      );
}
