import 'dart:math' as math;

import 'actions.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'own_playlist.dart';
import 'time.dart';
import 'world.dart';

/// The player asking a rival to feature on a song (docs K117). The
/// simulation already counts a featured artist's fans and listeners on
/// the song; this is how the player gets one.
abstract final class Features {
  /// Featured artists a song can have.
  static const maxPerSong = 2;

  /// Rivals offered at once.
  static const shortlist = 20;

  /// What [rival] asks for a verse: more the more famous.
  static int feeCents(Artist rival) =>
      (500000 + 30000000 * rival.fame * rival.fame).round();

  /// Whether [rival] would say yes to [a]: stars do not feature on
  /// unknowns' songs, though a shared genre helps.
  /// [w] given, a rival whose song is on the player's playlist is a
  /// little easier to get (docs K159).
  static bool willing(Artist rival, Artist a, [World? w]) =>
      rival.fame <=
      a.fame +
          (rival.genre == a.genre ? 0.5 : 0.35) +
          (w != null && a.tier == ArtistTier.player && OwnPlaylists.favours(w, rival)
              ? OwnPlaylists.goodwill
              : 0);

  /// Rivals worth asking for [s]: the ones who would say yes first, the
  /// same genre first among them, then the most famous.
  static List<Artist> candidates(World w, Artist a, Song s) {
    final all = [
      for (final id in w.activeArtistIds)
        if (id != a.id &&
            !w.artists[id].isRetired &&
            w.artists[id].tier != ArtistTier.player &&
            w.artists[id].fame >= 0.05 &&
            !s.featuredArtistIds.contains(id))
          w.artists[id]
    ]..sort((x, y) {
        int key(bool b) => b ? 0 : 1;
        final wx = key(willing(x, a, w)), wy = key(willing(y, a, w));
        if (wx != wy) return wx.compareTo(wy);
        final gx = key(x.genre == a.genre), gy = key(y.genre == a.genre);
        if (gx != gy) return gx.compareTo(gy);
        final f = y.fame.compareTo(x.fame);
        return f != 0 ? f : x.id.compareTo(y.id);
      });
    return all.take(shortlist).toList();
  }

  /// A remix verse costs more than one on a new song (docs K138).
  static const remixFeeFactor = 1.5;

  /// What [rival] asks for a verse on [s]: a released song is a remix.
  static int feeFor(Artist rival, Song s) => s.releasedWeek >= 0
      ? (feeCents(rival) * remixFeeFactor).round()
      : feeCents(rival);

  /// A remix of released [s] featuring [rival] (docs K138), the Despacito
  /// move: the star's fans and listeners come to the song from now on,
  /// and the remix brings a wave of listening, bigger the bigger the star.
  static void requestRemix(World w, Artist a, Song s, Artist rival) {
    if (s.primaryArtistId != a.id ||
        s.releasedWeek < 0 ||
        s.status == SongStatus.scrapped) {
      throw ActionException('Only released songs');
    }
    if (s.featuredArtistIds.length >= maxPerSong) {
      throw ActionException('Enough features');
    }
    if (s.featuredArtistIds.contains(rival.id)) {
      throw ActionException('Already on it');
    }
    if (!willing(rival, a, w)) throw ActionException('Out of reach');
    final fee = feeFor(rival, s);
    if (a.moneyCents < fee) throw ActionException('Not enough money');
    a.moneyCents -= fee;
    s.productionCostCents += fee;
    if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
    s.weeksBelowCutoff = 0;
    s.featuredArtistIds.add(rival.id);
    final year = GameTime.yearOf(w.week);
    final recent = s.versions.where((x) => w.week - x.$2 < 8).length;
    s.versionBoost += SongVersion.remix.boost(year) *
        (1 + rival.fame) *
        math.pow(0.7, recent);
    if (!s.versions.any((x) => x.$1 == SongVersion.remix)) {
      s.versions.add((SongVersion.remix, w.week));
    }
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// Gets [rival] on [s] for their fee.
  static void request(World w, Artist a, Song s, Artist rival) {
    if (s.primaryArtistId != a.id || s.status != SongStatus.vault) {
      throw ActionException('Only unreleased songs');
    }
    if (s.featuredArtistIds.length >= maxPerSong) {
      throw ActionException('Enough features');
    }
    if (s.featuredArtistIds.contains(rival.id)) {
      throw ActionException('Already on it');
    }
    if (!willing(rival, a, w)) throw ActionException('Out of reach');
    final fee = feeCents(rival);
    if (a.moneyCents < fee) throw ActionException('Not enough money');
    a.moneyCents -= fee;
    s.productionCostCents += fee;
    s.featuredArtistIds.add(rival.id);
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }
}
