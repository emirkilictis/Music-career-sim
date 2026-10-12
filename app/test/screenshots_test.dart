import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/game.dart' hide Actions;
import 'package:music_career_sim/core/career_state.dart';
import 'package:music_career_sim/core/commands.dart';
import 'package:music_career_sim/core/event_lines.dart';
import 'package:music_career_sim/core/scope.dart';
import 'package:music_career_sim/screens/charts_tab.dart';
import 'package:music_career_sim/widgets/celebration.dart';
import 'package:music_career_sim/widgets/media_tile.dart';

import 'support.dart';

/// Renders the main screens at iPhone size into build/screenshots/.
/// Run with: SCREENSHOTS=1 flutter test test/screenshots_test.dart
void main() {
  final enabled = Platform.environment['SCREENSHOTS'] == '1';
  final out = Directory('build/screenshots');
  final key = GlobalKey();

  Future<void> shot(WidgetTester tester, String name,
      {bool settle = true}) async {
    if (settle) await tester.pumpAndSettle();
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
      songs.add((await c.run(
              Cmd.writeSong(budget: BudgetTier.high, genres: const [0, 18])))
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
    // The next single is set for later and announced in advance (K45).
    final (_, now, _) = await c.run(Cmd.snapshot());
    await c.run(
        Cmd.scheduleSingle(songs[12], Campaign.standard, now + 8, now + 4));
    await c.exec(Cmd.closeCareer());

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await shot(tester, '01_careers');

    await tester.tap(find.byIcon(Icons.add));
    await shot(tester, '02_new_career');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Velvet Avenue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next week'));
    // Mid-way through the week transition card.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future.delayed(Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot(tester, '03a_week_transition', settle: false);
    await tester.pumpAndSettle();
    await shot(tester, '03_week_news');
    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .removeCurrentSnackBar();
    await shot(tester, '04_home');

    await tab(tester, 'Studio');
    await shot(tester, '05_studio');
    await tester.tap(find.text('Producer'));
    await shot(tester, '05b_producer_picker');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tab(tester, 'Releases');
    await shot(tester, '06_releases');
    await tester.tap(find.textContaining('Announcement: '));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change date'));
    await shot(tester, '06b_release_timing');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tab(tester, 'Charts');
    await shot(tester, '07_charts_songs');
    await tester.tap(find.text('US ALBUMS'));
    await shot(tester, '08_charts_albums');

    await tab(tester, 'Career');
    await shot(tester, '15_career');
    await tester.tap(find.text('Skip'));
    await shot(tester, '15b_skip_menu');
    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle();
    await tab(tester, 'Home');
    await tester.scrollUntilVisible(find.text('Streamify'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await shot(tester, '04b_home_platforms');
    await tester.tap(find.text('Streamify'));
    await shot(tester, '09_streamify');
    await tester.tap(find.text('Velvet Avenue').last);
    await shot(tester, '10_artist_page');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await shot(tester, '11_artist_page_more');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top 50 – Global'));
    await shot(tester, '12_top50');
    await tester.tap(find.byType(InkWell).at(2));
    await shot(tester, '13_rival_page');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tab(tester, 'Releases');
    await tester.tap(find.text('Neon Bloom'));
    await shot(tester, '14_album_detail');
    await tester.pageBack();
    await tester.pumpAndSettle();

    app.settings.setLanguage('tr');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await shot(tester, '16_home_tr');
    await tab(tester, 'Listeler');
    await shot(tester, '17_charts_tr');
    app.settings.setLanguage('en');
    await tester.pumpAndSettle();

    // Celebration screens (shown after a week with a first #1 or the
    // career's first chart entry).
    final ctx = tester.element(find.byType(ChartsTab));
    final state = Scope.read<CareerState>(ctx);
    final hit = songs.first;
    unawaited(showCelebration(
        ctx,
        EventLine(const NumberOne(Charts.usSongs, EntityKind.song, 0, 1),
            title: 'Kiss (Silent Hours)', songId: hit),
        state));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot(tester, '24_celebration_no1', settle: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    unawaited(showCelebration(
        ctx,
        EventLine(const ChartDebut(Charts.globalSongs, EntityKind.song, 0, 64),
            title: 'Kiss (Silent Hours)', songId: hit),
        state));
    await shot(tester, '25_celebration_first_chart');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  });

  testWidgets('screenshots: early 2000s career', skip: !enabled,
      (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);

    // 2002: CD singles and radio, no streaming yet.
    final c = app.controller;
    final port = ReceivePort();
    await c.exec(Cmd.start(
        CareerSetup(
          name: 'June Harper',
          genre: 0,
          startYear: 2002,
          tier: StartTier.risingStar,
          money: StartMoney.comfortable,
          premium: true,
          seed: 2002,
        ),
        port.sendPort));
    port.close();
    final song =
        (await c.run(Cmd.writeSong(budget: BudgetTier.high, genres: const [0])))
            .id;
    await c.run(Cmd.releaseSingle(song, Campaign.standard));
    for (var i = 0; i < 8; i++) {
      await c.run(Cmd.nextWeek());
    }
    await c.exec(Cmd.closeCareer());

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(find.text('June Harper'));
    await tester.pumpAndSettle();
    await tab(tester, 'Career');
    await shot(tester, '18_career_2002');
    await tab(tester, 'Releases');
    await tester.tap(find.byType(MediaTile).first);
    await shot(tester, '19_song_2002');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Energy, rest and day jobs on Home.
    await tab(tester, 'Home');
    await tester.tap(find.text('Energy'));
    await shot(tester, '20_energy_sheet');
    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Day job'));
    await shot(tester, '21_job_picker');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();

    // Light theme from Settings: the open screen repaints in place.
    app.settings.setLightTheme(true);
    await tester.pumpAndSettle();
    await shot(tester, '22_home_light');
    await tab(tester, 'Studio');
    await shot(tester, '23_studio_light');
    app.settings.setLightTheme(false);
    await tester.pumpAndSettle();
  });
}
