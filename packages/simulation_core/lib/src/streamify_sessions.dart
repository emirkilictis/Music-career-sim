import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'audience.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// One studio session at the streaming app (docs K178).
class StreamifySession {
  const StreamifySession(this.week, this.songId, this.coverSongId);
  final int week;

  /// The player's song recorded stripped back, and the rival hit covered.
  final int songId;
  final int coverSongId;

  static String encode(List<StreamifySession> s) =>
      jsonEncode([for (final x in s) [x.week, x.songId, x.coverSongId]]);
  static List<StreamifySession> decode(String? s) => s == null || s.isEmpty
      ? []
      : [
          for (final x in jsonDecode(s) as List)
            StreamifySession(x[0] as int, x[1] as int, x[2] as int)
        ];
}

/// What stops a session now.
enum SessionBlock { tooEarly, notKnown, tooSoon }

/// Streamify Sessions (docs K178), like the real app's Singles: the app
/// invites artists people listen to into its studio to record one of
/// their own songs stripped back and a cover of someone else's hit. The
/// new version sends people back to the song, the app features it, and
/// the cover reaches the other artist's listeners.
abstract final class StreamifySessions {
  static const fromYear = 2017;

  /// Monthly listeners the app wants before it invites someone.
  static const minListeners = 1e6;

  /// One a year.
  static const gapWeeks = 52;
  static const energy = 6.0;

  /// Share of the covered artist's listeners who hear the cover, more
  /// when it is the player's own genre.
  static const coverReach = 0.012;

  /// The wave the cover sends to the original.
  static const originalLift = 0.05;

  static SessionBlock? block(World w, double listeners) {
    if (GameTime.yearOf(w.week) < fromYear) return SessionBlock.tooEarly;
    if (listeners < minListeners) return SessionBlock.notKnown;
    final last = w.streamifySessions.lastOrNull;
    if (last != null && w.week - last.week < gapWeeks) {
      return SessionBlock.tooSoon;
    }
    return null;
  }

  /// Whether [s] can be recorded: the artist's released song without a
  /// session yet.
  static bool canRecord(Song s, Artist a) =>
      s.primaryArtistId == a.id &&
      s.releasedWeek >= 0 &&
      s.status != SongStatus.scrapped &&
      !s.versions.any((v) => v.$1 == SongVersion.session);

  /// Whether [s] can be covered: someone else's released song.
  static bool canCover(Song s, Artist a) =>
      s.primaryArtistId != a.id &&
      s.releasedWeek >= 0 &&
      s.status != SongStatus.scrapped;

  /// Listeners the cover of [cover] would win [a].
  static double coverListeners(World w, Artist a, Song cover) {
    final o = w.artists[cover.primaryArtistId];
    final fit = o.genre == a.genre ? 1.0 : 0.5;
    return o.casual * coverReach * fit;
  }

  /// Records the session: [own] stripped back as a new version the app
  /// features, and a cover of [cover].
  static StreamifySession record(
      World w, Artist a, Song own, Song cover, double listeners) {
    if (block(w, listeners) case final b?) {
      throw ActionException('No session: $b');
    }
    if (!canRecord(own, a)) throw ActionException('Not this song');
    if (!canCover(cover, a)) throw ActionException('Not that cover');
    if (a.creativeEnergy < energy) {
      throw ActionException('Not enough creativity');
    }
    a.creativeEnergy -= energy;
    Actions.releaseVersion(w, a, own, SongVersion.session);
    own.playlistBoost =
        math.max(own.playlistBoost, w.config.playlistMidBoost);
    Audience.addCasual(w, a, coverListeners(w, a, cover));
    if (cover.status == SongStatus.dormant) Lifecycle.reactivateSong(w, cover);
    cover.versionBoost += originalLift;
    w.dirtySongs.add(cover.id);
    final s = StreamifySession(w.week, own.id, cover.id);
    w.streamifySessions.add(s);
    w.dirtyArtists.add(a.id);
    return s;
  }
}
