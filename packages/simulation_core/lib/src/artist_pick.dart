import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'model.dart';
import 'time.dart';
import 'world.dart';

/// What the player pinned to the top of their streaming profile (docs
/// K185). Index order is stored.
enum PickKind {
  song,
  album,

  /// An announced album on its countdown page (2021+).
  upcoming,
}

class ArtistPick {
  const ArtistPick(this.kind, this.id, this.sinceWeek);
  final PickKind kind;

  /// A song id, an album id or a scheduled release id.
  final int id;
  final int sinceWeek;

  String encode() => jsonEncode([kind.index, id, sinceWeek]);
  static ArtistPick? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    final j = jsonDecode(s) as List;
    return ArtistPick(PickKind.values[j[0] as int], j[1] as int, j[2] as int);
  }
}

/// The Artist Pick (docs K185), like the real app's: one release pinned on
/// top of the profile, where followers and visitors see it first. A
/// fresh pick lifts it most; people stop noticing a pin that never
/// changes. From 2021 an announced album can be pinned on its countdown
/// page, where fans pre-save it faster.
abstract final class ArtistPicks {
  static const fromYear = 2016, countdownYear = 2021;

  /// Lift for a pinned song (an album's tracks share an album's), fading
  /// with the weeks it stays pinned.
  static const songLift = 0.06, albumLift = 0.1, fadeWeeks = 26.0;

  /// How much faster a countdown page gathers pre-saves.
  static const countdownPreSaves = 1.4;

  static bool open(World w) => GameTime.yearOf(w.week) >= fromYear;
  static bool countdownOpen(World w) =>
      GameTime.yearOf(w.week) >= countdownYear;

  /// Pins [id] of [kind] for [a]. Throws when it cannot be pinned.
  static ArtistPick pin(World w, Artist a, PickKind kind, int id) {
    if (!open(w)) throw ActionException('No artist pick yet');
    switch (kind) {
      case PickKind.song:
        if (id < 0 || id >= w.songs.length) throw ActionException('No song');
        final s = w.songs[id];
        if (s.primaryArtistId != a.id || s.releasedWeek < 0) {
          throw ActionException('Only released songs');
        }
      case PickKind.album:
        if (id < 0 || id >= w.albums.length) throw ActionException('No album');
        if (w.albums[id].artistId != a.id) throw ActionException('Not yours');
      case PickKind.upcoming:
        if (!countdownOpen(w)) throw ActionException('No countdown yet');
        final sr = a.scheduled.where((x) => x.id == id).firstOrNull;
        if (sr == null || !sr.isAlbum || !sr.announcedBy(w.week)) {
          throw ActionException('Only announced albums');
        }
    }
    return w.artistPick = ArtistPick(kind, id, w.week);
  }

  /// What the pick is now: a countdown whose album came out turns into
  /// that album.
  static ArtistPick? current(World w) {
    final p = w.artistPick;
    if (p == null || p.kind != PickKind.upcoming) return p;
    final a = w.player;
    if (a != null && a.scheduled.any((sr) => sr.id == p.id)) return p;
    for (final al in w.albums.reversed) {
      if (al.scheduleId == p.id && al.artistId == w.playerArtistId) {
        return ArtistPick(PickKind.album, al.id, al.releaseWeek);
      }
    }
    return null;
  }

  static double _fade(World w, ArtistPick p) =>
      math.exp(-(w.week - p.sinceWeek) / fadeWeeks);

  /// Exposure lifts for the pinned songs this week.
  static Map<int, double> lifts(World w) {
    final p = current(w);
    if (p == null) return const {};
    final f = _fade(w, p);
    switch (p.kind) {
      case PickKind.song:
        return {p.id: songLift * f};
      case PickKind.album:
        final ids = w.albums[p.id].songIds;
        if (ids.isEmpty) return const {};
        return {for (final id in ids) id: albumLift * f / ids.length};
      case PickKind.upcoming:
        return const {};
    }
  }

  /// Pre-save speed for scheduled release [scheduleId].
  static double preSaveFactor(World w, int scheduleId) {
    final p = w.artistPick;
    return p != null && p.kind == PickKind.upcoming && p.id == scheduleId
        ? countdownPreSaves
        : 1.0;
  }
}
