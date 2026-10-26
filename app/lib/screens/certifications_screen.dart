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

class _CertificationsScreenState extends State<CertificationsScreen> {
  CertificationsView? _view;

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
    return Scaffold(
      appBar: AppBar(title: Text(l.plaques)),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                const SizedBox(height: 14),
                Text(l.plaquesHint,
                    style: TextStyle(color: AppColors.textMuted, height: 1.4)),
                const SizedBox(height: 14),
                if (v.plaques.isEmpty) EmptyNote(l.plaquesEmpty),
                for (final p in v.plaques) ...[
                  _PlaqueCard(plaque: p),
                  const SizedBox(height: 12),
                ],
              ],
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

class _PlaqueCard extends StatelessWidget {
  const _PlaqueCard({required this.plaque});
  final PlaqueView plaque;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final p = plaque;
    final (level, multiple, week, label) = p.top;
    final (nextLevel, nextMultiple, nextUnits) = p.next;
    final progress =
        ((p.usUnits - p.topUnits) / (nextUnits - p.topUnits)).clamp(0.0, 1.0);
    TextSpan field(String label, String value) => TextSpan(children: [
          TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: value),
        ]);
    return Section(
      title: p.artistName,
      icon: Icons.album_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlaqueDisc(level: level, multiple: multiple, size: 96),
          const SizedBox(width: 14),
          Expanded(
            child: Text.rich(
              TextSpan(
                  style: TextStyle(
                      color: AppColors.textMuted, height: 1.45, fontSize: 14),
                  children: [
                    TextSpan(
                        text: '${p.title}\n',
                        style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                    TextSpan(
                        text: '${fmt.certLevel(level, multiple)} · '
                            '${fmt.date(week)}\n'),
                    field(l.plaqueLabel('').trim(), fmt.labelName(label)),
                    const TextSpan(text: '\n'),
                    field(
                        l.plaqueFormat('').trim(), fmt.plaqueFormat(p.format)),
                  ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
            l.plaqueToNext(fmt.compact(nextUnits - p.usUnits),
                fmt.certLevel(nextLevel, nextMultiple)),
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        PillBar(value: progress, height: 6),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => showPlaque(context, p),
            icon: const Icon(Icons.workspace_premium_outlined),
            label: Text(l.plaqueOpen),
          ),
        ),
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
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/plaque_${DateTime.now().millisecondsSinceEpoch}.png')
          ..writeAsBytesSync(png!.buffer.asUint8List());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
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
