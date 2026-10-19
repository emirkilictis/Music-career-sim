import 'dart:math' as math;

import 'package:simulation_core/simulation_core.dart';

import 'platforms.dart';
import 'views.dart';

/// The streaming app's editorial playlists (docs K125): the flagship of
/// the hits, the week's new releases and one per genre family. Each is
/// last week's listening ranked, the songs the editors picked (an
/// editorial playlist add still running, [Song.playlistBoost]) pushed up.
enum EditorialPlaylist {
  hotRightNow([], 30e6),
  freshFriday([], 6e6),
  popRising([0], 12e6),
  barsAndBeats([1], 14e6),
  slowBurn([2, 10], 6e6),
  rockSolid([3, 8, 9], 7e6),
  hotCountry([4, 15], 7e6),
  dancefloor([5, 12], 6e6),
  latinHeat([6, 16], 11e6),
  indieMix([7], 4e6),
  afroWave([17], 3e6),
  kpopNow([18], 5e6),
  grooveAndJazz([11, 13, 14, 19, 20], 2e6);

  const EditorialPlaylist(this.genres, this.maxFollowers);

  /// Genres it plays ([genreNames] indexes); empty: every genre.
  final List<int> genres;

  /// Followers once the app is fully grown.
  final double maxFollowers;

  String get displayName => switch (this) {
        hotRightNow => 'Hot Right Now',
        freshFriday => 'Fresh Friday',
        popRising => 'Pop Rising',
        barsAndBeats => 'Bars & Beats',
        slowBurn => 'Slow Burn',
        rockSolid => 'Rock Solid',
        hotCountry => 'Hot Country',
        dancefloor => 'Dancefloor',
        latinHeat => 'Latin Heat',
        indieMix => 'Indie Mix',
        afroWave => 'Afro Wave',
        kpopNow => 'K-Pop Now',
        grooveAndJazz => 'Groove & Jazz',
      };

  bool plays(Song s) {
    if (genres.isEmpty) return true;
    for (final g in s.genres) {
      if (genres.contains(g)) return true;
    }
    return false;
  }
}

/// One song on an editorial playlist.
class EditorialRow {
  EditorialRow.of(World w, Song s, this.position, this.plays)
      : songId = s.id,
        title = s.title,
        artistId = s.primaryArtistId,
        artistName = w.artists[s.primaryArtistId].name,
        coverAlbumId = coverAlbumOf(w, s),
        picked = Editorial.picked(s),
        isPlayer = s.primaryArtistId == w.playerArtistId;
  final int position;
  final int songId;
  final String title;
  final int artistId;
  final String artistName;
  final int coverAlbumId;

  /// Last week's plays on the app.
  final double plays;

  /// An editors' pick (a playlist add still running).
  final bool picked;
  final bool isPlayer;
}

/// A playlist with its songs.
class EditorialView {
  EditorialView(
      {required this.playlist, required this.followers, required this.rows});
  final EditorialPlaylist playlist;
  final double followers;
  final List<EditorialRow> rows;
}

/// A player song's places on the playlists (song page).
typedef EditorialPlacement = ({EditorialPlaylist playlist, int position});

abstract final class Editorial {
  /// The editors start curating (the app's playlists take over listening).
  static const firstYear = 2012;
  static const size = 50;

  /// A playlist add counts as the editors' pick while its lift lasts.
  static const pickedBoost = 0.05;

  static bool openIn(int year) =>
      year >= firstYear && MusicPlatform.streamify.openIn(year);

  static bool picked(Song s) =>
      s.playlistAdd != PlaylistAdd.none && s.playlistBoost >= pickedBoost;

  /// Followers in [year]: growing with the app over ten years.
  static double followers(EditorialPlaylist p, int year) =>
      p.maxFollowers * ((year - firstYear + 1) / 10).clamp(0.1, 1.0);

  /// How a song ranks: its plays, an editors' pick much higher (the
  /// flagship only takes the big adds).
  static double _score(EditorialPlaylist p, Song s, double plays) {
    final pick = picked(s) &&
        (p != EditorialPlaylist.hotRightNow ||
            s.playlistAdd == PlaylistAdd.big);
    return plays * (pick ? 1 + 3 * math.min(1.0, s.playlistBoost / 0.3) : 1);
  }

  static bool _eligible(World w, EditorialPlaylist p, Song s) {
    if (!p.plays(s)) return false;
    if (p == EditorialPlaylist.freshFriday) {
      final last = w.week - 1;
      return s.releasedWeek == last || (s.isSingle && s.singleWeek == last);
    }
    return true;
  }

  /// Last week's songs, best first.
  static List<(Song, double, double)> _ranked(
      World w, EditorialPlaylist p, Map<int, double> plays) {
    final out = <(Song, double, double)>[];
    for (final id in w.activeSongIds) {
      final s = w.songs[id];
      final v = plays[id] ?? 0;
      if (v <= 0 || !_eligible(w, p, s)) continue;
      out.add((s, v, _score(p, s, v)));
    }
    out.sort((x, y) {
      final d = y.$3.compareTo(x.$3);
      return d != 0 ? d : x.$1.id.compareTo(y.$1.id);
    });
    return out;
  }

  static Map<int, double> _plays(World w) => {
        for (final id in w.activeSongIds)
          id: w.songWeekStreamsIn(w.songs[id], ChartMarket.global) *
              Streamify.share,
      };

  static EditorialView view(World w, EditorialPlaylist p) {
    final ranked = _ranked(w, p, _plays(w));
    return EditorialView(
      playlist: p,
      followers: followers(p, GameTime.yearOf(w.week - 1)),
      rows: [
        for (final (i, (s, v, _)) in ranked.take(size).indexed)
          EditorialRow.of(w, s, i + 1, v),
      ],
    );
  }

  /// The playlists open last week.
  static List<EditorialPlaylist> playlists(World w) =>
      openIn(GameTime.yearOf(w.week - 1)) ? EditorialPlaylist.values : const [];

  /// Where [songId] is on the playlists, flagship first.
  static List<EditorialPlacement> placements(World w, int songId) {
    if (!openIn(GameTime.yearOf(w.week - 1))) return const [];
    final s = w.songs[songId];
    if (s.status != SongStatus.active) return const [];
    final plays = _plays(w);
    if ((plays[songId] ?? 0) <= 0) return const [];
    return [
      for (final p in EditorialPlaylist.values)
        if (_eligible(w, p, s))
          if (_ranked(w, p, plays)
                  .take(size)
                  .toList()
                  .indexWhere((r) => r.$1.id == songId)
              case final i when i >= 0)
            (playlist: p, position: i + 1),
    ];
  }
}
