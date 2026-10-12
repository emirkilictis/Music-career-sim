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

/// Builds a new world: AI artists, collaborators, and (optionally) a player.
abstract final class WorldGen {
  /// Creates a world whose clock starts [SimConfig.burnInYears] before
  /// [startYear]; run it up to [startYear] before handing it to the player.
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
      week: GameTime.firstWeekOf(startYear - cfg.burnInYears),
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
    final a = Artist(
      id: id,
      name: Names.artist(n),
      tier: tier,
      homeCountry:
          _homeCountry(RandomStream.keyed(w.seed, 1, id, RngPurpose.worldGen)),
      genre: r.nextInt(genreNames.length),
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
        genre: r.nextInt(genreNames.length),
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
    Skills? skills,
  }) {
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
    if (isLabel) cash += 2500000; // advance
    final a = Artist(
      id: w.artists.length,
      name: name,
      tier: ArtistTier.player,
      homeCountry: home,
      genre: genre,
      debutWeek: w.week,
      skills: skills ??
          Skills(
              songwriting: 37,
              vocals: 35,
              production: 29,
              performance: 27,
              charisma: 27),
      fame: fame,
      coreFans: fans * w.config.globalAudienceScale,
      casual: casual * w.config.globalAudienceScale,
      labelReach: isLabel ? 1.15 : 0.7,
      artistShare: isLabel ? 0.5 : 1.0,
      moneyCents: cash,
    );
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
