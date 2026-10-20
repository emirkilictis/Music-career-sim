import 'actions.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// Visual albums (docs K154): a film for every song of a new album, the
/// way Beyoncé did it. Each song gets its video (cheaper than one by one,
/// a little less striking), and the record becomes an event.
abstract final class VisualAlbums {
  /// The video site opens.
  static const fromYear = 2005;

  /// Weeks after release a visual album can still be made.
  static const windowWeeks = 4;

  /// A track's film against a medium-budget video: its cost and power.
  static const costShare = 0.4;
  static const powerShare = 0.8;

  /// The buzz of the event.
  static const hype = 0.1;

  static int trackCostCents() =>
      (VideoBudget.medium.costCents * costShare).round();

  /// Tracks of [al] that still need a video.
  static List<Song> tracks(World w, Album al) => [
        for (final id in al.songIds)
          if (w.songs[id].videoBudget < 0) w.songs[id]
      ];

  static int costCents(World w, Album al) =>
      trackCostCents() * tracks(w, al).length;

  /// Whether [a] can make [al] a visual album now.
  static bool can(World w, Artist a, Album al) =>
      GameTime.yearOf(w.week) >= fromYear &&
      al.artistId == a.id &&
      !al.visual &&
      al.type != AlbumType.mixtape &&
      w.week - al.releaseWeek < windowWeeks &&
      tracks(w, al).length >= 3;

  /// Films every track of [al] that has no video yet.
  static void make(World w, Artist a, Album al) {
    if (!can(w, a, al)) throw ActionException('No visual album now');
    final cost = costCents(w, al);
    if (a.moneyCents < cost) throw ActionException('Not enough money');
    a.moneyCents -= cost;
    al.campaignCostCents += cost;
    final craft = 0.6 +
        0.25 * a.skills.performance / 100 +
        0.15 * a.skills.charisma / 100;
    for (final s in tracks(w, al)) {
      s.videoBudget = VideoBudget.medium.index;
      s.videoPower = VideoBudget.medium.basePower * craft * powerShare;
      s.videoWeek = w.week;
      s.streamsAtVideo = w.songLifetimeStreams(s);
      w.dirtySongs.add(s.id);
    }
    al.visual = true;
    a.hype += hype;
    w.dirtyAlbums.add(al.id);
    w.dirtyArtists.add(a.id);
  }
}
