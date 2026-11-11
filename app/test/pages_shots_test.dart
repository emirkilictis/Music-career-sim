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

/// The song and album pages in tabs, the guide and the week list (docs
/// K296–K298) at iPhone size, into build/screenshots/. Run with:
/// SCREENSHOTS=1 flutter test test/pages_shots_test.dart
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

  testWidgets('page screenshots', skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Ivy Lane',
          genre: 0,
          startYear: 2016,
          tier: StartTier.risingStar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 31,
        ),
        PortSink(port.sendPort))));
    port.close();
    var single = '', album = 'Paper Moons';
    await tester.runAsync(() async {
      final songs = <SongView>[];
      while (songs.length < 9) {
        final (p, _, _) = await c.run(Cmd.snapshot());
        if (!p.canWrite || p.creativeEnergy < 30) {
          await c.run(Cmd.nextWeek());
          continue;
        }
        songs.add(await c.run(
            Cmd.writeSong(budget: BudgetTier.high, genres: const [0])));
      }
      single = songs.first.title;
      await c.run(Cmd.releaseSingle(songs.first.id, Campaign.standard));
      for (var i = 0; i < 3; i++) {
        await c.run(Cmd.nextWeek());
      }
      await c.run(Cmd.releaseAlbum(
          title: album,
          songIds: [for (final s in songs) s.id],
          type: AlbumType.album,
          variantWeeks: const [0],
          campaign: Campaign.standard));
      for (var i = 0; i < 3; i++) {
        await c.run(Cmd.nextWeek());
      }
      await c.exec(Cmd.closeCareer());
    });

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(ci('Ivy Lane'));
    await tester.pumpAndSettle();
    await shot(tester, 'k298_home');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await shot(tester, 'k298_home_todo');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Releases').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(single).first);
    await shot(tester, 'k296_song_overview');
    await tester.tap(find.text('Promote'));
    await shot(tester, 'k296_song_promote');
    await tester.tap(find.text('Radio').last);
    await shot(tester, 'k296_song_radio');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(album).first);
    await shot(tester, 'k296_album_overview');
    await tester.tap(find.text('What to do'));
    await shot(tester, 'k296_album_tools');
  });
}
