import 'actions.dart';
import 'model.dart';
import 'world.dart';

/// Writing for other artists (docs K143): the player sells an unreleased
/// song to a rival, who puts it out as a single a few weeks later. The
/// player gets a fee now and a songwriter's share of what it earns.
abstract final class Songwriting {
  /// Weeks until the buyer puts the song out.
  static const releaseAfter = 3;

  /// The writer's share of what a song earns (publishing).
  static const writerShare = 0.1;

  /// Buyers offered at once.
  static const shortlist = 12;

  /// What [rival] pays for [s]: more the more famous, and for a better
  /// song.
  static int feeCents(Artist rival, Song s) =>
      ((200000 + 5000000 * rival.fame * rival.fame) * (0.5 + s.quality / 100))
          .round();

  /// The least quality [rival] records: stars take only great songs.
  static double bar(Artist rival) => 45 + 35 * rival.fame;

  /// Whether [rival] would record [s].
  static bool wants(Artist rival, Song s) =>
      s.quality >= bar(rival) && s.genres.contains(rival.genre);

  /// Rivals of [s]'s genres, the ones who would take it first, then the
  /// most famous.
  static List<Artist> buyers(World w, Artist a, Song s) {
    final all = [
      for (final id in w.activeArtistIds)
        if (id != a.id &&
            !w.artists[id].isRetired &&
            w.artists[id].tier != ArtistTier.player &&
            w.artists[id].fame >= 0.05 &&
            s.genres.contains(w.artists[id].genre))
          w.artists[id]
    ]..sort((x, y) {
        final wx = wants(x, s) ? 0 : 1, wy = wants(y, s) ? 0 : 1;
        if (wx != wy) return wx.compareTo(wy);
        final f = y.fame.compareTo(x.fame);
        return f != 0 ? f : x.id.compareTo(y.id);
      });
    return all.take(shortlist).toList();
  }

  /// Sells [a]'s vault song [s] to [rival]: [rival] records it (the same
  /// song, with [a] as its writer) and plans it as a single; [a]'s
  /// version is gone. Returns the rival's song.
  static Song sell(World w, Artist a, Song s, Artist rival) {
    if (s.primaryArtistId != a.id || s.status != SongStatus.vault) {
      throw ActionException('Only unreleased songs');
    }
    if (rival.id == a.id || rival.isRetired) {
      throw ActionException('No such buyer');
    }
    if (!wants(rival, s)) throw ActionException('Not for them');
    final fee = feeCents(rival, s);
    final song = Song(
      id: w.songs.length,
      title: s.title,
      genre: s.genre,
      extraGenres: List.of(s.extraGenres),
      primaryArtistId: rival.id,
      writtenWeek: w.week,
      quality: s.quality,
      commercial: s.commercial,
      fanAppeal: s.fanAppeal,
      radioAppeal: s.radioAppeal,
      virality: s.virality,
      longevity: s.longevity,
      estimatedGrade: s.estimatedGrade,
    )
      ..holiday = s.holiday
      ..writerId = a.id;
    w.songs.add(song);
    w.writtenSongIds.add(song.id);
    w.dirtySongs.add(song.id);
    s.status = SongStatus.scrapped;
    s.soldTo = song.id;
    w.dirtySongs.add(s.id);
    a.moneyCents += fee;
    w.dirtyArtists.add(a.id);
    // The buyer puts it out in a few weeks, among their plans.
    final at = w.week + releaseAfter;
    final i = rival.plan.indexWhere((p) => p.week > at);
    final planned =
        PlannedRelease(week: at, kind: PlannedKind.single, songId: song.id);
    if (i < 0) {
      rival.plan.add(planned);
    } else {
      rival.plan.insert(i, planned);
    }
    w.dirtyArtists.add(rival.id);
    return song;
  }

  /// [a]'s songwriting money this week from songs others put out: the
  /// writer's share of what [s] earned.
  static double royalty(Song s, double songCents) => songCents * writerShare;
}
