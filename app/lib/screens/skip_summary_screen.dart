import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/event_lines.dart';
import '../core/format.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/bar_chart.dart';
import '../widgets/common.dart';
import '../widgets/event_icon.dart';
import 'album_detail_screen.dart';
import 'song_detail_screen.dart';

/// What happened over a skip (docs K203): the skip never stops, so this
/// page tells the whole stretch: the numbers, week by week, the most
/// played songs, what came out and every piece of news.
class SkipSummaryScreen extends StatelessWidget {
  const SkipSummaryScreen(
      {super.key,
      required this.report,
      required this.lines,
      required this.state});
  final YearReport report;

  /// The player's news over the skip.
  final List<EventLine> lines;
  final CareerState state;

  /// Bars for the week-by-week chart: weekly, or by four weeks once there
  /// are too many weeks for one row.
  static List<(int, double)> buckets(List<double> weekly, int fromWeek) {
    final size = weekly.length > 13 ? 4 : 1;
    return [
      for (var i = 0; i < weekly.length; i += size)
        (
          fromWeek + i,
          weekly
              .sublist(i, (i + size).clamp(0, weekly.length))
              .fold(0.0, (t, x) => t + x)
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final r = report;
    final endWeek = r.fromWeek + r.weeks - 1;
    final streaming =
        SalesEra.of(GameTime.yearOf(endWeek)) == SalesEra.streaming;
    final weekly = streaming ? r.weeklyStreams : r.weeklySales;
    final bars = buckets(weekly, r.fromWeek);
    final monthly = weekly.length > 13;
    final major = [
      for (final x in lines)
        if (x.event.isMajor) x
    ];
    final rest = [
      for (final x in lines)
        if (!x.event.isMajor) x
    ];
    void open(Widget page) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scope<CareerState>(value: state, child: page)));

    return Scaffold(
      appBar: AppBar(
        title: Text(r.isYear
            ? l.yearSummaryTitle(GameTime.yearOf(r.fromWeek))
            : l.weeksPlayed(r.weeks)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
              l.summaryPeriod(
                  fmt.monthYear(r.fromWeek), fmt.monthYear(endWeek)),
              style: TextStyle(
                  color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          StatGrid(tiles: [
            streaming
                ? StatTile(
                    label: l.streams, value: fmt.compact(r.streamsGained))
                : StatTile(
                    label: l.singleSales,
                    value: fmt.compact(r.singleSalesGained)),
            StatTile(label: l.albumUnits, value: fmt.compact(r.unitsGained)),
            StatTile(
                label: l.money,
                value: fmt.signedMoney(r.moneyDeltaCents),
                color:
                    r.moneyDeltaCents >= 0 ? AppColors.mint : AppColors.coral),
            StatTile(
                label: l.coreFans,
                value:
                    '${r.coreFansDelta >= 0 ? '+' : ''}${fmt.compact(r.coreFansDelta)}'),
            StatTile(
                label: l.summaryFame,
                value:
                    '${fmt.percent(r.fameBefore)} → ${fmt.percent(r.fameAfter)}'),
          ]),
          if (bars.length > 1 && weekly.any((x) => x > 0)) ...[
            const SizedBox(height: 14),
            Section(
              title: monthly ? l.summaryMonthly : l.summaryWeekly,
              icon: Icons.bar_chart_rounded,
              child: WeeklyBars(
                values: [for (final b in bars) b.$2],
                slots: bars.length,
                labels: [
                  for (final b in bars)
                    monthly
                        ? fmt.monthName(
                            Fmt.monthWeek(GameTime.weekOfYear(b.$1)).$1,
                            short: true)
                        : '${b.$1 - r.fromWeek + 1}',
                ],
              ),
            ),
          ],
          if (r.topSongs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Section(
              title: streaming ? l.summaryTopStreams : l.summaryTopSales,
              icon: Icons.headphones_rounded,
              child: Column(children: [
                for (final (i, s) in r.topSongs.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 22,
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                      CoverArt(
                          seed: songCoverSeed(s.songId, s.coverAlbumId),
                          songId: s.songId,
                          albumId: s.coverAlbumId >= 0 ? s.coverAlbumId : null,
                          size: 42),
                    ]),
                    title: Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(s.position > 0
                        ? l.summaryNowAt(s.position)
                        : l.offChart),
                    trailing: Text(
                        '+${fmt.compact(streaming ? s.streams : s.sales)}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    onTap: () =>
                        open(SongDetailScreen(songId: s.songId, state: state)),
                  ),
              ]),
            ),
          ],
          if (r.releases.isNotEmpty) ...[
            const SizedBox(height: 14),
            Section(
              title: l.summaryReleases,
              icon: Icons.album_rounded,
              child: Column(children: [
                for (final x in r.releases)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CoverArt(
                        seed: x.kind == EntityKind.album
                            ? albumCoverSeed(x.id)
                            : songCoverSeed(x.id, x.coverAlbumId),
                        songId: x.kind == EntityKind.song ? x.id : null,
                        albumId: x.kind == EntityKind.album
                            ? x.id
                            : (x.coverAlbumId >= 0 ? x.coverAlbumId : null),
                        size: 42),
                    title: Text(x.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(fmt.weekInMonth(x.week)),
                    trailing: Text(
                        x.peak > 0 ? l.summaryPeak(x.peak) : l.offChart,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => open(x.kind == EntityKind.album
                        ? AlbumDetailScreen(albumId: x.id, state: state)
                        : SongDetailScreen(songId: x.id, state: state)),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          Section(
            title: l.highlights,
            icon: Icons.auto_awesome_rounded,
            child: lines.isEmpty
                ? Text(l.summaryQuiet,
                    style: TextStyle(color: AppColors.textMuted))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final line in major.isEmpty ? rest.take(5) : major)
                        _NewsRow(line),
                      if (rest.isNotEmpty && major.isNotEmpty)
                        Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(l.summaryAllNews(lines.length),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            children: [for (final x in rest) _NewsRow(x)],
                          ),
                        )
                      else if (major.isEmpty && rest.length > 5)
                        Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(l.summaryAllNews(lines.length),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            children: [
                              for (final x in rest.skip(5)) _NewsRow(x)
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.summaryBack),
          ),
        ],
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow(this.line);
  final EventLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EventIcon(line.event, size: 32),
        const SizedBox(width: 10),
        Expanded(child: Text(context.fmt.event(line))),
      ]),
    );
  }
}
