import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../core/social_text.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import 'social_screen.dart';

/// A post opened with its replies (docs K238): the player reads what
/// people said and answers fans and haters, on their own posts and to
/// fans posting about them.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen(
      {super.key, required this.state, required this.postKey});
  final CareerState state;
  final int postKey;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  PostDetailView? _v;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await widget.state.read(Cmd.postDetail(widget.postKey));
      if (mounted) setState(() => _v = v);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _reply(int index, ReplyKind kind) async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final out = await widget.state
          .act(Cmd.replyToComment(widget.postKey, index, kind));
      if (mounted) {
        final r = out.reply;
        final (text, icon) = switch ((kind, r.ok)) {
          (ReplyKind.thanks, _) => (l.replyDoneThanks, Icons.favorite_rounded),
          (ReplyKind.clapBack, true) => (
              l.replyDoneRoast,
              Icons.local_fire_department_rounded
            ),
          (ReplyKind.clapBack, false) => (
              l.replyDonePetty,
              Icons.warning_amber_rounded
            ),
          (ReplyKind.kind, true) => (l.replyDoneSoftened, Icons.spa_rounded),
          (ReplyKind.kind, false) => (l.replyDoneIgnored, Icons.spa_rounded),
        };
        showInfo(context, text, icon: icon);
      }
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = _v;
    if (v == null) {
      return Scaffold(
          backgroundColor: SocialSkin.chirper.bg,
          body: const Center(child: CircularProgressIndicator()));
    }
    final skin = SocialSkin.of(v.network);
    final p = widget.state.player;
    final post = v.post;
    final canAnswer = v.canReply && v.repliesLeft > 0 && !_busy;
    final author = post.isPlayer
        ? ''
        : post.isRival
            ? post.rivalName
            : fanHandle(post.fan, p.name);
    return Theme(
      data: Theme.of(context)
          .copyWith(scaffoldBackgroundColor: skin.bg, dividerColor: skin.line),
      child: Scaffold(
        backgroundColor: skin.bg,
        appBar: AppBar(
          backgroundColor: skin.bar,
          foregroundColor: skin.barText,
          surfaceTintColor: Colors.transparent,
          shape: Border(bottom: BorderSide(color: skin.line)),
          title: Text(l.postTitle,
              style: TextStyle(
                  color: skin.barText,
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            FeedPost(
                item: post,
                state: widget.state,
                skin: skin,
                verified: v.verified),
            // A fan's post: answer its author.
            if (v.authorMood case final mood?)
              v.authorReply == null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.replyToAuthor(author),
                                style:
                                    TextStyle(color: skin.muted, fontSize: 13)),
                            const SizedBox(height: 6),
                            _Answers(
                                mood: mood,
                                skin: skin,
                                enabled: canAnswer,
                                onReply: (k) => _reply(Comments.author, k)),
                          ]),
                    )
                  : _ReplyThread(
                      reply: v.authorReply!,
                      fan: post.fan,
                      state: widget.state,
                      skin: skin,
                      verified: v.verified,
                      title: post.title),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: skin.line))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(l.commentsTitle,
                          style: TextStyle(
                              color: skin.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 17)),
                      const Spacer(),
                      if (v.canReply)
                        Text(l.repliesLeft(v.repliesLeft),
                            style:
                                TextStyle(color: skin.muted, fontSize: 12.5)),
                    ]),
                    if (v.canReply && post.isPlayer) ...[
                      const SizedBox(height: 4),
                      Text(l.replyHint,
                          style: TextStyle(color: skin.muted, fontSize: 12.5)),
                    ],
                  ]),
            ),
            if (v.comments.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.commentsEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: skin.muted)),
              ),
            for (final c in v.comments)
              _CommentTile(
                comment: c,
                post: post,
                state: widget.state,
                skin: skin,
                verified: v.verified,
                canAnswer: canAnswer && c.answerable,
                onReply: (k) => _reply(c.index, k),
              ),
          ],
        ),
      ),
    );
  }
}

/// The answers a comment allows: a thank-you for fans and questions, a
/// clap-back or kindness for haters.
class _Answers extends StatelessWidget {
  const _Answers(
      {required this.mood,
      required this.skin,
      required this.enabled,
      required this.onReply});
  final CommentMood mood;
  final SocialSkin skin;
  final bool enabled;
  final void Function(ReplyKind) onReply;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget button(ReplyKind k, String label, IconData icon, Color color) =>
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: enabled ? color : skin.line),
            visualDensity: VisualDensity.compact,
            shape: skin.round
                ? const StadiumBorder()
                : const RoundedRectangleBorder(),
          ),
          onPressed: enabled ? () => onReply(k) : null,
          icon: Icon(icon, size: 16),
          label: Text(label),
        );
    return Wrap(spacing: 8, runSpacing: 6, children: [
      if (mood != CommentMood.hater)
        button(ReplyKind.thanks, l.replyThanksButton, Icons.favorite_rounded,
            SocialSkin.like)
      else ...[
        button(ReplyKind.clapBack, l.replyClapBackButton,
            Icons.local_fire_department_rounded, AppColors.coral),
        button(
            ReplyKind.kind, l.replyKindButton, Icons.spa_rounded, skin.accent),
      ],
    ]);
  }
}

/// One reply under the post.
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.post,
    required this.state,
    required this.skin,
    required this.verified,
    required this.canAnswer,
    required this.onReply,
  });
  final CommentView comment;
  final SocialItemView post;
  final CareerState state;
  final SocialSkin skin;
  final bool verified;
  final bool canAnswer;
  final void Function(ReplyKind) onReply;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = comment;
    final p = state.player;
    final text = socialText(l, c.topic, c.variant,
        title: post.title, name: p.name, n: '');
    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: skin.line))),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Line(
          seed: c.fan,
          artist: p.name,
          skin: skin,
          text: text,
          likes: c.likes,
          tag: c.mood == CommentMood.hater
              ? (l.commentHaterTag, AppColors.coral)
              : null,
          replyingTo: post.isPlayer ? playerHandle(p.name) : null,
        ),
        if (c.reply case final r?)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 8),
            child: _ReplyThread(
                reply: r,
                fan: c.fan,
                state: state,
                skin: skin,
                verified: verified,
                title: post.title,
                bare: true),
          )
        else if (c.answerable)
          Padding(
            padding: const EdgeInsets.only(left: 50, top: 8),
            child: _Answers(
                mood: c.mood, skin: skin, enabled: canAnswer, onReply: onReply),
          ),
      ]),
    );
  }
}

/// The player's answer and what came back.
class _ReplyThread extends StatelessWidget {
  const _ReplyThread({
    required this.reply,
    required this.fan,
    required this.state,
    required this.skin,
    required this.verified,
    required this.title,
    this.bare = false,
  });
  final ReplyView reply;

  /// The handle seed of the person answered.
  final int fan;
  final CareerState state;
  final SocialSkin skin;
  final bool verified;
  final String title;

  /// Inside a comment (no own padding).
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = state.player;
    final reaction = reply.reaction;
    final body =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ArtistAvatar(
            name: p.name,
            seed: p.id,
            size: 34,
            artistId: p.id,
            square: !skin.round),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                  child: NameLine(
                      name: p.name, verified: verified, skin: skin, size: 14)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(playerHandle(p.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: skin.muted, fontSize: 13)),
              ),
            ]),
            Text(l.replyingTo(fanHandle(fan, p.name)),
                style: TextStyle(color: skin.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(
                socialText(l, reply.topic, reply.variant,
                    title: title, name: p.name, n: ''),
                style:
                    TextStyle(color: skin.text, fontSize: 14.5, height: 1.3)),
          ]),
        ),
      ]),
      if (reaction != null)
        Padding(
          padding: const EdgeInsets.only(left: 30, top: 8),
          child: _Line(
            seed: reply.reactionByOther ? fan ^ 0x5A5A5 : fan,
            artist: p.name,
            skin: skin,
            text: socialText(l, reaction, reply.variant + 3,
                title: title, name: p.name, n: ''),
            likes: 0,
            replyingTo: playerHandle(p.name),
            small: true,
          ),
        ),
    ]);
    return bare
        ? body
        : Container(
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: skin.line))),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: body);
  }
}

/// A fan's line: avatar, name, handle, words, likes.
class _Line extends StatelessWidget {
  const _Line({
    required this.seed,
    required this.artist,
    required this.skin,
    required this.text,
    required this.likes,
    this.tag,
    this.replyingTo,
    this.small = false,
  });
  final int seed;
  final String artist;
  final SocialSkin skin;
  final String text;
  final int likes;
  final (String, Color)? tag;
  final String? replyingTo;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = fanName(seed, artist);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ArtistAvatar(
          name: name.split(' | ').first,
          seed: seed,
          size: small ? 30 : 38,
          square: !skin.round),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
                child: NameLine(
                    name: name, verified: false, skin: skin, size: 14)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(fanHandle(seed, artist),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: skin.muted, fontSize: 13)),
            ),
            if (tag case (final label, final color)) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(skin.round ? 10 : 0)),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
          if (replyingTo != null)
            Text(l.replyingTo(replyingTo!),
                style: TextStyle(color: skin.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(text,
              style: TextStyle(
                  color: skin.text, fontSize: small ? 14 : 15, height: 1.3)),
          if (likes > 0) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.favorite_border_rounded, size: 15, color: skin.muted),
              const SizedBox(width: 4),
              Text(context.fmt.compact(likes.toDouble()),
                  style: TextStyle(color: skin.muted, fontSize: 12.5)),
            ]),
          ],
        ]),
      ),
    ]);
  }
}
