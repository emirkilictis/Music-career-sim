import 'dart:math' as math;

import 'actions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'world.dart';

/// Why an album cannot be re-recorded (docs K139).
enum RerecordBlock {
  /// Not the artist's own album or EP.
  notYours,

  /// It is a re-recording itself.
  isRerecord,

  /// Already re-recorded (or being re-recorded in the vault).
  done,

  /// The artist owns its masters: nothing to win back.
  ownMasters,

  /// The deal forbids it until [Rerecords.waitWeeks] after it came out.
  tooSoon,
}

/// Re-recordings, the Taylor's Version move (docs K139). A label owns
/// the masters of what came out under it and keeps its cut forever,
/// whoever the artist signs with later. The artist can record the songs
/// again under their own name: the new versions earn on the current deal,
/// and most fans switch to them, so the old ones lose most of their
/// listening.
abstract final class Rerecords {
  /// Weeks after an album comes out before its songs may be recorded
  /// again (the usual contract clause).
  static const waitWeeks = 104;

  /// Studio time per song: the songs are written, so it is cheaper than
  /// a new recording on the best budget.
  static const costPerTrackCents = 800000;

  /// Share of its listening an old version keeps once the new one is
  /// out: old playlists and people who never noticed.
  static const oldKeep = 0.35;

  /// The artist's share of [s]'s money.
  static double songShare(Artist a, Song s) => s.masterShare ?? a.artistShare;

  /// The artist's share of [al]'s sales.
  static double albumShare(Artist a, Album al) =>
      al.masterShare ?? a.artistShare;

  /// The album's songs are re-recordings.
  static bool isRerecord(World w, Album al) =>
      al.songIds.any((id) => w.songs[id].rerecordOf >= 0);

  /// Re-recordings of [al]'s songs made so far (in the vault or out).
  static List<Song> versionsOf(World w, Album al) => [
        for (final id in w.playerSongIds)
          if (w.songs[id].rerecordOf >= 0 &&
              w.songs[id].status != SongStatus.scrapped &&
              w.songs[w.songs[id].rerecordOf].albumId == al.id)
            w.songs[id]
      ];

  /// What stops [a] re-recording [al] now, or null.
  static RerecordBlock? block(World w, Artist a, Album al) {
    // A best-of has nothing of its own to re-record (docs K161).
    if (al.artistId != a.id ||
        (al.type != AlbumType.album && al.type != AlbumType.ep) ||
        al.hitIds.isNotEmpty) {
      return RerecordBlock.notYours;
    }
    if (isRerecord(w, al)) return RerecordBlock.isRerecord;
    if (versionsOf(w, al).isNotEmpty) return RerecordBlock.done;
    if (albumShare(a, al) >= 1) return RerecordBlock.ownMasters;
    if (w.week < al.releaseWeek + waitWeeks) return RerecordBlock.tooSoon;
    return null;
  }

  /// What re-recording [al] costs.
  static int costCents(Album al) => costPerTrackCents * al.songIds.length;

  /// Records [al]'s songs again into the vault, same songs and order,
  /// and returns them. They come out like any song, usually as the
  /// album's new version.
  static List<Song> record(World w, Artist a, Album al) {
    final why = block(w, a, al);
    if (why != null) throw ActionException('Cannot re-record: ${why.name}');
    final cost = costCents(al);
    if (a.moneyCents < cost) throw ActionException('Not enough money');
    if (a.creativeEnergy < energyCost(al)) {
      throw ActionException('Not enough creativity');
    }
    a.moneyCents -= cost;
    a.creativeEnergy -= energyCost(al);
    final out = <Song>[];
    for (final id in al.songIds) {
      final old = w.songs[id];
      final s = Song(
        id: w.songs.length,
        title: old.title,
        genre: old.genre,
        extraGenres: List.of(old.extraGenres),
        primaryArtistId: a.id,
        featuredArtistIds: List.of(old.featuredArtistIds),
        writtenWeek: w.week,
        quality: old.quality,
        commercial: old.commercial,
        fanAppeal: old.fanAppeal,
        radioAppeal: old.radioAppeal,
        virality: old.virality,
        longevity: old.longevity,
        // Everyone knows how these songs do.
        estimatedGrade: old.quality.round().clamp(1, 100),
      )
        ..gradeSpread = 0
        ..holiday = old.holiday
        ..radioFormat = old.radioFormat
        ..rerecordOf = old.id
        ..productionCostCents = costPerTrackCents;
      w.songs.add(s);
      w.playerSongIds.add(s.id);
      w.dirtySongs.add(s.id);
      out.add(s);
    }
    w.dirtyArtists.add(a.id);
    return out;
  }

  /// [s] came out: if it re-records a song, most of that song's listeners
  /// move to it from now on.
  static void onRelease(World w, Song s) {
    if (s.rerecordOf < 0) return;
    final old = w.songs[s.rerecordOf];
    if (old.replacedWeek >= 0) return;
    old.replacedWeek = w.week;
    Lifecycle.scaleDormant(w, old, oldKeep);
    w.dirtySongs.add(old.id);
  }

  /// How much of their usual listening fans give a re-recording: they
  /// know the songs, but many switch on purpose.
  static const fanFresh = 0.75;

  /// How much of a new song's reach a re-recording has: it is no news
  /// to the public, and radio and playlists move over slowly.
  static const reachFresh = 0.4;

  /// Studio creativity per song: less than writing one, and at most
  /// [maxEnergy] for a whole album, so a long one can be done too (F81).
  static const energyPerTrack = 5.0, maxEnergy = 60.0;

  static double fanFactor(Song s) => s.rerecordOf >= 0 ? fanFresh : 1.0;
  static double reachFactor(Song s) => s.rerecordOf >= 0 ? reachFresh : 1.0;

  /// Creativity re-recording [al] takes.
  static double energyCost(Album al) =>
      math.min(maxEnergy, energyPerTrack * al.songIds.length);

  /// Listening [s] keeps against its re-recording.
  static double keep(Song s) => s.replacedWeek >= 0 ? oldKeep : 1.0;
}
