/// Difficulty levels (docs/game-design.md §19), chosen per career.
///
/// [normal] ("Realistic") is the calibrated, real-world balance: the player
/// and the AI play by the same rules. [legend] is the power fantasy (become
/// the biggest artist of all time; 5M+ weeks are reachable with the right
/// moves): the player gets stronger and the AI steps back a little. [hard]
/// only weakens the player.
enum Difficulty {
  legend(
    exposure: 1.4,
    fanConversion: 1.6,
    qualityBonus: 5,
    albumDemand: 1.4,
    devotionGain: 1.5,
    aiExposure: 0.85,
    aiAlbumDemand: 0.85,
  ),

  /// "Realistic": the calibrated balance, all factors neutral.
  normal(
    exposure: 1.0,
    fanConversion: 1.0,
    qualityBonus: 0,
    albumDemand: 1.0,
    devotionGain: 1.0,
    aiExposure: 1.0,
    aiAlbumDemand: 1.0,
  ),

  hard(
    exposure: 0.8,
    fanConversion: 0.8,
    qualityBonus: -3,
    albumDemand: 0.85,
    devotionGain: 0.8,
    aiExposure: 1.0,
    aiAlbumDemand: 1.0,
  );

  const Difficulty({
    required this.exposure,
    required this.fanConversion,
    required this.qualityBonus,
    required this.albumDemand,
    required this.devotionGain,
    required this.aiExposure,
    required this.aiAlbumDemand,
  });

  /// Multiplier on how many new listeners the player's songs reach.
  final double exposure;

  /// Multiplier on how many listeners become the player's fans.
  final double fanConversion;

  /// Added to the raw quality of the player's songs.
  final double qualityBonus;

  /// Multiplier on purchases of the player's albums (fans, collectors,
  /// event buyers).
  final double albumDemand;

  /// Multiplier on devotion the player's fanbase gains from good eras.
  final double devotionGain;

  /// Multipliers on every AI artist's reach and album purchases.
  final double aiExposure;
  final double aiAlbumDemand;
}
