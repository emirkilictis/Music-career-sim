import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/images.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/event_icon.dart';
import 'channel_screen.dart';
import 'song_detail_screen.dart';

/// One music platform (docs K67): your week there and its Top 50.
class PlatformScreen extends StatefulWidget {
  const PlatformScreen(
      {super.key, required this.platform, required this.state});
  final MusicPlatform platform;
  final CareerState state;

  @override
  State<PlatformScreen> createState() => _PlatformScreenState();
}

class _PlatformScreenState extends State<PlatformScreen> {
  PlatformView? _view;

  /// On the video site: the player's videos and the billion club (K118).
  (List<VideoRow>, List<VideoRow>)? _videos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await widget.state.read(Cmd.platform(widget.platform));
    final videos = widget.platform == MusicPlatform.viewTube
        ? await widget.state.read(Cmd.videos())
        : null;
    if (mounted) {
      setState(() {
        _view = v;
        _videos = videos;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final p = widget.platform;
    final color = platformColor(p);
    final v = _view;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 170,
          backgroundColor: Color.lerp(color, AppColors.bg, 0.6),
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            centerTitle: false,
            titlePadding:
                const EdgeInsetsDirectional.only(start: 56, bottom: 14),
            title: Text(p.displayName,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: Colors.white)),
            background: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, Color.lerp(color, AppColors.bg, 0.75)!],
                ),
              ),
              child: Align(
                alignment: const Alignment(0.85, -0.1),
                child: Icon(platformIcon(p),
                    size: 96, color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(fmt.platformTagline(p),
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  if (v != null) _ProfileCard(view: v, color: color),
                  // The player's channel (docs K142).
                  if (p == MusicPlatform.viewTube) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChannelScreen(
                                  state: widget.state, color: color))).then(
                          (_) => _load()),
                      icon: const Icon(Icons.video_library_outlined),
                      label: Text(l.channelOpen),
                    ),
                  ],
                  if (_videos case (final mine, final club)) ...[
                    if (mine.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _VideoList(
                          title: l.videosMine,
                          rows: mine,
                          color: color,
                          state: widget.state),
                    ],
                    const SizedBox(height: 16),
                    _VideoList(
                        title: l.videosBillion,
                        rows: club,
                        color: color,
                        state: widget.state,
                        empty: l.videosBillionEmpty),
                  ],
                  const SizedBox(height: 16),
                  Text(caps(context, l.platformTop(Platforms.chartSize)),
                      style: capsStyle(const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800))),
                  const SizedBox(height: 6),
                ]),
          ),
        ),
        if (v == null)
          const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator())))
        else if (v.rows.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.platformEmpty,
                  style: TextStyle(color: AppColors.textFaint)),
            ),
          )
        else
          SliverList.builder(
            itemCount: v.rows.length,
            itemBuilder: (context, i) {
              final r = v.rows[i];
              return InkWell(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SongDetailScreen(
                            songId: r.songId, state: widget.state))),
                child: Container(
                  color: r.isPlayer ? color.withValues(alpha: 0.12) : null,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    SizedBox(
                      width: 30,
                      child: Text('${r.position}',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: r.position <= 3
                                  ? color
                                  : AppColors.textMuted)),
                    ),
                    CoverArt(
                        seed: songCoverSeed(r.songId, r.coverAlbumId),
                        size: 44,
                        songId: r.songId,
                        albumId: r.coverAlbumId),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(r.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13)),
                          ]),
                    ),
                    const SizedBox(width: 8),
                    Text(fmt.compact(r.value),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted)),
                  ]),
                ),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }
}

/// The player's own page on the platform (docs K82): photo, name, the
/// blue tick, followers, and their week there.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.view, required this.color});
  final PlatformView view;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = view;
    final me = v.profile;
    final p = v.platform;
    final followers = me?.followers;
    return Section(
      title: l.platformYourWeek,
      icon: platformIcon(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (me != null) ...[
          Row(children: [
            ArtistAvatar(
                name: me.name,
                seed: me.artistId,
                size: 60,
                artistId: me.artistId,
                photo: p == MusicPlatform.streamify
                    ? ArtistPhoto.streamify
                    : ArtistPhoto.general),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(me.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w900)),
                      ),
                      if (me.verified) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified_rounded, size: 18, color: color),
                      ],
                    ]),
                    if (followers != null)
                      Text(
                          p == MusicPlatform.viewTube
                              ? l.subscribersValue(fmt.compact(followers))
                              : l.followersValue(fmt.compact(followers)),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (me.monthlyListeners >= 1)
                      Text(l.monthlyListeners(fmt.compact(me.monthlyListeners)),
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                  ]),
            ),
          ]),
          const SizedBox(height: 14),
        ],
        Text(
            v.playerWeek < 1
                ? l.platformNothingYet
                : fmt.platformWeek(p, v.playerWeek),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (v.playerBestSongId >= 0) ...[
          const SizedBox(height: 4),
          Text(l.platformBest(v.playerBestTitle),
              style: TextStyle(color: AppColors.textMuted)),
        ],
      ]),
    );
  }
}

/// Videos with their all-time views (docs K118).
class _VideoList extends StatelessWidget {
  const _VideoList(
      {required this.title,
      required this.rows,
      required this.color,
      required this.state,
      this.empty});
  final String title;
  final List<VideoRow> rows;
  final Color color;
  final CareerState state;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(caps(context, title),
          style: capsStyle(
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      const SizedBox(height: 6),
      if (rows.isEmpty && empty != null)
        Text(empty!, style: TextStyle(color: AppColors.textFaint)),
      for (final r in rows)
        InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      SongDetailScreen(songId: r.songId, state: state))),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              CoverArt(
                  seed: songCoverSeed(r.songId, r.albumId),
                  size: 44,
                  radius: 4,
                  songId: r.songId,
                  albumId: r.albumId),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                          '${r.artistName} · ${l.videosViews(fmt.compact(r.views))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                    ]),
              ),
              if (r.views >= Platforms.billionViews)
                Tag('1B+', color: color)
              else if (r.views >= Platforms.certifiedViews)
                Tag(l.videoCertified, color: color)
              else if (!r.hasVideo)
                Text(l.videoNoVideo,
                    style: TextStyle(fontSize: 12, color: AppColors.textFaint)),
            ]),
          ),
        ),
    ]);
  }
}
