import 'rng.dart';

/// Deterministic fictional names for artists, songs, albums and collaborators.
abstract final class Names {
  static const _first = [
    'Nova',
    'Jaden',
    'Lyra',
    'Marcus',
    'Selene',
    'Theo',
    'Kira',
    'Dante',
    'Aria',
    'Rowan',
    'Mila',
    'Zane',
    'Iris',
    'Caleb',
    'Luna',
    'Felix',
    'Skye',
    'Andre',
    'Maya',
    'Elio',
    'Talia',
    'Remy',
    'Juno',
    'Silas',
    'Vera',
    'Quinn',
    'Nico',
    'Sasha',
    'Leon',
    'Ivy',
    'Omar',
    'Zara',
  ];
  static const _last = [
    'Vale',
    'Monroe',
    'Hayes',
    'Rivers',
    'Cross',
    'Sterling',
    'Lane',
    'Rowe',
    'Blake',
    'Knight',
    'Wilde',
    'Frost',
    'Reyes',
    'Carter',
    'Stone',
    'Ellis',
    'Marlowe',
    'Hart',
    'Quinn',
    'Vance',
    'Sloane',
    'Ward',
    'Moss',
  ];
  static const _bandA = [
    'Neon',
    'Velvet',
    'Silver',
    'Midnight',
    'Paper',
    'Golden',
    'Static',
    'Electric',
    'Hollow',
    'Crystal',
    'Wild',
    'Lunar',
    'Glass',
    'Satin',
  ];
  static const _bandB = [
    'Tigers',
    'Hearts',
    'Coast',
    'Parade',
    'Season',
    'Echoes',
    'Machines',
    'Saints',
    'Rebels',
    'Signals',
    'Avenue',
    'Riot',
    'Bloom',
    'Theory',
  ];
  static const _mononym = [
    'Kaia',
    'Zeno',
    'Solenne',
    'Rio',
    'Onyx',
    'Maven',
    'Lux',
    'Ezra',
    'Vesper',
    'Kai',
    'Nyx',
    'Sol',
    'Rumi',
    'Cyra',
    'Aster',
    'Jett',
  ];
  static const _w1 = [
    'Midnight',
    'Golden',
    'Broken',
    'Electric',
    'Silent',
    'Neon',
    'Velvet',
    'Wild',
    'Paper',
    'Burning',
    'Endless',
    'Summer',
    'Crystal',
    'Dangerous',
    'Sweet',
    'Cold',
    'Lonely',
    'Shining',
    'Secret',
    'Perfect',
    'Fading',
  ];
  static const _w2 = [
    'Mirrors',
    'Hearts',
    'Lights',
    'Dreams',
    'Love',
    'City',
    'Nights',
    'Fire',
    'Rain',
    'Eyes',
    'Gravity',
    'Paradise',
    'Waves',
    'Roses',
    'Thunder',
    'Diamonds',
    'Shadows',
    'Highway',
    'Satellite',
    'Kiss',
    'Sky',
  ];
  static const _short = [
    'Mirrors',
    'Gravity',
    'Halo',
    'Runaway',
    'Wildfire',
    'Overdrive',
    'Paradise',
    'Heartbeat',
    'Fever',
    'Gold',
    'Echo',
    'Starlight',
    'Venom',
    'Ritual',
    'Cherry',
    'Mercury',
    'Atlas',
    'Lullaby',
    'Riot',
    'Bloom',
  ];

  static String artist(RandomStream r) {
    final roll = r.nextDouble();
    if (roll < 0.55) return '${r.pick(_first)} ${r.pick(_last)}';
    if (roll < 0.80) return r.pick(_mononym);
    return 'The ${r.pick(_bandA)} ${r.pick(_bandB)}';
  }

  static String person(RandomStream r) => '${r.pick(_first)} ${r.pick(_last)}';

  static String song(RandomStream r) {
    final roll = r.nextDouble();
    if (roll < 0.45) return r.pick(_short);
    if (roll < 0.85) return '${r.pick(_w1)} ${r.pick(_w2)}';
    return '${r.pick(_w2)} (${r.pick(_w1)} ${r.pick(_w2)})';
  }

  static String album(RandomStream r) {
    final roll = r.nextDouble();
    if (roll < 0.5) return r.pick(_short);
    return '${r.pick(_w1)} ${r.pick(_w2)}';
  }
}
