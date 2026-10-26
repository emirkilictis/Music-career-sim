import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/game.dart';
import 'package:music_career_sim/core/commands.dart';
import 'package:music_career_sim/core/game_controller.dart';

/// The real controller sends closures to another isolate. This checks every
/// kind of command the UI uses really crosses the isolate boundary.
void main() {
  test('commands run in the game isolate', () async {
    final dir = Directory.systemTemp.createTempSync('mcs_iso_');
    final c = await IsolateGameController.spawn('${dir.path}/careers');
    final progress = <double>[];
    final port = ReceivePort()..listen((p) => progress.add(p as double));
    final slotId = await c.exec(Cmd.start(
        CareerSetup(name: 'Iso', genre: 1, startYear: 2015, seed: 5),
        PortSink(port.sendPort)));
    expect(slotId, startsWith('career_'));

    final (p, week, _) = await c.run(Cmd.snapshot());
    expect(p.name, 'Iso');
    expect(GameTime.yearOf(week), 2015);

    final song = await c.run(Cmd.writeSong(
        budget: BudgetTier.low, genres: const [1, 2], title: 'Over There'));
    expect(song.title, 'Over There');
    await c.run(Cmd.releaseSingle(song.id, Campaign.none));
    await c.run(Cmd.setJob(Job.cafe));
    await c.run(Cmd.rewardAd());

    final (w, _, delta, _) = await c.run(Cmd.nextWeek());
    expect(w, week);
    expect(delta, greaterThan(0));

    final weeks = <int>[];
    final yearPort = ReceivePort()..listen((n) => weeks.add(n as int));
    final (year, _) = await c.run(Cmd.skipWeeks(
        GameTime.weeksPerYear, SkipStop.major, PortSink(yearPort.sendPort)));
    expect(year.weeks, greaterThan(0));

    final chart = await c.run(Cmd.chart(Charts.usSongs));
    expect(chart.rows, isNotEmpty);
    expect(await c.run(Cmd.careerByYear()), isNotEmpty);

    // Rule errors arrive as GameException with their code.
    await expectLater(
        c.run(Cmd.writeSong(budget: BudgetTier.high, genres: const [])),
        throwsA(isA<GameException>()));

    await c.exec(Cmd.closeCareer());
    expect(await c.exec(Cmd.listSlots()), hasLength(1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(progress, isNotEmpty);
    expect(weeks, isNotEmpty);
    port.close();
    yearPort.close();
    await c.dispose();
    dir.deleteSync(recursive: true);
  });
}
