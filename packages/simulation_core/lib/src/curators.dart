import 'dart:math' as math;

import 'actions.dart';
import 'audience.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// How many independent curators a submission reaches, and its price.
/// Index order is stored in saves: only append.
enum CuratorPack {
  small(10, 10000),
  medium(30, 30000),
  large(80, 80000);

  const CuratorPack(this.curators, this.costCents);
  final int curators;
  final int costCents;
}

/// Why a curator said what they said.
enum CuratorNote { added, notOurSound, notReady, passed }

/// One curator's answer to a submission.
class CuratorAnswer {
  const CuratorAnswer(this.name, this.followers, this.genre, this.note);
  final String name;
  final double followers;
  final int genre;
  final CuratorNote note;
  bool get added => note == CuratorNote.added;
}

/// Submitting a song to independent playlist curators (docs K160), the
/// SubmitHub way: a few dollars a curator, an answer from each within a
/// week, most of them no. The ones who add it play it to their followers
/// for a couple of months; for a newcomer that is real listening, and a
/// song people save from playlists gets noticed by the app's algorithm.
abstract final class Curators {
  /// Paid submission sites start.
  static const fromYear = 2015;

  /// A song can be sent while it is out this recently (or before).
  static const windowWeeks = 16;

  /// Weeks a curator keeps a song on their playlist, the weekly plays per
  /// follower and how they fade.
  static const playWeeks = 10;
  static const playsPerFollower = 0.08;
  static const fade = 0.85;

  /// Followers who become listeners of the artist.
  static const casualPerFollower = 0.01;

  /// Followers of the curators who added a song for twice the usual
  /// chance of the discovery mixes picking it.
  static const discoverHalf = 100000.0;

  static bool open(World w) => GameTime.yearOf(w.week) >= fromYear;

  static bool can(World w, Song s) =>
      open(w) &&
      s.curatorWeek < 0 &&
      s.status != SongStatus.scrapped &&
      !s.cloudOnly &&
      s.releasedWeek >= 0 &&
      w.week - math.max(s.releasedWeek, s.singleWeek) <= windowWeeks;

  /// What [pack] costs [a].
  static int costCents(Artist a, CuratorPack pack) => pack.costCents;

  /// Sends [s] to [pack]'s curators; they answer at the end of the week.
  static void submit(World w, Artist a, Song s, CuratorPack pack) {
    if (!can(w, s)) throw ActionException('Cannot submit');
    final cost = costCents(a, pack);
    if (a.moneyCents < cost) throw ActionException('Not enough money');
    a.moneyCents -= cost;
    s.productionCostCents += cost;
    s.curatorWeek = w.week;
    s.curatorPack = pack;
    w.dirtySongs.add(s.id);
    w.dirtyArtists.add(a.id);
  }

  /// Week the answers come in, played with the song on the playlists
  /// (-1: not sent).
  static int answerWeek(Song s) => s.curatorWeek;

  /// The chance one curator of [genre] adds [s]: a good song in their
  /// genre often, anything else rarely.
  static double addChance(Song s, int genre) {
    final q = s.quality / 100;
    final fit = s.genres.contains(genre) ? 1.8 : 0.35;
    return math.min(0.85, (0.02 + 0.35 * math.pow(q, 2.5)) * fit);
  }

  static const _first = [
    'Late Night', 'Indie', 'Fresh', 'Chill', 'Morning', 'Sunset', 'Hidden',
    'Golden', 'Midnight', 'Weekend', 'Rainy Day', 'Road Trip', 'Bedroom',
    'Neon', 'Lo-Fi', 'Summer', 'Underground', 'Daily', 'New', 'Soft',
  ];
  static const _second = [
    'Vibes', 'Gems', 'Finds', 'Hours', 'Drive', 'Mix', 'Waves', 'Club',
    'Radar', 'Picks', 'Session', 'Diaries', 'Rotation', 'Sounds', 'Mood',
    'Discoveries', 'Tapes', 'Feels', 'Selects', 'Heat',
  ];

  /// The curators [s] went to and what each said (same every time).
  static List<CuratorAnswer> answers(World w, Song s) {
    if (s.curatorWeek < 0) return const [];
    final r = RandomStream.keyed(
        w.seed, s.curatorWeek, s.id, RngPurpose.curators);
    final out = <CuratorAnswer>[];
    for (var i = 0; i < s.curatorPack.curators; i++) {
      // Half of them work the song's own genres.
      final genre = r.chance(0.5)
          ? s.genres[r.nextInt(s.genres.length)]
          : r.nextInt(genreNames.length);
      // Most playlists are small (log-uniform 500..200K).
      final followers =
          500 * math.pow(400, r.nextDouble() * r.nextDouble()).toDouble();
      final name = '${_first[r.nextInt(_first.length)]} '
          '${_second[r.nextInt(_second.length)]}';
      final CuratorNote note;
      if (r.chance(addChance(s, genre))) {
        note = CuratorNote.added;
      } else if (!s.genres.contains(genre)) {
        note = CuratorNote.notOurSound;
      } else if (s.quality < 60) {
        note = CuratorNote.notReady;
      } else {
        note = CuratorNote.passed;
      }
      out.add(CuratorAnswer(name, followers.roundToDouble(), genre, note));
    }
    return out;
  }

  /// The answers come in: the curators who said yes start playing it.
  static void answer(World w) {
    final p = w.player;
    if (p == null) return;
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (answerWeek(s) != w.week) continue;
      var adds = 0;
      var reach = 0.0;
      for (final a in answers(w, s)) {
        if (!a.added) continue;
        adds++;
        reach += a.followers;
      }
      s.curatorAdds = adds;
      s.curatorReach = reach;
      if (reach > 0) {
        if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
        s.weeksBelowCutoff = 0;
        Audience.addCasual(w, p, reach * casualPerFollower);
      }
      w.dirtySongs.add(id);
    }
  }

  /// Plays from curators' playlists in [week] (all regions).
  static double streams(Song s, int week) {
    if (s.curatorReach <= 0) return 0;
    final age = week - answerWeek(s);
    if (age < 0 || age >= playWeeks) return 0;
    return s.curatorReach * playsPerFollower * math.pow(fade, age);
  }

  /// How much likelier the discovery mixes pick [s] in [week] (1: as
  /// usual).
  static double discoverFactor(Song s, int week) {
    if (s.curatorReach <= 0) return 1;
    final age = week - answerWeek(s);
    if (age < 0 || age >= playWeeks) return 1;
    return 1 + s.curatorReach / (s.curatorReach + discoverHalf) * 2;
  }
}
