import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';

/// The player's social media (docs K93): post, and read what fans say
/// about the releases, the charts, the awards and the posts.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key, required this.state});
  final CareerState state;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  SocialView? _view;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await widget.state.read(Cmd.social());
    if (mounted) setState(() => _view = v);
  }

  Future<void> _post(PostKind kind) async {
    final l = context.l10n;
    final v = _view!;
    var songId = -1;
    if (kind == PostKind.promote) {
      final picked = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l.pickSongToShare,
                  style: Theme.of(c).textTheme.titleLarge),
            ),
            for (final (id, title) in v.songs)
              ListTile(
                leading: const Icon(Icons.music_note_rounded),
                title: Text(title),
                onTap: () => Navigator.pop(c, id),
              ),
          ]),
        ),
      );
      if (picked == null) return;
      songId = picked;
    }
    setState(() => _posting = true);
    try {
      final out = await widget.state.act(Cmd.post(kind, songId: songId));
      if (mounted) {
        if (out.backlash) {
          showInfo(context, l.postBacklash, icon: Icons.warning_amber_rounded);
        } else {
          showInfo(context, l.postDone, icon: Icons.chat_bubble_rounded);
        }
      }
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final v = _view;
    return Scaffold(
      appBar: AppBar(title: Text(v == null ? '' : fmt.network(v.network))),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _Profile(view: v, state: widget.state),
                const SizedBox(height: 14),
                if (v.canPost)
                  _Composer(
                      view: v,
                      energy: widget.state.player.creativeEnergy,
                      busy: _posting,
                      onPost: _post)
                else
                  Text(context.l10n.socialLocked,
                      style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 18),
                if (v.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(context.l10n.socialEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  for (final i in v.items)
                    FeedPost(item: i, state: widget.state),
              ],
            ),
    );
  }
}

/// The player's handle on social media.
String playerHandle(String name) =>
    '@${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';

const _handleWords = [
  'melodymaker',
  'nightdrive',
  'vinylhoarder',
  'chartwatcher',
  'bassline',
  'popdiary',
  'replyguy',
  'lyricfreak',
  'stagelights',
  'headphonesalways',
  'midnightradio',
  'echoes',
  'loudmusic',
  'frontrow',
  'setlist',
  'bridgeenjoyer',
  'falsetto',
  'b_side',
  'encore',
  'bedroompop',
];

/// A fan's handle: a stan account named after the player, or a music
/// nerd's (stable for the fan's seed).
String fanHandle(int seed, String artist) {
  final short = artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final n = seed % 1000;
  final word = _handleWords[(seed >> 4) % _handleWords.length];
  return switch (seed % 12) {
    0 || 1 => '@${short}stan$n',
    2 => '@${short}daily',
    3 => '@${short}x$word',
    4 || 5 => '@$word$n',
    6 || 7 => '@${word}_',
    8 => '@its$word',
    _ => '@$word${n % 100}',
  };
}

class _Profile extends StatelessWidget {
  const _Profile({required this.view, required this.state});
  final SocialView view;
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final p = state.player;
    return Row(children: [
      ArtistAvatar(name: p.name, seed: p.id, size: 64, artistId: p.id),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.text)),
          Text(playerHandle(p.name),
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(l.followersValue(fmt.compact(view.followers)),
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.text)),
        ]),
      ),
      if (view.canPost)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppShape.r(8))),
          child: Text('${view.postsLeft}/${Social.postsPerWeek}',
              style: TextStyle(
                  fontFamily: AppFonts.condensed,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.text)),
        ),
    ]);
  }
}

/// The five kinds of post, each with what it does and its energy.
class _Composer extends StatelessWidget {
  const _Composer(
      {required this.view,
      required this.energy,
      required this.busy,
      required this.onPost});
  final SocialView view;
  final double energy;
  final bool busy;
  final void Function(PostKind) onPost;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return Section(
      title: l.socialPostsLeft(view.postsLeft),
      icon: Icons.edit_rounded,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      child: Column(children: [
        for (final k in PostKind.values)
          ListTile(
            dense: true,
            enabled: !busy &&
                view.postsLeft > 0 &&
                energy >= k.energy &&
                (k != PostKind.teaser || view.hasTeaser) &&
                (k != PostKind.promote || view.songs.isNotEmpty),
            leading: Icon(switch (k) {
              PostKind.teaser => Icons.visibility_rounded,
              PostKind.studio => Icons.photo_camera_rounded,
              PostKind.fans => Icons.forum_rounded,
              PostKind.hotTake => Icons.local_fire_department_rounded,
              PostKind.promote => Icons.campaign_rounded,
            }),
            title: Text(fmt.postKind(k),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(fmt.postKindHint(k)),
            trailing: Text(l.postEnergy(k.energy.round()),
                style: TextStyle(color: AppColors.textMuted)),
            onTap: () => onPost(k),
          ),
      ]),
    );
  }
}

/// One post in the feed: the player's own marked with the accent.
class FeedPost extends StatelessWidget {
  const FeedPost({super.key, required this.item, required this.state});
  final SocialItemView item;
  final CareerState state;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final p = state.player;
    final handle =
        item.isPlayer ? playerHandle(p.name) : fanHandle(item.fan, p.name);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: item.isPlayer ? AppColors.accentSoft : null,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        item.isPlayer
            ? ArtistAvatar(name: p.name, seed: p.id, size: 38, artistId: p.id)
            : ArtistAvatar(name: handle.substring(1), seed: item.fan, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(item.isPlayer ? p.name : handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.text)),
              ),
              const SizedBox(width: 6),
              Text('· ${fmt.feedAge(item.week, state.week)}',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            ]),
            const SizedBox(height: 2),
            Text(fmt.social(item, p.name),
                style: TextStyle(color: AppColors.text, height: 1.3)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.favorite_border_rounded,
                  size: 15, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(fmt.compact(item.likes.toDouble()),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
