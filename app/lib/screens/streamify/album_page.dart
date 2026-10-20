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
import '../album_detail_screen.dart';
import '../song_detail_screen.dart';

/// Streamify album page, laid out like a big streaming app's (docs F23):
/// cover over a tinted header, title and artist, controls, the tracklist
/// with each track's plays, release date and totals.
class StreamifyAlbumPage extends StatefulWidget {
  const StreamifyAlbumPage({super.key, required this.albumId});
  final int albumId;

  @override
  State<StreamifyAlbumPage> createState() => _StreamifyAlbumPageState();
}

class _StreamifyAlbumPageState extends State<StreamifyAlbumPage> {
  (AlbumView, List<SongView>)? _page;

  /// The bar shows the title once the big one has scrolled away.
  final _scroll = ScrollController();
  final _showTitle = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _showTitle.value = _scroll.offset > 300);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _showTitle.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final page = await context.careerRead.read(Cmd.albumPage(widget.albumId));
    if (mounted) setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      backgroundColor: StreamifyColors.bg,
      body: page == null
          ? const Center(
              child: CircularProgressIndicator(color: StreamifyColors.accent))
          : _content(context, page.$1, page.$2),
    );
  }

  Widget _content(BuildContext context, AlbumView al, List<SongView> tracks) {
    final l = context.l10n;
    final fmt = context.fmt;
    final career = context.careerRead;
    final plays = NumberFormat.decimalPattern(l.localeName);
    final c1 = coverColor(albumCoverSeed(al.id));
    final year = GameTime.yearOf(al.releaseWeek);
    final (month, _) = Fmt.monthWeek(GameTime.weekOfYear(al.releaseWeek));
    final total = tracks.fold(0.0, (sum, s) => sum + s.lifetimeStreams.total);
    String count(double streams) =>
        plays.format((streams * Streamify.share).round());
    void openSong(SongView s) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SongDetailScreen(songId: s.id, state: career)));

    return CustomScrollView(controller: _scroll, slivers: [
      SliverAppBar(
        pinned: true,
        backgroundColor: Color.lerp(c1, StreamifyColors.bg, 0.55),
        foregroundColor: Colors.white,
        title: ValueListenableBuilder(
          valueListenable: _showTitle,
          builder: (_, show, __) => AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Text(al.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(c1, StreamifyColors.bg, 0.55)!,
                StreamifyColors.bg,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: DecoratedBox(
                  decoration: const BoxDecoration(boxShadow: [
                    BoxShadow(
                        color: Color(0x99000000),
                        blurRadius: 24,
                        offset: Offset(0, 10)),
                  ]),
                  child: CoverArt(
                      seed: albumCoverSeed(al.id),
                      size: 240,
                      radius: 2,
                      albumId: al.id),
                ),
              ),
              const SizedBox(height: 20),
              Text(al.title,
                  style: const TextStyle(
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 10),
              Row(children: [
                ArtistAvatar(
                    name: al.artistName,
                    seed: al.artistId,
                    size: 24,
                    artistId: al.artistId,
                    photo: ArtistPhoto.streamify),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(al.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ]),
              const SizedBox(height: 6),
              Text('${fmt.albumType(al.type)} · $year',
                  style: const TextStyle(
                      color: StreamifyColors.muted, fontSize: 13)),
              // Not on the app yet (docs K174).
              if (career.week < al.windowUntil) ...[
                const SizedBox(height: 4),
                Text(l.windowStreamify(fmt.week(al.windowUntil)),
                    style: const TextStyle(
                        color: StreamifyColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.add_circle_outline_rounded,
                    color: StreamifyColors.muted, size: 28),
                const SizedBox(width: 20),
                const Icon(Icons.arrow_circle_down_rounded,
                    color: StreamifyColors.muted, size: 28),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: l.albumStats,
                  icon: const Icon(Icons.more_horiz_rounded,
                      color: StreamifyColors.muted),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AlbumDetailScreen(
                              albumId: al.id, state: career))),
                ),
                const Spacer(),
                const Icon(Icons.shuffle_rounded,
                    color: StreamifyColors.muted, size: 26),
                const SizedBox(width: 14),
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                      color: StreamifyColors.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.black, size: 34),
                ),
              ]),
              const SizedBox(height: 4),
            ]),
          ),
        ),
      ),
      SliverList.builder(
        itemCount: tracks.length,
        itemBuilder: (context, i) {
          final s = tracks[i];
          return InkWell(
            onTap: () => openSong(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                SizedBox(
                  width: 28,
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: StreamifyColors.muted,
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15.5)),
                        const SizedBox(height: 2),
                        Text(al.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: StreamifyColors.muted, fontSize: 13)),
                      ]),
                ),
                const SizedBox(width: 12),
                Text(count(s.lifetimeStreams.total),
                    style: const TextStyle(
                        color: StreamifyColors.muted,
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(width: 6),
                const Icon(Icons.more_vert_rounded,
                    color: StreamifyColors.muted, size: 20),
              ]),
            ),
          );
        },
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${fmt.monthName(month)} $year',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(l.albumPageTotals(tracks.length, count(total)),
                style: const TextStyle(color: StreamifyColors.muted)),
            const SizedBox(height: 14),
            Text('© $year ${al.artistName}\n℗ $year ${al.artistName}',
                style: const TextStyle(
                    color: StreamifyColors.muted, fontSize: 12)),
          ]),
        ),
      ),
    ]);
  }
}
