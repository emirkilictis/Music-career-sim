import 'dart:io';
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

/// A release's Streamify counter (docs K210), like the fan accounts post:
/// daily plays, their change and the total, song by song, as a card to
/// share.
class StreamCounterScreen extends StatefulWidget {
  const StreamCounterScreen(
      {super.key, required this.state, required this.kind, required this.id});
  final CareerState state;
  final EntityKind kind;
  final int id;

  @override
  State<StreamCounterScreen> createState() => _StreamCounterScreenState();
}

class _StreamCounterScreenState extends State<StreamCounterScreen> {
  StreamCounterView? _view;
  final _card = GlobalKey();
  final _shareButton = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.state.read(Cmd.streamCounter(widget.kind, widget.id)).then((v) {
      if (mounted) setState(() => _view = v);
    });
  }

  Future<void> _share() async {
    final l = context.l10n;
    final v = _view!;
    final box = _shareButton.currentContext?.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final boundary =
        _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/counter_${DateTime.now().millisecondsSinceEpoch}.png')
          ..writeAsBytesSync(png!.buffer.asUint8List());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      text: l.counterShareText(v.title, v.artistName, l.appTitle),
      sharePositionOrigin: origin,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = _view;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.counterTitle),
        actions: [
          if (v != null)
            IconButton(
              key: _shareButton,
              onPressed: _share,
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: l.share,
            ),
        ],
      ),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                RepaintBoundary(key: _card, child: CounterCard(view: v)),
                const SizedBox(height: 10),
                Text(l.counterNote,
                    style:
                        TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
              ],
            ),
    );
  }
}

/// The counter itself (docs K210): cover, title, the day, three numbers
/// up top and the song table under them.
class CounterCard extends StatelessWidget {
  const CounterCard({super.key, required this.view});
  final StreamCounterView view;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = view;
    final up = v.change >= 0;
    final green = const Color(0xFF4CC46B), red = const Color(0xFFE5566A);
    String pct(double x) => '${(x.abs() * 100).toStringAsFixed(2)}%';
    TextStyle head = TextStyle(
        color: AppColors.textMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151517),
        borderRadius: BorderRadius.circular(AppShape.r(18)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppShape.r(12)),
            child: CoverArt(
                seed: v.kind == EntityKind.album
                    ? albumCoverSeed(v.id)
                    : songCoverSeed(v.id, v.coverAlbumId),
                songId: v.kind == EntityKind.song ? v.id : null,
                albumId: v.coverAlbumId >= 0 ? v.coverAlbumId : null,
                size: 112),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(v.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                          color: Colors.white,
                          height: 1.1)),
                  const SizedBox(height: 4),
                  Container(height: 3, width: 70, color: green),
                  const SizedBox(height: 6),
                  Text(
                      '${v.artistName.toUpperCase()} · '
                      '${fmt.date(v.week).toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _Box(
                            label: l.counterDaily.toUpperCase(),
                            value: fmt.number(v.daily))),
                    const SizedBox(width: 6),
                    _Box(
                        label: l.counterChange.toUpperCase(),
                        value: '${up ? '↑' : '↓'} ${pct(v.changeShare)}',
                        color: up ? green : red),
                  ]),
                ]),
          ),
        ]),
        const SizedBox(height: 6),
        _Box(label: l.counterTotal.toUpperCase(), value: fmt.number(v.total)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1F),
            borderRadius: BorderRadius.circular(AppShape.r(12)),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Row(children: [
                SizedBox(width: 22, child: Text('', style: head)),
                Expanded(
                    flex: 5,
                    child: Text(l.counterTrack.toUpperCase(), style: head)),
                Expanded(
                    flex: 3,
                    child: Text(l.counterColDaily.toUpperCase(),
                        textAlign: TextAlign.right, style: head)),
                Expanded(
                    flex: 3,
                    child: Text(l.counterColPct.toUpperCase(),
                        textAlign: TextAlign.center, style: head)),
                Expanded(
                    flex: 4,
                    child: Text(l.counterColTotal.toUpperCase(),
                        textAlign: TextAlign.right, style: head)),
              ]),
            ),
            for (final (i, r) in v.rows.indexed)
              _Row(index: i + 1, row: r, green: green, red: red),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppShape.r(8)),
              ),
              child: Row(children: [
                const SizedBox(width: 18),
                Expanded(
                    flex: 5,
                    child: Text(l.counterTotalRow.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900))),
                Expanded(
                    flex: 3,
                    child: Text(fmt.number(v.daily),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800))),
                Expanded(
                    flex: 3,
                    child: Text('${up ? '↑' : '↓'}${pct(v.changeShare)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: up ? green : red,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5))),
                Expanded(
                    flex: 4,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(fmt.number(v.total),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    )),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.label, required this.value, this.color});
  final String label, value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: color ?? const Color(0xFF232327),
          borderRadius: BorderRadius.circular(AppShape.r(10)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: color == null ? Colors.white60 : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900)),
          ),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.index,
      required this.row,
      required this.green,
      required this.red});
  final int index;
  final CounterRow row;
  final Color green, red;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final up = row.change >= 0;
    final share = row.changeShare.abs();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)))),
      child: Row(children: [
        SizedBox(
            width: 22,
            child: Text('$index',
                style: const TextStyle(color: Colors.white54, fontSize: 12))),
        Expanded(
            flex: 5,
            child: Text(row.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5))),
        Expanded(
            flex: 3,
            child: Text(fmt.number(row.daily),
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontSize: 13))),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                    '${up ? '↑' : '↓'}${(share * 100).toStringAsFixed(2)}%',
                    maxLines: 1,
                    style: TextStyle(
                        color: up ? green : red,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (share * 10).clamp(0.04, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: up ? green : red,
                ),
              ),
            ]),
          ),
        ),
        Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(fmt.number(row.total),
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            )),
      ]),
    );
  }
}
