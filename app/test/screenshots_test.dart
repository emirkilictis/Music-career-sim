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
import 'package:music_career_sim/widgets/art.dart';
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
    while (songs.length < 16) {
      final (p, _, _) = await c.run(Cmd.snapshot());
      if (!p.canWrite || p.creativeEnergy < 30) {
        await c.run(Cmd.nextWeek());
        continue;
      }
      songs.add((await c.run(
              Cmd.writeSong(budget: BudgetTier.high, genres: const [0, 18])))
          .id);
    }
    // A rising star signs with a major label (K54).
    await c.run(Cmd.signLabel(Label.major));
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
    // An EP waits in the vault for its moment (F31).
    await c.run(Cmd.saveDraft(
        title: 'Midnight Tapes',
        songIds: songs.sublist(13),
        type: AlbumType.ep,
        variantWeeks: const [0]));
    await c.exec(Cmd.closeCareer());

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await shot(tester, '01_careers');

    await tester.tap(find.byIcon(Icons.add));
    await shot(tester, '02_new_career');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(_ci('Velvet Avenue'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Next week'));
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
    // What fame means and the numbers behind it (E7).
    await tester
        .tap(find.textContaining(RegExp('^fame\$', caseSensitive: false)));
    await shot(tester, '04c_fame_info');
    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle();

    await tab(tester, 'Studio');
    await shot(tester, '05_studio');
    await tester.tap(_ci('Producer'));
    await shot(tester, '05b_producer_picker');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tab(tester, 'Releases');
    await shot(tester, '06_releases');
    await tester.tap(find.textContaining('Announcement: '));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Change date'));
    await shot(tester, '06b_release_timing');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    // Album builder: extra editions with their own format (K46).
    await tester.tap(_ci('New album / EP'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_ci('Edition 2'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(_ci('Edition 2'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Edition 3'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_ci('Cassette').last);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Cassette').last);
    await tester.pumpAndSettle();
    expect(_ci('Cassette · \$20,000'), findsOneWidget);
    await tester.scrollUntilVisible(_ci('Release extras in later weeks'), 200,
        scrollable: find.byType(Scrollable).first);
    await shot(tester, '06c_album_editions');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tab(tester, 'Charts');
    await shot(tester, '07_charts_songs');
    // A row opens its week underneath (K89).
    await tester.tap(find.byType(CoverArt).at(1));
    await shot(tester, '07b_chart_row_open');
    await tester.tap(_ci('US ALBUMS'));
    await shot(tester, '08_charts_albums');
    await tester.tap(find.byType(CoverArt).first);
    await shot(tester, '08c_album_row_open');

    await tab(tester, 'Career');
    await shot(tester, '15_career');
    await tester.scrollUntilVisible(_ci('See labels'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('See labels'));
    await shot(tester, '15c_labels');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Discography and the sales chart of covers (K86).
    final disco = _ci('Discography & sales chart');
    await tester.scrollUntilVisible(disco, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(disco), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(disco);
    await shot(tester, '15i_discography');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await shot(tester, '15j_discography_list');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_ci('Plan a tour'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Plan a tour'));
    await shot(tester, '15d_tour');
    await tester.scrollUntilVisible(_ci('Expected'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await shot(tester, '15e_tour_estimate');
    await tester.scrollUntilVisible(_ci('Schedule'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await shot(tester, '15f_tour_schedule');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Festivals and the box office (K77).
    await tester.scrollUntilVisible(_ci('Festival season'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Festival season'));
    await shot(tester, '15g_festivals');
    await tester.tap(_ci('Lineup').first);
    await shot(tester, '15h_festival_lineup');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tab(tester, 'Charts');
    await tester.drag(_ci('US ALBUMS'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(_ci('TOURS'));
    await shot(tester, '08b_top_tours');
    await tab(tester, 'Career');
    await tester.scrollUntilVisible(_ci('Skills'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(_ci('Skip'));
    await shot(tester, '15b_skip_menu');
    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle();
    await tab(tester, 'Home');
    // Social media (docs K93): the card, then the feed after a post.
    final feed = _ci('Open the feed');
    await tester.scrollUntilVisible(feed, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(feed), alignment: 0.4);
    await tester.pumpAndSettle();
    await shot(tester, '04d_home_social');
    await tester.tap(feed);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Behind the scenes'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await shot(tester, '04e_social_feed');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await shot(tester, '04f_social_feed_more');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_ci('Streamify'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await shot(tester, '04b_home_platforms');
    await tester.tap(_ci('ViewTube'));
    await shot(tester, '09c_viewtube');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(_ci('Streamify'));
    await shot(tester, '09_streamify');
    await tester.tap(_ci('Velvet Avenue').last);
    await shot(tester, '10_artist_page');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await shot(tester, '11_artist_page_more');
    await tester.tap(_ci('Neon Bloom').last);
    await shot(tester, '11b_streamify_album');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(_ci('Top 50 – Global'));
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
    await tester.tap(_ci('Neon Bloom'));
    await shot(tester, '14_album_detail');
    await tester.scrollUntilVisible(_ci('Week by week on the charts'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await shot(tester, '14b_album_weekly');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // A single's numbers (F46): four figures, regions as one bar.
    final single = find.textContaining(RegExp(r'^[\d.,]+[KMB]? streams$'));
    await tester.scrollUntilVisible(single.first, 300,
        scrollable: find.byType(Scrollable).first);
    // Clear of the floating week bar at the bottom.
    await Scrollable.ensureVisible(tester.element(single.first),
        alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(single.first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_ci('More numbers'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(_ci('More numbers'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 330));
    await shot(tester, '14c_song_numbers');
    // A remix and a CD single from the song page (docs K92, F26).
    final newVersion = _ci('New version');
    await tester.scrollUntilVisible(newVersion, -300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(newVersion), alignment: 0.4);
    await tester.pumpAndSettle();
    await tester.tap(newVersion);
    await tester.pumpAndSettle();
    await shot(tester, '14d_version_sheet');
    await tester.tap(_ci('Remix'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Physical edition'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('CD single'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await Scrollable.ensureVisible(tester.element(_ci('Versions & editions')),
        alignment: 0.2);
    await shot(tester, '14e_versions');
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
    await tester.tap(_ci('Continue'));
    await tester.pumpAndSettle();
    unawaited(showCelebration(
        ctx,
        EventLine(const ChartDebut(Charts.globalSongs, EntityKind.song, 0, 64),
            title: 'Kiss (Silent Hours)', songId: hit),
        state));
    await shot(tester, '25_celebration_first_chart');
    await tester.tap(_ci('Continue'));
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
    await tester.tap(_ci('June Harper'));
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
    await tester.tap(
        find.textContaining(RegExp('^creativity\$', caseSensitive: false)));
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

    // Corner styles side by side, same moment (docs F1); the firm style
    // is the default (K88).
    await tab(tester, 'Home');
    app.settings.setSharpCorners(false);
    await tester.pumpAndSettle();
    await shot(tester, '26_home_soft');
    app.settings.setSharpCorners(true);
    await tester.pumpAndSettle();
    await shot(tester, '27_home_sharp');
    await tab(tester, 'Studio');
    await shot(tester, '28_studio_sharp');
    app.settings.setSharpCorners(false);
    await tester.pumpAndSettle();
    await shot(tester, '29_studio_soft');
    app.settings.setSharpCorners(true);
  });
  testWidgets('screenshots: a discography', skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);

    // A star with five albums over four years (docs K86).
    final c = app.controller;
    final port = ReceivePort();
    await c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2014,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 86,
        ),
        port.sendPort));
    port.close();
    await c.run(_fiveAlbums());
    await c.exec(Cmd.closeCareer());

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    await tab(tester, 'Career');
    final disco = _ci('Discography & sales chart');
    await tester.scrollUntilVisible(disco, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(disco), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(disco);
    await shot(tester, '15k_sales_chart');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -640));
    await shot(tester, '15l_discography_list');

    // The Golden Record Awards of the last show (docs K91).
    await tester.pageBack();
    await tester.pumpAndSettle();
    final awards = _ci('See the awards');
    await tester.scrollUntilVisible(awards, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(awards), alignment: 0.5);
    await tester.pumpAndSettle();
    await shot(tester, '15m_awards_section');
    await tester.tap(awards);
    await shot(tester, '15n_awards');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(tester, '15o_awards_more');
  });
}

/// Five albums of ten songs, about forty weeks apart (screenshots, K86).
SessionCmd<void> _fiveAlbums() => (s) {
      const titles = [
        'Midnight Signals',
        'Golden Hour',
        'Paper Crowns',
        'Afterglow',
        'Northern Lights',
      ];
      for (final t in titles) {
        final ids = <int>[];
        for (var i = 0; i < 10; i++) {
          s.world.player!
            ..creativeEnergy = 100
            ..moneyCents = 1 << 40;
          ids.add(s.writeSong(budget: BudgetTier.high).id);
        }
        s.releaseAlbum(t, ids);
        s.advanceWeeks(40, stop: SkipStop.never);
      }
    };

/// A text in any letter case (labels are set in capitals in the default
/// style, docs K88).
Finder _ci(String text) => find.byWidgetPredicate((w) =>
    w is Text && w.data != null && w.data!.toLowerCase() == text.toLowerCase());
