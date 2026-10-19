import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../../core/commands.dart';
import '../../core/format.dart';
import '../../core/scope.dart';
import '../../ui/palette.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import '../game_shell.dart';
import '../song_detail_screen.dart';
import 'artist_page.dart';

/// Each editorial playlist's cover color (docs K125).
Color editorialColor(EditorialPlaylist p) => switch (p) {
      EditorialPlaylist.hotRightNow => const Color(0xFFE8115B),
      EditorialPlaylist.freshFriday => const Color(0xFFD7F75B),
      EditorialPlaylist.popRising => const Color(0xFFFF4FA3),
      EditorialPlaylist.barsAndBeats => const Color(0xFFFF6B35),
      EditorialPlaylist.slowBurn => const Color(0xFF8D67AB),
      EditorialPlaylist.rockSolid => const Color(0xFF777777),
      EditorialPlaylist.hotCountry => const Color(0xFFD9A441),
      EditorialPlaylist.dancefloor => const Color(0xFF2D46B9),
      EditorialPlaylist.latinHeat => const Color(0xFFE13300),
      EditorialPlaylist.indieMix => const Color(0xFF608108),
      EditorialPlaylist.afroWave => const Color(0xFF1E9E5A),
      EditorialPlaylist.kpopNow => const Color(0xFF6B3CF5),
      EditorialPlaylist.grooveAndJazz => const Color(0xFF0D72EA),
    };

String editorialDescription(BuildContext context, EditorialPlaylist p) {
  final l = context.l10n;
  return switch (p) {
    EditorialPlaylist.hotRightNow => l.edHotRightNow,
    EditorialPlaylist.freshFriday => l.edFreshFriday,
    _ => l.edGenre(p.genres.map((g) => genreNames[g]).join(', ')),
  };
}

/// Square flat cover: the color block and the name in heavy type.
class EditorialCover extends StatelessWidget {
  const EditorialCover({super.key, required this.playlist, this.size = 150});
  final EditorialPlaylist playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = editorialColor(playlist);
    final ink =
        c.computeLuminance() > 0.5 ? const Color(0xFF141414) : Colors.white;
    return Container(
      width: size,
      height: size,
      color: c,
      padding: EdgeInsets.all(size * 0.09),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.graphic_eq_rounded, color: ink, size: size * 0.13),
        const Spacer(),
        Text(playlist.displayName,
            maxLines: 3,
            style: TextStyle(
                fontFamily: AppFonts.condensed,
                color: ink,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.2,
                height: 0.95)),
      ]),
    );
  }
}

/// An editorial playlist: its songs, the editors' picks marked.
class EditorialPage extends StatefulWidget {
  const EditorialPage({super.key, required this.playlist});
  final EditorialPlaylist playlist;

  @override
  State<EditorialPage> createState() => _EditorialPageState();
}

class _EditorialPageState extends State<EditorialPage> {
  EditorialView? _view;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final v = await context.careerRead.read(Cmd.editorial(widget.playlist));
    if (mounted) setState(() => _view = v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final view = _view;
    final p = widget.playlist;
    final career = context.careerRead;
    return Scaffold(
      backgroundColor: StreamifyColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: view == null
          ? const Center(
              child: CircularProgressIndicator(color: StreamifyColors.accent))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        editorialColor(p).withValues(alpha: 0.6),
                        StreamifyColors.bg
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: EditorialCover(playlist: p, size: 210)),
                      const SizedBox(height: 18),
                      Text(p.displayName,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(editorialDescription(context, p),
                          style: const TextStyle(color: StreamifyColors.muted)),
                      const SizedBox(height: 8),
                      Text(
                          '$platformName · ${l.edFollowers(fmt.compact(view.followers))} · ${l.songsCount(view.rows.length)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
                if (view.rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.edEmpty,
                        style: const TextStyle(color: StreamifyColors.muted)),
                  ),
                for (final r in view.rows)
                  InkWell(
                    onTap: () => r.isPlayer
                        ? Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SongDetailScreen(
                                    songId: r.songId, state: career)))
                        : pushInCareer(
                            context, ArtistPage(artistId: r.artistId)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      child: Row(children: [
                        SizedBox(
                          width: 30,
                          child: Text('${r.position}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: StreamifyColors.muted)),
                        ),
                        CoverArt(
                            seed: songCoverSeed(r.songId, r.coverAlbumId),
                            songId: r.songId,
                            albumId: r.coverAlbumId,
                            size: 48,
                            radius: 2),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15.5,
                                        color: r.isPlayer
                                            ? StreamifyColors.accent
                                            : Colors.white)),
                                Row(children: [
                                  if (r.picked) ...[
                                    const Icon(Icons.push_pin_rounded,
                                        size: 13,
                                        color: StreamifyColors.accent),
                                    const SizedBox(width: 3),
                                  ],
                                  Expanded(
                                    child: Text(
                                        r.picked
                                            ? '${l.edPick} · ${r.artistName}'
                                            : r.artistName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: StreamifyColors.muted,
                                            fontSize: 13)),
                                  ),
                                ]),
                              ]),
                        ),
                        Text(fmt.compact(r.plays),
                            style: const TextStyle(
                                color: StreamifyColors.muted, fontSize: 13)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
