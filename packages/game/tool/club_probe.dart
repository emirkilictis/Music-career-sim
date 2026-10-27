// How many songs are in the Billions Club when a career starts (docs
// K222)? Prints the club and the biggest lifetime streams.
//
//   dart run tool/club_probe.dart [startYear]
import 'dart:io';

import 'package:game/game.dart';

void main(List<String> args) {
  final year = args.isNotEmpty ? int.parse(args[0]) : 2018;
  final dir = Directory.systemTemp.createTempSync('club');
  final g = GameSession.start(
      SaveSlots(dir),
      CareerSetup(
          name: 'Probe', genre: 0, startYear: year, tier: StartTier.unknown, seed: 4242),
      slotId: 'p');
  final club = g.billionsClub;
  print('$year club ${club.length}: ${club.take(5).map((c) => '${(c.plays / 1e9).toStringAsFixed(2)}B').join(' ')}');
  g.close();
  dir.deleteSync(recursive: true);
}
