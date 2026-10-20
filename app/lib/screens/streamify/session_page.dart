import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../../core/commands.dart';
import '../../core/scope.dart';
import '../../ui/palette.dart';
import '../../widgets/common.dart';

/// The Streamify Sessions card on the app's home (docs K178).
class SessionsCard extends StatelessWidget {
  const SessionsCard({super.key, required this.view, required this.onRecord});
  final SessionsView view;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final muted = const TextStyle(color: StreamifyColors.muted, fontSize: 13);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: StreamifyColors.surfaceHigh,
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.mic_rounded, color: StreamifyColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                switch (view.block) {
                  null => l.sessInvite,
                  SessionBlock.notKnown => l.sessNotKnown(
                      fmt.compact(StreamifySessions.minListeners),
                      fmt.compact(view.listeners)),
                  SessionBlock.tooSoon => l.sessTooSoon(fmt.week(view.nextWeek)),
                  SessionBlock.tooEarly => '',
                },
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(l.sessHint, style: muted),
        if (view.block == null) ...[
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: StreamifyColors.accent,
                foregroundColor: Colors.black),
            onPressed: onRecord,
            child: Text(l.sessRecord),
          ),
        ],
        for (final s in view.sessions) ...[
          const SizedBox(height: 8),
          Text(l.sessDone(s.title, s.coverTitle, s.coverArtist),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(fmt.week(s.week), style: muted),
        ],
      ]),
    );
  }
}

/// Picks the two songs of a Streamify Session (docs K178).
class SessionPage extends StatefulWidget {
  const SessionPage({super.key, required this.view});
  final SessionsView view;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  int? _song, _cover;

  Future<void> _record() async {
    final l = context.l10n;
    final career = context.careerRead;
    try {
      await career.act(Cmd.recordSession(_song!, _cover!));
      if (!mounted) return;
      Navigator.pop(context);
      showInfo(context, l.sessRecorded, icon: Icons.mic_rounded);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = widget.view;
    const h = TextStyle(fontSize: 18, fontWeight: FontWeight.w900);
    return Scaffold(
      backgroundColor: StreamifyColors.bg,
      appBar: AppBar(
          backgroundColor: StreamifyColors.bg,
          foregroundColor: Colors.white,
          title: Text(l.sessTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(l.sessPageHint(StreamifySessions.energy.round()),
            style: const TextStyle(color: StreamifyColors.muted)),
        const SizedBox(height: 16),
        Text(l.sessYourSong, style: h),
        if (v.songs.isEmpty) EmptyNote(l.noReleasesYet),
        RadioGroup<int>(
          groupValue: _song,
          onChanged: (x) => setState(() => _song = x),
          child: Column(children: [
            for (final s in v.songs)
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                value: s.id,
                title: Text(s.title),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(l.sessCover, style: h),
        RadioGroup<int>(
          groupValue: _cover,
          onChanged: (x) => setState(() => _cover = x),
          child: Column(children: [
            for (final s in v.covers)
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                value: s.id,
                title: Text('${s.title} · ${s.artist}'),
                subtitle: Text(l.sessReach(fmt.compact(s.listeners)),
                    style: const TextStyle(color: StreamifyColors.muted)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: StreamifyColors.accent,
              foregroundColor: Colors.black),
          onPressed: _song != null && _cover != null && !context.career.busy
              ? _record
              : null,
          child: Text(l.sessRecord),
        ),
      ]),
    );
  }
}
