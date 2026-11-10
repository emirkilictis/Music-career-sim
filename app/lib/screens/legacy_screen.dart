import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:game/game.dart';
import 'package:share_plus/share_plus.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'album_detail_screen.dart';
import 'song_detail_screen.dart';

/// The player's legacy (docs K288): the career summary, its score and
/// all-time rank, the Hall of Fame, the biggest records; the summary card
/// can be shared. The career ends and comes back from here.
class LegacyScreen extends StatefulWidget {
  const LegacyScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<LegacyScreen> createState() => _LegacyScreenState();
}

class _LegacyScreenState extends State<LegacyScreen> {
  LegacyView? _view;
  final _frame = GlobalKey();
  final _shareButton = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await widget.state.read(Cmd.legacy());
    if (mounted) setState(() => _view = v);
  }

  Future<void> _share() async {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = _view!;
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
      files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'legacy.png')],
      text: l.legacyShareText(v.name, fmt.legacyTitle(v.title),
          v.score.round().toString(), l.appTitle),
      sharePositionOrigin: origin,
    ));
  }

  Future<void> _retire() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.legacyRetireConfirmTitle),
        content: Text(l.legacyRetireConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(l.legacyRetire)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.state.act(Cmd.retire());
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _comeBack() async {
    final l = context.l10n;
    try {
      await widget.state.act(Cmd.comeBack());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.legacyComeBackDone)));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = _view;
    return Scaffold(
      appBar: AppBar(title: Text(l.legacyTitle)),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              RepaintBoundary(key: _frame, child: _SummaryCard(view: v)),
              const SizedBox(height: 12),
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
                  child: v.retired
                      ? FilledButton.icon(
                          onPressed: _comeBack,
                          icon: const Icon(Icons.replay_rounded),
                          label: Text(l.legacyComeBack),
                        )
                      : OutlinedButton.icon(
                          onPressed: v.canRetire ? _retire : null,
                          icon: const Icon(Icons.flag_outlined),
                          label: Text(l.legacyRetire),
                        ),
                ),
              ]),
              if (!v.retired && !v.canRetire) ...[
                const SizedBox(height: 6),
                Text(l.legacyRetireBlocked,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
              if (v.retired) ...[
                const SizedBox(height: 6),
                Text(l.legacyRetiredHint,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              _Records(
                  title: l.legacyTopSongs,
                  rows: v.topSongs,
                  state: widget.state),
              const SizedBox(height: 12),
              _Records(
                  title: l.legacyTopAlbums,
                  rows: v.topAlbums,
                  state: widget.state),
              const SizedBox(height: 12),
              Text(l.legendsNote,
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            ]),
    );
  }
}

/// The shareable career summary.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.view});
  final LegacyView view;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = view;
    const ink = Color(0xFF141414);
    const paper = Color(0xFFF7F4EF);
    const muted = Color(0xFF6E6A64);
    final parts = [
      (l.legacyPartSales, v.sales),
      (l.legacyPartHits, v.hits),
      (l.legacyPartNo1, v.numberOnes),
      (l.legacyPartAwards, v.awards),
      (l.legacyPartLongevity, v.longevity),
    ];
    final most = parts.fold(1.0, (m, p) => p.$2 > m ? p.$2 : m);
    TextStyle cond(double size, {Color color = ink}) => TextStyle(
        fontFamily: AppFonts.condensed,
        fontWeight: FontWeight.w800,
        fontSize: size,
        height: 1.05,
        color: color);
    Widget stat(String label, String value) => SizedBox(
          width: 96,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: cond(22)),
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: muted)),
          ]),
        );
    return Container(
      color: paper,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            (v.retired ? l.legacySummary : l.legacyTitle).toUpperCase(),
            style: const TextStyle(
                fontFamily: AppFonts.condensed,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 2,
                color: muted)),
        const SizedBox(height: 10),
        Row(children: [
          ArtistAvatar(
              name: v.name, seed: v.artistId, artistId: v.artistId, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: cond(28)),
                  Text('${v.firstYear}–${v.retired ? v.lastYear : ''}',
                      style: const TextStyle(color: muted)),
                  Text(fmt.legacyTitle(v.title),
                      style: const TextStyle(
                          fontFamily: AppFonts.serif,
                          fontStyle: FontStyle.italic,
                          fontSize: 15,
                          color: ink)),
                ]),
          ),
        ]),
        const Divider(height: 28, color: Color(0xFFE4DFD7)),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.number(v.score.round()), style: cond(54)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l.legacyScore.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: muted)),
          ),
        ]),
        Text(
            v.rank > 0 ? l.legacyRankOf(v.rank, v.ranked) : l.legacyUnranked,
            style: cond(18)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.account_balance_rounded,
              size: 16,
              color: v.hallOfFameYear > 0 ? const Color(0xFFB8860B) : muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                v.hallOfFameYear > 0
                    ? l.legacyHofIn(v.hallOfFameYear)
                    : v.yearsToEligible > 0
                        ? l.legacyHofYears(v.yearsToEligible)
                        : l.legacyHofEligible,
                style: const TextStyle(color: ink, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 14),
        for (final (label, pts) in parts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(
                  width: 96,
                  child: Text(label,
                      style: const TextStyle(fontSize: 12, color: ink))),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                        height: 10,
                        width: c.maxWidth * (pts / most).clamp(0.0, 1.0),
                        color: ink),
                  ),
                ),
              ),
              SizedBox(
                  width: 48,
                  child: Text(fmt.number(pts.round()),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: ink))),
            ]),
          ),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          stat(l.legacyUnits, fmt.compact(v.units)),
          stat(l.legacyRecordsSold, fmt.compact(v.recordsSold)),
          if (v.streams >= 1) stat(l.legacyStreams, fmt.compact(v.streams)),
          stat(l.legacyNo1Singles, '${v.no1Singles}'),
          stat(l.legacyNo1Albums, '${v.no1Albums}'),
          stat(l.legacyTop10, '${v.top10}'),
          stat(l.legacyAwardWins, '${v.awardWins}'),
          stat(l.legacyHitYears, '${v.hitYears}'),
        ]),
        const SizedBox(height: 12),
        Text(l.appTitle.toUpperCase(),
            style: const TextStyle(
                fontFamily: AppFonts.condensed,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 2,
                color: muted)),
      ]),
    );
  }
}

class _Records extends StatelessWidget {
  const _Records(
      {required this.title, required this.rows, required this.state});
  final String title;
  final List<LegacyRecord> rows;
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    if (rows.isEmpty) return const SizedBox.shrink();
    return Section(
      title: title,
      child: Column(children: [
        for (final r in rows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CoverArt(
                seed: r.kind == EntityKind.album
                    ? albumCoverSeed(r.id)
                    : songCoverSeed(r.id, r.albumId),
                size: 42,
                radius: 4,
                songId: r.kind == EntityKind.album ? null : r.id,
                albumId: r.albumId),
            title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([
              '${r.year}',
              if (r.peak > 0) '#${r.peak}',
            ].join(' · ')),
            trailing: Text(fmt.compact(r.units)),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => r.kind == EntityKind.album
                        ? AlbumDetailScreen(albumId: r.id, state: state)
                        : SongDetailScreen(songId: r.id, state: state))),
          ),
      ]),
    );
  }
}
