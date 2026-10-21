import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/common.dart';
import 'releases_tab.dart';

/// An EP or album from the vault under another name: a member's solo
/// record (docs K173), or the old group's on a reunion (docs K194).
class SideAlbumScreen extends StatefulWidget {
  const SideAlbumScreen(
      {super.key,
      required this.state,
      required this.songs,
      required this.title,
      required this.hint,
      required this.campaignHeader,
      required this.costs,
      required this.release,
      required this.done,
      required this.button});

  /// A member's solo EP or album (docs K173).
  factory SideAlbumScreen.member(BuildContext context,
      {required CareerState state,
      required MemberView member,
      required List<SongView> songs}) {
    final l = context.l10n;
    return SideAlbumScreen(
      state: state,
      songs: songs,
      title: l.memberAlbumScreen(member.name),
      hint: l.memberAlbumHint(member.name),
      campaignHeader: l.memberSoloCampaign(member.name),
      costs: Cmd.memberSoloCosts(member.index),
      release: (title, ids, type, campaign) =>
          Cmd.releaseMemberAlbum(member.index, title, ids, type, campaign),
      done: (al) => l.memberAlbumDone(al.title, member.name),
      button: l.memberAlbumButton,
    );
  }

  final CareerState state;

  /// Vault songs not set for a release.
  final List<SongView> songs;
  final String title, hint, campaignHeader, button;
  final SessionCmd<List<int>> costs;
  final SessionCmd<AlbumView> Function(
          String title, List<int> songIds, AlbumType type, Campaign campaign)
      release;
  final String Function(AlbumView album) done;

  @override
  State<SideAlbumScreen> createState() => _SideAlbumScreenState();
}

class _SideAlbumScreenState extends State<SideAlbumScreen> {
  final _title = TextEditingController();
  final List<int> _picked = [];
  AlbumType _type = AlbumType.ep;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _release() async {
    final career = widget.state;
    try {
      final costs = await career.read(widget.costs);
      if (!mounted) return;
      final campaign = await pickCampaign(context, career,
          costs: costs,
          header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(widget.campaignHeader,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ));
      if (campaign == null || !mounted) return;
      final al = await career
          .act(widget.release(_title.text, List.of(_picked), _type, campaign));
      if (!mounted) return;
      Navigator.pop(context);
      showInfo(context, widget.done(al), icon: Icons.person_outline_rounded);
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
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.hint, style: TextStyle(color: AppColors.textMuted)),
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
            child: Text(widget.button),
          ),
        ],
      ),
    );
  }
}
