import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:game/game.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/profit_card.dart';
import 'album_detail_screen.dart';
import 'song_detail_screen.dart';

/// The career's releases at a glance (docs K86): a sales bar chart made of
/// the covers, shareable as an image, and every album and single with its
/// peak, first week, total and certification.
class DiscographyScreen extends StatefulWidget {
  const DiscographyScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<DiscographyScreen> createState() => _DiscographyScreenState();
}

/// One bar / row: an album or a single.
class _Release {
  _Release.album(AlbumView a)
      : id = a.id,
        title = a.title,
        week = a.releaseWeek,
        isAlbum = true,
        subtitle = (a.type, a.trackIds.length),
        units = a.lifetimeUnits.total,
        usUnits = a.usLifetimeUnits,
        firstWeek = a.firstWeekUnits,
        charts = a.charts,
        songId = null,
        albumId = a.id;

  _Release.single(SongView s)
      : id = s.id,
        title = s.title,
        week = s.singleWeek >= 0 ? s.singleWeek : s.releasedWeek,
        isAlbum = false,
        subtitle = null,
        units = s.singleUnits,
        usUnits = s.usSingleUnits,
        firstWeek = 0,
        charts = s.charts,
        songId = s.id,
        albumId = s.coverAlbumId;

  final int id;
  final String title;
  final int week;
  final bool isAlbum;
  final (AlbumType, int)? subtitle;
  final double units, usUnits, firstWeek;
  final List<ChartRecord> charts;
  final int? songId;
  final int albumId;

  int get coverSeed =>
      isAlbum ? albumCoverSeed(id) : songCoverSeed(id, albumId);

  /// The US chart record, else the best other one.
  ChartRecord? get bestChart {
    final us = isAlbum ? Charts.usAlbums : Charts.usSongs;
    final onUs = charts.where((c) => c.chartId == us && c.peak > 0);
    if (onUs.isNotEmpty) return onUs.first;
    final any = charts.where((c) => c.peak > 0).toList()
      ..sort((a, b) => a.peak.compareTo(b.peak));
    return any.firstOrNull;
  }
}

class _DiscographyScreenState extends State<DiscographyScreen> {
  List<_Release>? _albums, _singles;
  bool _showSingles = false;
  final _card = GlobalKey();
  final _shareButton = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final albums = await widget.state.read(Cmd.albums());
    final songs = await widget.state.read(Cmd.songs());
    if (!mounted) return;
    final week = widget.state.week;
    setState(() {
      _albums = [
        for (final a in albums)
          if (a.releaseWeek <= week) _Release.album(a)
      ]..sort((a, b) => a.week.compareTo(b.week));
      _singles = [
        for (final s in songs)
          if (s.isSingle && !s.inVault) _Release.single(s)
      ]..sort((a, b) => a.week.compareTo(b.week));
    });
  }

  List<_Release> get _items => (_showSingles ? _singles : _albums) ?? const [];

  /// The bars: every album; for singles the 15 biggest, in release order.
  List<_Release> get _bars {
    if (!_showSingles) return _items;
    final top = [..._items]..sort((a, b) => b.units.compareTo(a.units));
    return top.take(15).toList()..sort((a, b) => a.week.compareTo(b.week));
  }

  Future<void> _share() async {
    final l = context.l10n;
    final box = _shareButton.currentContext?.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final boundary =
        _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/career_sales_${DateTime.now().millisecondsSinceEpoch}.png')
      ..writeAsBytesSync(png!.buffer.asUint8List());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      text: l.salesChartShareText(widget.state.player.name, l.appTitle),
      sharePositionOrigin: origin,
    ));
  }

  void _open(_Release r) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => r.isAlbum
              ? AlbumDetailScreen(albumId: r.id, state: widget.state)
              : SongDetailScreen(songId: r.id, state: widget.state)));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = widget.state;
    final p = career.player;
    final items = _items;
    final bars = _bars;
    // Bars shrink to fit the screen (down to 40 wide); a longer career
    // scrolls sideways, and the shared image keeps every bar.
    final screen = MediaQuery.sizeOf(context).width - 32;
    final fit = bars.isEmpty
        ? _SalesChartCard.maxBar
        : (screen - 36) / bars.length - _SalesChartCard.barGap;
    final barWidth =
        fit.clamp(_SalesChartCard.minBar, _SalesChartCard.maxBar).toDouble();
    final chartWidth = math.max(
        screen, bars.length * (barWidth + _SalesChartCard.barGap) + 36);
    return Scaffold(
      appBar: AppBar(title: Text(l.discography)),
      body: _albums == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l.discoAlbums)),
                    ButtonSegment(value: true, label: Text(l.singles)),
                  ],
                  selected: {_showSingles},
                  onSelectionChanged: (v) =>
                      setState(() => _showSingles = v.first),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.discoEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                else ...[
                  // Wide careers scroll sideways; the image keeps every bar.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: RepaintBoundary(
                      key: _card,
                      child: _SalesChartCard(
                        artistId: p.id,
                        artistName: p.name,
                        singles: _showSingles,
                        bars: bars,
                        total: items.fold(0.0, (t, r) => t + r.units),
                        mode: fmt.difficulty(career.difficulty),
                        years: _years(bars),
                        width: chartWidth,
                        barWidth: barWidth,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: _shareButton,
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(l.shareSalesChart),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final r in items.reversed) ...[
                    _ReleaseRow(release: r, onTap: () => _open(r)),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
    );
  }

  String _years(List<_Release> bars) {
    if (bars.isEmpty) return '';
    final a = GameTime.yearOf(bars.first.week);
    final b = GameTime.yearOf(bars.last.week);
    return a == b ? '$a' : '$a–$b';
  }
}

/// The shareable chart: the artist, the career total, and one bar per
/// release filled with its cover (light, like a printed chart, whatever the
/// app's theme).
class _SalesChartCard extends StatelessWidget {
  const _SalesChartCard({
    required this.artistId,
    required this.artistName,
    required this.singles,
    required this.bars,
    required this.total,
    required this.mode,
    required this.years,
    required this.width,
    required this.barWidth,
  });
  final int artistId;
  final String artistName;
  final bool singles;
  final List<_Release> bars;
  final double total;
  final String mode, years;
  final double width, barWidth;

  static const _ink = Color(0xFF15131C);
  static const _muted = Color(0xFF5C5868);
  static const _chartHeight = 300.0;

  /// A bar's width range and the gap between bars.
  static const minBar = 40.0, maxBar = 64.0, barGap = 10.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final top = bars.fold(0.0, (m, r) => math.max(m, r.units));
    TextStyle condensed(double size) => TextStyle(
        fontFamily: AppFonts.condensed,
        fontWeight: FontWeight.w800,
        fontSize: size,
        height: 1.05,
        color: _ink);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppShape.r(18)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF2F1F5), Color(0xFFD9D7E0)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ArtistAvatar(
              name: artistName, seed: artistId, size: 64, artistId: artistId),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  (singles
                          ? l.salesChartSinglesTitle(artistName)
                          : l.salesChartTitle(artistName))
                      .toUpperCase(),
                  style: condensed(21)),
              const SizedBox(height: 2),
              Text(l.salesChartTotal(fmt.compact(total)).toUpperCase(),
                  style: condensed(21)),
              const SizedBox(height: 4),
              Text('$years · $mode',
                  style: const TextStyle(
                      color: _muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          height: _chartHeight + 46,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final r in bars)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: barGap / 2),
                  child: SizedBox(
                    width: barWidth,
                    child: _Bar(
                      release: r,
                      height: top <= 0
                          ? 8
                          : math.max(8, _chartHeight * r.units / top),
                      value: fmt.compact(r.units),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.graphic_eq_rounded, size: 14, color: _muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(l.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(l.salesChartUnitsNote,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(color: _muted, fontSize: 11)),
          ),
        ]),
      ]),
    );
  }
}

/// A bar: value and title on top, the cover filling the bar.
class _Bar extends StatelessWidget {
  const _Bar(
      {required this.release, required this.height, required this.value});
  final _Release release;
  final double height;
  final String value;

  @override
  Widget build(BuildContext context) {
    final r = release;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            maxLines: 1,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _SalesChartCard._ink)),
        Text(r.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _SalesChartCard._ink)),
        const SizedBox(height: 4),
        SizedBox(
          height: height,
          width: double.infinity,
          child: ClipRRect(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppShape.r(4))),
            child: LayoutBuilder(builder: (context, c) {
              // The cover, as big as the bar needs and centred.
              final side = math.max(c.maxWidth, c.maxHeight);
              return OverflowBox(
                maxWidth: side,
                maxHeight: side,
                child: CoverArt(
                  seed: r.coverSeed,
                  size: side,
                  radius: 0,
                  songId: r.songId,
                  albumId: r.isAlbum ? r.id : r.albumId,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// One release in the list: cover, title, what it is, its chart peak, first
/// week, total and certification.
class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.release, required this.onTap});
  final _Release release;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final r = release;
    final chart = r.bestChart;
    final us = r.isAlbum ? Charts.usAlbums : Charts.usSongs;
    final peak = chart == null
        ? l.discoNoChart
        : chart.chartId != us
            ? l.discoOtherPeak(fmt.chart(chart.chartId), chart.peak)
            : chart.peak == 1
                ? l.discoNo1(chart.weeksAtNo1)
                : l.discoPeak(chart.peak);
    final kind = r.subtitle == null
        ? l.typeSingle
        : '${fmt.albumType(r.subtitle!.$1)} · ${l.discoTracks(r.subtitle!.$2)}';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppShape.r(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.r(18)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CoverArt(
                seed: r.coverSeed,
                size: 68,
                songId: r.songId,
                albumId: r.isAlbum ? r.id : r.albumId),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${GameTime.yearOf(r.week)} · $kind',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(peak,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: chart?.peak == 1 && chart?.chartId == us
                                ? AppColors.gold
                                : AppColors.text)),
                    Text(
                        [
                          if (r.isAlbum && r.firstWeek >= 1)
                            l.discoFirstWeek(fmt.compact(r.firstWeek)),
                          l.discoTotal(fmt.compact(r.units)),
                        ].join(' · '),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 6),
                    CertificationTag(units: r.usUnits),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}
