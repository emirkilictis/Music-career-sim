import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// The player's own playlist on the streaming app (docs K159): songs
/// they pick, theirs or anyone's. People follow a playlist that plays
/// what they like (songs people listen to, new ones, kept fresh) and
/// leave one that only plugs its owner; its followers' listening lifts
/// every song on it, and the artists on it remember the favour.
class OwnPlaylist {
  OwnPlaylist(
      {required this.name,
      required this.createdWeek,
      List<int>? songIds,
      this.followers = 0,
      this.updatedWeek = -1})
      : songIds = songIds ?? [];

  String name;
  final int createdWeek;
  final List<int> songIds;
  double followers;

  /// Last week its songs changed.
  int updatedWeek;

  List<Object> toJson() =>
      [name, createdWeek, songIds, followers, updatedWeek];

  static OwnPlaylist fromJson(List<dynamic> j) => OwnPlaylist(
        name: j[0] as String,
        createdWeek: j[1] as int,
        songIds: [for (final x in j[2] as List) x as int],
        followers: (j[3] as num).toDouble(),
        updatedWeek: j[4] as int,
      );

  static String encode(OwnPlaylist? p) =>
      p == null ? '' : jsonEncode(p.toJson());

  static OwnPlaylist? decode(String? s) =>
      s == null || s.isEmpty ? null : fromJson(jsonDecode(s) as List);
}

abstract final class OwnPlaylists {
  /// Playlists are how people listen from this year (docs K125).
  static const fromYear = 2012;

  static const maxSongs = 50;

  /// Fewer songs than this is not a playlist anyone follows.
  static const minSongs = 5;

  /// Followers move this share of the way to what the playlist can hold
  /// each week.
  static const pull = 0.08;

  /// Up to this share of the playlist can be the owner's own without
  /// putting people off.
  static const ownFree = 0.3;

  /// Weeks a playlist stays fresh without a change; it then loses a
  /// little appeal each week.
  static const freshWeeks = 6;
  static const staleFactor = 0.96;
  static const staleFloor = 0.4;

  /// Weekly lift a track gets at most, on a playlist of up to
  /// [fullLiftSongs] songs with a very big following.
  static const maxLift = 0.25;
  static const liftHalf = 2e6;
  static const fullLiftSongs = 10;

  /// How much further a rival's reach extends for the player while one
  /// of their songs is on the playlist (docs K117).
  static const goodwill = 0.1;

  static bool open(World w) => GameTime.yearOf(w.week) >= fromYear;

  /// Starts the player's playlist.
  static OwnPlaylist create(World w, String name) {
    if (!open(w)) throw ActionException('No playlists yet');
    if (w.ownPlaylist != null) throw ActionException('Already have one');
    final n = name.trim();
    if (n.isEmpty) throw ActionException('Name it');
    final p = OwnPlaylist(name: n, createdWeek: w.week, updatedWeek: w.week);
    w.ownPlaylist = p;
    return p;
  }

  /// Whether [s] can go on a playlist: out, and not taken down.
  static bool canAdd(World w, Song s) =>
      s.releasedWeek >= 0 &&
      s.releasedWeek <= w.week &&
      s.status != SongStatus.scrapped &&
      !s.cloudOnly;

  static void add(World w, Song s) {
    final p = w.ownPlaylist;
    if (p == null) throw ActionException('No playlist');
    if (!canAdd(w, s)) throw ActionException('Not out');
    if (p.songIds.contains(s.id)) throw ActionException('Already on it');
    if (p.songIds.length >= maxSongs) throw ActionException('Full');
    p.songIds.add(s.id);
    p.updatedWeek = w.week;
    // People find it again through the playlist.
    if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
    s.weeksBelowCutoff = 0;
    w.dirtySongs.add(s.id);
  }

  static void remove(World w, int songId) {
    final p = w.ownPlaylist;
    if (p == null || !p.songIds.remove(songId)) {
      throw ActionException('Not on it');
    }
    p.updatedWeek = w.week;
  }

  /// Share of [p]'s songs that are [ownerId]'s (featured counts).
  static double ownShare(World w, OwnPlaylist p, int ownerId) {
    if (p.songIds.isEmpty) return 0;
    var n = 0;
    for (final id in p.songIds) {
      final s = w.songs[id];
      if (s.primaryArtistId == ownerId ||
          s.featuredArtistIds.contains(ownerId) ||
          w.artists[s.primaryArtistId].managedBy == ownerId) {
        n++;
      }
    }
    return n / p.songIds.length;
  }

  /// What makes people follow [p] (0..1): songs they listen to, new ones,
  /// little self-promotion and a recent update.
  static double appeal(World w, OwnPlaylist p) {
    if (p.songIds.length < minSongs) return 0;
    var sum = 0.0;
    for (final id in p.songIds) {
      final s = w.songs[id];
      final heard = math.sqrt(math.min(1.0, s.weekStreams / 5e6));
      final fresh = w.week - s.releasedWeek <= 12 ? 1.5 : 1.0;
      sum += math.min(1.0, heard * fresh);
    }
    final songs = sum / p.songIds.length;
    // A bigger playlist holds more listeners, up to about 30 songs.
    final size = math.min(1.0, 0.5 + p.songIds.length / 60);
    final own = ownShare(w, p, w.playerArtistId);
    final plug = own <= ownFree ? 1.0 : 1 - (own - ownFree) / (1 - ownFree);
    return (0.15 + 0.85 * songs) * size * math.max(0.0, plug) * freshness(w, p);
  }

  /// 1 while fresh, then a little less each week without a change.
  static double freshness(World w, OwnPlaylist p) {
    final idle = w.week - p.updatedWeek - freshWeeks;
    if (idle <= 0) return 1;
    return math.max(staleFloor, math.pow(staleFactor, idle).toDouble());
  }

  /// Followers [a]'s playlist can hold now: some of their fans follow
  /// whatever they post, the rest come for the songs.
  static double target(World w, Artist a, OwnPlaylist p) {
    final pull = appeal(w, p);
    return (a.coreFans * 0.25 + a.casual * 0.04 + 3e6 * a.fame) * pull;
  }

  /// The lift each song on [p] gets this week.
  static double lift(OwnPlaylist p) {
    if (p.songIds.length < minSongs) return 0;
    final reach = p.followers / (p.followers + liftHalf);
    final spread = math.sqrt(fullLiftSongs / math.max(fullLiftSongs, p.songIds.length));
    return maxLift * reach * spread;
  }

  /// Before the week's listening: followers move towards what the
  /// playlist can hold.
  static void weekly(World w) {
    final p = w.ownPlaylist;
    final a = w.player;
    if (p == null || a == null) return;
    p.followers += (target(w, a, p) - p.followers) * pull;
    if (p.followers < 1) p.followers = 0;
  }

  /// This week's lift for each song on the playlist (empty: none).
  static Map<int, double> lifts(World w) {
    final p = w.ownPlaylist;
    if (p == null) return const {};
    final l = lift(p);
    if (l <= 0) return const {};
    return {for (final id in p.songIds) id: l};
  }

  /// Whether [rival] has a song on the player's playlist.
  static bool favours(World w, Artist rival) {
    final p = w.ownPlaylist;
    if (p == null) return false;
    for (final id in p.songIds) {
      if (w.songs[id].primaryArtistId == rival.id) return true;
    }
    return false;
  }
}
