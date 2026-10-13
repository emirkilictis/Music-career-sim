import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/event_icon.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await widget.state.read(Cmd.platform(widget.platform));
    if (mounted) setState(() => _view = v);
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
                  if (v != null)
                    Section(
                      title: l.platformYourWeek,
                      icon: platformIcon(p),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                v.playerWeek < 1
                                    ? l.platformNothingYet
                                    : fmt.platformWeek(p, v.playerWeek),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            if (v.playerBestSongId >= 0) ...[
                              const SizedBox(height: 4),
                              Text(l.platformBest(v.playerBestTitle),
                                  style: TextStyle(color: AppColors.textMuted)),
                            ],
                          ]),
                    ),
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
