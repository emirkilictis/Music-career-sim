import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';
import 'package:intl/intl.dart';

import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'album_detail_screen.dart';
import 'best_sellers_board.dart';
import 'game_shell.dart' show pushInCareer;
import 'song_detail_screen.dart';
import 'streamify/artist_page.dart';

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
  Charts.usRadio,
  Charts.usStreaming,
  Charts.usDigital,
  Charts.usAlbumSales,
  Charts.usStreamingAlbums,
];

/// The box-office board in the chart tabs (docs K77).
const _toursChart = -1;

/// The year-end charts in the chart tabs (docs K110).
const _yearEndChart = -2;

/// The all-time records in the chart tabs (docs K111).
const _recordsChart = -3;

/// The top artists in the chart tabs (docs K113).
const _artistsChart = -4;

/// The K-pop music show, for K-pop artists (docs K114).
const _musicShowChart = -5;

/// Best sellers (docs K141).
const _bestSellersChart = -6;

/// Saturday of a game week, for "Week of …" dates.
DateTime chartDate(int week) {
  final first = DateTime(GameTime.yearOf(week));
  final d = first.add(Duration(days: (GameTime.weekOfYear(week) - 1) * 7));
  return d.add(Duration(days: (DateTime.saturday - d.weekday) % 7));
}

class _ChartsTabState extends State<ChartsTab> {
  int _chart = Charts.usSongs;
  ChartView? _view;

  /// The row opened under itself (docs K89), by entity id.
  int? _openId;
  int _loadedRevision = -1;

  /// Box office: the year shown (null = all time), its rows, first year.
  int? _tourYear;
  List<TourRankView>? _tours;
  int _firstTourYear = 0;

  /// Year-end: the chart and year shown (null = the latest), its rows and
  /// the years there are.
  int _yearEndOf = Charts.usSongs;
  int? _yearEndYear;
  List<YearEndRow>? _yearEnd;
  List<int> _yearEndYears = const [];
  bool _yearEndMine = false;

  /// Top artists this week.
  List<ArtistChartRow>? _artists;

  /// The music show's recent weeks.
  List<MusicShowRow>? _show;

  /// Records: every board and the year they count from.
  Map<RecordKind, List<RecordEntry>>? _records;
  int _recordsSince = 0;

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
    if (_chart == _musicShowChart) {
      final rows = await career.read(Cmd.musicShow());
      if (mounted) setState(() => _show = rows);
      return;
    }
    if (_chart == _artistsChart) {
      final rows = await career.read(Cmd.artistChart());
      if (mounted) setState(() => _artists = rows);
      return;
    }
    if (_chart == _bestSellersChart) return;
    if (_chart == _recordsChart) {
      final (boards, since) = await career.read(Cmd.records());
      if (mounted) {
        setState(() {
          _records = boards;
          _recordsSince = since;
        });
      }
      return;
    }
    if (_chart == _yearEndChart) {
      final (rows, years) =
          await career.read(Cmd.yearEnd(_yearEndOf, _yearEndYear));
      if (mounted) {
        setState(() {
          _yearEnd = rows;
          _yearEndYears = years;
          _yearEndYear ??= years.isEmpty ? null : years.first;
        });
      }
      return;
    }
    if (_chart == _toursChart) {
      final (rows, first) = await career.read(Cmd.topTours(_tourYear));
      if (mounted) {
        setState(() {
          _tours = rows;
          _firstTourYear = first;
        });
      }
      return;
    }
    final view = await career.read(Cmd.chart(_chart));
    if (mounted) {
      setState(() {
        _view = view;
        _openId = null;
      });
    }
  }

  void _select(int chart) {
    setState(() {
      if (chart == _yearEndChart && _chart != _yearEndChart) _yearEnd = null;
      if (chart == _recordsChart && _chart != _recordsChart) _records = null;
      if (chart == _artistsChart && _chart != _artistsChart) _artists = null;
      if (chart == _musicShowChart && _chart != _musicShowChart) _show = null;
      if (chart == _toursChart && _chart != _toursChart) {
        _tourYear = context.careerRead.year;
        _tours = null;
      }
      _chart = chart;
    });
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
              Text(
                  (_chart == _toursChart
                          ? l.chartTopTours
                          : _chart == _yearEndChart
                              ? (_yearEndOf == YearEnd.summer
                                  ? l.songsOfSummer
                                  : '${l.chartYearEnd} · ${fmt.chartShort(_yearEndOf)}')
                              : _chart == _bestSellersChart
                                  ? l.chartBestSellers
                                  : _chart == _recordsChart
                                      ? l.chartRecords
                                      : _chart == _artistsChart
                                          ? l.chartTopArtists
                                          : _chart == _musicShowChart
                                              ? l.chartMusicShow
                                              : fmt.chart(_chart))
                      .toUpperCase(),
                  style: const TextStyle(
                      fontFamily: AppFonts.condensed,
                      fontWeight: FontWeight.w800,
                      fontSize: 38,
                      height: 1.05,
                      color: Colors.white)),
              Text(
                  (_chart == _toursChart
                          ? (_tourYear == null ? l.toursAllTime : '$_tourYear')
                          : _chart == _yearEndChart
                              ? (_yearEndYear == null ? '' : '$_yearEndYear')
                              : _chart == _bestSellersChart
                                  ? l.bestSellersSub
                                  : _chart == _recordsChart
                                      ? (_records == null
                                          ? ''
                                          : l.recordsSince(_recordsSince))
                                      : _chart == _artistsChart ||
                                              _chart == _musicShowChart
                                          ? l.weekOf(
                                              DateFormat.yMMMMd(l.localeName)
                                                  .format(chartDate(
                                                      context.career.week - 1)))
                                          : l.weekOf(date))
                      .toUpperCase(),
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
                      // The streaming and download charts start in their
                      // year (docs K166).
                      if (Charts.all[id].activeIn(context.career.week - 1))
                        _ChartTab(
                          label: fmt.chartShort(id),
                          selected: _chart == id,
                          onTap: () => _select(id),
                        ),
                    // K-pop artists get their music show (docs K114).
                    if (context.career.player.genre == MusicShow.genre)
                      _ChartTab(
                        label: l.chartMusicShow,
                        selected: _chart == _musicShowChart,
                        onTap: () => _select(_musicShowChart),
                      ),
                    _ChartTab(
                      label: l.chartArtists,
                      selected: _chart == _artistsChart,
                      onTap: () => _select(_artistsChart),
                    ),
                    _ChartTab(
                      label: l.chartYearEnd,
                      selected: _chart == _yearEndChart,
                      onTap: () => _select(_yearEndChart),
                    ),
                    _ChartTab(
                      label: l.chartBestSellers,
                      selected: _chart == _bestSellersChart,
                      onTap: () => _select(_bestSellersChart),
                    ),
                    _ChartTab(
                      label: l.chartRecords,
                      selected: _chart == _recordsChart,
                      onTap: () => _select(_recordsChart),
                    ),
                    _ChartTab(
                      label: l.chartShortTours,
                      selected: _chart == _toursChart,
                      onTap: () => _select(_toursChart),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_chart == _musicShowChart)
          Expanded(
            child: _MusicShowBoard(
              rows: _show,
              onOpen: (r) => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SongDetailScreen(
                          songId: r.songId, state: context.careerRead))),
            ),
          )
        else if (_chart == _artistsChart)
          Expanded(
            child: _ArtistsBoard(
              rows: _artists,
              onOpen: (r) =>
                  pushInCareer(context, ArtistPage(artistId: r.artistId)),
            ),
          )
        else if (_chart == _bestSellersChart)
          const Expanded(child: BestSellersBoard())
        else if (_chart == _recordsChart)
          Expanded(
            child: _RecordsBoard(
              boards: _records,
              onOpen: (kind, r) {
                final career = context.careerRead;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => kind.isAlbum
                            ? AlbumDetailScreen(
                                albumId: r.entityId, state: career)
                            : SongDetailScreen(
                                songId: r.entityId, state: career)));
              },
            ),
          )
        else if (_chart == _yearEndChart)
          Expanded(
            child: _YearEndBoard(
              rows: _yearEnd,
              chart: _yearEndOf,
              year: _yearEndYear,
              years: _yearEndYears,
              mineOnly: _yearEndMine,
              onMine: (v) => setState(() => _yearEndMine = v),
              onChart: (c) {
                setState(() {
                  _yearEndOf = c;
                  _yearEnd = null;
                });
                _load();
              },
              onYear: (y) {
                setState(() {
                  _yearEndYear = y;
                  _yearEnd = null;
                });
                _load();
              },
              onOpen: (r) {
                final career = context.careerRead;
                final songs = Charts.all[_yearEndOf].kind == ChartKind.songs;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => songs
                            ? SongDetailScreen(
                                songId: r.entityId, state: career)
                            : AlbumDetailScreen(
                                albumId: r.entityId, state: career)));
              },
            ),
          )
        else if (_chart == _toursChart)
          Expanded(
            child: _ToursBoard(
              rows: _tours,
              year: _tourYear,
              years: [
                for (var y = context.career.year; y >= _firstTourYear; y--) y
              ],
              onYear: (y) {
                setState(() {
                  _tourYear = y;
                  _tours = null;
                });
                _load();
              },
            ),
          )
        else ...[
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
                        itemBuilder: (context, i) {
                          final r = view.rows[i];
                          final albums = view.def.kind == ChartKind.albums;
                          final open = _openId == r.entityId;
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ChartLine(
                                  row: r,
                                  albums: albums,
                                  open: open,
                                  onTap: () => setState(
                                      () => _openId = open ? null : r.entityId),
                                ),
                                if (open)
                                  _ChartDetails(
                                      row: r,
                                      albums: albums,
                                      onOpen: () => _open(r)),
                              ]);
                        },
                      ),
          ),
        ],
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

/// Top-grossing tours, magazine style: rank, artist, tour, gross.
/// The K-pop music show (docs K114): the winners, newest first.
class _MusicShowBoard extends StatelessWidget {
  const _MusicShowBoard({required this.rows, required this.onOpen});
  final List<MusicShowRow>? rows;
  final ValueChanged<MusicShowRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final list = rows;
    if (list == null) {
      return const Center(
          child: CircularProgressIndicator(color: PaperColors.ink));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(l.musicShowHint,
            style: const TextStyle(fontSize: 13, color: PaperColors.muted)),
      ),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.musicShowEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PaperColors.muted)),
        ),
      for (final r in list)
        InkWell(
          onTap: () => onOpen(r),
          child: Container(
            color: r.isPlayer ? const Color(0xFFE6EAFF) : PaperColors.card,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            margin: const EdgeInsets.only(bottom: 1),
            child: Row(children: [
              CoverArt(
                  seed: songCoverSeed(r.songId, r.albumId),
                  size: 48,
                  radius: 4,
                  songId: r.songId,
                  albumId: r.albumId),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmt.week(r.week),
                          style: const TextStyle(
                              fontFamily: AppFonts.condensed,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              letterSpacing: 0.6,
                              color: PaperColors.muted)),
                      Text(r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: PaperColors.ink)),
                      Text(r.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: PaperColors.ink)),
                      if (r.runnerUpTitle.isNotEmpty)
                        Text(
                            l.musicShowVs(r.runnerUpTitle, r.runnerUpArtist,
                                r.runnerUpScore),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: PaperColors.muted)),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${r.score}',
                    style: const TextStyle(
                        fontFamily: AppFonts.condensed,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: PaperColors.ink)),
                if (r.tripleCrown)
                  _Badge(l.tripleCrown, const Color(0xFFFFE9A8),
                      const Color(0xFF6B4E00))
                else
                  Text(l.musicShowWins(r.wins),
                      style: const TextStyle(
                          fontSize: 11.5, color: PaperColors.muted)),
              ]),
            ]),
          ),
        ),
    ]);
  }
}

/// The week's top artists (docs K113): rank, movement, weekly streams.
class _ArtistsBoard extends StatelessWidget {
  const _ArtistsBoard({required this.rows, required this.onOpen});
  final List<ArtistChartRow>? rows;
  final ValueChanged<ArtistChartRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final list = rows;
    if (list == null) {
      return const Center(
          child: CircularProgressIndicator(color: PaperColors.ink));
    }
    if (list.isEmpty) {
      return Center(
          child: Text(l.chartEmpty,
              style: const TextStyle(color: PaperColors.muted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: list.length,
      separatorBuilder: (_, __) =>
          const Divider(color: PaperColors.line, height: 1, indent: 16),
      itemBuilder: (context, i) {
        final r = list[i];
        final top = r.rank == 1;
        final gain = r.lastRank > 0 ? r.lastRank - r.rank : 0;
        return InkWell(
          onTap: () => onOpen(r),
          child: Container(
            color: r.isPlayer ? const Color(0xFFE6EAFF) : PaperColors.card,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              SizedBox(
                width: 54,
                child: Column(children: [
                  Text('${r.rank}',
                      style: TextStyle(
                          fontFamily: AppFonts.condensed,
                          fontWeight: FontWeight.w800,
                          fontSize: top ? 40 : 30,
                          height: 1,
                          color: PaperColors.ink)),
                  SizedBox(
                    height: 20,
                    child: Center(
                      child: r.lastRank == 0
                          ? _Badge(l.chartNew, PaperColors.ink, Colors.white)
                          : gain > 0
                              ? const Icon(Icons.arrow_drop_up_rounded,
                                  color: PaperColors.up, size: 24)
                              : gain < 0
                                  ? const Icon(Icons.arrow_drop_down_rounded,
                                      color: PaperColors.down, size: 24)
                                  : const Icon(Icons.remove_rounded,
                                      color: PaperColors.muted, size: 14),
                    ),
                  ),
                ]),
              ),
              ArtistAvatar(
                  name: r.name, seed: r.artistId, artistId: r.artistId),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: top ? 18 : 15.5,
                              color: PaperColors.ink)),
                      Text(l.artistChartLine(fmt.compact(r.weekStreams)),
                          style: const TextStyle(
                              fontSize: 12.5, color: PaperColors.muted)),
                    ]),
              ),
              if (r.isPlayer)
                _Badge(l.you, AppColors.lilac, const Color(0xFF241A45)),
            ]),
          ),
        );
      },
    );
  }
}

/// All-time records (docs K111): each record's top 5, the holder first.
class _RecordsBoard extends StatelessWidget {
  const _RecordsBoard({required this.boards, required this.onOpen});
  final Map<RecordKind, List<RecordEntry>>? boards;
  final void Function(RecordKind, RecordEntry) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final all = boards;
    if (all == null) {
      return const Center(
          child: CircularProgressIndicator(color: PaperColors.ink));
    }
    if (all.values.every((b) => b.isEmpty)) {
      return Center(
          child: Text(l.recordsEmpty,
              style: const TextStyle(color: PaperColors.muted)));
    }
    String value(RecordKind k, double v) => switch (k) {
          RecordKind.weeksAtNo1Song ||
          RecordKind.weeksAtNo1Album ||
          RecordKind.weeksOnChart =>
            l.recordWeeks(v.round()),
          RecordKind.mostNo1s => l.recordNo1s(v.round()),
          _ => fmt.compact(v),
        };
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      for (final k in RecordKind.values)
        if (all[k]!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Text(fmt.recordName(k).toUpperCase(),
                style: const TextStyle(
                    fontFamily: AppFonts.condensed,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1,
                    color: PaperColors.ink)),
          ),
          for (final r in all[k]!.take(5))
            InkWell(
              onTap: k.isArtist ? null : () => onOpen(k, r),
              child: Container(
                color: r.isPlayer ? const Color(0xFFE6EAFF) : PaperColors.card,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  SizedBox(
                    width: 36,
                    child: Text('${r.rank}',
                        style: TextStyle(
                            fontFamily: AppFonts.condensed,
                            fontWeight: FontWeight.w800,
                            fontSize: r.rank == 1 ? 28 : 22,
                            height: 1,
                            color: PaperColors.ink)),
                  ),
                  if (k.isArtist)
                    ArtistAvatar(name: r.artistName, seed: r.entityId, size: 40)
                  else
                    CoverArt(
                        seed: k.isAlbum
                            ? albumCoverSeed(r.entityId)
                            : songCoverSeed(r.entityId, r.albumId),
                        size: 40,
                        radius: 4,
                        songId: k.isAlbum ? null : r.entityId,
                        albumId: k.isAlbum ? r.entityId : r.albumId),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.isArtist ? r.artistName : r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: PaperColors.ink)),
                          if (!k.isArtist)
                            Text(r.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, color: PaperColors.muted)),
                        ]),
                  ),
                  Text(value(k, r.value),
                      style: const TextStyle(
                          fontFamily: AppFonts.condensed,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: PaperColors.ink)),
                ]),
              ),
            ),
        ],
    ]);
  }
}

/// Year-end charts (docs K110): year chips, the chart, ranked rows.
class _YearEndBoard extends StatelessWidget {
  const _YearEndBoard(
      {required this.rows,
      required this.chart,
      required this.year,
      required this.years,
      required this.onChart,
      required this.onYear,
      required this.onOpen,
      required this.mineOnly,
      required this.onMine});
  final List<YearEndRow>? rows;
  final int chart;

  /// Only the player's entries (F74).
  final bool mineOnly;
  final ValueChanged<bool> onMine;
  final int? year;
  final List<int> years;
  final ValueChanged<int> onChart;
  final ValueChanged<int> onYear;
  final ValueChanged<YearEndRow> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final list = mineOnly ? rows?.where((r) => r.isPlayer).toList() : rows;
    final albums =
        chart != YearEnd.summer && Charts.all[chart].kind == ChartKind.albums;
    return Column(children: [
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(l.yearEndMine),
                selected: mineOnly,
                onSelected: onMine,
              ),
            ),
            for (final c in [...YearEnd.charts, YearEnd.summer])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c == YearEnd.summer
                      ? l.songsOfSummer
                      : fmt.chartShort(c)),
                  selected: chart == c,
                  onSelected: (_) => onChart(c),
                ),
              ),
          ],
        ),
      ),
      if (years.isNotEmpty)
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            children: [
              for (final y in years)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('$y'),
                    selected: year == y,
                    onSelected: (_) => onYear(y),
                  ),
                ),
            ],
          ),
        ),
      Expanded(
        child: list == null
            ? const Center(
                child: CircularProgressIndicator(color: PaperColors.ink))
            : list.isEmpty
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.yearEndEmpty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: PaperColors.muted)),
                  ))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: PaperColors.line, height: 1, indent: 16),
                    itemBuilder: (context, i) {
                      final r = list[i];
                      final top = r.rank == 1;
                      return InkWell(
                        onTap: () => onOpen(r),
                        child: Container(
                          color: r.isPlayer
                              ? const Color(0xFFE6EAFF)
                              : PaperColors.card,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Row(children: [
                            SizedBox(
                              width: 50,
                              child: Text('${r.rank}',
                                  style: TextStyle(
                                      fontFamily: AppFonts.condensed,
                                      fontWeight: FontWeight.w800,
                                      fontSize: top ? 40 : 30,
                                      height: 1,
                                      color: PaperColors.ink)),
                            ),
                            CoverArt(
                                seed: albums
                                    ? albumCoverSeed(r.entityId)
                                    : songCoverSeed(r.entityId, r.albumId),
                                size: 48,
                                radius: 4,
                                songId: albums ? null : r.entityId,
                                albumId: albums ? r.entityId : r.albumId),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: top ? 17 : 15,
                                            color: PaperColors.ink)),
                                    Text(r.artistName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: PaperColors.ink)),
                                    Text(
                                        albums
                                            ? '${l.yearEndSold(fmt.compact(r.points.toDouble()))} · ${l.yearEndLine(r.peak, r.weeksOn)}'
                                            : l.yearEndLine(r.peak, r.weeksOn),
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: PaperColors.muted)),
                                  ]),
                            ),
                            if (r.isPlayer)
                              _Badge(l.you, AppColors.lilac,
                                  const Color(0xFF241A45)),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}

class _ToursBoard extends StatelessWidget {
  const _ToursBoard(
      {required this.rows,
      required this.year,
      required this.years,
      required this.onYear});
  final List<TourRankView>? rows;
  final int? year;
  final List<int> years;
  final ValueChanged<int?> onYear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final list = rows;
    return Column(children: [
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            for (final y in [...years.take(12), null])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(y == null ? l.toursAllTime : '$y'),
                  selected: year == y,
                  onSelected: (_) => onYear(y),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: list == null
            ? const Center(
                child: CircularProgressIndicator(color: PaperColors.ink))
            : list.isEmpty
                ? Center(
                    child: Text(l.toursEmpty,
                        style: const TextStyle(color: PaperColors.muted)))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: PaperColors.line, height: 1, indent: 16),
                    itemBuilder: (context, i) {
                      final r = list[i];
                      final top = r.rank == 1;
                      return Container(
                        color: r.isPlayer
                            ? const Color(0xFFE6EAFF)
                            : PaperColors.card,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(children: [
                          SizedBox(
                            width: 50,
                            child: Text('${r.rank}',
                                style: TextStyle(
                                    fontFamily: AppFonts.condensed,
                                    fontWeight: FontWeight.w800,
                                    fontSize: top ? 40 : 30,
                                    height: 1,
                                    color: PaperColors.ink)),
                          ),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.artistName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: top ? 18 : 15.5,
                                          color: PaperColors.ink)),
                                  Text(
                                      r.tourName.isEmpty
                                          ? l.tourSection
                                          : r.tourName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: PaperColors.ink)),
                                  Text(
                                      l.toursLine(
                                          fmt.compact(r.tickets), r.shows),
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          color: PaperColors.muted)),
                                  if (r.isPlayer || r.onGoing) ...[
                                    const SizedBox(height: 4),
                                    Wrap(spacing: 6, children: [
                                      if (r.isPlayer)
                                        _Badge(l.you, AppColors.lilac,
                                            const Color(0xFF241A45)),
                                      if (r.onGoing)
                                        _Badge(
                                            l.toursOnRoad,
                                            const Color(0xFFDDF3E6),
                                            PaperColors.up),
                                    ]),
                                  ],
                                ]),
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(fmt.money(r.grossCents.round()),
                                    style: const TextStyle(
                                        fontFamily: AppFonts.condensed,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        color: PaperColors.ink)),
                                Text(l.toursGross,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: PaperColors.muted)),
                              ]),
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }
}

/// One chart position, magazine style.
class _ChartLine extends StatelessWidget {
  const _ChartLine(
      {required this.row,
      required this.albums,
      required this.onTap,
      this.open = false});
  final ChartRow row;
  final bool albums;
  final VoidCallback onTap;

  /// Its details are showing underneath.
  final bool open;

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
      color: r.isOurs ? const Color(0xFFE6EAFF) : PaperColors.card,
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
                  Text(
                      r.featuring.isEmpty
                          ? r.artistName
                          : l.chartFeat(r.artistName, r.featuring),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                          color: PaperColors.muted)),
                  if (r.isOurs || gain >= 10) ...[
                    const SizedBox(height: 5),
                    Wrap(spacing: 6, children: [
                      if (r.isPlayer)
                        _Badge(l.you, AppColors.lilac, const Color(0xFF241A45)),
                      // On it under another name (docs K158).
                      if (r.credit != ChartCredit.none)
                        _Badge(
                            switch (r.credit) {
                              ChartCredit.member => l.creditMember,
                              ChartCredit.imprint => l.creditImprint,
                              _ => l.creditGuest,
                            },
                            AppColors.lilac,
                            const Color(0xFF241A45)),
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
            Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18, color: PaperColors.muted),
          ]),
        ),
      ),
    );
  }
}

/// The week of a chart entry, opened under its row (docs K89): what made
/// its points in this chart's market, and a way to its full page.
class _ChartDetails extends StatelessWidget {
  const _ChartDetails(
      {required this.row, required this.albums, required this.onOpen});
  final ChartRow row;
  final bool albums;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final r = row;
    final stats = <(String, double)>[
      if (albums) ...[
        (l.chartStatUnits, r.weekValue),
        (l.chartStatPure, r.pure),
        (l.chartStatSea, r.sea),
        (l.chartStatTea, r.tea),
      ] else ...[
        (l.chartStatPoints, r.points),
        (l.chartStatStreams, r.streams),
        (l.chartStatSales, r.sales),
        (l.chartStatRadio, r.radio),
      ],
    ].where((x) => x.$2 >= 1).toList();
    return Container(
      color: const Color(0xFFF2EFE8),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.chartThisWeek.toUpperCase(),
            style: const TextStyle(
                fontFamily: AppFonts.condensed,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.8,
                color: PaperColors.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 20, runSpacing: 8, children: [
          for (final (label, v) in stats)
            Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmt.compact(v),
                      style: const TextStyle(
                          fontFamily: AppFonts.condensed,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          height: 1.1,
                          color: PaperColors.ink)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: PaperColors.muted)),
                ]),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: PaperColors.ink),
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(albums ? l.chartOpenAlbum : l.chartOpenSong),
          ),
        ),
      ]),
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
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(AppShape.r(3))),
        child: Text(text,
            style: TextStyle(
                fontFamily: AppFonts.condensed,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                letterSpacing: 0.6,
                color: fg)),
      );
}
