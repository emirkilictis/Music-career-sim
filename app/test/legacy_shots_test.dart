import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/game.dart' hide Actions;
import 'package:music_career_sim/core/commands.dart';
import 'package:music_career_sim/core/game_controller.dart';

import 'support.dart';

/// The legacy page and the legends board (docs K288) at iPhone size, into
/// build/screenshots/. Run with:
/// SCREENSHOTS=1 flutter test test/legacy_shots_test.dart
void main() {
  final enabled = Platform.environment['SCREENSHOTS'] == '1';
  final out = Directory('build/screenshots');
  final key = GlobalKey();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Finder ci(String text) => find.byWidgetPredicate((w) =>
      w is Text && w.data != null && w.data!.toLowerCase() == text.toLowerCase());

  testWidgets('legacy screenshots', skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Lane',
          genre: 0,
          startYear: 2016,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 88,
        ),
        PortSink(port.sendPort))));
    port.close();
    await tester.runAsync(() async {
      final songs = <int>[];
      while (songs.length < 10) {
        final (p, _, _) = await c.run(Cmd.snapshot());
        if (!p.canWrite || p.creativeEnergy < 30) {
          await c.run(Cmd.nextWeek());
          continue;
        }
        songs.add((await c.run(Cmd.writeSong(budget: BudgetTier.high, genres: const [0]))).id);
      }
      await c.run(Cmd.releaseSingle(songs.first, Campaign.standard));
      for (var i = 0; i < 4; i++) {
        await c.run(Cmd.nextWeek());
      }
      await c.run(Cmd.releaseAlbum(
          title: 'Afterglow',
          songIds: songs,
          type: AlbumType.album,
          variantWeeks: const [0],
          campaign: Campaign.standard));
      for (var i = 0; i < 70; i++) {
        await c.run(Cmd.nextWeek());
      }
      await c.run(Cmd.retire());
      await c.exec(Cmd.closeCareer());
    });

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(ci('Nova Lane'));
    await tester.pumpAndSettle();
    await shot(tester, 'k288_home_retired');
    await tester.tap(find.text('Charts').last);
    await tester.pumpAndSettle();
    final legends = ci('Legends');
    final tabs = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal);
    await tester.scrollUntilVisible(legends, 200,
        scrollable:
            find.descendant(of: tabs.first, matching: find.byType(Scrollable)));
    await tester.tap(legends);
    await shot(tester, 'k288_legends');
    await tester.tap(ci('Hall of Fame'));
    await shot(tester, 'k288_hall_of_fame');
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(ci('Career summary').first);
    await shot(tester, 'k288_legacy');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(tester, 'k288_legacy_more');
  });
}
