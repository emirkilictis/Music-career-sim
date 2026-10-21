import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../../core/commands.dart';
import '../../core/scope.dart';
import '../../ui/palette.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import '../game_shell.dart';
import '../song_detail_screen.dart';
import 'artist_page.dart';

const _plColor = Color(0xFF8E6CFF);

/// The cover of the player's own playlist (docs K159).
class OwnPlaylistCover extends StatelessWidget {
  const OwnPlaylistCover({super.key, required this.name, this.size = 150});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.09),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_plColor, Color(0xFF2A1B5C)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.queue_music_rounded,
              color: Colors.white, size: size * 0.14),
          const Spacer(),
          Text(name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: AppFonts.condensed,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.17,
                  height: 0.95)),
        ]),
      );
}

/// Asks for a playlist name.
Future<String?> askPlaylistName(BuildContext context, String initial) {
  final l = context.l10n;
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(l.ownPlName),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 40,
        onSubmitted: (v) => Navigator.pop(d, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(l.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(d, ctrl.text), child: Text(l.ok)),
      ],
    ),
  );
  // [ctrl] is not disposed: the closing animation still builds with it,
  // and nothing holds it once the dialog is gone (K188).
}

/// The player's own playlist: its following, what draws people to it and
/// its songs (docs K159).
class OwnPlaylistPage extends StatefulWidget {
  const OwnPlaylistPage({super.key});

  @override
  State<OwnPlaylistPage> createState() => _OwnPlaylistPageState();
}

class _OwnPlaylistPageState extends State<OwnPlaylistPage> {
  OwnPlaylistView? _view;
  int _loadedRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final career = context.career;
    if (career.revision != _loadedRevision) {
      _loadedRevision = career.revision;
      _load();
    }
  }

  Future<void> _load() async {
    final v = await context.careerRead.read(Cmd.ownPlaylist());
    if (mounted) setState(() => _view = v);
  }

  Future<void> _rename(OwnPlaylistView v) async {
    final name = await askPlaylistName(context, v.name);
    if (name == null || !mounted) return;
    try {
      await context.careerRead.act(Cmd.renamePlaylist(name));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _remove(PlaylistTrackView t) async {
    final l = context.l10n;
    try {
      await context.careerRead.act(Cmd.removeFromPlaylist(t.songId));
      if (mounted) showInfo(context, l.ownPlRemoved(t.title));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _add() async {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final list = await career.read(Cmd.playlistCandidates());
    if (!mounted) return;
    final pick = await showModalBottomSheet<PlaylistTrackView>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l.ownPlAdd, style: Theme.of(c).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final t in list)
                  ListTile(
                    enabled: !t.onPlaylist,
                    leading: CoverArt(
                        seed: songCoverSeed(t.songId, t.albumId),
                        songId: t.songId,
                        albumId: t.albumId,
                        size: 44,
                        radius: 2),
                    title: Text(t.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text([
                      t.artistName,
                      fmt.compact(t.weekStreams * Streamify.share),
                      if (t.fresh) l.ownPlNew,
                    ].join(' · ')),
                    trailing: Icon(
                        t.onPlaylist
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: t.onPlaylist ? _plColor : null),
                    onTap: () => Navigator.pop(c, t),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      await career.act(Cmd.addToPlaylist(pick.songId));
      if (mounted) {
        showInfo(context, l.ownPlAdded(pick.title),
            icon: Icons.queue_music_rounded);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = _view;
    final career = context.careerRead;
    Widget meter(String label, double value, String text, {bool bad = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(
                width: 130,
                child: Text(label,
                    style: const TextStyle(
                        color: StreamifyColors.muted, fontSize: 13))),
            Expanded(
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 6,
                color: bad ? const Color(0xFFF15E6C) : _plColor,
                backgroundColor: Colors.white12,
              ),
            ),
            SizedBox(
                width: 84,
                child: Text(text,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13))),
          ]),
        );
    return Scaffold(
      backgroundColor: StreamifyColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          if (v != null)
            IconButton(
                tooltip: l.ownPlRename,
                onPressed: () => _rename(v),
                icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton:
          v == null || v.tracks.length >= OwnPlaylists.maxSongs
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: _plColor,
                  foregroundColor: Colors.white,
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.ownPlAdd)),
      body: v == null
          ? const Center(
              child: CircularProgressIndicator(color: StreamifyColors.accent))
          : ListView(padding: EdgeInsets.zero, children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _plColor.withValues(alpha: 0.7),
                      StreamifyColors.bg
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(boxShadow: [
                            BoxShadow(blurRadius: 30, color: Colors.black54),
                          ]),
                          child: OwnPlaylistCover(name: v.name, size: 200),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(v.name,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                          [
                            l.ownPlFollowers(fmt.compact(v.followers)),
                            l.ownPlHeading(fmt.compact(v.target)),
                          ].join(' · '),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(l.ownPlCount(v.tracks.length, OwnPlaylists.maxSongs),
                          style: const TextStyle(
                              color: StreamifyColors.muted, fontSize: 13)),
                      const SizedBox(height: 12),
                      meter(l.ownPlAppeal, v.appeal,
                          '${(v.appeal * 100).round()}%'),
                      // Up to the free share is fine.
                      meter(l.ownPlOwn, v.ownShare,
                          '${(v.ownShare * 100).round()}% / ${(OwnPlaylists.ownFree * 100).round()}%',
                          bad: v.tooMuchSelf),
                      meter(l.ownPlFresh, v.freshness,
                          '${(v.freshness * 100).round()}%',
                          bad: v.freshness < 1),
                      meter(l.ownPlLift, v.lift / OwnPlaylists.maxLift,
                          '+${(v.lift * 100).toStringAsFixed(1)}%'),
                      const SizedBox(height: 8),
                      for (final warn in [
                        if (v.tooShort) l.ownPlTooShort(OwnPlaylists.minSongs),
                        if (v.tooMuchSelf) l.ownPlTooMuchSelf,
                        if (v.freshness < 1) l.ownPlStale,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 16, color: Color(0xFFF15E6C)),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(warn,
                                    style: const TextStyle(fontSize: 13))),
                          ]),
                        ),
                      Text(l.ownPlFavourHint,
                          style: const TextStyle(
                              color: StreamifyColors.muted, fontSize: 12)),
                    ]),
              ),
              if (v.tracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.ownPlEmpty,
                      style: const TextStyle(color: StreamifyColors.muted)),
                ),
              for (final t in v.tracks)
                InkWell(
                  onTap: () => t.isPlayer
                      ? Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SongDetailScreen(
                                  songId: t.songId, state: career)))
                      : pushInCareer(context, ArtistPage(artistId: t.artistId)),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(children: [
                      CoverArt(
                          seed: songCoverSeed(t.songId, t.albumId),
                          songId: t.songId,
                          albumId: t.albumId,
                          size: 48,
                          radius: 2),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.5,
                                      color: t.isPlayer
                                          ? StreamifyColors.accent
                                          : Colors.white)),
                              Text(
                                  [
                                    t.artistName,
                                    if (t.fresh) l.ownPlNew,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: StreamifyColors.muted,
                                      fontSize: 13)),
                            ]),
                      ),
                      Text(fmt.compact(t.weekStreams * Streamify.share),
                          style: const TextStyle(
                              color: StreamifyColors.muted, fontSize: 13)),
                      IconButton(
                        tooltip: l.ownPlSongRemove,
                        onPressed: () => _remove(t),
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            color: StreamifyColors.muted),
                      ),
                    ]),
                  ),
                ),
              const SizedBox(height: 88),
            ]),
    );
  }
}
