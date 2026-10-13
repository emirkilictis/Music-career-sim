import 'package:flutter/material.dart' hide Actions;
import 'package:game/game.dart';
import 'package:intl/intl.dart';

import '../../core/commands.dart';
import '../../core/format.dart';
import '../../core/images.dart';
import '../../core/scope.dart';
import '../../ui/palette.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import '../game_shell.dart';
import '../song_detail_screen.dart';
import 'artist_page.dart';
import 'playlist_page.dart';

const _top50 = [
  Charts.platformGlobal,
  Charts.platformNorthAmerica,
  Charts.platformEurope,
];

/// The in-game streaming app: your artist profile and its Top 50 charts.
/// One of several platforms (opened from Home → Platforms).
class StreamifyScreen extends StatefulWidget {
  const StreamifyScreen({super.key});

  @override
  State<StreamifyScreen> createState() => _StreamifyScreenState();
}

class _StreamifyScreenState extends State<StreamifyScreen> {
  ArtistPageView? _me;
  List<int> _active = const [];
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
    final career = context.careerRead;
    final me = await career.read(Cmd.artistPage(career.player.id));
    final active = await career.read(Cmd.activeCharts());
    if (mounted) {
      setState(() {
        _me = me;
        _active = active;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = _me;
    final career = context.career;
    final p = career.player;
    final charts = _top50.where(_active.contains).toList();
    final plays = NumberFormat.decimalPattern(l.localeName);
    TextStyle h = const TextStyle(fontSize: 22, fontWeight: FontWeight.w900);

    return Scaffold(
        backgroundColor: StreamifyColors.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Row(children: [
                Transform.translate(
                    offset: const Offset(-12, 0),
                    child: const BackButton(color: Colors.white)),
                const SizedBox(width: 0),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                      color: StreamifyColors.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.graphic_eq_rounded,
                      color: Colors.black, size: 22),
                ),
                const SizedBox(width: 10),
                const Text(platformName,
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(context.fmt.week(career.week),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: StreamifyColors.muted,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 22),
              Text(l.yourProfile, style: h),
              const SizedBox(height: 12),
              Material(
                color: StreamifyColors.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () =>
                      pushInCareer(context, ArtistPage(artistId: p.id)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      ArtistAvatar(
                          name: p.name,
                          seed: p.id,
                          size: 72,
                          artistId: p.id,
                          photo: ArtistPhoto.streamify),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(
                                  l.monthlyListeners(plays.format(
                                      (me?.monthlyListeners ?? 0).round())),
                                  style: const TextStyle(
                                      color: StreamifyColors.muted)),
                            ]),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: StreamifyColors.muted),
                    ]),
                  ),
                ),
              ),
              if (charts.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text(l.streamifyCharts, style: h),
                const SizedBox(height: 12),
                SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: charts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => InkWell(
                      onTap: () => pushInCareer(
                          context, PlaylistPage(chartId: charts[i])),
                      child: SizedBox(
                        width: 150,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Top50Cover(chartId: charts[i]),
                              const SizedBox(height: 8),
                              Text(
                                  l.top50Title(top50Region(context, charts[i])),
                                  maxLines: 2,
                                  style: const TextStyle(
                                      color: StreamifyColors.muted,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ]),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text(l.yourTopTracks, style: h),
              const SizedBox(height: 8),
              if (me == null || me.popular.isEmpty)
                EmptyNote(l.noReleasesYet)
              else
                for (final (i, s) in me.popular.take(5).indexed)
                  InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SongDetailScreen(songId: s.id, state: career))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        SizedBox(
                            width: 24,
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    color: StreamifyColors.muted,
                                    fontWeight: FontWeight.w600))),
                        CoverArt(
                            seed: songCoverSeed(s.id, s.coverAlbumId),
                            songId: s.id,
                            albumId: s.coverAlbumId,
                            size: 48,
                            radius: 2),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15.5)),
                                Text(
                                    streamifyPlays(
                                        context, s.lifetimeStreams.total),
                                    style: const TextStyle(
                                        color: StreamifyColors.muted,
                                        fontSize: 13)),
                              ]),
                        ),
                      ]),
                    ),
                  ),
            ],
          ),
        ));
  }
}
