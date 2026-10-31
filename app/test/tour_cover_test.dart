import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/game.dart' hide Actions;
import 'package:music_career_sim/core/career_state.dart';
import 'package:music_career_sim/core/game_controller.dart';
import 'package:music_career_sim/l10n/gen/app_localizations.dart';
import 'package:music_career_sim/screens/tour_screen.dart';
import 'package:music_career_sim/widgets/art.dart';
import 'support.dart';

void main() {
  testWidgets('cover directions render at thumbnail and album sizes',
      (tester) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const titles = [
      'AFTER HOURS',
      'Velvet Summer',
      'BLUE ROOM',
      'The Other Side',
      'Still / Moving',
      'SECOND NATURE',
      'Moonlight',
      'ECHOES',
      'Lost in Color',
      'GOLDEN'
    ];
    CoverArt.labels = {
      for (var i = 0; i < 10; i++) albumCoverSeed(i): (titles[i], 0)
    };
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
            key: key,
            child: Scaffold(
                backgroundColor: const Color(0xFF202024),
                body: Wrap(children: [
                  for (var i = 0; i < 10; i++)
                    Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(children: [
                          CoverArt(
                              seed: albumCoverSeed(i),
                              albumId: i,
                              size: 180,
                              radius: 2),
                          const SizedBox(height: 8),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            CoverArt(
                                seed: albumCoverSeed(i),
                                albumId: i,
                                songId: 100 + i,
                                size: 48),
                            const SizedBox(width: 8),
                            CoverArt(
                                seed: albumCoverSeed(i),
                                albumId: i,
                                imageKey: 'edition-$i',
                                size: 48)
                          ])
                        ])),
                ])))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/cover-preview.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
      img.dispose();
    });
    CoverArt.labels = {};
  });
  testWidgets('setlist searches and separates selected songs', (tester) async {
    phoneView(tester);
    final dir = Directory.systemTemp.createTempSync('tour_ui_');
    final controller = LocalGameController(dir.path);
    addTearDown(() async {
      await controller.dispose();
      dir.deleteSync(recursive: true);
    });
    await controller.exec((h) {
      h.session = GameSession.start(
          h.slots,
          CareerSetup(
              name: 'Nova',
              genre: 0,
              startYear: 2018,
              premium: true,
              tier: StartTier.superstar,
              money: StartMoney.millionaire,
              seed: 4242));
      final g = h.open;
      for (var album = 0; album < 4; album++) {
        final ids = <int>[];
        for (var i = 0; i < 10; i++) {
          g.world.player!
            ..creativeEnergy = 100
            ..burnoutUntilWeek = -1;
          ids.add(g.writeSong(budget: BudgetTier.medium).id);
        }
        g.releaseAlbum('Chapter $album', ids, campaign: Campaign.none);
      }
    });
    final state = CareerState(controller);
    await state.refresh();
    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TourScreen(state: state)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Edit the set'), 300);
    await tester.tap(find.text('Edit the set'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/40'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Chapter 3');
    await tester.pumpAndSettle();
    expect(find.text('Chapter 3'), findsWidgets);
    await tester.tap(find.text('Hide selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
