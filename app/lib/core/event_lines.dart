import 'package:game/game.dart';

/// A game event with the names it refers to, resolved on the game side so
/// the UI can build the sentence without another round trip.
class EventLine {
  EventLine(this.event,
      {this.title = '', this.artistName = '', this.songId, this.albumId = -1});
  final GameEvent event;

  /// The release the line is about, for its cover (song first, then album).
  final int? songId;
  final int albumId;

  /// Song or album title (empty when the event has none).
  final String title;

  /// Rival artist name for industry headlines.
  final String artistName;
}

/// Runs on the game side (inside a command).
List<EventLine> describeEvents(GameSession s, List<GameEvent> events) {
  final w = s.world;
  String song(int id) => w.songs[id].title;
  String album(int id) => w.albums[id].title;
  String entity(EntityKind k, int id) =>
      k == EntityKind.song ? song(id) : album(id);
  EventLine release(GameEvent e, EntityKind k, int id) => k == EntityKind.song
      ? EventLine(e, title: song(id), songId: id, albumId: w.songs[id].albumId)
      : EventLine(e, title: album(id), albumId: id);
  return [
    for (final e in events)
      switch (e) {
        ChartDebut() => release(e, e.kind, e.entityId),
        NumberOne() => release(e, e.kind, e.entityId),
        NewPeak() => EventLine(e, title: song(e.songId)),
        AlbumFirstWeek() => EventLine(e, title: album(e.albumId)),
        ViralTrend() => EventLine(e, title: song(e.songId)),
        PlaylistAdded() => EventLine(e, title: song(e.songId)),
        EraClosed() => EventLine(e),
        BurnoutOver() => EventLine(e),
        RivalNumberOne() => EventLine(e,
            title: entity(e.kind, e.entityId),
            artistName: w.artists[e.artistId].name),
      },
  ];
}

/// The player's own news (docs K37): industry headlines are left out.
List<EventLine> playerNews(List<EventLine> lines) =>
    lines.where((l) => !l.event.isIndustry).toList();

/// Most important first: player #1s and big moments before small news.
List<EventLine> sortLines(List<EventLine> lines) {
  int rank(EventLine l) => switch (l.event) {
        NumberOne() => 0,
        AlbumFirstWeek() => 1,
        EraClosed() => 2,
        ViralTrend() => 3,
        ChartDebut() => 4,
        NewPeak() => 5,
        PlaylistAdded() => 6,
        BurnoutOver() => 7,
        RivalNumberOne() => 8,
      };
  return [...lines]..sort((a, b) => rank(a).compareTo(rank(b)));
}
