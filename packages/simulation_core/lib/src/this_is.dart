import 'model.dart';
import 'time.dart';
import 'world.dart';

/// The streaming app's This Is playlist (docs K189), like Spotify's "This
/// Is" lists: the editors make one for an artist people listen to, with
/// the essential songs first and the new ones near the top. Once made it
/// stays and keeps itself up to date. Fans who put it on hear songs they
/// would not have picked, so the catalog beyond the hits gets played.
abstract final class ThisIs {
  static const fromYear = 2016;

  /// What the editors want before they make one: enough released songs
  /// and enough monthly listeners (the game checks the listeners).
  static const minSongs = 8;
  static const minListeners = 250000.0;

  static const size = 25;

  /// The best known songs at the top get little from it; deeper songs
  /// more; a new release, put in at #2 and #3 for [newWeeks], too.
  static const hits = 5;
  static const hitLift = 0.02, catalogLift = 0.07, newLift = 0.05;
  static const newWeeks = 8, newSlots = 2;

  static bool open(World w) => GameTime.yearOf(w.week) >= fromYear;

  /// [a]'s songs the list can take: released under their name, still
  /// theirs to play (not scrapped, not replaced by a re-recording).
  static List<Song> eligible(World w, Artist a) {
    final ids = a.tier == ArtistTier.player
        ? w.playerSongIds
        : [
            for (final s in w.songs)
              if (s.primaryArtistId == a.id) s.id
          ];
    return [
      for (final id in ids)
        if (w.songs[id] case final s
            when s.primaryArtistId == a.id &&
                s.releasedWeek >= 0 &&
                s.releasedWeek <= w.week &&
                s.status != SongStatus.scrapped &&
                s.replacedWeek < 0)
          s
    ];
  }

  /// Whether the editors would make one for [a] now, given [listeners].
  static bool qualifies(World w, Artist a, double listeners) =>
      open(w) &&
      listeners >= minListeners &&
      eligible(w, a).length >= minSongs;

  /// Whether [s] counts as new on the list this week.
  static bool isNew(World w, Song s) => w.week - s.releasedWeek < newWeeks;

  /// The list for [a], in order: the biggest song, then up to [newSlots]
  /// new ones, then the rest by all-time streams.
  static List<Song> songs(World w, Artist a) {
    final all = eligible(w, a)
      ..sort((x, y) => w.songLifetimeStreams(y).compareTo(
          w.songLifetimeStreams(x)));
    if (all.isEmpty) return all;
    final fresh = [
      for (final s in all)
        if (isNew(w, s)) s
    ]..sort((x, y) => y.releasedWeek.compareTo(x.releasedWeek));
    final top = fresh.take(newSlots).toSet();
    final rest = [
      for (final s in all)
        if (!top.contains(s)) s
    ];
    return [
      if (rest.isNotEmpty) rest.first,
      ...top,
      ...rest.skip(1),
    ].take(size).toList();
  }

  /// The lift a song gets at [index] on the list.
  static double liftAt(World w, Song s, int index) {
    if (isNew(w, s)) return newLift;
    return index < hits ? hitLift : catalogLift;
  }

  /// This week's lifts for the player's songs on their list.
  static Map<int, double> lifts(World w) {
    final a = w.player;
    if (a == null || w.thisIsWeek < 0) return const {};
    final list = songs(w, a);
    return {
      for (var i = 0; i < list.length; i++) list[i].id: liftAt(w, list[i], i)
    };
  }
}
