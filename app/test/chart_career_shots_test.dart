import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/game.dart' hide Actions;
import 'package:music_career_sim/core/commands.dart';
import 'package:music_career_sim/core/game_controller.dart';
import 'package:music_career_sim/core/scope.dart';
import 'package:music_career_sim/screens/chart_history_screen.dart';

import 'support.dart';

/// The chart career page (docs K299) at iPhone size, into
/// build/screenshots/. Run with:
/// SCREENSHOTS=1 flutter test test/chart_career_shots_test.dart
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

  testWidgets('chart career screenshots', skip: !enabled, (tester) async {
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
          seed: 5,
        ),
        PortSink(port.sendPort))));
    port.close();
    await tester.runAsync(() async {
      for (var era = 0; era < 3; era++) {
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
        for (final id in songs.take(3)) {
          await c.run(Cmd.releaseSingle(id, Campaign.standard));
          for (var i = 0; i < 5; i++) {
            await c.run(Cmd.nextWeek());
          }
        }
        await c.run(Cmd.releaseAlbum(
            title: era == 0 ? 'Afterglow' : 'Second Sun',
            songIds: songs,
            type: AlbumType.album,
            variantWeeks: const [0],
            campaign: Campaign.standard));
        for (var i = 0; i < 12; i++) {
          await c.run(Cmd.nextWeek());
        }
      }
      await c.exec(Cmd.closeCareer());
    });

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova Lane'));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.text('Next week').first);
    Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => ChartHistoryScreen(state: ctx.careerRead)));
    await shot(tester, 'k299_chart_career');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(tester, 'k299_chart_career_more');
  });
}
