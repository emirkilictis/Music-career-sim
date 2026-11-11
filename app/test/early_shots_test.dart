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

/// A career that starts in 1955 (docs K289) at iPhone size, into
/// build/screenshots/. Run with:
/// SCREENSHOTS=1 flutter test test/early_shots_test.dart
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

  testWidgets('1955 screenshots', skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Rosie Vale',
          genre: 0,
          startYear: 1955,
          tier: StartTier.risingStar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 55,
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
        songs.add((await c.run(
                Cmd.writeSong(budget: BudgetTier.high, genres: const [0])))
            .id);
      }
      await c.run(Cmd.releaseSingle(songs.first, Campaign.standard));
      for (var i = 0; i < 6; i++) {
        await c.run(Cmd.nextWeek());
      }
      await c.exec(Cmd.closeCareer());
    });

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await shot(tester, 'k289_new_career');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(ci('Rosie Vale'));
    await tester.pumpAndSettle();
    await shot(tester, 'k289_home');
    await tester.tap(find.text('Studio').last);
    await shot(tester, 'k289_studio');
    await tester.tap(find.text('Releases').last);
    await shot(tester, 'k289_releases');
    await tester.tap(find.text('Charts').last);
    await shot(tester, 'k289_charts');
    await tester.tap(ci('US ALBUMS'));
    await shot(tester, 'k289_charts_albums');
    await tester.tap(find.text('Career').last);
    await shot(tester, 'k289_career');
  });
}
