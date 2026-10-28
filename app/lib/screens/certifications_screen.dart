import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:game/game.dart';
import 'package:share_plus/share_plus.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';
import '../widgets/plaque.dart';

/// The player's gold, platinum and diamond records (docs K209): the
/// counts, then each certified release with its disc, its day and how
/// far the next level is; its plaque opens framed, ready to share.
class CertificationsScreen extends StatefulWidget {
  const CertificationsScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<CertificationsScreen> createState() => _CertificationsScreenState();
}

/// Which plaques are listed, and in what order (docs K231).
enum _Order { highest, newest }

class _CertificationsScreenState extends State<CertificationsScreen> {
  CertificationsView? _view;
  Certification? _level;
  EntityKind? _kind;
  _Order _order = _Order.highest;

  @override
  void initState() {
    super.initState();
    widget.state.read(Cmd.certifications()).then((v) {
      if (mounted) setState(() => _view = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = _view;
    if (v == null) {
      return Scaffold(
          appBar: AppBar(title: Text(l.plaques)),
          body: const Center(child: CircularProgressIndicator()));
    }
    final shown = [
      for (final p in v.plaques)
        if ((_level == null || p.top.$1 == _level) &&
            (_kind == null || p.kind == _kind))
          p
    ];
    if (_order == _Order.highest) {
      shown.sort((a, b) {
        final d = b.topUnits.compareTo(a.topUnits);
        return d != 0 ? d : b.usUnits.compareTo(a.usUnits);
      });
    }
    // Every certified unit counted in platinum (a diamond is ten).
    final platinums = v.plaques.fold(
        0,
        (t, p) =>
            t + (p.topUnits / Certification.platinum.units).floor());
    final songs = v.plaques.where((p) => p.kind == EntityKind.song).length;
    final albums = v.plaques.length - songs;
    double progress(PlaqueView p) =>
        ((p.usUnits - p.topUnits) / (p.next.$3 - p.topUnits)).clamp(0.0, 1.0);
    final closest = [...v.plaques]
      ..sort((a, b) => progress(b).compareTo(progress(a)));
    return Scaffold(
      appBar: AppBar(title: Text(l.plaques)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(children: [
            for (final (c, n) in [
              (Certification.gold, v.gold),
              (Certification.platinum, v.platinum),
              (Certification.diamond, v.diamond),
            ]) ...[
              Expanded(child: _Count(level: c, count: n)),
              if (c != Certification.diamond) const SizedBox(width: 10),
            ],
          ]),
          const SizedBox(height: 10),
          if (v.plaques.isNotEmpty)
            Text(l.plaquesTotals(platinums, songs, albums),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(l.plaquesHint,
              style: TextStyle(color: AppColors.textMuted, height: 1.4)),
          if (v.plaques.isEmpty) ...[
            const SizedBox(height: 14),
            EmptyNote(l.plaquesEmpty),
          ] else ...[
            const SizedBox(height: 14),
            // The ones about to go up a level.
            Section(
              title: l.plaquesClosest,
              icon: Icons.trending_up_rounded,
              child: Column(children: [
                for (final p in closest.take(3)) _Row(plaque: p, next: true),
              ]),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in [null, ...Certification.values.reversed])
                ChoiceChip(
                  label: Text(switch (c) {
                    null => l.plaquesAll,
                    Certification.gold => l.certGold,
                    Certification.platinum => l.certPlatinum,
                    Certification.diamond => l.certDiamond,
                  }),
                  selected: _level == c,
                  onSelected: (_) => setState(() => _level = c),
                ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in [null, EntityKind.song, EntityKind.album])
                ChoiceChip(
                  label: Text(switch (k) {
                    null => l.plaquesAll,
                    EntityKind.song => l.historySongs,
                    EntityKind.album => l.historyAlbums,
                  }),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
              const SizedBox(width: 12),
              for (final o in _Order.values)
                ChoiceChip(
                  label: Text(o == _Order.highest
                      ? l.plaquesHighest
                      : l.historySortNewest),
                  selected: _order == o,
                  onSelected: (_) => setState(() => _order = o),
                ),
            ]),
            const SizedBox(height: 8),
            Text(l.plaquesShown(shown.length),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            for (final p in shown) _Row(plaque: p),
            const SizedBox(height: 8),
            Text(l.plaquesTapHint,
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// A plaque in a line: its disc, the record, its level and how far the
/// next one is; tapping opens it framed.
class _Row extends StatelessWidget {
  const _Row({required this.plaque, this.next = false});
  final PlaqueView plaque;

  /// Shows what the next level needs.
  final bool next;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final p = plaque;
    final (level, multiple, week, _) = p.top;
    final (nextLevel, nextMultiple, nextUnits) = p.next;
    final progress =
        ((p.usUnits - p.topUnits) / (nextUnits - p.topUnits)).clamp(0.0, 1.0);
    return InkWell(
      onTap: () => showPlaque(context, p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          PlaqueDisc(level: level, multiple: multiple, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15.5)),
                  Text(
                      '${fmt.certLevel(level, multiple)} · '
                      '${fmt.plaqueFormat(p.format)} · ${fmt.date(week)}',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12.5)),
                  if (next)
                    Text(
                        l.plaqueToNext(fmt.compact(nextUnits - p.usUnits),
                            fmt.certLevel(nextLevel, nextMultiple)),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  PillBar(value: progress, height: 4),
                ]),
          ),
          const SizedBox(width: 8),
          Text(fmt.compact(p.usUnits),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.level, required this.count});
  final Certification level;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final metal = plaqueMetal(level);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.r(14)),
        border: Border.all(color: metal[1].withValues(alpha: 0.35)),
      ),
      child: Column(children: [
        Text('$count',
            style: const TextStyle(
                fontFamily: AppFonts.condensed,
                fontSize: 32,
                fontWeight: FontWeight.w800)),
        Text(
            switch (level) {
              Certification.gold => l.certGold,
              Certification.platinum => l.certPlatinum,
              Certification.diamond => l.certDiamond,
            }
                .toUpperCase(),
            style: TextStyle(
                fontFamily: AppFonts.condensed,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: metal[1])),
      ]),
    );
  }
}

/// The framed plaque in a sheet, with a share button (docs K209).
Future<void> showPlaque(BuildContext context, PlaqueView p) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      builder: (_) => _PlaqueSheet(plaque: p),
    );

class _PlaqueSheet extends StatefulWidget {
  const _PlaqueSheet({required this.plaque});
  final PlaqueView plaque;

  @override
  State<_PlaqueSheet> createState() => _PlaqueSheetState();
}

class _PlaqueSheetState extends State<_PlaqueSheet> {
  final _frame = GlobalKey();
  final _shareButton = GlobalKey();

  Future<void> _share() async {
    final l = context.l10n;
    final fmt = context.fmt;
    final p = widget.plaque;
    final box = _shareButton.currentContext?.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final boundary =
        _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    // No files on the web: the image goes as bytes (docs K218).
    final bytes = png!.buffer.asUint8List();
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'plaque.png')],
      text: l.plaqueShareText(
          p.title, p.artistName, fmt.certLevel(p.top.$1, p.top.$2), l.appTitle),
      sharePositionOrigin: origin,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(
              key: _frame, child: PlaqueFrame(plaque: widget.plaque)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: _shareButton,
                onPressed: _share,
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(l.share),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.close),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
