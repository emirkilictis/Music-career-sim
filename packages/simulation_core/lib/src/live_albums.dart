import 'actions.dart';
import 'model.dart';
import 'tours.dart';
import 'world.dart';

/// Live albums (docs K146): after a real tour, the player can put out its
/// recordings. Live versions of released songs: as good as the artist on
/// stage, loved by fans, little played by anyone else. They neither open
/// an era nor count as an album the label is owed.
abstract final class LiveAlbums {
  /// Shows a tour needs to be worth a record.
  static const minShows = 10;

  /// Weeks after the tour the recordings stay fresh.
  static const windowWeeks = 52;

  /// Mixing per track, and creativity.
  static const costPerTrackCents = 500000;
  static const energyPerTrack = 2.0;

  /// Fans who buy a live album against a studio one, and the event
  /// buyers it draws.
  static const fanBuy = 0.25;

  /// Fans' listening a live version gets against a studio song.
  static const fanListen = 0.3;
  static const eventBuy = 0.1;

  static const minTracks = 8;
  static const maxTracks = 20;

  /// [a]'s finished tours a live album can come from, latest first.
  static List<TourRecord> tours(World w, Artist a) => [
        for (final t in w.tourRecords.reversed)
          if (t.artistId == a.id &&
              t.shows >= minShows &&
              t.endWeek <= w.week &&
              w.week - t.endWeek <= windowWeeks &&
              !w.albums.any((al) => al.artistId == a.id && al.liveTour == t.startWeek))
            t
      ];

  /// How good [a]'s live version of [s] is: the stage decides.
  static double quality(Artist a, Song s) =>
      (s.quality * (0.85 + 0.25 * a.skills.performance / 100))
          .clamp(1.0, 100.0)
          .toDouble();

  static int costCents(int tracks) => costPerTrackCents * tracks;

  /// Records and releases a live album of [songIds] from tour [t].
  static Album release(World w, Artist a, TourRecord t, String title,
      List<int> songIds,
      {Campaign campaign = Campaign.none}) {
    if (!tours(w, a).contains(t)) throw ActionException('No such tour');
    if (songIds.length < minTracks ||
        songIds.length > maxTracks ||
        songIds.toSet().length != songIds.length) {
      throw ActionException('$minTracks–$maxTracks different songs');
    }
    for (final id in songIds) {
      final s = w.songs[id];
      if (s.primaryArtistId != a.id ||
          s.releasedWeek < 0 ||
          s.liveOf >= 0 ||
          s.status == SongStatus.scrapped) {
        throw ActionException('Only your released songs');
      }
    }
    final cost = costCents(songIds.length);
    if (a.moneyCents < cost) throw ActionException('Not enough money');
    final energy = energyPerTrack * songIds.length;
    if (a.creativeEnergy < energy) {
      throw ActionException('Not enough creativity');
    }
    a.moneyCents -= cost;
    a.creativeEnergy -= energy;
    final live = <int>[];
    for (final id in songIds) {
      final old = w.songs[id];
      final q = quality(a, old);
      final s = Song(
        id: w.songs.length,
        title: old.title,
        genre: old.genre,
        extraGenres: List.of(old.extraGenres),
        primaryArtistId: a.id,
        featuredArtistIds: List.of(old.featuredArtistIds),
        writtenWeek: w.week,
        quality: q,
        commercial: (old.commercial * 0.6).clamp(0.02, 1.0).toDouble(),
        fanAppeal: (old.fanAppeal * 1.1).clamp(0.02, 1.0).toDouble(),
        radioAppeal: (old.radioAppeal * 0.5).clamp(0.02, 1.0).toDouble(),
        virality: old.virality * 0.5,
        longevity: old.longevity * 0.7,
        estimatedGrade: q.round().clamp(1, 100),
      )
        ..gradeSpread = 0
        ..liveOf = old.id
        ..productionCostCents = costPerTrackCents;
      w.songs.add(s);
      w.playerSongIds.add(s.id);
      w.dirtySongs.add(s.id);
      live.add(s.id);
    }
    return Actions.releaseAlbum(w, a, title, live,
        campaign: campaign, announced: true, liveTour: t.startWeek);
  }
}
