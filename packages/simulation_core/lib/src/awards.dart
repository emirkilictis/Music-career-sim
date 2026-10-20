import 'dart:convert';
import 'dart:math' as math;

import 'audience.dart';
import 'award_campaigns.dart';
import 'config/charts.dart';
import 'critics.dart';
import 'lifecycle.dart';
import 'model.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

/// Award categories of the Golden Record Awards (docs K91). Index order is
/// stored in saves: only append.
enum AwardCategory {
  /// A single: how big a hit and how good a record.
  record,

  /// The songwriting: mostly how good it is.
  song,

  /// An album: the critics first, then quality and success.
  album,

  /// An artist whose first records came out lately.
  newArtist,

  /// The best album in the player's genre ([AwardRace.genre]).
  genreAlbum;

  /// What the nominees are.
  AwardEntry get entry => switch (this) {
        record || song => AwardEntry.song,
        album || genreAlbum => AwardEntry.album,
        newArtist => AwardEntry.artist,
      };

  /// One of the four big awards everyone watches.
  bool get isGeneralField => this != genreAlbum;
}

enum AwardEntry { song, album, artist }

/// One nominee: a song, an album or an artist (then [id] is the artist).
class AwardNominee {
  const AwardNominee(this.id, this.artistId);
  final int id;
  final int artistId;
}

/// A category at one show: its nominees in order of the voters' score and
/// the winner once the show is held.
class AwardRace {
  AwardRace(
      {required this.category,
      required this.nominees,
      this.genre = -1,
      this.winner = -1});
  final AwardCategory category;
  final List<AwardNominee> nominees;

  /// [genreNames] index for [AwardCategory.genreAlbum].
  final int genre;

  /// Index into [nominees]; -1 until the show.
  int winner;

  AwardNominee? get won => winner >= 0 ? nominees[winner] : null;

  List<Object> toJson() => [
        category.index,
        genre,
        winner,
        [for (final n in nominees) n.id],
        [for (final n in nominees) n.artistId],
      ];

  static AwardRace fromJson(List<dynamic> j) {
    final ids = (j[3] as List).cast<int>();
    final artists = (j[4] as List).cast<int>();
    return AwardRace(
      category: AwardCategory.values[j[0] as int],
      genre: j[1] as int,
      winner: j[2] as int,
      nominees: [
        for (var i = 0; i < ids.length; i++) AwardNominee(ids[i], artists[i])
      ],
    );
  }
}

/// How the player goes to the show (docs K91).
enum AwardAttendance { none, attend, perform }

/// One year's Golden Record Awards: nominated in late November, held in
/// mid-February of [year] for records out from October two years before
/// to September of the year before (like the Grammys).
class AwardShow {
  AwardShow({required this.year, required this.races});
  final int year;
  final List<AwardRace> races;
  bool held = false;
  AwardAttendance attendance = AwardAttendance.none;

  int get ceremonyWeek =>
      GameTime.firstWeekOf(year) + Awards.ceremonyWeekOfYear - 1;

  /// Races [artistId] is nominated in.
  Iterable<AwardRace> racesOf(int artistId) =>
      races.where((r) => r.nominees.any((n) => n.artistId == artistId));

  /// Races [artistId] won.
  Iterable<AwardRace> winsOf(int artistId) =>
      races.where((r) => r.won?.artistId == artistId);

  List<Object> toJson() => [
        year,
        held ? 1 : 0,
        attendance.index,
        [for (final r in races) r.toJson()],
      ];

  static AwardShow fromJson(List<dynamic> j) => AwardShow(
        year: j[0] as int,
        races: [for (final r in j[3] as List) AwardRace.fromJson(r as List)],
      )
        ..held = j[1] == 1
        ..attendance = AwardAttendance.values[j[2] as int];

  static String encode(List<AwardShow> s) =>
      jsonEncode([for (final x in s) x.toJson()]);

  static List<AwardShow> decode(String? s) => s == null || s.isEmpty
      ? []
      : [for (final x in jsonDecode(s) as List) fromJson(x as List)];
}

/// What the show did for the player, for the news.
class AwardNight {
  AwardNight(
      {required this.show,
      required this.nominations,
      required this.wins,
      required this.fans,
      required this.hype});
  final AwardShow show;
  final List<AwardRace> nominations;
  final List<AwardRace> wins;
  final double fans;
  final double hype;
}

abstract final class Awards {
  /// Nominations come out in late November, the show is in mid-February.
  static const nominationsWeekOfYear = 47;
  static const ceremonyWeekOfYear = 6;

  /// Eligibility runs from this week of the year (early October).
  static const windowStartWeekOfYear = 40;

  /// The year the show of [week]'s nominations is held in.
  static int showYearOf(int week) => GameTime.yearOf(week) + 1;

  /// First and one-past-last eligible week for [year]'s show.
  static (int, int) window(int year) => (
        GameTime.firstWeekOf(year - 2) + windowStartWeekOfYear - 1,
        GameTime.firstWeekOf(year - 1) + windowStartWeekOfYear - 1,
      );

  /// Nominees per category: five, eight in the big four from 2019.
  static int slots(AwardCategory c, int year) =>
      c.isGeneralField && year >= 2019 ? 8 : 5;

  static AwardShow? showFor(World w, int year) {
    for (final s in w.awardShows) {
      if (s.year == year) return s;
    }
    return null;
  }

  /// The show the player can go to this week: nominated, not held yet.
  static AwardShow? upcoming(World w) {
    final s = showFor(w, GameTime.yearOf(w.week));
    return s != null && !s.held ? s : null;
  }

  /// Picks this year's nominees (in the nominations week). Each nomination
  /// brings a little buzz.
  static AwardShow? nominate(World w) {
    if (GameTime.weekOfYear(w.week) != nominationsWeekOfYear) return null;
    final year = showYearOf(w.week);
    if (showFor(w, year) != null) return null;
    final (from, to) = window(year);
    final r = RandomStream.keyed(w.seed, w.week, year, RngPurpose.awards);
    double noise() => r.nextNormal() * 0.05;

    // Songs: singles (or charting album tracks) out in the window.
    final record = <(double, AwardNominee)>[];
    final song = <(double, AwardNominee)>[];
    final firstRelease = <int, int>{};
    for (final s in w.songs) {
      if (s.releasedWeek < 0) continue;
      final a = s.primaryArtistId;
      final first = firstRelease[a];
      if (first == null || s.releasedWeek < first) {
        firstRelease[a] = s.releasedWeek;
      }
      final out =
          s.isSingle && s.singleWeek >= 0 ? s.singleWeek : s.releasedWeek;
      if (out < from || out >= to) continue;
      final hit = _songHit(s);
      if (hit <= 0) continue;
      final q = _quality(s.quality);
      final fame = w.artists[a].fame;
      final n = AwardNominee(s.id, a);
      // A For Your Consideration campaign (docs K171).
      final fyc = AwardCampaigns.nominationLift(w, year, a);
      record.add((0.5 * hit + 0.4 * q + 0.1 * fame + noise() + fyc, n));
      song.add((0.3 * hit + 0.65 * q + 0.05 * fame + noise() + fyc, n));
    }

    // Albums out in the window that critics reviewed.
    final album = <(double, AwardNominee)>[];
    final genreAlbum = <(double, AwardNominee)>[];
    final me = w.player;
    for (final al in w.albums) {
      if (al.releaseWeek < from || al.releaseWeek >= to) continue;
      if (al.type != AlbumType.album || al.criticScore < 0) continue;
      final a = w.artists[al.artistId];
      final critic = (Critics.metascore(w, al) / 10 - 1) / 9;
      final hit = _albumHit(al);
      final q = _quality(al.quality);
      final n = AwardNominee(al.id, a.id);
      final fyc = AwardCampaigns.nominationLift(w, year, a.id);
      if (hit > 0 || critic >= 0.75) {
        album.add((
          0.45 * critic + 0.25 * q + 0.2 * hit + 0.1 * a.fame + noise() + fyc,
          n
        ));
      }
      if (me != null && a.genre == me.genre) {
        genreAlbum
            .add((0.5 * critic + 0.2 * q + 0.3 * hit + noise() + fyc, n));
      }
    }

    // New artists: first records in the window or the year before it,
    // never up for it before, with something on the charts.
    final before = <int>{
      for (final show in w.awardShows)
        for (final race in show.races)
          if (race.category == AwardCategory.newArtist)
            for (final n in race.nominees) n.id,
    };
    final best = <int, double>{};
    for (final (score, n) in record) {
      best[n.artistId] = math.max(best[n.artistId] ?? 0, score);
    }
    final newArtist = <(double, AwardNominee)>[];
    for (final e in best.entries) {
      final a = w.artists[e.key];
      final first = firstRelease[a.id] ?? -1;
      if (before.contains(a.id) ||
          a.debutWeek < from - GameTime.weeksPerYear ||
          first < from - GameTime.weeksPerYear) {
        continue;
      }
      newArtist.add(
          (0.6 * e.value + 0.4 * a.fame + noise(), AwardNominee(a.id, a.id)));
    }

    final races = <AwardRace>[];
    void add(AwardCategory c, List<(double, AwardNominee)> pool,
        {int genre = -1, bool onePerArtist = true}) {
      pool.sort((x, y) {
        final d = y.$1.compareTo(x.$1);
        return d != 0 ? d : x.$2.id.compareTo(y.$2.id);
      });
      final picked = <AwardNominee>[];
      final artists = <int>{};
      for (final (_, n) in pool) {
        if (picked.length >= slots(c, year)) break;
        if (onePerArtist && !artists.add(n.artistId)) continue;
        picked.add(n);
      }
      if (picked.length >= 3) {
        races.add(AwardRace(category: c, nominees: picked, genre: genre));
      }
    }

    add(AwardCategory.record, record);
    add(AwardCategory.song, song);
    add(AwardCategory.album, album);
    add(AwardCategory.newArtist, newArtist);
    if (me != null) add(AwardCategory.genreAlbum, genreAlbum, genre: me.genre);
    if (races.isEmpty) return null;
    final show = AwardShow(year: year, races: races);
    w.awardShows.add(show);
    // Being nominated gets people talking.
    final counts = <int, int>{};
    for (final race in races) {
      for (final n in race.nominees) {
        counts[n.artistId] = (counts[n.artistId] ?? 0) + 1;
      }
    }
    for (final id in counts.keys.toList()..sort()) {
      final a = w.artists[id];
      a.hype += 0.02 * math.min(3, counts[id]!);
      w.dirtyArtists.add(id);
    }
    return show;
  }

  /// Holds the show (in its week): the voters pick the winners, mostly the
  /// favorite, and winning brings fame, fans and a return to the charts
  /// for the winning record. Returns the player's night when they were
  /// nominated.
  static AwardNight? hold(World w) {
    if (GameTime.weekOfYear(w.week) != ceremonyWeekOfYear) return null;
    final show = upcoming(w);
    if (show == null) return null;
    show.held = true;
    final r = RandomStream.keyed(w.seed, w.week, show.year, RngPurpose.awards);
    for (final race in show.races) {
      // The ballot order is the voters' favorite first; an upset is
      // possible but rare.
      final weights = [
        for (var i = 0; i < race.nominees.length; i++)
          math.exp(-0.75 * i) *
              // The voting campaign (docs K171).
              AwardCampaigns.voteFactor(
                  w, show.year, race.nominees[i].artistId)
      ];
      final total = weights.fold(0.0, (a, b) => a + b);
      var x = r.nextDouble() * total;
      race.winner = race.nominees.length - 1;
      for (var i = 0; i < weights.length; i++) {
        x -= weights[i];
        if (x <= 0) {
          race.winner = i;
          break;
        }
      }
      _celebrate(w, race, show);
    }
    final me = w.player;
    if (me == null) return null;
    final noms = show.racesOf(me.id).toList();
    if (noms.isEmpty) return null;
    final wins = show.winsOf(me.id).toList();
    // The night itself: a performance reaches millions.
    var fans = 0.0, hype = 0.0;
    switch (show.attendance) {
      case AwardAttendance.perform:
        fans = me.casual * (0.004 + 0.008 * me.skills.performance / 100);
        hype = 0.06;
      case AwardAttendance.attend:
        hype = 0.02;
      case AwardAttendance.none:
        break;
    }
    fans = Audience.addFans(w, me, fans);
    me.hype += hype;
    w.dirtyArtists.add(me.id);
    return AwardNight(
        show: show, nominations: noms, wins: wins, fans: fans, hype: hype);
  }

  /// A win: fame, devotion and buzz for the artist (less when they stayed
  /// home), and the record is heard again.
  static void _celebrate(World w, AwardRace race, AwardShow show) {
    final n = race.won!;
    final a = w.artists[n.artistId];
    final big = race.category.isGeneralField;
    final there =
        a.tier != ArtistTier.player || show.attendance != AwardAttendance.none;
    // A retired artist's audience is frozen (and rebuilt from fame on load).
    if (!a.isRetired) {
      a.fame = math.min(1.0, a.fame + (big ? 0.03 : 0.01));
      a.updateRegionShare();
    }
    a.devotion = math.min(1.0, a.devotion + 0.01);
    a.hype += (big ? 0.1 : 0.04) * (there ? 1 : 0.5);
    Audience.addFans(w, a, a.casual * (big ? 0.008 : 0.003));
    w.dirtyArtists.add(a.id);
    void lift(Song s, double boost) {
      if (s.status == SongStatus.dormant) Lifecycle.reactivateSong(w, s);
      if (s.status != SongStatus.active) return;
      s.weeksBelowCutoff = 0;
      s.playlistBoost = math.max(s.playlistBoost, boost);
      w.dirtySongs.add(s.id);
    }

    switch (race.category) {
      case AwardCategory.record:
        lift(w.songs[n.id], 0.6);
      case AwardCategory.song:
        lift(w.songs[n.id], 0.4);
      case AwardCategory.album || AwardCategory.genreAlbum:
        final al = w.albums[n.id];
        for (final id in al.songIds) {
          lift(w.songs[id], race.category == AwardCategory.album ? 0.35 : 0.12);
        }
      case AwardCategory.newArtist:
        Audience.addCasual(w, a, a.casual * 0.05);
    }
  }

  /// How big a hit [s] was: 1 for a long-running #1, 0 if it never charted.
  static double _songHit(Song s) {
    var peak = 0;
    for (final c in [Charts.usSongs, Charts.globalSongs]) {
      final p = s.peakOn(c);
      if (p > 0 && (peak == 0 || p < peak)) peak = p;
    }
    if (peak == 0) return 0;
    final weeks = math.max(
        s.weeksOnChart(Charts.usSongs), s.weeksOnChart(Charts.globalSongs));
    return 0.7 * (1 - math.log(peak) / math.log(101)) +
        0.3 * math.min(1.0, weeks / 40);
  }

  static double _albumHit(Album al) {
    var peak = 0;
    for (final c in [Charts.usAlbums, Charts.globalAlbums]) {
      final p = al.peakOn(c);
      if (p > 0 && (peak == 0 || p < peak)) peak = p;
    }
    if (peak == 0) return 0;
    final weeks = math.max(
        al.weeksOnChart(Charts.usAlbums), al.weeksOnChart(Charts.globalAlbums));
    return 0.7 * (1 - math.log(peak) / math.log(201)) +
        0.3 * math.min(1.0, weeks / 52);
  }

  /// Quality on a 0..1 scale where it matters to voters (40 → 0, 95 → 1).
  static double _quality(double q) => ((q - 40) / 55).clamp(0.0, 1.0);
}
