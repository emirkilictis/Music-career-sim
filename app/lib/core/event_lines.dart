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
      ? EventLine(e,
          title: song(id), songId: id, albumId: coverAlbumOf(w, w.songs[id]))
      : EventLine(e, title: album(id), albumId: id);
  return [
    for (final e in events)
      switch (e) {
        ChartDebut() => release(e, e.kind, e.entityId),
        NumberOne() => release(e, e.kind, e.entityId),
        StillNumberOne() => release(e, e.kind, e.entityId),
        NewPeak() => EventLine(e, title: song(e.songId)),
        AlbumFirstWeek() => EventLine(e, title: album(e.albumId)),
        ViralTrend() => EventLine(e, title: song(e.songId)),
        PlaylistAdded() => EventLine(e, title: song(e.songId)),
        EraClosed() => EventLine(e),
        BurnoutOver() => EventLine(e),
        PlatformLaunched() => EventLine(e),
        ReleaseOut() => release(e, e.kind, e.entityId),
        LabelOffer() => EventLine(e),
        CriticReview() => release(e, EntityKind.album, e.albumId),
        LabelDropped() => EventLine(e),
        OpportunityCame() => EventLine(e),
        OpportunityLapsed() => EventLine(e),
        MilestoneReached() => EventLine(e),
        TourFinished() => EventLine(e),
        PlatformOpened() => EventLine(e),
        ReleaseAnnounced() =>
          EventLine(e, title: e.title, songId: e.songId < 0 ? null : e.songId),
        RivalNumberOne() => EventLine(e,
            title: entity(e.kind, e.entityId),
            artistName: w.artists[e.artistId].name),
      },
  ];
}

/// The player's own news (docs K37): industry headlines are left out, and
/// a scheduled album that charted is told by its first-week line only.
List<EventLine> playerNews(List<EventLine> lines) {
  final firstWeek = {
    for (final l in lines)
      if (l.event case AlbumFirstWeek(:final albumId)) albumId,
  };
  return lines
      .where((l) => !l.event.isIndustry)
      .where((l) => switch (l.event) {
            ReleaseOut(kind: EntityKind.album, :final entityId) =>
              !firstWeek.contains(entityId),
            _ => true,
          })
      .toList();
}

/// Scheduled albums that came out in [lines]: (schedule id, album id), so
/// a cover picked in advance can move to the album (docs K45).
List<(int, int)> scheduledAlbumsOut(List<EventLine> lines) => [
      for (final l in lines)
        if (l.event
            case ReleaseOut(
              kind: EntityKind.album,
              :final entityId,
              :final scheduleId
            ))
          (scheduleId, entityId),
    ];

/// Most important first: player #1s and big moments before small news.
List<EventLine> sortLines(List<EventLine> lines) {
  int rank(EventLine l) => switch (l.event) {
        NumberOne() => 0,
        StillNumberOne() => 1,
        AlbumFirstWeek() => 1,
        EraClosed() => 2,
        ViralTrend() => 3,
        ChartDebut() => 4,
        NewPeak() => 5,
        PlaylistAdded() => 6,
        ReleaseOut() => 2,
        LabelOffer() => 2,
        CriticReview() => 3,
        LabelDropped() => 2,
        OpportunityCame() => 3,
        MilestoneReached() => 2,
        TourFinished() => 2,
        PlatformOpened() => 8,
        OpportunityLapsed() => 6,
        ReleaseAnnounced() => 6,
        BurnoutOver() => 7,
        PlatformLaunched() => 8,
        RivalNumberOne() => 9,
      };
  return [...lines]..sort((a, b) => rank(a).compareTo(rank(b)));
}
