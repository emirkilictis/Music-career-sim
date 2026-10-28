import 'dart:math' as math;

import 'actions.dart';
import 'model.dart';
import 'rng.dart';
import 'social.dart';
import 'time.dart';
import 'world.dart';

/// Who wrote a comment (docs K238).
enum CommentMood { fan, hater, neutral }

/// How the player answers a comment (docs K238). Index order is stored in
/// saves: only append.
enum ReplyKind {
  /// A heart and a thank-you to a fan: devotion.
  thanks,

  /// A roast for a hater: the fans love it, unless it looks petty.
  clapBack,

  /// Killing a hater with kindness: small and safe.
  kind,
}

/// One comment under a post. Comments are not stored: the same post always
/// shows the same comments, drawn from its key.
class Comment {
  const Comment(
      {required this.index,
      required this.mood,
      required this.topic,
      required this.variant,
      required this.fan,
      required this.likes});
  final int index;
  final CommentMood mood;
  final FanTopic topic;
  final int variant;

  /// The commenter's handle seed.
  final int fan;
  final int likes;
}

/// The player's answer to a comment, kept in the save.
class CommentReply {
  CommentReply(this.postKey, this.index, this.kind, this.week, this.ok,
      this.variant);

  /// [Comments.keyOf] of the post.
  final int postKey;

  /// The comment answered ([Comments.author]: the post itself).
  final int index;
  final ReplyKind kind;
  final int week;

  /// Went down well (a clap-back that worked, a hater that softened).
  final bool ok;
  final int variant;

  List<int> toJson() =>
      [postKey, index, kind.index, week, ok ? 1 : 0, variant];

  static CommentReply fromJson(List<dynamic> j) => CommentReply(
      j[0] as int,
      j[1] as int,
      ReplyKind.values[j[2] as int],
      j[3] as int,
      j[4] == 1,
      j[5] as int);
}

/// What a reply did.
class ReplyOutcome {
  const ReplyOutcome(this.reply, {this.devotion = 0, this.popularity = 0});
  final CommentReply reply;
  final double devotion;
  final double popularity;
}

/// Comments under posts and the player's replies to them (docs K238).
abstract final class Comments {
  /// Replies a week, apart from the three posts.
  static const repliesPerWeek = 5;

  /// Comments shown under a post.
  static const maxShown = 10;

  /// Wordings of a comment or reply topic.
  static const variants = 8;

  /// [CommentReply.index] for answering the post's author.
  static const author = -1;

  /// Replies kept in the save.
  static const kept = 300;

  /// A stable key for a feed item: items never change once posted.
  static int keyOf(SocialItem i) =>
      ((i.week * 128 + i.topic.index) * 4 + i.variant % 4) * 1000003 +
      ((i.fan & 0xFFFFF) ^ (i.likes % 1000003));

  /// Fan posts written by people who dislike the player.
  static bool hateTopic(FanTopic t) => switch (t) {
        FanTopic.releaseHate ||
        FanTopic.flopEra ||
        FanTopic.replyBacklash ||
        FanTopic.replySellout ||
        FanTopic.replyDissAgainst ||
        FanTopic.hateWave ||
        FanTopic.cashGrab ||
        FanTopic.beefLost =>
          true,
        _ => false,
      };

  /// Fan posts that are neither for nor against.
  static bool mixedTopic(FanTopic t) => switch (t) {
        FanTopic.releaseMixed ||
        FanTopic.criticLow ||
        FanTopic.scandal ||
        FanTopic.dmLeak ||
        FanTopic.stageMishap ||
        FanTopic.hiatus =>
          true,
        _ => false,
      };

  /// How the author of a fan post feels about the player.
  static CommentMood authorMood(SocialItem i) => hateTopic(i.topic)
      ? CommentMood.hater
      : mixedTopic(i.topic)
          ? CommentMood.neutral
          : CommentMood.fan;

  /// Share of haters under a post: the bolder the post and the less
  /// popular the player, the more.
  static double haterShare(Artist p, SocialItem i) {
    final base = i.byPlayer
        ? switch (i.topic) {
            FanTopic.postHotTake => 0.3,
            FanTopic.postDiss => 0.35,
            FanTopic.postDissHaters => 0.4,
            FanTopic.postSponsored => 0.25,
            _ => 0.1,
          }
        : hateTopic(i.topic)
            ? 0.55
            : mixedTopic(i.topic)
                ? 0.3
                : 0.1;
    return (base + (0.5 - p.popularity) * 0.15).clamp(0.05, 0.75);
  }

  /// The comments under [post], most liked first.
  static List<Comment> of(World w, Artist p, SocialItem post) {
    if (post.fan == SocialItem.byRival) return const [];
    final key = keyOf(post);
    final r = RandomStream.keyed(w.seed, post.week, key, RngPurpose.comments);
    final n = math
        .min(maxShown, 2 + (math.log(post.likes + 1) / math.ln10 * 1.6).round())
        .clamp(2, maxShown);
    final haters = haterShare(p, post);
    final out = <Comment>[
      for (var i = 0; i < n; i++)
        () {
          final u = r.nextDouble();
          final mood = u < haters
              ? CommentMood.hater
              : u < haters + 0.15
                  ? CommentMood.neutral
                  : CommentMood.fan;
          return Comment(
              index: i,
              mood: mood,
              topic: switch (mood) {
                CommentMood.fan => FanTopic.commentFan,
                CommentMood.hater => FanTopic.commentHater,
                CommentMood.neutral => FanTopic.commentAsk,
              },
              variant: r.nextInt(variants),
              fan: r.nextInt(1 << 20),
              likes: (post.likes * r.range(0.002, 0.04) * (i == 0 ? 2 : 1))
                  .round());
        }(),
    ];
    out.sort((a, b) => b.likes.compareTo(a.likes));
    return out;
  }

  /// Replies left this week.
  static int repliesLeft(World w) =>
      repliesPerWeek - w.social.repliesIn(w.week);

  /// The player's reply to comment [index] of [post], if any.
  static CommentReply? replyTo(World w, SocialItem post, int index) {
    final key = keyOf(post);
    for (final x in w.social.replies) {
      if (x.postKey == key && x.index == index) return x;
    }
    return null;
  }

  /// Who the player would answer: comment [index] of their own post, or
  /// the author of a fan's post ([author]).
  static CommentMood? target(World w, Artist p, SocialItem post, int index) {
    if (index == author) {
      return post.fan >= 0 ? authorMood(post) : null;
    }
    if (!post.byPlayer) return null;
    final list = of(w, p, post);
    for (final c in list) {
      if (c.index == index) return c.mood;
    }
    return null;
  }

  /// The player answers a comment (docs K238). Thanks are for fans and
  /// questions, clap-backs and kindness for haters. Each reply in a week
  /// does a little less.
  static ReplyOutcome reply(
      World w, Artist p, SocialItem post, int index, ReplyKind kind) {
    if (!Social.canPostIn(GameTime.yearOf(w.week))) {
      throw ActionException('No social media yet');
    }
    final mood = target(w, p, post, index);
    if (mood == null) throw ActionException('No such comment');
    if (replyTo(w, post, index) != null) {
      throw ActionException('Already replied');
    }
    if (repliesLeft(w) <= 0) throw ActionException('Replied enough this week');
    if ((kind == ReplyKind.thanks) != (mood != CommentMood.hater)) {
      throw ActionException('Not that kind of comment');
    }
    final st = w.social;
    final made = st.repliesIn(w.week);
    final r = RandomStream.keyed(
        w.seed, w.week, keyOf(post) * 16 + index + 1, RngPurpose.comments + 1);
    final f = math.pow(0.8, made).toDouble();
    final charm = 0.5 + p.skills.charisma / 100;
    var devotion = 0.0, popularity = 0.0;
    var ok = true;
    switch (kind) {
      case ReplyKind.thanks:
        devotion = 0.003 * charm * f * (1 - p.devotion);
        st.engagement = math.min(1.0, st.engagement + 0.006 * f);
      case ReplyKind.clapBack:
        // Charm and a big following make a roast land; a small artist
        // snapping back looks thin-skinned.
        ok = r.chance((0.45 + p.skills.charisma / 250 + p.fame * 0.2)
            .clamp(0.3, 0.85));
        if (ok) {
          devotion = 0.004 * charm * f * (1 - p.devotion);
          p.buzz += 0.01 * f * math.max(0.0, 1 - p.buzz / 0.1);
          st.engagement = math.min(1.0, st.engagement + 0.01 * f);
        } else {
          devotion = -0.003;
          popularity = -0.004;
        }
      case ReplyKind.kind:
        ok = r.chance(0.5);
        devotion = 0.002 * charm * f * (1 - p.devotion);
        st.engagement = math.min(1.0, st.engagement + 0.004 * f);
    }
    p.devotion = (p.devotion + devotion).clamp(0.0, 1.0);
    p.popularity = math.max(0.0, p.popularity + popularity);
    w.dirtyArtists.add(p.id);
    final reply = CommentReply(
        keyOf(post), index, kind, w.week, ok, r.nextInt(variants));
    st.replies.add(reply);
    if (st.replies.length > kept) {
      st.replies.removeRange(0, st.replies.length - kept);
    }
    st.replyWeek = w.week;
    st.repliesThisWeek = made + 1;
    return ReplyOutcome(reply, devotion: devotion, popularity: popularity);
  }
}
