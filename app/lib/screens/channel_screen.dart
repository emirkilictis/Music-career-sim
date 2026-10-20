import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'song_detail_screen.dart';

/// The player's channel on the video site (docs K142): subscribers, views,
/// every video, and uploads beyond the music video.
class ChannelScreen extends StatefulWidget {
  const ChannelScreen({super.key, required this.state, required this.color});
  final CareerState state;
  final Color color;

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  ChannelView? _view;
  bool _popular = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await widget.state.read(Cmd.channel());
    if (mounted) setState(() => _view = v);
  }

  /// Picks a kind, then a song for a song video, and uploads it.
  Future<void> _upload(ChannelView v) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final kind = await showModalBottomSheet<VideoKind>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l.channelUpload,
                  style: Theme.of(c).textTheme.titleLarge),
            ),
            for (final k in v.kinds)
              ListTile(
                enabled: k.forSong
                    ? v.songs.any((s) => !(v.made[s.$1]?.contains(k) ?? false))
                    : !v.artistVideoThisWeek,
                leading: Icon(videoKindIcon(k), color: widget.color),
                title: Text(fmt.videoKind(k)),
                subtitle: Text(
                    '${fmt.videoKindHint(k)}\n'
                    '${fmt.money(k.costCents)} · ${l.energyCost(k.energy.round())}'),
                isThreeLine: true,
                onTap: () => Navigator.pop(c, k),
              ),
          ]),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    var songId = -1;
    if (kind.forSong) {
      final picked = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(c).size.height * 0.8),
            child: ListView(shrinkWrap: true, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(l.channelPickSong(fmt.videoKind(kind)),
                    style: Theme.of(c).textTheme.titleMedium),
              ),
              for (final (id, title) in v.songs)
                if (!(v.made[id]?.contains(kind) ?? false))
                  ListTile(
                    title: Text(title),
                    onTap: () => Navigator.pop(c, id),
                  ),
            ]),
          ),
        ),
      );
      if (picked == null || !mounted) return;
      songId = picked;
    }
    try {
      await widget.state.act(Cmd.uploadVideo(kind, songId));
      if (mounted) {
        showInfo(context, l.channelUploaded(fmt.videoKind(kind)),
            icon: videoKindIcon(kind));
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = _view;
    final color = widget.color;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.channelTitle),
        backgroundColor: Color.lerp(color, AppColors.bg, 0.6),
        foregroundColor: Colors.white,
      ),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              // The banner and the channel's numbers.
              Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    color,
                    Color.lerp(color, AppColors.bg, 0.7)!,
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  ArtistAvatar(
                      name: v.name,
                      seed: v.artistId,
                      size: 72,
                      artistId: v.artistId),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w900)),
                          Text(
                              l.channelStats(
                                  fmt.compact(v.subscribers),
                                  v.videos.length,
                                  fmt.compact(v.totalViews)),
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ]),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: v.open
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: color),
                        onPressed: () => _upload(v),
                        icon: const Icon(Icons.file_upload_outlined),
                        label: Text(l.channelUpload),
                      )
                    : Text(l.channelClosed,
                        style: TextStyle(color: AppColors.textMuted)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(l.channelHint,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ),
              if (v.hasVideos)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text(l.channelLatest)),
                      ButtonSegment(value: true, label: Text(l.channelPopular)),
                    ],
                    selected: {_popular},
                    onSelectionChanged: (s) =>
                        setState(() => _popular = s.first),
                  ),
                ),
              const SizedBox(height: 8),
              if (!v.hasVideos)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.channelEmpty,
                      style: TextStyle(color: AppColors.textFaint)),
                ),
              for (final r in _popular ? v.popular : v.videos)
                _VideoTile(
                    row: r,
                    color: color,
                    onTap: r.songId < 0
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SongDetailScreen(
                                    songId: r.songId, state: widget.state)))),
            ]),
    );
  }
}

/// One video: a 16:9 thumbnail, its title and views.
class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.row, required this.color, this.onTap});
  final ChannelVideoRow row;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final r = row;
    final kind = r.kind;
    final title = r.songId < 0
        ? fmt.videoKind(kind!)
        : '${r.title} (${kind == null ? l.channelMusicVideo : fmt.videoKind(kind)})';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 128,
            height: 72,
            child: Stack(fit: StackFit.expand, children: [
              if (r.songId >= 0)
                ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: CoverArt(
                        seed: songCoverSeed(r.songId, r.albumId),
                        size: 128,
                        radius: 0,
                        songId: r.songId,
                        albumId: r.albumId),
                  ),
                )
              else
                ColoredBox(color: Color.lerp(color, AppColors.bg, 0.5)!),
              Center(
                child: Icon(
                    kind == null
                        ? Icons.play_circle_fill_rounded
                        : videoKindIcon(kind),
                    size: 30,
                    color: Colors.white.withValues(alpha: 0.9)),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                      '${l.videosViews(fmt.compact(r.views))} · ${fmt.week(r.week)}',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ]),
          ),
        ]),
      ),
    );
  }
}

/// The icon of a channel video kind.
IconData videoKindIcon(VideoKind k) => switch (k) {
      VideoKind.lyric => Icons.subtitles_outlined,
      VideoKind.visualizer => Icons.graphic_eq_rounded,
      VideoKind.live => Icons.mic_external_on_outlined,
      VideoKind.acoustic => Icons.music_note_outlined,
      VideoKind.dance => Icons.directions_run_rounded,
      VideoKind.behindScenes => Icons.movie_filter_outlined,
      VideoKind.vlog => Icons.videocam_outlined,
    };
