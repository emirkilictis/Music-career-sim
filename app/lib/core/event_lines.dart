import 'package:game/game.dart';

/// A game event with the names it refers to, resolved on the game side so
/// the UI can build the sentence without another round trip.
class EventLine {
  EventLine(this.event,
      {this.title = '',
      this.artistName = '',
      this.songId,
      this.albumId = -1,
      this.title2 = '',
      this.artistName2 = '',
      this.genre = -1});
  final GameEvent event;

  /// The release the line is about, for its cover (song first, then album).
  final int? songId;
  final int albumId;

  /// Song or album title (empty when the event has none).
  final String title;

  /// Rival artist name for industry headlines.
  final String artistName;

  /// A second release and artist (the award winners' headline).
  final String title2;
  final String artistName2;

  /// The player's genre, for the genre award's name (docs K91).
  final int genre;
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
        CatchingOn() => EventLine(e, title: song(e.songId)),
        EraClosed() => EventLine(e),
        BurnoutOver() => EventLine(e),
        PlatformLaunched() => EventLine(e),
        HolidaySeason() => EventLine(e),
        ReleaseOut() => release(e, e.kind, e.entityId),
        LabelOffer() => EventLine(e),
        CriticReview() => release(e, EntityKind.album, e.albumId),
        LabelDropped() => EventLine(e),
        OpportunityCame() => EventLine(e),
        OpportunityLapsed() => EventLine(e),
        MilestoneReached() => EventLine(e),
        TourFinished() => EventLine(e),
        FestivalPlayed() => EventLine(e),
        PlatformOpened() => EventLine(e),
        ChartBattle() => EventLine(e,
            title: entity(e.kind, e.playerEntityId),
            artistName: w.artists[e.rivalArtistId].name),
        ReleaseAnnounced() =>
          EventLine(e, title: e.title, songId: e.songId < 0 ? null : e.songId),
        RivalNumberOne() => EventLine(e,
            title: entity(e.kind, e.entityId),
            artistName: w.artists[e.artistId].name),
        BotsCaught() => release(e, EntityKind.song, e.songId),
        RivalBotsCaught() => EventLine(e,
            title: song(e.songId), artistName: w.artists[e.artistId].name),
        CriticsList() => release(e, EntityKind.album, e.albumId),
        RivalAlbumMove() => EventLine(e,
            title: album(e.albumId),
            albumId: e.albumId,
            artistName: w.artists[e.artistId].name),
        PitchDeclined() => EventLine(e, title: song(e.songId)),
        CreatorsFlopped() => EventLine(e, title: song(e.songId)),
        HolidayReturn() => release(e, EntityKind.song, e.songId),
        SongLeaked() => release(e, EntityKind.song, e.songId),
        SalesMilestone() => EventLine(e),
        ListenersMilestone() => EventLine(e),
        ThisIsMade() => EventLine(e),
        AlbumStreamMilestone() => release(e, EntityKind.album, e.albumId),
        WrittenSongHit() => EventLine(e,
            title: song(e.songId), artistName: w.artists[e.artistId].name),
        CreditSongHit() => EventLine(e,
            title: song(e.songId), artistName: w.artists[e.artistId].name),
        CuratorsAnswered() => EventLine(e, title: song(e.songId)),
        ClubMilestone() => EventLine(e),
        DocumentaryPremiere() => EventLine(e),
        PlaylistMilestone() =>
          EventLine(e, title: w.ownPlaylist?.name ?? ''),
        AllTimeBestSeller() => EventLine(e),
        SongOfSummer() => e.hasPlayer
            ? release(e, EntityKind.song, e.playerSongId)
            : EventLine(e,
                title: song(e.topSongId),
                artistName:
                    w.artists[w.songs[e.topSongId].primaryArtistId].name),
        TopArtist() => EventLine(e),
        DiscoverPick() => release(e, EntityKind.song, e.songId),
        AdvanceRecouped() => EventLine(e),
        VideoMilestone() => release(e, EntityKind.song, e.songId),
        StreamMilestone() => release(e, EntityKind.song, e.songId),
        MusicShowResult() => EventLine(e,
            title: song(e.songId),
            title2: e.otherSongId < 0 ? '' : song(e.otherSongId),
            songId: e.songId,
            albumId: coverAlbumOf(w, w.songs[e.songId])),
        RecordBroken(:final kind, :final entityId) => kind.isAlbum
            ? EventLine(e, title: album(entityId), albumId: entityId)
            : release(e, EntityKind.song, entityId),
        WrappedOut() => release(e, EntityKind.song, e.topSongId),
        SurpriseDrop() => release(e, EntityKind.album, e.albumId),
        YearEndCharts() => EventLine(e,
            title: e.hasPlayer
                ? _ranked([for (final (r, id) in e.songs) (r, song(id))])
                : e.topSongId < 0
                    ? ''
                    : song(e.topSongId),
            title2: _ranked([for (final (r, id) in e.albums) (r, album(id))]),
            artistName: e.topSongId < 0
                ? ''
                : w.artists[w.songs[e.topSongId].primaryArtistId].name,
            songId: e.songs.isNotEmpty
                ? e.songs.first.$2
                : (!e.hasPlayer && e.topSongId >= 0 ? e.topSongId : null),
            albumId: e.albums.isNotEmpty ? e.albums.first.$2 : -1),
        RivalAlbumClash() => EventLine(e,
            title: e.clash.title, artistName: w.artists[e.clash.artistId].name),
        BrandDealBroken() => EventLine(e),
        AwardNominated() => EventLine(e, genre: w.player!.genre),
        AwardResults() => EventLine(e, genre: w.player!.genre),
        AwardWinners() => EventLine(e,
            title: e.albumId >= 0 ? album(e.albumId) : '–',
            artistName:
                e.albumArtistId >= 0 ? w.artists[e.albumArtistId].name : '–',
            albumId: e.albumId,
            title2: e.songId >= 0 ? song(e.songId) : '–',
            artistName2:
                e.recordArtistId >= 0 ? w.artists[e.recordArtistId].name : '–'),
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
        CatchingOn() => 4,
        ReleaseOut() => 2,
        LabelOffer() => 2,
        CriticReview() => 3,
        LabelDropped() => 2,
        OpportunityCame() => 3,
        MilestoneReached() => 2,
        TourFinished() => 2,
        FestivalPlayed() => 2,
        PlatformOpened() => 8,
        ChartBattle() => 1,
        OpportunityLapsed() => 6,
        ReleaseAnnounced() => 6,
        BurnoutOver() => 7,
        PlatformLaunched() => 8,
        HolidaySeason() => 8,
        RivalNumberOne() => 9,
        AwardResults() => 0,
        BotsCaught() => 1,
        PitchDeclined() => 6,
        CreatorsFlopped() => 6,
        HolidayReturn() => 4,
        SongLeaked() => 2,
        SalesMilestone() => 3,
        ListenersMilestone() => 3,
        ThisIsMade() => 3,
        AlbumStreamMilestone() => 3,
        WrittenSongHit() => 2,
        CreditSongHit() => 2,
        CuratorsAnswered() => 4,
        ClubMilestone() => 3,
        DocumentaryPremiere() => 1,
        PlaylistMilestone() => 3,
        AllTimeBestSeller() => 1,
        SongOfSummer() => 1,
        RivalAlbumClash() => 3,
        YearEndCharts() => 0,
        WrappedOut() => 1,
        SurpriseDrop() => 0,
        RecordBroken() => 0,
        TopArtist() => 1,
        DiscoverPick() => 6,
        AdvanceRecouped() => 2,
        VideoMilestone() => 3,
        StreamMilestone() => 3,
        MusicShowResult() => 2,
        BrandDealBroken() => 2,
        RivalBotsCaught() => 9,
        RivalAlbumMove() => 4,
        CriticsList() => 1,
        AwardNominated() => 1,
        AwardWinners() => 9,
      };
  return [...lines]..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// “A” #4, “B” #37 and 2 more (year-end news, docs K110).
String _ranked(List<(int, String)> entries) {
  final shown = [for (final (rank, title) in entries.take(3)) '“$title” #$rank']
      .join(', ');
  return entries.length > 3 ? '$shown +${entries.length - 3}' : shown;
}
