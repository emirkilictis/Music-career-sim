import 'dart:math' as math;

import 'config/difficulty.dart';
import 'config/regions.dart';
import 'config/sim_config.dart';
import 'model.dart';
import 'names.dart';
import 'real_artists.dart';
import 'rng.dart';
import 'time.dart';
import 'world.dart';

enum StartTier { unknown, localBuzz, risingStar, superstar }

/// Starting cash. [basic] is the free start (more via the job or rewarded
/// ads); [comfortable] and [millionaire] are Premium starts (§20).
enum StartMoney { basic, comfortable, millionaire }

enum CareerPath { independent, smallLabel }

/// Starting stat allocation (docs/game-design.md §2.1): every stat starts at
/// [base] and the player spends a pool of points on top, up to a cap.
/// Premium gets a bigger pool and a higher cap.
abstract final class StartingStats {
  static const base = 25.0;

  static int points({required bool premium}) => premium ? 55 : 30;
  static double cap({required bool premium}) => premium ? 70 : 60;

  static bool isValid(Skills s, {required bool premium}) {
    final v = [
      s.songwriting,
      s.vocals,
      s.production,
      s.performance,
      s.charisma,
    ];
    final limit = cap(premium: premium);
    if (v.any((x) => x < base || x > limit)) return false;
    final spent = v.fold(0.0, (a, x) => a + x - base);
    return spent <= points(premium: premium) + 1e-9;
  }

  /// The "auto distribute" button: a build that suits the artist [kind]
  /// (whole points, largest remainder).
  static Skills auto(
      {required bool premium, ArtistKind kind = ArtistKind.solo}) {
    final p = points(premium: premium);
    final exact = [for (final wt in kind.statWeights) wt * p];
    final pts = [for (final x in exact) x.floor()];
    final order = List.generate(5, (i) => i)
      ..sort((i, j) {
        final d = (exact[j] - pts[j]).compareTo(exact[i] - pts[i]);
        return d != 0 ? d : i.compareTo(j);
      });
    var left = p - pts.fold(0, (a, x) => a + x);
    for (final i in order) {
      if (left <= 0) break;
      pts[i]++;
      left--;
    }
    return Skills(
      songwriting: base + pts[0],
      vocals: base + pts[1],
      production: base + pts[2],
      performance: base + pts[3],
      charisma: base + pts[4],
    );
  }
}

/// Builds a new world: AI artists, collaborators, and (optionally) a player.
abstract final class WorldGen {
  /// Creates a world whose clock starts at [SimConfig.worldStartYear] (at
  /// least [SimConfig.burnInYears] before [startYear]); run it up to
  /// [startYear] before handing it to the player.
  static World create({
    required int seed,
    required int startYear,
    SimConfig? config,
    Difficulty difficulty = Difficulty.normal,
    bool realNames = false,
  }) {
    final cfg = config ?? SimConfig();
    final w = World(
      config: cfg,
      seed: seed,
      week: GameTime.firstWeekOf(cfg.worldStartYear(startYear)),
      difficulty: difficulty,
      realNames: realNames,
    );
    for (var i = 0; i < cfg.tierACount; i++) {
      _addAiArtist(w, ArtistTier.a);
    }
    for (var i = 0; i < cfg.tierBCount; i++) {
      _addAiArtist(w, ArtistTier.b);
    }
    _addCollaborators(w);
    return w;
  }

  static Artist addNewAiArtist(World w) =>
      _addAiArtist(w, ArtistTier.b, newcomer: true);

  static Artist _addAiArtist(World w, ArtistTier tier,
      {bool newcomer = false}) {
    final id = w.artists.length;
    final r = RandomStream.keyed(w.seed, 0, id, RngPurpose.worldGen);
    final n = RandomStream.keyed(w.seed, 0, id, RngPurpose.names);
    final isA = tier == ArtistTier.a;
    // The home is drawn first so real names keep the made-up world's mix
    // of countries (docs K70).
    final homeRoll =
        _homeCountry(RandomStream.keyed(w.seed, 1, id, RngPurpose.worldGen));
    final real = w.realNames
        ? _pickReal(w, id, isA: isA, newcomer: newcomer, home: homeRoll)
        : null;
    // Newcomers who became stars in real life start with a star's craft
    // and a label behind them; whether they make it is up to the
    // simulation. Their audience starts like anyone's, so real names do not
    // make the market bigger than a made-up world's (docs K70).
    final craftA = isA || (newcomer && real != null && real.star >= 2);
    double skill(double lo, double hi) => r.range(lo, hi);
    final skills = Skills(
      songwriting: craftA ? skill(60, 92) : skill(35, 78),
      vocals: craftA ? skill(60, 95) : skill(35, 80),
      production: craftA ? skill(40, 85) : skill(25, 70),
      performance: craftA ? skill(55, 95) : skill(30, 80),
      charisma: craftA ? skill(55, 95) : skill(25, 80),
    );
    final double fame;
    final double coreFans;
    final double casual;
    if (newcomer) {
      fame = r.range(0.01, 0.10);
      coreFans = 2e4 * r.logNormal(0.8);
      casual = 2e5 * r.logNormal(0.8);
    } else if (isA) {
      fame = r.range(0.55, 0.95);
      coreFans = 1.6e6 * r.logNormal(0.8) * (0.5 + fame);
      casual = 2.5e7 * r.logNormal(0.4) * (0.5 + fame);
    } else {
      fame = math.pow(r.nextDouble(), 1.6) * 0.5 + 0.02;
      coreFans = 1.5e5 * r.logNormal(0.9) * (0.3 + 3 * fame);
      casual = 1.5e6 * r.logNormal(0.9) * (0.3 + 3 * fame);
    }
    final scale = w.config.globalAudienceScale;
    // Kind and members use their own streams so the other draws stay put.
    final k = RandomStream.keyed(w.seed, 2, id, RngPurpose.worldGen);
    final kindRoll = k.nextDouble();
    final kind = real?.kind ??
        (kindRoll < 0.12
            ? ArtistKind.band
            : (kindRoll < 0.20 ? ArtistKind.vocalGroup : ArtistKind.solo));
    final m = RandomStream.keyed(w.seed, 3, id, RngPurpose.names);
    final memberCount = real != null
        ? 0
        : switch (kind) {
            ArtistKind.solo => 0,
            ArtistKind.band => 3 + m.nextInt(3),
            ArtistKind.vocalGroup => 4 + m.nextInt(4),
          };
    final genreRoll = _weightedGenre(r.nextDouble());
    // Drawn only for founding rivals, as before (keeps made-up worlds the
    // same).
    final debutRoll = newcomer ? 0 : r.nextInt(GameTime.weeksPerYear * 12);
    final a = Artist(
      id: id,
      name: real?.name ??
          _freeName(w, () => kind.isGroup ? Names.group(n) : Names.solo(n)),
      kind: kind,
      members: [for (var i = 0; i < memberCount; i++) Names.person(m)],
      tier: tier,
      homeCountry: real?.home ?? homeRoll,
      genre: real?.genre ?? genreRoll,
      debutWeek: newcomer
          ? w.week
          : real != null
              ? math.min(
                  w.week, GameTime.firstWeekOf(real.debut) + debutRoll % 40)
              : w.week - debutRoll,
      skills: skills,
      fame: fame,
      coreFans: coreFans * scale,
      casual: casual * scale,
      labelReach:
          isA || (newcomer && craftA) ? r.range(1.1, 1.4) : r.range(0.6, 1.1),
      artistShare: 0.5,
    );
    a.devotion = newcomer
        ? r.range(0.05, 0.2)
        : (isA ? r.range(0.15, 0.6) : r.range(0.05, 0.35));
    a.nextEraWeek =
        w.week + (newcomer ? r.nextInt(30) : r.nextInt(isA ? 150 : 90));
    w.addArtist(a);
    return a;
  }

  /// A real artist for a new rival (docs K66): at world creation, one active
  /// by now (the biggest ones fill the top tier); later, one who broke
  /// through this year or just before, biggest first. Never a name already
  /// in the world. Null when none is left: the rival gets a made-up name.
  static RealArtist? _pickReal(World w, int id,
      {required bool isA, required bool newcomer, required HomeCountry home}) {
    final year = GameTime.yearOf(w.week);
    final used = {
      for (final a in w.artists) a.name.toLowerCase(),
      for (final c in w.collaborators) c.name.toLowerCase(),
    };
    final pool = [
      for (final ra in realArtists)
        if (!used.contains(ra.name.toLowerCase()) &&
            ra.debut <= year &&
            (!newcomer || ra.debut >= year - 2) &&
            ra.home == home &&
            (!isA || ra.star >= 2))
          ra,
    ];
    if (pool.isEmpty) return null;
    // The top tier and newcomers take the biggest names first.
    final top =
        isA || newcomer ? pool.fold(0, (m, ra) => math.max(m, ra.star)) : 0;
    final group = [
      for (final ra in pool)
        if (ra.star >= top) ra
    ];
    final r = RandomStream.keyed(w.seed, 4, id, RngPurpose.names);
    return group[r.nextInt(group.length)];
  }

  /// A made-up name no artist or collaborator in the world has yet (tries
  /// a few draws).
  static String _freeName(World w, String Function() draw) {
    final used = {
      for (final a in w.artists) a.name.toLowerCase(),
      for (final c in w.collaborators) c.name.toLowerCase(),
    };
    var name = draw();
    for (var i = 0; i < 20 && used.contains(name.toLowerCase()); i++) {
      name = draw();
    }
    return name;
  }

  /// AI home countries: half American, a third European, the rest elsewhere.
  static HomeCountry _homeCountry(RandomStream r) {
    final x = r.nextDouble();
    if (x < 0.50) return HomeCountry.us;
    if (x < 0.55) return HomeCountry.canada;
    if (x < 0.67) return HomeCountry.uk;
    if (x < 0.85) return HomeCountry.europe;
    return HomeCountry.other;
  }

  /// Picks an AI artist's genre from [genreAiWeights] with one uniform draw.
  static int _weightedGenre(double u) {
    final total = genreAiWeights.fold(0.0, (a, x) => a + x);
    var x = u * total;
    for (var i = 0; i < genreAiWeights.length; i++) {
      x -= genreAiWeights[i];
      if (x < 0) return i;
    }
    return genreAiWeights.length - 1;
  }

  static void _addCollaborators(World w) {
    for (var i = 0; i < 80; i++) {
      final r = RandomStream.keyed(w.seed, 0, 100000 + i, RngPurpose.worldGen);
      final n = RandomStream.keyed(w.seed, 0, 100000 + i, RngPurpose.names);
      final skill = 20 + 78 * math.pow(r.nextDouble(), 0.9).toDouble();
      w.collaborators.add(Collaborator(
        id: i,
        // Unique across artists and collaborators (C6).
        name: _freeName(w, () => Names.person(n)),
        role:
            i.isEven ? CollaboratorRole.producer : CollaboratorRole.songwriter,
        skill: skill,
        genre: _weightedGenre(r.nextDouble()),
        feeCents: (20000 * math.pow(skill / 20, 2.6)).round(),
        minFame: math.max(0, (skill - 45) / 60),
      ));
    }
  }

  /// Adds the player's artist at the current week.
  static Artist addPlayer(
    World w, {
    required String name,
    required int genre,
    StartTier tier = StartTier.unknown,
    StartMoney money = StartMoney.basic,
    CareerPath path = CareerPath.independent,
    HomeCountry home = HomeCountry.us,
    ArtistKind kind = ArtistKind.solo,
    List<String> members = const [],
    Skills? skills,
  }) {
    if (kind.isGroup
        ? members.length < ArtistKind.minMembers ||
            members.length > ArtistKind.maxMembers
        : members.isNotEmpty) {
      throw ArgumentError.value(members.length, 'members',
          kind.isGroup ? 'a group needs 2–7 members' : 'solo has no members');
    }
    final (fame, fans, casual) = switch (tier) {
      StartTier.unknown => (0.0, 2e3, 2e4),
      StartTier.localBuzz => (0.05, 2e4, 2e5),
      StartTier.risingStar => (0.30, 4e5, 4e6),
      // (0.80, 3e6, 2.4e7) until docs K127: the top of the industry from
      // day one, with nothing left to win.
      StartTier.superstar => (0.75, 2e6, 1.6e7),
    };
    var cash = switch (money) {
      StartMoney.basic => 500000,
      StartMoney.comfortable => 5000000,
      StartMoney.millionaire => 100000000,
    };
    final isLabel = path == CareerPath.smallLabel;
    if (isLabel) cash += Label.small.advanceCents;
    // A rival with the player's own name (a real artist) takes another one.
    for (final other in w.artists) {
      if (other.name.toLowerCase() == name.trim().toLowerCase()) {
        final n = RandomStream.keyed(w.seed, 5, other.id, RngPurpose.names);
        other.name = _freeName(
            w, () => other.kind.isGroup ? Names.group(n) : Names.solo(n));
        w.dirtyArtists.add(other.id);
      }
    }
    final a = Artist(
      id: w.artists.length,
      name: name,
      tier: ArtistTier.player,
      homeCountry: home,
      kind: kind,
      members: [...members],
      genre: genre,
      debutWeek: w.week,
      skills: skills ?? StartingStats.auto(premium: false, kind: kind),
      fame: fame,
      coreFans: fans * w.config.globalAudienceScale,
      casual: casual * w.config.globalAudienceScale,
      labelReach: isLabel ? Label.small.reach : Label.independent.reach,
      artistShare:
          isLabel ? Label.small.artistShare : Label.independent.artistShare,
      moneyCents: cash,
    );
    if (isLabel) {
      a.label = Label.small;
      a.contractAlbumsLeft = Label.small.contractAlbums;
      a.contractAlbums = Label.small.contractAlbums;
      a.contractAdvanceCents = Label.small.advanceCents;
      a.unrecoupedCents = Label.small.advanceCents;
    }
    a.devotion = switch (tier) {
      StartTier.unknown => 0.1,
      StartTier.localBuzz => 0.15,
      StartTier.risingStar => 0.3,
      StartTier.superstar => 0.5,
    };
    w.addArtist(a);
    w.playerArtistId = a.id;
    return a;
  }
}
