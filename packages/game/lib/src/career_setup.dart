import 'package:simulation_core/simulation_core.dart';

/// A player action or setup choice that the rules do not allow. [message] is
/// for logs; the UI shows its own text for [code].
class GameException implements Exception {
  GameException(this.code, this.message);

  /// Stable identifier the UI can translate, e.g. `notEnoughMoney`.
  final String code;
  final String message;

  @override
  String toString() => 'GameException($code): $message';
}

/// Everything chosen on the "new career" screen (docs/game-design.md §2).
class CareerSetup {
  CareerSetup({
    required this.name,
    required this.genre,
    this.kind = ArtistKind.solo,
    this.members = const [],
    this.home = HomeCountry.us,
    this.startYear = 2010,
    this.difficulty = Difficulty.normal,
    this.tier = StartTier.unknown,
    this.money = StartMoney.basic,
    this.path = CareerPath.independent,
    this.skills,
    this.premium = false,
    this.realNames = true,
    this.seed,
  });

  final String name;
  final int genre;
  final ArtistKind kind;
  final List<String> members;
  final HomeCountry home;
  final int startYear;
  final Difficulty difficulty;
  final StartTier tier;
  final StartMoney money;
  final CareerPath path;

  /// Allocated stats; null = "auto distribute" for the kind.
  final Skills? skills;

  /// Whether the player has Premium right now (checked by the app's store).
  final bool premium;

  /// Rivals use real artists' names where one fits (docs K66).
  final bool realNames;

  /// World seed; null picks one from the clock.
  final int? seed;

  /// Content is calibrated from 2000 to today (docs/README.md, Faz 1).
  static const minStartYear = 2000;
  static const maxStartYear = 2026;
  static const maxNameLength = 40;

  static bool isPremiumTier(StartTier t) =>
      t == StartTier.risingStar || t == StartTier.superstar;
  static bool isPremiumMoney(StartMoney m) => m != StartMoney.basic;

  Skills get resolvedSkills =>
      skills ?? StartingStats.auto(premium: premium, kind: kind);

  /// Throws [GameException] when a choice is not allowed.
  void validate() {
    final n = name.trim();
    if (n.isEmpty || n.length > maxNameLength) {
      throw GameException('invalidName', 'Name must be 1–$maxNameLength chars');
    }
    if (genre < 0 || genre >= genreNames.length) {
      throw GameException('invalidGenre', 'Unknown genre $genre');
    }
    if (kind.isGroup) {
      if (members.length < ArtistKind.minMembers ||
          members.length > ArtistKind.maxMembers) {
        throw GameException('invalidMembers', 'A group needs 2–13 members');
      }
      if (members.any((m) => m.trim().isEmpty)) {
        throw GameException('invalidMembers', 'Member names cannot be empty');
      }
    } else if (members.isNotEmpty) {
      throw GameException('invalidMembers', 'A solo artist has no members');
    }
    if (startYear < minStartYear || startYear > maxStartYear) {
      throw GameException(
          'invalidStartYear', 'Start year must be $minStartYear–$maxStartYear');
    }
    if (!premium && (isPremiumTier(tier) || isPremiumMoney(money))) {
      throw GameException('premiumRequired', 'This start needs Premium');
    }
    if (!StartingStats.isValid(resolvedSkills, premium: premium)) {
      throw GameException('invalidSkills', 'Stat allocation breaks the rules');
    }
  }
}
