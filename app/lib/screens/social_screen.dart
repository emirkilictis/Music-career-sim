import 'package:flutter/material.dart';
import 'package:game/game.dart';

import '../core/career_state.dart';
import 'beef_screen.dart';
import 'post_detail_screen.dart';
import '../core/commands.dart';
import '../core/scope.dart';
import '../ui/palette.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/post_media.dart';

/// How a network looks (docs K93, K94): Chirper is a black, X-like app;
/// MyPlace a 2006 profile page; the fan forum an old message board.
class SocialSkin {
  const SocialSkin._({
    required this.dark,
    required this.bg,
    required this.row,
    required this.text,
    required this.muted,
    required this.line,
    required this.accent,
    required this.bar,
    required this.barText,
    required this.round,
  });

  final bool dark;
  final Color bg, row, text, muted, line, accent, bar, barText;

  /// Round avatars and pill buttons (Chirper) or square (the 2000s).
  final bool round;

  static const chirper = SocialSkin._(
    dark: true,
    bg: Color(0xFF000000),
    row: Color(0xFF000000),
    text: Color(0xFFE7E9EA),
    muted: Color(0xFF71767B),
    line: Color(0xFF2F3336),
    accent: Color(0xFF1D9BF0),
    bar: Color(0xFF000000),
    barText: Color(0xFFE7E9EA),
    round: true,
  );

  static const myPlace = SocialSkin._(
    dark: false,
    bg: Color(0xFFFFFFFF),
    row: Color(0xFFF2F6FB),
    text: Color(0xFF111111),
    muted: Color(0xFF666666),
    line: Color(0xFFB9CBE3),
    accent: Color(0xFF003399),
    bar: Color(0xFF003399),
    barText: Color(0xFFFFFFFF),
    round: false,
  );

  static const forum = SocialSkin._(
    dark: false,
    bg: Color(0xFFE5E5E5),
    row: Color(0xFFEFEFEF),
    text: Color(0xFF111111),
    muted: Color(0xFF5F5F5F),
    line: Color(0xFFC4C9CF),
    accent: Color(0xFF006699),
    bar: Color(0xFF006699),
    barText: Color(0xFFFFFFFF),
    round: false,
  );

  static SocialSkin of(SocialNetwork n) => switch (n) {
        SocialNetwork.chirper => chirper,
        SocialNetwork.myPlace => myPlace,
        SocialNetwork.forum => forum,
      };

  static const like = Color(0xFFF91880);
}

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
  bool _mine = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await widget.state.read(Cmd.social());
    if (mounted) setState(() => _view = v);
  }

  Future<void> _compose() async {
    final v = _view!;
    final pick = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SocialSkin.of(v.network).bg,
      shape: const RoundedRectangleBorder(),
      builder: (_) => _ComposeSheet(view: v, state: widget.state),
    );
    switch (pick) {
      case final PostKind k:
        await _post(k);
      case _Diss.rival:
        await _dissRival(v.beefRivalId);
      case _Diss.haters:
        await _dissHaters();
    }
  }

  Future<void> _busy(Future<void> Function() f) async {
    setState(() => _posting = true);
    try {
      await f();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  /// A diss post at [rivalId], or at one the player picks when there is no
  /// beef on (docs K234).
  Future<void> _dissRival(int rivalId) async {
    final l = context.l10n;
    final skin = SocialSkin.of(_view!.network);
    if (rivalId < 0) {
      final targets = await widget.state.read(Cmd.dissTargets());
      if (!mounted) return;
      final picked = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        backgroundColor: skin.bg,
        builder: (c) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(c).height * 0.7),
            child: ListView(shrinkWrap: true, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(l.composePickRival,
                    style: TextStyle(
                        color: skin.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
              for (final t in targets)
                ListTile(
                  enabled: t.block == null || t.block == DissBlock.noPost,
                  leading: ArtistAvatar(
                      name: t.name, seed: t.artistId, artistId: t.artistId),
                  title: Text(t.name, style: TextStyle(color: skin.text)),
                  subtitle: Text(
                      t.block == DissBlock.cooldown
                          ? l.beefCooldown
                          : t.punch < 0
                              ? l.beefBully
                              : t.punch > 0
                                  ? l.beefBrave
                                  : context.fmt.percent(t.fame),
                      style: TextStyle(
                          color:
                              t.punch < 0 ? AppColors.coral : skin.muted)),
                  onTap: () => Navigator.pop(c, t.artistId),
                ),
            ]),
          ),
        ),
      );
      if (picked == null) return;
      rivalId = picked;
    }
    await _busy(() async {
      await widget.state.act(Cmd.dissPost(rivalId));
      if (mounted) {
        showInfo(context, l.beefPosted,
            icon: Icons.local_fire_department_rounded);
      }
    });
  }

  Future<void> _dissHaters() => _busy(() async {
        final backlash = await widget.state.act(Cmd.dissHaters());
        if (mounted) {
          final l = context.l10n;
          showInfo(context, backlash ? l.beefHatersBacklash : l.beefHatersDone,
              icon: backlash
                  ? Icons.warning_amber_rounded
                  : Icons.favorite_rounded);
        }
      });

  Future<void> _post(PostKind kind) async {
    final l = context.l10n;
    final v = _view!;
    final skin = SocialSkin.of(v.network);
    var songId = -1;
    if (kind == PostKind.promote) {
      final picked = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: skin.bg,
        builder: (c) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(l.pickSongToShare,
                  style: TextStyle(
                      color: skin.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            for (final (id, title) in v.songs)
              ListTile(
                leading: Icon(Icons.music_note_rounded, color: skin.muted),
                title: Text(title, style: TextStyle(color: skin.text)),
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
        showInfo(context, out.backlash ? l.postBacklash : l.postDone,
            icon: out.backlash
                ? Icons.warning_amber_rounded
                : Icons.chat_bubble_rounded);
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
    final v = _view;
    if (v == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final skin = SocialSkin.of(v.network);
    final items = _mine ? _ownThreads(v.items) : v.items;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: skin.bg,
        dividerColor: skin.line,
      ),
      child: Scaffold(
        backgroundColor: skin.bg,
        appBar: _bar(context, v, skin),
        floatingActionButton: v.canPost
            ? _PostButton(
                skin: skin, busy: _posting || v.postsLeft == 0, onTap: _compose)
            : null,
        body: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _Profile(view: v, state: widget.state, skin: skin),
            if (skin == SocialSkin.chirper)
              _Tabs(
                  mine: _mine,
                  skin: skin,
                  onChanged: (m) => setState(() => _mine = m))
            else
              _BoxTitle(
                  skin: skin,
                  text: v.network == SocialNetwork.forum
                      ? context.l10n.forumTitle(widget.state.player.name)
                      : context.l10n.fanComments),
            if (!v.canPost)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.socialLocked,
                    style: TextStyle(color: skin.muted)),
              ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                    _mine
                        ? context.l10n.chirperNoPosts
                        : context.l10n.socialEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: skin.muted)),
              ),
            for (final i in items)
              FeedPost(
                  item: i,
                  state: widget.state,
                  skin: skin,
                  verified: v.verified,
                  // Answer the rival right under their post (docs K234).
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PostDetailScreen(
                                state: widget.state, postKey: i.key)));
                    _load();
                  },
                  onClapBack: i.isRival &&
                          i.rivalId == v.beefRivalId &&
                          v.canPost &&
                          v.postsLeft > 0 &&
                          !_posting
                      ? () => _dissRival(i.rivalId)
                      : null),
          ],
        ),
      ),
    );
  }

  /// The player's posts with the replies under them.
  static List<SocialItemView> _ownThreads(List<SocialItemView> items) {
    final out = <SocialItemView>[];
    var inThread = false;
    for (final i in items) {
      if (i.isPlayer) {
        inThread = true;
        out.add(i);
      } else if (inThread && _isReply(i.topic)) {
        out.add(i);
      } else {
        inThread = false;
      }
    }
    return out;
  }

  static bool _isReply(FanTopic t) => switch (t) {
        FanTopic.replyTeaser ||
        FanTopic.replyStudio ||
        FanTopic.replyFans ||
        FanTopic.replyHotTake ||
        FanTopic.replyBacklash ||
        FanTopic.replyPromote =>
          true,
        _ => false,
      };

  PreferredSizeWidget _bar(BuildContext context, SocialView v, SocialSkin s) {
    final fmt = context.fmt;
    return AppBar(
      backgroundColor: s.bar,
      foregroundColor: s.barText,
      surfaceTintColor: Colors.transparent,
      centerTitle: s == SocialSkin.chirper,
      shape: s == SocialSkin.chirper
          ? Border(bottom: BorderSide(color: s.line))
          : null,
      title: s == SocialSkin.chirper
          ? const ChirperMark()
          : Text(fmt.network(v.network),
              style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontWeight: FontWeight.w900,
                  fontStyle: v.network == SocialNetwork.myPlace
                      ? FontStyle.italic
                      : FontStyle.normal,
                  fontSize: 22,
                  color: s.barText)),
      // Beefs (docs K229).
      actions: [
        IconButton(
          tooltip: context.l10n.beefTitle,
          icon: const Icon(Icons.local_fire_department_rounded),
          onPressed: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BeefScreen(state: widget.state)));
            _load();
          },
        ),
      ],
    );
  }
}

/// A handle from an artist name: "@velvetavenue".
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

const _fanNames = [
  'mira',
  'Jae',
  'sol',
  'Noa',
  'dani',
  'Kayla',
  'Emre',
  'zeynep',
  'Luca',
  'ava',
  'Theo',
  'yuki',
  'Sam',
  'ines',
  'Omar',
  'lena',
  'Kai',
  'Bea',
  'arda',
  'Nil',
  'Maya',
  'jo',
  'Ren',
  'Lou',
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

/// The name a fan shows above their handle.
String fanName(int seed, String artist) => switch (seed % 12) {
      0 || 1 => '${_fanNames[(seed >> 6) % _fanNames.length]} | $artist',
      2 => '$artist Daily',
      _ => _fanNames[(seed >> 6) % _fanNames.length],
    };

/// Banner, avatar, name, handle and counts, like an X profile; a boxed
/// profile on MyPlace and the forum.
class _Profile extends StatelessWidget {
  const _Profile({required this.view, required this.state, required this.skin});
  final SocialView view;
  final CareerState state;
  final SocialSkin skin;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final p = state.player;
    if (skin == SocialSkin.chirper) {
      final following = 80 + p.id % 400;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 150,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
                bottom: 30, child: Container(color: avatarColor(p.id))),
            Positioned(
              left: 16,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration:
                    BoxDecoration(color: skin.bg, shape: BoxShape.circle),
                child: ArtistAvatar(
                    name: p.name, seed: p.id, size: 72, artistId: p.id),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                    border: Border.all(color: skin.line),
                    borderRadius: BorderRadius.circular(99)),
                child: Text(l.socialPostsLeft(view.postsLeft),
                    style: TextStyle(
                        color: skin.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            NameLine(
                name: p.name, verified: view.verified, skin: skin, size: 20),
            Text(playerHandle(p.name), style: TextStyle(color: skin.muted)),
            const SizedBox(height: 10),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: fmt.compact(following.toDouble()),
                  style:
                      TextStyle(color: skin.text, fontWeight: FontWeight.w700)),
              TextSpan(
                  text: ' ${l.followingLabel}   ',
                  style: TextStyle(color: skin.muted)),
              TextSpan(
                  text: fmt.compact(view.followers),
                  style:
                      TextStyle(color: skin.text, fontWeight: FontWeight.w700)),
              TextSpan(
                  text: ' ${l.followersLabel}',
                  style: TextStyle(color: skin.muted)),
            ])),
          ]),
        ),
      ]);
    }
    // MyPlace and the forum: a square photo and a box of details.
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: skin.line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ArtistAvatar(
            name: p.name, seed: p.id, size: 96, artistId: p.id, square: true),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name,
                style: TextStyle(
                    color: skin.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(l.friendsCount(fmt.compact(view.followers)),
                style:
                    TextStyle(color: skin.accent, fontWeight: FontWeight.w700)),
            if (view.canPost) ...[
              const SizedBox(height: 4),
              Text(l.socialPostsLeft(view.postsLeft),
                  style: TextStyle(color: skin.muted, fontSize: 13)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class NameLine extends StatelessWidget {
  /// A display name with the blue tick when [verified].
  const NameLine(
      {super.key,
      required this.name,
      required this.verified,
      required this.skin,
      this.size = 15});
  final String name;
  final bool verified;
  final SocialSkin skin;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: skin.text,
                  fontSize: size,
                  fontWeight: FontWeight.w800)),
        ),
        if (verified) ...[
          const SizedBox(width: 3),
          Icon(Icons.verified_rounded, color: skin.accent, size: size + 1),
        ],
      ]);
}

/// "For you" and "Your posts", X-style with a blue underline.
class _Tabs extends StatelessWidget {
  const _Tabs(
      {required this.mine, required this.skin, required this.onChanged});
  final bool mine;
  final SocialSkin skin;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget tab(String text, bool on, bool value) => Expanded(
          child: InkWell(
            onTap: () => onChanged(value),
            child: Column(children: [
              const SizedBox(height: 14),
              Text(text,
                  style: TextStyle(
                      color: on ? skin.text : skin.muted,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
              const SizedBox(height: 10),
              Container(
                  height: 4,
                  width: 56,
                  decoration: BoxDecoration(
                      color: on ? skin.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(2))),
            ]),
          ),
        );
    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: skin.line))),
      child: Row(children: [
        tab(l.tabForYou, !mine, false),
        tab(l.tabYourPosts, mine, true),
      ]),
    );
  }
}

/// A 2000s box heading: white bold text on the network's color.
class _BoxTitle extends StatelessWidget {
  const _BoxTitle({required this.skin, required this.text});
  final SocialSkin skin;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: skin.accent,
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800)),
      );
}

/// Blue round "+" (Chirper) or a square bulletin button (the 2000s).
class _PostButton extends StatelessWidget {
  const _PostButton(
      {required this.skin, required this.busy, required this.onTap});
  final SocialSkin skin;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (skin == SocialSkin.chirper) {
      return FloatingActionButton(
        backgroundColor: busy ? skin.muted : skin.accent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: busy ? null : onTap,
        child: const Icon(Icons.add_rounded, size: 30),
      );
    }
    return FloatingActionButton.extended(
      backgroundColor: busy ? skin.muted : skin.accent,
      foregroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      onPressed: busy ? null : onTap,
      icon: const Icon(Icons.campaign_rounded),
      label: Text(context.l10n.postBulletin),
    );
  }
}

/// A diss from the compose sheet (docs K234).
enum _Diss { rival, haters }

/// Write a post: pick what to share; each shows what it does.
class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.view, required this.state});
  final SocialView view;
  final CareerState state;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  PostKind? _kind;
  _Diss? _diss;

  bool _can(PostKind k) =>
      (k != PostKind.teaser || widget.view.hasTeaser) &&
      (k != PostKind.promote || widget.view.songs.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final skin = SocialSkin.of(widget.view.network);
    final p = widget.state.player;
    final chirper = skin == SocialSkin.chirper;
    final k = _kind;
    final d = _diss;
    final beef = widget.view.beefRivalId >= 0;
    Widget chip(String label, bool selected, VoidCallback? onTap,
            {Color? color}) =>
        ChoiceChip(
          selected: selected,
          onSelected: onTap == null ? null : (_) => onTap(),
          showCheckmark: false,
          backgroundColor: skin.bg,
          selectedColor: color ?? skin.accent,
          disabledColor: skin.bg,
          side: BorderSide(
              color: selected ? color ?? skin.accent : color ?? skin.line),
          shape: chirper ? const StadiumBorder() : const RoundedRectangleBorder(),
          label: Text(label,
              style: TextStyle(
                  color: selected
                      ? Colors.white
                      : onTap != null
                          ? skin.text
                          : skin.muted,
                  fontWeight: FontWeight.w600)),
        );
    final hint = switch ((k, d)) {
      (final PostKind k?, _) => fmt.postKindHint(k),
      (_, _Diss.rival) => beef
          ? l.composeClapBackHint(widget.view.beefRivalName)
          : l.composeDissRivalHint,
      (_, _Diss.haters) => l.beefHatersHint,
      _ => null,
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: skin.text),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: skin.accent,
                disabledBackgroundColor: skin.accent.withValues(alpha: 0.4),
                foregroundColor: Colors.white,
                shape: chirper
                    ? const StadiumBorder()
                    : const RoundedRectangleBorder(),
              ),
              onPressed: k == null && d == null
                  ? null
                  : () => Navigator.pop(context, k ?? d),
              child: Text(l.postButton),
            ),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ArtistAvatar(name: p.name, seed: p.id, size: 40, artistId: p.id),
            const SizedBox(width: 12),
            Expanded(
              child: Text(hint ?? l.composeHint,
                  style: TextStyle(
                      color: hint == null ? skin.muted : skin.text,
                      fontSize: 19)),
            ),
          ]),
          const SizedBox(height: 18),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final kind in PostKind.values)
              chip(
                  fmt.postKind(kind),
                  k == kind,
                  _can(kind)
                      ? () => setState(() {
                            _kind = kind;
                            _diss = null;
                          })
                      : null),
            // Beefing from the feed (docs K229, K234).
            for (final diss in _Diss.values)
              chip(
                  switch (diss) {
                    _Diss.rival => beef ? l.clapBack : l.composeDissRival,
                    _Diss.haters => l.beefHaters,
                  },
                  d == diss,
                  () => setState(() {
                        _diss = diss;
                        _kind = null;
                      }),
                  color: AppColors.coral),
          ]),
        ]),
      ),
    );
  }
}

/// One post in the feed, like a post on the network: X-style on Chirper,
/// a comment box on MyPlace and the forum.
class FeedPost extends StatelessWidget {
  const FeedPost(
      {super.key,
      required this.item,
      required this.state,
      this.skin = SocialSkin.chirper,
      this.verified = false,
      this.onClapBack,
      this.onTap});
  final SocialItemView item;
  final CareerState state;
  final SocialSkin skin;

  /// The player's blue tick.
  final bool verified;

  /// Answers a rival's post (null: no button; docs K234).
  final VoidCallback? onClapBack;

  /// Opens the post with its replies (docs K238).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final post = _post(context);
    return onTap == null
        ? post
        : Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap, child: post));
  }

  Widget _post(BuildContext context) {
    final fmt = context.fmt;
    final p = state.player;
    final rival = item.isRival;
    final handle = item.isPlayer
        ? playerHandle(p.name)
        : rival
            ? playerHandle(item.rivalName)
            : fanHandle(item.fan, p.name);
    final name = item.isPlayer
        ? p.name
        : rival
            ? item.rivalName
            : fanName(item.fan, p.name);
    final square = !skin.round;
    final avatar = item.isPlayer
        ? ArtistAvatar(
            name: p.name,
            seed: p.id,
            size: square ? 48 : 40,
            artistId: p.id,
            square: square)
        : rival
            ? ArtistAvatar(
                name: item.rivalName,
                seed: item.rivalId,
                size: square ? 48 : 40,
                artistId: item.rivalId,
                square: square)
            : ArtistAvatar(
            name: name.split(' | ').first,
            seed: item.fan,
            size: square ? 48 : 40,
            square: square);
    final text = fmt.social(item, p.name);
    final age = fmt.feedAge(item.week, state.week);
    final clapBack = onClapBack == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.coral,
                side: BorderSide(color: AppColors.coral),
                visualDensity: VisualDensity.compact,
                shape: skin.round
                    ? const StadiumBorder()
                    : const RoundedRectangleBorder(),
              ),
              onPressed: onClapBack,
              icon: const Icon(Icons.local_fire_department_rounded, size: 18),
              label: Text(context.l10n.clapBack),
            ),
          );
    if (skin != SocialSkin.chirper) {
      // A 2000s comment: square photo and handle on the left.
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        decoration: BoxDecoration(
            color: item.isPlayer ? skin.bg : skin.row,
            border: Border.all(color: skin.line)),
        padding: const EdgeInsets.all(8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 84,
            child: Column(children: [
              avatar,
              const SizedBox(height: 4),
              Text(item.isPlayer || rival ? name : handle.substring(1),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: skin.accent,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                      decorationColor: skin.accent)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(age,
                  style: TextStyle(
                      color: skin.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(text, style: TextStyle(color: skin.text, height: 1.3)),
              // Forums before social media show no pictures (docs K211).
              if (skin == SocialSkin.myPlace)
                PostMediaCard(
                    item: item,
                    artistName: p.name,
                    week: state.week,
                    dark: false,
                    round: false),
              if (clapBack != null) clapBack,
            ]),
          ),
        ]),
      );
    }
    // Chirper: X's layout and counts.
    final seed = item.fan < 0 ? item.likes : item.fan;
    final replies = (item.likes * (0.02 + (seed % 7) / 300)).round();
    final reposts = (item.likes * (0.08 + (seed % 5) / 100)).round();
    final views = item.likes * (18 + seed % 20);
    Widget count(IconData icon, int n, {Color? color}) => Expanded(
          child: Row(children: [
            Icon(icon, size: 17, color: color ?? skin.muted),
            const SizedBox(width: 4),
            if (n > 0)
              // Big counts on a narrow phone: cut, not overflow.
              Flexible(
                child: Text(fmt.compact(n.toDouble()),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style:
                        TextStyle(color: color ?? skin.muted, fontSize: 13)),
              ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
          color: skin.bg, border: Border(bottom: BorderSide(color: skin.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        avatar,
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: NameLine(
                    name: name,
                    verified: item.isPlayer && verified || rival,
                    skin: skin),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text('$handle · $age',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: skin.muted, fontSize: 14)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(text,
                style: TextStyle(color: skin.text, fontSize: 15, height: 1.3)),
            PostMediaCard(item: item, artistName: p.name, week: state.week),
            const SizedBox(height: 10),
            Row(children: [
              count(Icons.chat_bubble_outline_rounded, replies),
              count(Icons.repeat_rounded, reposts),
              count(Icons.favorite_border_rounded, item.likes),
              count(Icons.bar_chart_rounded, views),
              Icon(Icons.ios_share_rounded, size: 17, color: skin.muted),
            ]),
            if (clapBack != null) clapBack,
          ]),
        ),
      ]),
    );
  }
}

/// Chirper's wordmark: a heavy lowercase name with a blue dot.
class ChirperMark extends StatelessWidget {
  const ChirperMark({super.key, this.size = 24, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(
            text: 'chirper',
            style: TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: FontWeight.w900,
                fontSize: size,
                letterSpacing: -0.8,
                color: color ?? SocialSkin.chirper.text)),
        TextSpan(
            text: '.',
            style: TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: FontWeight.w900,
                fontSize: size,
                color: SocialSkin.chirper.accent)),
      ]));
}
