import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/scope.dart';
import '../ui/palette.dart';
import 'common.dart';

/// A long weekly table: the latest weeks first, the rest behind
/// "Show all" (docs K47).
class _Expandable extends StatefulWidget {
  const _Expandable({required this.header, required this.rows});
  final List<String> header;
  final List<List<String>> rows;

  @override
  State<_Expandable> createState() => _ExpandableState();
}

class _ExpandableState extends State<_Expandable> {
  static const _short = 12;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = _all ? widget.rows : widget.rows.take(_short).toList();
    TextStyle head = TextStyle(
        color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 12);
    Widget cell(String t, {TextStyle? style, bool first = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          child: Text(t,
              textAlign: first ? TextAlign.left : TextAlign.right,
              style: style ??
                  const TextStyle(
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()])),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 64),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            columnWidths: const {0: IntrinsicColumnWidth(flex: 1)},
            border: TableBorder(
                horizontalInside:
                    BorderSide(color: AppColors.line, width: 0.5)),
            children: [
              TableRow(children: [
                for (var i = 0; i < widget.header.length; i++)
                  cell(widget.header[i], style: head, first: i == 0),
              ]),
              for (final r in rows)
                TableRow(children: [
                  for (var i = 0; i < r.length; i++) cell(r[i], first: i == 0),
                ]),
            ],
          ),
        ),
      ),
      if (widget.rows.length > _short)
        TextButton(
          onPressed: () => setState(() => _all = !_all),
          child:
              Text(_all ? l.showFewerRows : l.showAllRows(widget.rows.length)),
        ),
    ]);
  }
}

/// Week-by-week sales of an album, newest first: chart position, units,
/// and for the player's own albums the pure / track / stream breakdown.
class AlbumSalesTable extends StatelessWidget {
  const AlbumSalesTable({super.key, required this.weeks, required this.full});
  final List<AlbumSalesWeek> weeks;

  /// The player's album (full breakdown) or a rival's (chart units only).
  final bool full;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    String n(double? v) => v == null ? '—' : fmt.compact(v);
    String pos(AlbumSalesWeek w) {
      final p = w.positions[Charts.usAlbums];
      return p == null ? '—' : '#$p';
    }

    final rows = [
      for (final w in weeks.reversed)
        full
            ? [
                fmt.weekShort(w.week),
                pos(w),
                n(w.units),
                n(w.usUnits),
                n(w.pure),
                n(w.tea),
                n(w.sea),
              ]
            : [fmt.weekShort(w.week), pos(w), n(w.usUnits), n(w.units)],
    ];
    return _Expandable(
      header: full
          ? [
              l.colWeek,
              l.colPos,
              l.colUnits,
              l.colUsUnits,
              l.colPure,
              l.colTea,
              l.colSea
            ]
          : [l.colWeek, l.colPos, l.colUsUnits, l.colUnits],
      rows: rows,
    );
  }
}

/// Every chart week of a song or album, newest first: the position on each
/// chart it was on that week ("—" when off it).
class ChartRunTable extends StatelessWidget {
  const ChartRunTable({super.key, required this.run});
  final List<ChartWeek> run;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    if (run.isEmpty) return EmptyNote(l.notOnChart);
    final charts = <int>{for (final w in run) ...w.entries.keys}.toList()
      ..sort();
    return _Expandable(
      header: [l.colWeek, for (final c in charts) fmt.chartShort(c)],
      rows: [
        for (final w in run.reversed)
          [
            fmt.weekShort(w.week),
            for (final c in charts)
              w.entries[c] == null ? '—' : '#${w.entries[c]!.position}',
          ],
      ],
    );
  }
}
