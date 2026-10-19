import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// Where fans talk in a year (docs K93): a fan forum before social media
/// (read only), then MyPlace, then Chirper.
enum SocialNetwork { forum, myPlace, chirper }

/// What the player can post (docs K93). Posting costs no energy (docs
/// K98: writing songs takes enough); three posts a week at most.
enum PostKind {
  /// A snippet of something unreleased: hype for what is coming.
  teaser,

  /// Behind the scenes: fans feel closer, a few new ones find you.
  studio,

  /// Answering fans: devotion.
  fans,

  /// A bold opinion: everyone talks, but it can backfire.
  hotTake,

  /// Pushing a released song: a small wave of listening.
  promote,
}

/// What a feed item is about; each has [Social.variants] wordings. Index
/// order is stored in saves: only append.
enum FanTopic {
  releaseLove,
  releaseMixed,
  releaseHate,
  numberOne,
  topTen,
  bigWeek,
  criticHigh,
  criticLow,
  nominated,
  awardWon,
  awardRobbed,
  scandal,
  tour,
  viral,
  flopEra,
  hiatus,
  battleLost,
  milestone,
  replyTeaser,
  replyStudio,
  replyFans,
  replyHotTake,
  replyBacklash,
  replyPromote,
  postTeaser,
  postStudio,
  postFans,
  postHotTake,
  postPromote,
  botsCaught,
  rivalPurge,
  postSponsored,
  replySponsored,
  replySellout,
}

/// One post in the feed: the player's ([fan] = -1) or a fan's.
class SocialItem {
  SocialItem({
    required this.week,
    required this.topic,
    required this.variant,
    this.fan = -1,
    this.songId = -1,
    this.albumId = -1,
    this.likes = 0,
    this.number = 0,
    this.brand = -1,
  });
  final int week;
  final FanTopic topic;
  final int variant;

  /// Picks the fan's handle (-1: the player).
  final int fan;
  final int songId;
  final int albumId;
  final int likes;

  /// A number the text uses (a chart position, units, a score ×10, days).
  final int number;

  /// The brand of a sponsored post ([Brands.all] index; docs K102).
  final int brand;

  bool get byPlayer => fan < 0;

  List<int> toJson() =>
      [week, topic.index, variant, fan, songId, albumId, likes, number, brand];

  static SocialItem fromJson(List<dynamic> j) => SocialItem(
        week: j[0] as int,
        topic: FanTopic.values[j[1] as int],
        variant: j[2] as int,
        fan: j[3] as int,
        songId: j[4] as int,
        albumId: j[5] as int,
        likes: j[6] as int,
        number: j[7] as int,
        brand: j.length > 8 ? j[8] as int : -1,
      );
}

/// The player's social media (docs K93): the feed, this week's posts and
/// how engaged the followers are.
class SocialState {
  final List<SocialItem> feed = [];
  int postWeek = -1;
  int postsThisWeek = 0;

  /// Grows with posts, fades week by week; more followers and likes.
  double engagement = 0;
  int lastHiatusWeek = -1000;

  int postsIn(int week) => postWeek == week ? postsThisWeek : 0;

  String encode() => jsonEncode({
        'f': [for (final i in feed) i.toJson()],
        'pw': postWeek,
        'pc': postsThisWeek,
        'e': engagement,
        'h': lastHiatusWeek,
      });

  void decode(String? s) {
    if (s == null || s.isEmpty) return;
    final j = jsonDecode(s) as Map<String, dynamic>;
    feed
      ..clear()
      ..addAll(
          [for (final x in j['f'] as List) SocialItem.fromJson(x as List)]);
    postWeek = j['pw'] as int;
    postsThisWeek = j['pc'] as int;
    engagement = (j['e'] as num).toDouble();
    lastHiatusWeek = j['h'] as int;
  }
}

/// What a post did.
class PostOutcome {
  PostOutcome(
      {required this.kind,
      this.hype = 0,
      this.fans = 0,
      this.devotion = 0,
      this.backlash = false});
  final PostKind kind;
  final double hype;
  final double fans;
  final double devotion;

  /// A hot take that went wrong.
  final bool backlash;
}

abstract final class Social {
  static const postsPerWeek = 3;

  /// Wordings per topic.
  static const variants = 3;

  /// Items kept in the feed.
  static const feedSize = 120;

  static SocialNetwork networkIn(int year) => year < 2004
      ? SocialNetwork.forum
      : year < 2009
          ? SocialNetwork.myPlace
          : SocialNetwork.chirper;

  static bool canPostIn(int year) => year >= 2004;

  /// Share of an audience on social media in [year].
  static double adoption(int year) => year < 2004
      ? 0.05
      : year < 2009
          ? 0.15 + 0.05 * (year - 2004)
          : math.min(1.0, 0.4 + 0.085 * (year - 2009));

  /// Followers of [a] in [year].
  static double followers(World w, Artist a) {
    final year = GameTime.yearOf(w.week);
    return adoption(year) *
        (a.coreFans * 0.8 + a.casual * 0.04) *
        (1 + w.social.engagement);
  }

  /// Something unreleased to tease: a song in the vault or a release on
  /// the calendar.
  static bool hasTeaser(World w, Artist a) =>
      a.scheduled.isNotEmpty ||
      w.playerSongIds.any((id) => w.songs[id].status == SongStatus.vault);

  /// Posts; effects grow with charisma and shrink with every post in the
  /// same week. Fans answer in the feed.
  static PostOutcome post(World w, Artist a, PostKind kind, {int songId = -1}) {
    final year = GameTime.yearOf(w.week);
    final st = w.social;
    if (!canPostIn(year)) throw ActionException('No social media yet');
    if (st.postsIn(w.week) >= postsPerWeek) {
      throw ActionException('Posted enough this week');
    }
    Song? song;
    if (kind == PostKind.teaser && !hasTeaser(w, a)) {
      throw ActionException('Nothing to tease');
    }
    if (kind == PostKind.promote) {
      if (songId < 0 || songId >= w.songs.length) {
        throw ActionException('No song');
      }
      song = w.songs[songId];
      if (song.primaryArtistId != a.id || song.releasedWeek < 0) {
        throw ActionException('Only released songs');
      }
    }
    final made = st.postsIn(w.week);
    final r =
        RandomStream.keyed(w.seed, w.week, a.id * 8 + made, RngPurpose.social);
    final f = math.pow(0.7, made).toDouble();
    final charm = 0.5 + a.skills.charisma / 100;
    var hype = 0.0, fans = 0.0, devotion = 0.0;
    var backlash = false;
    switch (kind) {
      case PostKind.teaser:
        hype = 0.04 * charm * f;
      case PostKind.studio:
        devotion = 0.004 * f;
        fans = a.casual * 0.001 * charm * f;
      case PostKind.fans:
        devotion = 0.01 * charm * f;
      case PostKind.hotTake:
        hype = 0.08 * f;
        a.buzz += 0.3 * f;
        a.casual += a.casual * 0.004 * f;
        backlash = r.chance(0.3);
        if (backlash) {
          devotion = -0.02;
          a.popularity = math.max(0.0, a.popularity - 0.01);
        }
      case PostKind.promote:
        final s = song!;
        if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
        s.weeksBelowCutoff = 0;
        s.versionBoost += 0.06 * charm * f;
        w.dirtySongs.add(s.id);
    }
    a.hype += hype;
    a.coreFans += fans;
    a.devotion = (a.devotion + devotion).clamp(0.0, 1.0);
    st.engagement = math.min(1.0, st.engagement + 0.03 * f);
    st.postWeek = w.week;
    st.postsThisWeek = made + 1;
    w.dirtyArtists.add(a.id);

    // The post and what fans say to it.
    final reach = followers(w, a);
    final likes = (reach * r.range(0.04, 0.1) * (backlash ? 0.5 : 1)).round();
    add(
        w,
        SocialItem(
            week: w.week,
            topic: switch (kind) {
              PostKind.teaser => FanTopic.postTeaser,
              PostKind.studio => FanTopic.postStudio,
              PostKind.fans => FanTopic.postFans,
              PostKind.hotTake => FanTopic.postHotTake,
              PostKind.promote => FanTopic.postPromote,
            },
            variant: r.nextInt(variants),
            songId: songId,
            likes: likes));
    final reply = switch (kind) {
      PostKind.teaser => FanTopic.replyTeaser,
      PostKind.studio => FanTopic.replyStudio,
      PostKind.fans => FanTopic.replyFans,
      PostKind.hotTake =>
        backlash ? FanTopic.replyBacklash : FanTopic.replyHotTake,
      PostKind.promote => FanTopic.replyPromote,
    };
    final replies = 1 + r.nextInt(2);
    for (var i = 0; i < replies; i++) {
      add(
          w,
          SocialItem(
              week: w.week,
              topic: reply,
              variant: (r.nextInt(variants) + i) % variants,
              fan: r.nextInt(1 << 20),
              songId: songId,
              likes: (likes * r.range(0.005, 0.05)).round()));
    }
    return PostOutcome(
        kind: kind,
        hype: hype,
        fans: fans,
        devotion: devotion,
        backlash: backlash);
  }

  /// A brand deal's sponsored post (docs K102): it takes one of the week's
  /// posts; fans like it when the brand suits the artist and call it
  /// selling out when it does not.
  static void sponsoredPost(World w, Artist a, int deal, double fit) {
    final st = w.social;
    final made = st.postsIn(w.week);
    final brand = w.brandDeals[deal].brand;
    final r = RandomStream.keyed(
        w.seed, w.week, a.id * 8 + made, RngPurpose.social + 2);
    st.postWeek = w.week;
    st.postsThisWeek = made + 1;
    st.engagement = math.min(1.0, st.engagement + 0.01);
    final likes = (followers(w, a) * r.range(0.02, 0.06) * (0.5 + fit)).round();
    add(
        w,
        SocialItem(
            week: w.week,
            topic: FanTopic.postSponsored,
            variant: r.nextInt(variants),
            likes: likes,
            brand: brand));
    final good = fit >= 0.5;
    for (var i = 0; i < 2; i++) {
      add(
          w,
          SocialItem(
              week: w.week,
              topic: good || i == 0 && r.chance(0.3)
                  ? FanTopic.replySponsored
                  : FanTopic.replySellout,
              variant: (r.nextInt(variants) + i) % variants,
              fan: r.nextInt(1 << 20),
              likes: (likes * r.range(0.005, 0.04)).round(),
              brand: brand));
    }
  }

  /// Adds to the feed, dropping the oldest.
  static void add(World w, SocialItem item) {
    final feed = w.social.feed;
    feed.add(item);
    if (feed.length > feedSize) feed.removeRange(0, feed.length - feedSize);
  }

  /// End of a week: engagement fades.
  static void weekly(World w) {
    w.social.engagement *= 0.985;
  }
}
