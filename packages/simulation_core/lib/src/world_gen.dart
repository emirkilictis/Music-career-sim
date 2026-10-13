import 'dart:math' as math;

import 'config/difficulty.dart';
import 'config/regions.dart';
import 'config/sim_config.dart';
import 'model.dart';
import 'names.dart';
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
  }) {
    final cfg = config ?? SimConfig();
    final w = World(
      config: cfg,
      seed: seed,
      week: GameTime.firstWeekOf(cfg.worldStartYear(startYear)),
      difficulty: difficulty,
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
    double skill(double lo, double hi) => r.range(lo, hi);
    final skills = Skills(
      songwriting: isA ? skill(60, 92) : skill(35, 78),
      vocals: isA ? skill(60, 95) : skill(35, 80),
      production: isA ? skill(40, 85) : skill(25, 70),
      performance: isA ? skill(55, 95) : skill(30, 80),
      charisma: isA ? skill(55, 95) : skill(25, 80),
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
    final kind = kindRoll < 0.12
        ? ArtistKind.band
        : (kindRoll < 0.20 ? ArtistKind.vocalGroup : ArtistKind.solo);
    final m = RandomStream.keyed(w.seed, 3, id, RngPurpose.names);
    final memberCount = switch (kind) {
      ArtistKind.solo => 0,
      ArtistKind.band => 3 + m.nextInt(3),
      ArtistKind.vocalGroup => 4 + m.nextInt(4),
    };
    final a = Artist(
      id: id,
      name: kind.isGroup ? Names.group(n) : Names.solo(n),
      kind: kind,
      members: [for (var i = 0; i < memberCount; i++) Names.person(m)],
      tier: tier,
      homeCountry:
          _homeCountry(RandomStream.keyed(w.seed, 1, id, RngPurpose.worldGen)),
      genre: _weightedGenre(r.nextDouble()),
      debutWeek:
          newcomer ? w.week : w.week - r.nextInt(GameTime.weeksPerYear * 12),
      skills: skills,
      fame: fame,
      coreFans: coreFans * scale,
      casual: casual * scale,
      labelReach: isA ? r.range(1.1, 1.4) : r.range(0.6, 1.1),
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
        name: Names.person(n),
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
      StartTier.superstar => (0.80, 3e6, 2.4e7),
    };
    var cash = switch (money) {
      StartMoney.basic => 500000,
      StartMoney.comfortable => 5000000,
      StartMoney.millionaire => 100000000,
    };
    final isLabel = path == CareerPath.smallLabel;
    if (isLabel) cash += Label.small.advanceCents;
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
    }
    a.devotion = switch (tier) {
      StartTier.unknown => 0.1,
      StartTier.localBuzz => 0.15,
      StartTier.risingStar => 0.3,
      StartTier.superstar => 0.6,
    };
    w.addArtist(a);
    w.playerArtistId = a.id;
    return a;
  }
}
