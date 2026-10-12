import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/game.dart' hide Actions;
import 'package:music_career_sim/core/commands.dart';

import 'support.dart';

/// Renders the main screens at iPhone size into build/screenshots/.
/// Run with: SCREENSHOTS=1 flutter test test/screenshots_test.dart
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

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('screenshots', skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);

    // A Premium vocal group with a single and an album out.
    final c = app.controller;
    final port = ReceivePort();
    await c.exec(Cmd.start(
        CareerSetup(
          name: 'Velvet Avenue',
          genre: 0,
          kind: ArtistKind.vocalGroup,
          members: const ['Mira', 'Jae', 'Sol', 'Noa', 'Rin'],
          startYear: 2022,
          tier: StartTier.risingStar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 2024,
        ),
        port.sendPort));
    port.close();
    final songs = <int>[];
    while (songs.length < 13) {
      final (p, _, _) = await c.run(Cmd.snapshot());
      if (p.songsLeftThisWeek == 0 || p.creativeEnergy < 30) {
        await c.run(Cmd.nextWeek());
        continue;
      }
      songs.add((await c.run(Cmd.writeSong(
              budget: BudgetTier.high, genres: const [0, 18])))
          .id);
    }
    await c.run(Cmd.releaseSingle(songs.first, Campaign.intensive));
    for (var i = 0; i < 4; i++) {
      await c.run(Cmd.nextWeek());
    }
    await c.run(Cmd.releaseAlbum(
        title: 'Neon Bloom',
        songIds: songs.sublist(0, 12),
        type: AlbumType.album,
        variantWeeks: const [0, 0, 1, 2],
        campaign: Campaign.global));
    await c.run(Cmd.nextWeek());
    await c.exec(Cmd.closeCareer());

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await shot(tester, '01_careers');

    await tester.tap(find.byIcon(Icons.add));
    await shot(tester, '02_new_career');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Velvet Avenue'));
    await tester.pumpAndSettle();
    if (find.text('OK').evaluate().isNotEmpty) {
      await tester.tap(find.text('OK'));
    }
    await tester.tap(find.text('Next week'));
    await tester.pumpAndSettle();
    await shot(tester, '03_week_news');
    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle();
    await shot(tester, '04_home');

    await tab(tester, 'Studio');
    await shot(tester, '05_studio');
    await tab(tester, 'Releases');
    await shot(tester, '06_releases');
    await tab(tester, 'Charts');
    await shot(tester, '07_charts');
    await tester.ensureVisible(find.text('US Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('US Albums'));
    await tester.pumpAndSettle();
    await shot(tester, '08_album_chart');
    await tab(tester, 'Career');
    await shot(tester, '09_career');

    await tab(tester, 'Releases');
    await tester.tap(find.text('Neon Bloom'));
    await shot(tester, '10_album_detail');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    final single = find.byType(ListTile).last;
    await tester.tap(single);
    await shot(tester, '11_song_detail');
    await tester.pageBack();
    await tester.pumpAndSettle();

    app.settings.setLanguage('tr');
    await tester.pumpAndSettle();
    await tab(tester, 'Ana sayfa');
    await shot(tester, '12_home_tr');
  });
}
