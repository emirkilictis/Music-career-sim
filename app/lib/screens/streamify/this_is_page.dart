import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';

import '../../core/scope.dart';
import '../../ui/palette.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import '../song_detail_screen.dart';
import 'artist_page.dart';

/// Square "This Is" cover in the artist's colors (docs K189).
class ThisIsCover extends StatelessWidget {
  const ThisIsCover(
      {super.key,
      required this.name,
      required this.seed,
      this.size = 146,
      this.locked = false});
  final String name;
  final int seed;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final (a, b) = streamifyHeaderColors(seed);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: locked ? [Colors.grey.shade800, Colors.black] : [a, b]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(locked ? Icons.lock_outline_rounded : Icons.graphic_eq_rounded,
            color: Colors.white, size: size * 0.13),
        const Spacer(),
        Text('THIS IS',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: size * 0.1)),
        Text(name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: StreamifyColors.accent,
                fontWeight: FontWeight.w900,
                height: 1.05,
                fontSize: size * 0.13)),
      ]),
    );
  }
}

/// An artist's This Is list (docs K189): the essential songs, the new ones
/// near the top; for the player, what each song gets from it.
class ThisIsPage extends StatelessWidget {
  const ThisIsPage({super.key, required this.view, required this.seed});
  final ThisIsView view;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final v = view;
    const muted = TextStyle(color: StreamifyColors.muted, fontSize: 13);
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: StreamifyColors.bg,
        colorScheme: Theme.of(context)
            .colorScheme
            .copyWith(primary: StreamifyColors.accent),
      ),
      child: Scaffold(
        backgroundColor: StreamifyColors.bg,
        appBar: AppBar(
          backgroundColor: StreamifyColors.bg,
          foregroundColor: Colors.white,
          title: Text(l.thisIsTitle(v.artistName)),
        ),
        body: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ThisIsCover(
                  name: v.artistName, seed: seed, size: 220, locked: !v.made),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.thisIsTitle(v.artistName),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(l.thisIsBlurb, style: muted),
              const SizedBox(height: 4),
              Text(
                  [
                    'Streamify',
                    if (v.made) l.thisIsSongs(v.songs.length),
                    if (v.madeWeek >= 0) l.thisIsSince(fmt.week(v.madeWeek)),
                  ].join(' · '),
                  style: muted),
              if (v.isPlayer) ...[
                const SizedBox(height: 10),
                Text(
                    v.made
                        ? l.thisIsHint
                        : l.thisIsLocked(
                            v.eligible,
                            ThisIs.minSongs,
                            fmt.compact(v.listeners),
                            fmt.compact(ThisIs.minListeners)),
                    style: const TextStyle(fontSize: 13.5)),
              ],
              const SizedBox(height: 8),
            ]),
          ),
          for (var i = 0; i < v.songs.length; i++)
            _row(context, i, v.songs[i],
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SongDetailScreen(
                            songId: v.songs[i].id, state: career)))),
        ]),
      ),
    );
  }

  Widget _row(BuildContext context, int i, SongView s, VoidCallback onTap) {
    final l = context.l10n;
    final v = view;
    return InkWell(
      onTap: v.isPlayer ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(children: [
          SizedBox(
            width: 26,
            child: Text('${i + 1}',
                style: const TextStyle(
                    color: StreamifyColors.muted, fontWeight: FontWeight.w600)),
          ),
          CoverArt(
              seed: songCoverSeed(s.id, s.coverAlbumId),
              size: 46,
              radius: 2,
              songId: s.id,
              albumId: s.coverAlbumId),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15.5)),
              const SizedBox(height: 2),
              Row(children: [
                if (v.newIds.contains(s.id)) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: StreamifyColors.accent,
                        borderRadius: BorderRadius.circular(2)),
                    child: Text(l.thisIsNew,
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(streamifyPlays(context, s.lifetimeStreams.total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: StreamifyColors.muted, fontSize: 13)),
                ),
              ]),
            ]),
          ),
          if (i < v.lifts.length)
            Text(l.thisIsLift((v.lifts[i] * 100).round()),
                style: const TextStyle(
                    color: StreamifyColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5)),
        ]),
      ),
    );
  }
}
