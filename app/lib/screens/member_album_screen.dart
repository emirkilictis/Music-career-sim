import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';
import 'releases_tab.dart';

/// A member's solo EP or album from the group's vault (docs K173).
class MemberAlbumScreen extends StatefulWidget {
  const MemberAlbumScreen(
      {super.key,
      required this.state,
      required this.member,
      required this.songs});
  final CareerState state;
  final MemberView member;

  /// Vault songs not set for a release.
  final List<SongView> songs;

  @override
  State<MemberAlbumScreen> createState() => _MemberAlbumScreenState();
}

class _MemberAlbumScreenState extends State<MemberAlbumScreen> {
  final _title = TextEditingController();
  final List<int> _picked = [];
  AlbumType _type = AlbumType.ep;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _release() async {
    final l = context.l10n;
    final career = widget.state;
    final m = widget.member;
    try {
      final costs = await career.read(Cmd.memberSoloCosts(m.index));
      if (!mounted) return;
      final campaign = await pickCampaign(context, career,
          costs: costs,
          header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.memberSoloCampaign(m.name),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ));
      if (campaign == null || !mounted) return;
      final al = await career.act(Cmd.releaseMemberAlbum(
          m.index, _title.text, List.of(_picked), _type, campaign));
      if (!mounted) return;
      Navigator.pop(context);
      showInfo(context, l.memberAlbumDone(al.title, m.name),
          icon: Icons.person_outline_rounded);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final (lo, hi) = GameSession.trackRange(_type);
    final n = _picked.length;
    final ok = n >= lo && n <= hi && _title.text.trim().isNotEmpty;
    final songs = [...widget.songs]
      ..sort((a, b) => b.estimatedGrade.compareTo(a.estimatedGrade));
    return Scaffold(
      appBar: AppBar(title: Text(l.memberAlbumScreen(widget.member.name))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.memberAlbumHint(widget.member.name),
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: l.albumTitle, border: const OutlineInputBorder()),
          ),
          SegmentedButton<AlbumType>(
            showSelectedIcon: false,
            segments: [
              for (final t in Credits.memberAlbumTypes)
                ButtonSegment(value: t, label: Text(fmt.albumType(t))),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          Section(
            title: l.tracksPicked(n, lo, hi),
            child: songs.isEmpty
                ? EmptyNote(l.noSongsToRelease)
                : Column(children: [
                    for (final s in songs)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _picked.contains(s.id),
                        onChanged: (on) => setState(() =>
                            on! ? _picked.add(s.id) : _picked.remove(s.id)),
                        title: Text(s.title),
                        subtitle: Text(
                            '${fmt.songGrade(s)} · ${fmt.genres(s.genres)}'),
                      ),
                  ]),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: ok && !widget.state.busy ? _release : null,
            child: Text(l.memberAlbumButton),
          ),
        ],
      ),
    );
  }
}
