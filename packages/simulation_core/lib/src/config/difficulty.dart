/// Difficulty levels (docs/game-design.md §2.4). The calibrated, real-world
/// balance is [normal] ("Realistic"); the other levels only scale the
/// player's own numbers, never the AI or the market.
enum Difficulty {
  /// Easier than reality: the player's releases travel further.
  easy(exposure: 1.3, fanConversion: 1.3, qualityBonus: 3),

  /// "Realistic": the calibrated balance, all factors neutral.
  normal(exposure: 1.0, fanConversion: 1.0, qualityBonus: 0),

  /// Harder than reality.
  hard(exposure: 0.8, fanConversion: 0.8, qualityBonus: -3);

  const Difficulty({
    required this.exposure,
    required this.fanConversion,
    required this.qualityBonus,
  });

  /// Multiplier on how many new listeners the player's songs reach.
  final double exposure;

  /// Multiplier on how many listeners become the player's fans.
  final double fanConversion;

  /// Added to the raw quality of the player's songs.
  final double qualityBonus;
}
