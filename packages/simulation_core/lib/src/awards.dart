import 'dart:convert';
import 'dart:math' as math;

import 'actions.dart';
import 'audience.dart';
import 'award_campaigns.dart';
import 'award_submissions.dart';
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

  /// Most entries the player can put up in one category (docs K227).
  static const maxEntries = 3;

  /// Most genre awards the player can enter.
  static const maxGenres = 2;

  /// What each of an artist's entries in a category loses for every other
  /// one there: they split the voters.
  static const splitPenalty = 0.03;

  /// What an album loses in a genre award it does not fit at all.
  static const misfitPenalty = 0.3;

  /// Whether the player can submit for the next show now: from the end of
  /// the eligibility window to the nominations (docs K227).
  static bool submissionsOpen(World w) {
    final woy = GameTime.weekOfYear(w.week);
    return woy >= windowStartWeekOfYear && woy < nominationsWeekOfYear;
  }

  /// The player's songs in the running for [year]'s show: out in the
  /// window and on the charts.
  static List<Song> eligibleSongs(World w, int year) {
    final (from, to) = window(year);
    return [
      for (final id in w.playerSongIds)
        if (w.songs[id] case final s
            when s.primaryArtistId == w.playerArtistId &&
                s.releasedWeek >= 0 &&
                _out(s) >= from &&
                _out(s) < to &&
                _songHit(s) > 0)
          s
    ];
  }

  static int _out(Song s) =>
      s.isSingle && s.singleWeek >= 0 ? s.singleWeek : s.releasedWeek;

  /// The player's albums in the running for [year]'s show: out in the
  /// window and reviewed.
  static List<Album> eligibleAlbums(World w, int year) {
    final (from, to) = window(year);
    return [
      for (final al in w.albums)
        if (al.artistId == w.playerArtistId &&
            al.releaseWeek >= from &&
            al.releaseWeek < to &&
            al.type == AlbumType.album &&
            al.criticScore >= 0)
          al
    ];
  }

  /// Whether [al] can be up for Album of the Year: on the charts, or the
  /// critics loved it.
  static bool albumOfYearEligible(World w, Album al) =>
      _albumHit(al) > 0 || _critic(w, al) >= 0.75;

  static double _critic(World w, Album al) =>
      (Critics.metascore(w, al) / 10 - 1) / 9;

  /// How much of [al] is [genre]: the share of its tracks in it.
  static double genreFit(World w, Album al, int genre) {
    if (al.songIds.isEmpty) return 0;
    var n = 0;
    for (final id in al.songIds) {
      if (w.songs[id].genres.contains(genre)) n++;
    }
    return n / al.songIds.length;
  }

  /// The genre awards [al] could go up for: the artist's genre and its
  /// tracks' genres.
  static List<int> genreOptions(World w, Album al) => {
        w.artists[al.artistId].genre,
        for (final id in al.songIds) ...w.songs[id].genres,
      }.toList()
        ..sort();

  /// Whether the player could be up for Best New Artist at [year]'s show.
  static bool newArtistEligible(World w, int year) {
    final me = w.player;
    if (me == null) return false;
    final (from, _) = window(year);
    if (me.debutWeek < from - GameTime.weeksPerYear) return false;
    var first = -1;
    for (final id in w.playerSongIds) {
      final s = w.songs[id];
      if (s.primaryArtistId != me.id || s.releasedWeek < 0) continue;
      if (first < 0 || s.releasedWeek < first) first = s.releasedWeek;
    }
    if (first < from - GameTime.weeksPerYear) return false;
    for (final show in w.awardShows) {
      for (final race in show.races) {
        if (race.category == AwardCategory.newArtist &&
            race.nominees.any((n) => n.id == me.id)) {
          return false;
        }
      }
    }
    return eligibleSongs(w, year).isNotEmpty;
  }

  /// What the label submits when the player does not (docs K227): its two
  /// biggest hits for Record and Song of the Year, its biggest album for
  /// Album of the Year and the artist's genre, and Best New Artist.
  static AwardSubmissions labelPicks(World w, int year) {
    final songs = eligibleSongs(w, year)
      ..sort((a, b) {
        final d = _songHit(b).compareTo(_songHit(a));
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    final albums = eligibleAlbums(w, year)
      ..sort((a, b) {
        final d = _albumHit(b).compareTo(_albumHit(a));
        return d != 0 ? d : a.id.compareTo(b.id);
      });
    final top = albums.isEmpty ? null : albums.first;
    final genre = w.player?.genre ?? -1;
    return AwardSubmissions(year, [
      for (final s in songs.take(2)) AwardSubmission(AwardCategory.record, s.id),
      for (final s in songs.take(2)) AwardSubmission(AwardCategory.song, s.id),
      if (top != null && albumOfYearEligible(w, top))
        AwardSubmission(AwardCategory.album, top.id),
      if (top != null)
        AwardSubmission(AwardCategory.genreAlbum, top.id, genre: genre),
    ]);
  }

  /// The player's entries for [year]'s show: theirs, or the label's.
  static AwardSubmissions submissionsFor(World w, int year) {
    final s = w.awardSubmissions;
    return s != null && s.year == year ? s : labelPicks(w, year);
  }

  /// Every entry the player could make for [year]'s show.
  static AwardSubmissions everything(World w, int year) =>
      AwardSubmissions(year, [
        for (final s in eligibleSongs(w, year)) ...[
          AwardSubmission(AwardCategory.record, s.id),
          AwardSubmission(AwardCategory.song, s.id),
        ],
        for (final al in eligibleAlbums(w, year)) ...[
          if (albumOfYearEligible(w, al))
            AwardSubmission(AwardCategory.album, al.id),
          for (final g in genreOptions(w, al))
            AwardSubmission(AwardCategory.genreAlbum, al.id, genre: g),
        ],
      ]);

  /// Puts in the player's entries for the next show (docs K227).
  static void submit(World w, AwardSubmissions s) {
    if (!submissionsOpen(w) || s.year != showYearOf(w.week)) {
      throw ActionException('Submissions are closed');
    }
    final allowed = everything(w, s.year).entries.toSet();
    for (final e in s.entries) {
      if (!allowed.contains(e)) throw ActionException('Not eligible');
    }
    if (s.entries.toSet().length != s.entries.length) {
      throw ActionException('Twice');
    }
    for (final c in AwardCategory.values) {
      if (c == AwardCategory.genreAlbum) {
        for (final g in s.genres) {
          if (s.count(c, genre: g) > maxEntries) {
            throw ActionException('Too many');
          }
        }
      } else if (s.count(c) > maxEntries) {
        throw ActionException('Too many');
      }
    }
    if (s.genres.length > maxGenres) throw ActionException('Too many genres');
    w.awardSubmissions = s;
  }

  /// How each of the player's possible entries looks to the voters now,
  /// against the field (no luck, no split vote).
  static Map<AwardSubmission, AwardOutlook> outlook(World w, int year) {
    final all = everything(w, year);
    final ballots = _ballots(w, year, () => 0, all, split: false);
    final out = <AwardSubmission, AwardOutlook>{};
    for (final e in all.entries) {
      final key =
          (e.category, e.category == AwardCategory.genreAlbum ? e.genre : -1);
      final pool = ballots[key] ?? const [];
      final mine = pool
          .where((x) => x.$2.id == e.id && x.$2.artistId == w.playerArtistId)
          .firstOrNull;
      if (mine == null) continue;
      // Rivals ahead of it, each artist once.
      final ahead = <int>{
        for (final (score, n) in pool)
          if (n.artistId != w.playerArtistId && score > mine.$1) n.artistId
      }.length;
      final slots = Awards.slots(e.category, year);
      out[e] = ahead < slots - 1
          ? AwardOutlook.strong
          : ahead < slots + 2
              ? AwardOutlook.borderline
              : AwardOutlook.longShot;
    }
    if (newArtistEligible(w, year)) {
      final pool = ballots[(AwardCategory.newArtist, -1)] ?? const [];
      final mine =
          pool.where((x) => x.$2.id == w.playerArtistId).firstOrNull;
      if (mine != null) {
        final ahead = pool.where((x) => x.$1 > mine.$1).length;
        final slots = Awards.slots(AwardCategory.newArtist, year);
        out[AwardSubmission(AwardCategory.newArtist, w.playerArtistId)] =
            ahead < slots - 1
                ? AwardOutlook.strong
                : ahead < slots + 2
                    ? AwardOutlook.borderline
                    : AwardOutlook.longShot;
      }
    }
    return out;
  }

  /// The voters' scores in every race of [year]'s show: (category, genre
  /// or -1) to (score, nominee). The player is in only with [mine].
  static Map<(AwardCategory, int), List<(double, AwardNominee)>> _ballots(
      World w, int year, double Function() noise, AwardSubmissions mine,
      {bool split = true}) {
    final (from, to) = window(year);
    final me = w.player;
    final pid = w.playerArtistId;
    double splitOf(AwardCategory c, {int genre = -1}) =>
        split ? splitPenalty * (mine.count(c, genre: genre) - 1) : 0;

    // Songs: singles (or charting album tracks) out in the window.
    final record = <(double, AwardNominee)>[];
    final song = <(double, AwardNominee)>[];
    final firstRelease = <int, int>{};
    // Each artist's best record, whatever they submitted: the voters know
    // a new artist by all of it.
    final best = <int, double>{};
    for (final s in w.songs) {
      if (s.releasedWeek < 0) continue;
      final a = s.primaryArtistId;
      final first = firstRelease[a];
      if (first == null || s.releasedWeek < first) {
        firstRelease[a] = s.releasedWeek;
      }
      final out = _out(s);
      if (out < from || out >= to) continue;
      final hit = _songHit(s);
      if (hit <= 0) continue;
      final q = _quality(s.quality);
      final fame = w.artists[a].fame;
      final n = AwardNominee(s.id, a);
      // A For Your Consideration campaign (docs K171).
      final fyc = AwardCampaigns.nominationLift(w, year, a);
      final rec = 0.5 * hit + 0.4 * q + 0.1 * fame + noise() + fyc;
      final son = 0.3 * hit + 0.65 * q + 0.05 * fame + noise() + fyc;
      best[a] = math.max(best[a] ?? 0, rec);
      // The player's records are up only where they were submitted (K227).
      if (a != pid || mine.has(AwardCategory.record, s.id)) {
        record.add((rec - (a == pid ? splitOf(AwardCategory.record) : 0), n));
      }
      if (a != pid || mine.has(AwardCategory.song, s.id)) {
        song.add((son - (a == pid ? splitOf(AwardCategory.song) : 0), n));
      }
    }

    // Albums out in the window that critics reviewed.
    final album = <(double, AwardNominee)>[];
    final genres = <int>{if (me != null) me.genre, ...mine.genres};
    final genreAlbum = {for (final g in genres) g: <(double, AwardNominee)>[]};
    for (final al in w.albums) {
      if (al.releaseWeek < from || al.releaseWeek >= to) continue;
      if (al.type != AlbumType.album || al.criticScore < 0) continue;
      final a = w.artists[al.artistId];
      final critic = _critic(w, al);
      final hit = _albumHit(al);
      final q = _quality(al.quality);
      final n = AwardNominee(al.id, a.id);
      final fyc = AwardCampaigns.nominationLift(w, year, a.id);
      final own = a.id == pid;
      // The voters' luck is drawn as before submissions (docs K227), so
      // worlds play out the same: for every album in the running, and for
      // the genre race the artist is in.
      if (hit > 0 || critic >= 0.75) {
        final score = 0.45 * critic +
            0.25 * q +
            0.2 * hit +
            0.1 * a.fame +
            noise() +
            fyc;
        if (!own || mine.has(AwardCategory.album, al.id)) {
          album.add((score - (own ? splitOf(AwardCategory.album) : 0), n));
        }
      }
      if (own) {
        if (genres.isEmpty) continue;
        final genreScore = 0.5 * critic + 0.2 * q + 0.3 * hit + noise() + fyc;
        // The player's album goes up for the genre awards they picked,
        // weaker where it does not fit (docs K227).
        for (final g in genres) {
          if (!mine.has(AwardCategory.genreAlbum, al.id, genre: g)) continue;
          genreAlbum[g]!.add((
            genreScore -
                misfitPenalty * (1 - genreFit(w, al, g)) -
                splitOf(AwardCategory.genreAlbum, genre: g),
            n
          ));
        }
      } else if (genreAlbum[a.genre] case final pool?) {
        pool.add((0.5 * critic + 0.2 * q + 0.3 * hit + noise() + fyc, n));
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
    final newArtist = <(double, AwardNominee)>[];
    for (final e in best.entries) {
      final a = w.artists[e.key];
      final first = firstRelease[a.id] ?? -1;
      if (before.contains(a.id) ||
          a.debutWeek < from - GameTime.weeksPerYear ||
          first < from - GameTime.weeksPerYear) {
        continue;
      }
      // The player may hold it back for next year (docs K227).
      if (a.id == pid && !mine.newArtist) continue;
      newArtist.add(
          (0.6 * e.value + 0.4 * a.fame + noise(), AwardNominee(a.id, a.id)));
    }
    return {
      (AwardCategory.record, -1): record,
      (AwardCategory.song, -1): song,
      (AwardCategory.album, -1): album,
      (AwardCategory.newArtist, -1): newArtist,
      for (final g in genres) (AwardCategory.genreAlbum, g): genreAlbum[g]!,
    };
  }

  /// Picks this year's nominees (in the nominations week). Each nomination
  /// brings a little buzz.
  static AwardShow? nominate(World w) {
    if (GameTime.weekOfYear(w.week) != nominationsWeekOfYear) return null;
    final year = showYearOf(w.week);
    if (showFor(w, year) != null) return null;
    final r = RandomStream.keyed(w.seed, w.week, year, RngPurpose.awards);
    double noise() => r.nextNormal() * 0.05;
    final me = w.player;
    final mine = submissionsFor(w, year);
    final ballots = _ballots(w, year, noise, mine);

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

    add(AwardCategory.record, ballots[(AwardCategory.record, -1)]!);
    add(AwardCategory.song, ballots[(AwardCategory.song, -1)]!);
    add(AwardCategory.album, ballots[(AwardCategory.album, -1)]!);
    add(AwardCategory.newArtist, ballots[(AwardCategory.newArtist, -1)]!);
    // The artist's genre, then any other genre the player entered.
    final genres = [
      if (me != null) me.genre,
      for (final g in mine.genres.toList()..sort())
        if (g != me?.genre) g
    ];
    for (final g in genres) {
      add(AwardCategory.genreAlbum, ballots[(AwardCategory.genreAlbum, g)]!,
          genre: g);
    }
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

  /// What a UK chart run counts for next to a US or global one (docs
  /// K239): voters hear of a British hit too, not as loudly.
  static const ukWeight = 0.8;

  /// How big a hit [s] was: 1 for a long-running #1, 0 if it never charted.
  static double _songHit(Song s) => math.max(
      _hit(s, [Charts.usSongs, Charts.globalSongs], 101, 40),
      ukWeight * _hit(s, [Charts.ukSongs], 101, 40));

  static double _albumHit(Album al) => math.max(
      _hit(al, [Charts.usAlbums, Charts.globalAlbums], 201, 52),
      ukWeight * _hit(al, [Charts.ukAlbums], 201, 52));

  static double _hit(Charted e, List<int> charts, int size, int fullWeeks) {
    var peak = 0, weeks = 0;
    for (final c in charts) {
      final p = e.peakOn(c);
      if (p > 0 && (peak == 0 || p < peak)) peak = p;
      weeks = math.max(weeks, e.weeksOnChart(c));
    }
    if (peak == 0) return 0;
    return 0.7 * (1 - math.log(peak) / math.log(size)) +
        0.3 * math.min(1.0, weeks / fullWeeks);
  }

  /// Quality on a 0..1 scale where it matters to voters (40 → 0, 95 → 1).
  static double _quality(double q) => ((q - 40) / 55).clamp(0.0, 1.0);
}
