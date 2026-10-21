import 'dart:math' as math;

import 'actions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// The streaming app's mood and activity playlists (docs K186). Index
/// order is stored.
enum Mood { chill, workout, party, sad, focus }

/// Mood playlists (docs K186), like Peaceful Piano or Beast Mode: lists
/// people put on for hours, for years. Unlike the editors' new music
/// lists they take songs that are already out, and a song on one keeps
/// being played long after its release. One pitch per song.
abstract final class MoodPlaylists {
  static const fromYear = 2013;

  /// A song must have been out this long: the lists take proven songs.
  static const minAgeWeeks = 8;

  /// The listening a list brings, fading over about a year.
  static const lift = 0.3, fadeWeeks = 52.0;

  /// Genres ([genreNames] indexes) each list plays most.
  static const _genres = {
    Mood.chill: {2, 7, 10, 11, 13, 16, 17},
    Mood.workout: {1, 3, 5, 8, 9, 17},
    Mood.party: {0, 1, 5, 6, 12, 16, 17, 18},
    Mood.sad: {0, 2, 4, 7, 10, 14, 15},
    Mood.focus: {5, 7, 13, 15, 20},
  };

  /// How well [s] fits [m] (0–1): its genres and what it is like.
  static double fit(Song s, Mood m) {
    final inGenre = s.genres.any(_genres[m]!.contains);
    final trait = switch (m) {
      Mood.chill => s.longevity,
      Mood.workout => s.virality,
      Mood.party => (s.commercial + s.virality) / 2,
      Mood.sad => s.quality / 100,
      Mood.focus => s.longevity,
    };
    return ((inGenre ? 0.6 : 0.15) + 0.4 * trait).clamp(0.0, 1.0);
  }

  static bool can(World w, Artist a, Song s) =>
      GameTime.yearOf(w.week) >= fromYear &&
      s.primaryArtistId == a.id &&
      s.releasedWeek >= 0 &&
      s.status != SongStatus.scrapped &&
      w.week - s.releasedWeek >= minAgeWeeks &&
      s.moodWeek < 0;

  /// Chance the curators of [m] take [s].
  static double chance(Song s, Mood m) {
    final q = s.quality / 100;
    return 0.1 + 0.6 * fit(s, m) * (0.4 + 0.6 * q);
  }

  /// Pitches [s] to [m]; true if it got in.
  static bool pitch(World w, Artist a, Song s, Mood m) {
    if (!can(w, a, s)) throw ActionException('Not this song');
    final r = RandomStream.keyed(w.seed, w.week, s.id, RngPurpose.pitch + 60);
    final inList = r.chance(chance(s, m));
    s
      ..moodWeek = w.week
      ..mood = m.index
      ..moodIn = inList;
    if (inList) {
      if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
      s.weeksBelowCutoff = 0;
    }
    w.dirtySongs.add(s.id);
    return inList;
  }

  /// This week's lift for each of the player's songs on a mood list.
  static Map<int, double> lifts(World w) {
    final out = <int, double>{};
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (!s.moodIn) continue;
      out[id] = lift * math.exp(-(w.week - s.moodWeek) / fadeWeeks);
    }
    return out;
  }
}
