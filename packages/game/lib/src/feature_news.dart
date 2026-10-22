import 'package:simulation_core/simulation_core.dart';

/// Features that open in a later year, announced when they do (docs
/// K200), so the player need not find them by chance. The year comes from
/// the rule that opens each one.
enum GameFeature {
  ringtones,
  priceCuts,
  visualAlbum,
  channel,
  cloud,
  streamWindow,
  ownPlaylist,
  moodPlaylists,
  bundles,
  curators,
  documentary,
  exclusives,
  autoplay,
  artistPick,
  preSaves,
  sessions,
  catalogSale,
  creators,
  canvas,
  snippets,
  marquee,
  countdown,
  showcase;

  /// The year it opens.
  int get year => switch (this) {
        ringtones => Ringtones.fromYear,
        priceCuts => PriceCuts.fromYear,
        visualAlbum => VisualAlbums.fromYear,
        channel => Channel.openYear,
        cloud => Cloud.openYear,
        streamWindow => StreamWindows.fromYear,
        ownPlaylist => OwnPlaylists.fromYear,
        moodPlaylists => MoodPlaylists.fromYear,
        bundles => Bundles.fromYear,
        curators => Curators.fromYear,
        documentary => Documentaries.fromYear,
        exclusives => StreamingTools.exclusiveFrom,
        autoplay => StreamingTools.autoplayYear,
        artistPick => ArtistPicks.fromYear,
        preSaves => Actions.preSaveYear,
        sessions => StreamifySessions.fromYear,
        catalogSale => CatalogSale.fromYear,
        creators => StreamingTools.creatorYear,
        canvas => SongCanvas.fromYear,
        snippets => Snippets.fromYear,
        marquee => StreamingTools.marqueeYear,
        countdown => ArtistPicks.countdownYear,
        showcase => StreamingTools.showcaseYear,
      };

  /// Those opening in [year].
  static List<GameFeature> opening(int year) => [
        for (final f in values)
          if (f.year == year) f
      ];
}
