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
import 'package:music_career_sim/core/game_controller.dart';
import 'package:music_career_sim/core/event_lines.dart';
import 'package:music_career_sim/core/scope.dart';
import 'package:music_career_sim/screens/charts_tab.dart';
import 'package:music_career_sim/screens/rival_editor_screen.dart';
import 'package:music_career_sim/screens/social_screen.dart';
import 'package:music_career_sim/screens/streamify/editorial_page.dart';
import 'package:music_career_sim/screens/streamify/this_is_page.dart';
import 'package:music_career_sim/widgets/art.dart';
import 'package:music_career_sim/widgets/celebration.dart';
import 'package:music_career_sim/widgets/media_tile.dart';
import 'package:music_career_sim/widgets/removal_alert.dart';

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

  /// The discography's sales chart as it is shared, whole (docs K241).
  Future<void> card(WidgetTester tester, String name) async {
    final chart = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_SalesChartCard');
    if (chart.evaluate().isEmpty) return; // nothing to chart
    final boundary = tester.renderObject<RenderRepaintBoundary>(find
        .ancestor(of: chart, matching: find.byType(RepaintBoundary))
        .first);
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

  /// Opens a part of the Career tab (its chips at the top).
  Future<void> careerPage(WidgetTester tester, String name) async {
    await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, name), -300,
        scrollable: find.byType(Scrollable).first);
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, name))
        .onSelected!(true);
    await tester.pumpAndSettle();
    // Back to the top of the new part.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
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
    await tester.runAsync(() => c.exec(Cmd.start(
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
        PortSink(port.sendPort))));
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
    // The lead single goes to independent curators (docs K160).
    await c.run(Cmd.submitToCurators(songs.first, CuratorPack.medium));
    await c.run(Cmd.nextWeek());
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
    final fame = find.textContaining(RegExp('^fame\$', caseSensitive: false));
    await tester.scrollUntilVisible(fame, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(fame);
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
    await tester.ensureVisible(_ci('Edition 2'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Edition 2'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_ci('Edition 3'));
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
    // The release calendar (K177).
    await tester.scrollUntilVisible(_ci('Release calendar'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(_ci('Release calendar'));
    await tester.pumpAndSettle();
    await shot(tester, '06d_calendar');
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
    await careerPage(tester, 'Business');
    await tester.scrollUntilVisible(_ci('See labels'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('See labels'));
    await shot(tester, '15c_labels');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Discography and the sales chart of covers (K86).
    await careerPage(tester, 'Track record');
    final disco = _ci('Discography & sales chart');
    await tester.scrollUntilVisible(disco, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(disco), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(disco);
    await shot(tester, '15i_discography');
    // The shared images, whole (docs K241).
    await card(tester, '15i_share_albums');
    await tester.tap(find.text('Singles').first);
    await tester.pumpAndSettle();
    await card(tester, '15i_share_singles');
    await tester.tap(find.text('Albums').first);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await shot(tester, '15j_discography_list');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await careerPage(tester, 'Stage');
    await tester.scrollUntilVisible(_ci('Plan a tour'), 200,
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
    await tester.scrollUntilVisible(_ci('TOURS'), 200,
        scrollable: find
            .byWidgetPredicate((w) =>
                w is Scrollable && w.axisDirection == AxisDirection.right)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('TOURS'));
    await shot(tester, '08b_top_tours');
    await tab(tester, 'Career');
    await careerPage(tester, 'Me');
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
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Behind the scenes'));
    await tester.pumpAndSettle();
    await shot(tester, '04g_social_compose');
    await tester.tap(find.text('Post'));
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
    // The player's channel and its uploads (docs K142).
    await tester.scrollUntilVisible(_ci('Open your channel'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Open your channel'));
    await tester.pumpAndSettle();
    await shot(tester, '09k_channel');
    await tester.tap(_ci('Upload a video'));
    await tester.pumpAndSettle();
    await shot(tester, '09l_channel_upload');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
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
    // Buying the masters back from the label (docs K162).
    final buyBack = find.textContaining('Buy the masters back');
    await tester.scrollUntilVisible(buyBack, 200,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(buyBack), alignment: 0.5);
    await tester.pumpAndSettle();
    await shot(tester, '14m_buy_masters');
    await tester.scrollUntilVisible(_ci('Week by week on the charts'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await shot(tester, '14b_album_weekly');
    // The critics' panel (docs K112).
    final meta = _ci('Metascore');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(meta, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(meta), alignment: 0.3);
    await tester.pumpAndSettle();
    await shot(tester, '14h_reviews');
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
    // Pitch, autoplay and bought streams (docs K95-K97).
    final tools = _ci('Streaming tools');
    await tester.scrollUntilVisible(tools, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(tools), alignment: 0.15);
    await tester.pumpAndSettle();
    await shot(tester, '14f_streaming_tools');
    // The tools sit in groups (docs K198).
    await tester.tap(find.widgetWithText(ExpansionTile, 'Ads and creators'));
    await tester.pumpAndSettle();
    final buy = _ci('Buy streams');
    await tester.scrollUntilVisible(buy, 200,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(buy), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(buy);
    await tester.pumpAndSettle();
    await shot(tester, '14g_buy_streams');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    // What independent curators said (docs K160).
    final lists = find.widgetWithText(ExpansionTile, 'Playlists');
    await tester.scrollUntilVisible(lists, -200,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(lists), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(lists);
    await tester.pumpAndSettle();
    final answers = _ci('See their answers');
    await tester.scrollUntilVisible(answers, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(answers), alignment: 0.4);
    await tester.pumpAndSettle();
    await shot(tester, '14i_curators');
    await tester.tap(answers);
    await tester.pumpAndSettle();
    await shot(tester, '14j_curator_answers');
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
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
    // Bought streams caught and removed (docs K95, F65).
    unawaited(showRemovalAlert(
        ctx,
        EventLine(BotsCaught(hit, 4.2e6, refundCents: 1029000),
            title: 'Kiss (Silent Hours)', songId: hit)));
    await shot(tester, '25b_streams_removed');
    await tester.tap(_ci('Continue'));
    await tester.pumpAndSettle();
    // A skip plays on and tells what happened at the end (docs K203).
    await tester.tap(_ci('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('8 weeks'));
    await tester.pumpAndSettle();
    await shot(tester, '15c_skip_summary');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(tester, '15d_skip_summary_more');
    await tester.scrollUntilVisible(_ci('Back to the game'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(_ci('Back to the game'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Back to the game'));
    await tester.pumpAndSettle();
    // Finished songs from songwriters (docs K205).
    await tab(tester, 'Studio');
    final market = _ci('See the demos');
    await tester.scrollUntilVisible(market, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(market);
    await tester.pumpAndSettle();
    await shot(tester, '05k_song_market');
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
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'June Harper',
          genre: 0,
          startYear: 2002,
          tier: StartTier.risingStar,
          money: StartMoney.comfortable,
          premium: true,
          seed: 2002,
        ),
        PortSink(port.sendPort))));
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
    // Before social media: the fan forum (docs K94).
    final forum = _ci('Open the feed');
    await tester.scrollUntilVisible(forum, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(forum), alignment: 0.4);
    await tester.pumpAndSettle();
    await tester.tap(forum);
    await shot(tester, '21b_fan_forum');
    await tester.pageBack();
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
  testWidgets('screenshots: plaques and the stream counter', skip: !enabled,
      (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2019,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 209,
        ),
        PortSink(port.sendPort))));
    port.close();
    // An album and its singles, half a year on (docs K209, K210).
    await c.run((s) {
      final p = s.world.player!;
      p.moneyCents = 1 << 40;
      final songs = <int>[];
      for (var i = 0; i < 10; i++) {
        p.creativeEnergy = 100;
        songs.add(s.writeSong(budget: BudgetTier.high, title: 'Track ${i + 1}').id);
      }
      s.releaseSingle(songs.first);
      s.advanceWeeks(3, stop: SkipStop.never);
      s.releaseAlbum('Gold Rush', songs);
      s.advanceWeeks(30, stop: SkipStop.never);
    });
    await c.exec(Cmd.closeCareer());
    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    await tab(tester, 'Career');
    await careerPage(tester, 'Track record');
    final plaques = _ci('My plaques');
    await tester.scrollUntilVisible(plaques, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(plaques);
    await tester.pumpAndSettle();
    await shot(tester, '15ze_plaques');
    await tester.tap(find.text('Gold Rush').first);
    await tester.pumpAndSettle();
    await shot(tester, '15zf_plaque');
    await tester.tap(_ci('Close'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tab(tester, 'Releases');
    final album = _ci('Gold Rush').first;
    await tester.scrollUntilVisible(album, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(album);
    await tester.pumpAndSettle();
    final counter = _ci('Stream counter');
    await tester.scrollUntilVisible(counter, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(counter);
    await tester.pumpAndSettle();
    await shot(tester, '14o_stream_counter');
  });
  testWidgets('screenshots: album versions and an anniversary',
      skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    // The world is built in turns (docs K218): in real time.
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2019,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 225,
        ),
        PortSink(port.sendPort))));
    port.close();
    await tester.runAsync(() => c.run((s) {
      final p = s.world.player!;
      p.moneyCents = 1 << 40;
      final songs = <int>[];
      for (var i = 0; i < 10; i++) {
        p.creativeEnergy = 100;
        songs.add(
            s.writeSong(budget: BudgetTier.high, title: 'Track ${i + 1}').id);
      }
      s.releaseAlbum('Gold Rush', songs);
      s.advanceWeeks(6, stop: SkipStop.never);
      for (var i = 0; i < 3; i++) {
        p.creativeEnergy = 100;
        s.writeSong(budget: BudgetTier.high, title: 'Vault ${i + 1}');
      }
    }));
    await c.exec(Cmd.closeCareer());
    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    // An album of hers from ten years ago (docs K226).
    await c.run((s) {
      final w = s.world;
      final gold = w.albums.lastWhere((a) => a.title == 'Gold Rush');
      w.albums.add(Album(
          id: w.albums.length,
          title: 'Paper Hearts',
          artistId: w.playerArtistId,
          type: AlbumType.album,
          releaseWeek: w.week - 10 * GameTime.weeksPerYear,
          songIds: List.of(gold.songIds),
          quality: 78)
        ..status = AlbumStatus.dormant);
    });
    await tester.tap(_ci('Next week'));
    for (var i = 0; i < 12 && _ci('Anniversary').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future.delayed(Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      if (i > 3 && _ci('Anniversary').evaluate().isEmpty) {
        await tester.tapAt(const Offset(200, 80));
      }
    }
    await tester.pump(const Duration(seconds: 1));
    await shot(tester, '16a_anniversary_prompt');
    await tester.tap(_ci('Make an anniversary edition'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future.delayed(Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    await shot(tester, '16b_anniversary_edition');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // Two versions of the new album (docs K225).
    await tester.runAsync(() => c.run((s) {
      final w = s.world;
      final gold = w.albums.lastWhere((a) => a.title == 'Gold Rush');
      final vault = s.vault;
      s.releaseAlbumVersion(gold.id,
          name: '3am Edition',
          songIds: [vault[0].id, vault[1].id],
          format: EditionFormat.vinyl);
      s.advanceWeeks(4, stop: SkipStop.never);
      s.releaseAlbumVersion(gold.id,
          name: 'Platinum Edition', songIds: [vault[2].id]);
    }));
    await tab(tester, 'Releases');
    final album = _ci('Gold Rush').first;
    await tester.scrollUntilVisible(album, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(album);
    await tester.pumpAndSettle();
    await shot(tester, '16c_album_versions_top');
    final editions = _ci('Editions');
    await tester.scrollUntilVisible(editions, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await shot(tester, '16d_album_editions');
    await tester.scrollUntilVisible(_ci('Tracklist'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await shot(tester, '16e_album_bonus_tracks');
    await tester.scrollUntilVisible(_ci('New version'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(_ci('New version'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future.delayed(Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    await shot(tester, '16f_new_version');
  });
  testWidgets('screenshots: award submissions and a crisis',
      skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2019,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 227,
        ),
        PortSink(port.sendPort))));
    port.close();
    // A year of records, up to the awards submissions (docs K227).
    await tester.runAsync(() => c.run((s) {
          final p = s.world.player!;
          p.moneyCents = 1 << 40;
          final songs = <int>[];
          for (var i = 0; i < 10; i++) {
            p.creativeEnergy = 100;
            songs.add(s
                .writeSong(budget: BudgetTier.high, title: 'Track ${i + 1}')
                .id);
          }
          s.releaseSingle(songs.first);
          s.advanceWeeks(3, stop: SkipStop.never);
          s.releaseSingle(songs[1]);
          s.advanceWeeks(3, stop: SkipStop.never);
          s.releaseAlbum('Gold Rush', songs);
          while (GameTime.weekOfYear(s.week) < Awards.windowStartWeekOfYear) {
            s.advanceWeek();
          }
          // A hate wave to answer (docs K228).
          p.opportunity =
              Opportunity(kind: OpportunityKind.hateWave, week: s.week);
          s.world.dirtyArtists.add(p.id);
          s.writeSong(budget: BudgetTier.low);
        }));
    await c.exec(Cmd.closeCareer());
    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .removeCurrentSnackBar();
    final crisis = _ci('Hate wave');
    await tester.scrollUntilVisible(crisis, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await shot(tester, '17a_crisis');
    await tab(tester, 'Career');
    await careerPage(tester, 'Track record');
    final subs = _ci('Choose submissions');
    await tester.scrollUntilVisible(subs, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await shot(tester, '17b_submissions_card');
    await tester.tap(subs);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future.delayed(Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    await shot(tester, '17c_submissions');
  });
  testWidgets('screenshots: a beef', skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2019,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 229,
        ),
        PortSink(port.sendPort))));
    port.close();
    // A diss post and a diss track at the biggest rival (docs K229).
    await tester.runAsync(() => c.run((s) {
          final p = s.world.player!;
          p.moneyCents = 1 << 40;
          final rival = s.dissTargets.first.artistId;
          s.dissPost(rival);
          s.advanceWeeks(2, stop: SkipStop.never);
          p.creativeEnergy = 100;
          final diss = s.writeSong(
              budget: BudgetTier.high, title: 'Smaller Now', dissTarget: rival);
          s.releaseSingle(diss.id);
          s.advanceWeeks(2, stop: SkipStop.never);
          // Until the rival answers in a post of their own (docs K234).
          bool posted() => s.world.social.feed.any((i) =>
              i.topic == FanTopic.rivalPost &&
              i.week >= s.world.week - 1 &&
              i.artistId == s.beefs.active?.rivalId);
          for (var i = 0; i < 30 && !posted(); i++) {
            if (s.beefs.active == null) {
              s.dissPost(s.dissTargets.firstWhere((t) => t.block == null).artistId);
            }
            s.advanceWeeks(1, stop: SkipStop.never);
          }
        }));
    await c.exec(Cmd.closeCareer());
    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    final feed = _ci('Open the feed');
    await tester.scrollUntilVisible(feed, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(feed);
    await tester.pumpAndSettle();
    await shot(tester, '18a_beef_feed');
    // Diss from the compose sheet (docs K234).
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clap back').last);
    await tester.pumpAndSettle();
    await shot(tester, '18d_beef_compose');
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.local_fire_department_rounded).first);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future.delayed(Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    await shot(tester, '18b_beef');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    await shot(tester, '18c_beef_more');
  });
  testWidgets('screenshots: post replies', skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2019,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 238,
        ),
        PortSink(port.sendPort))));
    port.close();
    // A hot take: fans and haters reply (docs K238).
    await tester.runAsync(() => c.run((s) {
          s.advanceWeeks(1, stop: SkipStop.never);
          s.post(PostKind.hotTake);
        }));
    await c.exec(Cmd.closeCareer());
    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    final feed = _ci('Open the feed');
    await tester.scrollUntilVisible(feed, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(feed);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -560));
    await tester.pumpAndSettle();
    await tester.tap(find.text('For you').hitTestable().evaluate().isEmpty
        ? find.byType(FeedPost).first
        : find.byType(FeedPost).first);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future.delayed(Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();
    await shot(tester, '19a_post_replies');
    await tester.tap(find.text('Thank').first);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future.delayed(Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();
    final roast = find.text('Clap back');
    if (roast.evaluate().isNotEmpty) {
      await tester.ensureVisible(roast.first);
      await tester.pumpAndSettle();
      await tester.tap(roast.first);
      for (var i = 0; i < 4; i++) {
        await tester
            .runAsync(() => Future.delayed(Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await shot(tester, '19b_post_answered');
  });
  testWidgets('screenshots: collabs with the singles', skip: !enabled,
      (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2019,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 230,
        ),
        PortSink(port.sendPort))));
    port.close();
    // A single of hers and two verses on rivals' songs (docs K158).
    await tester.runAsync(() => c.run((s) {
          final w = s.world;
          final p = w.player!;
          p.moneyCents = 1 << 40;
          p.creativeEnergy = 100;
          final song =
              s.writeSong(budget: BudgetTier.high, title: 'Gold Rush').id;
          s.releaseSingle(song);
          for (final rival in s.dissTargets.take(2)) {
            p.creativeEnergy = 100;
            p.opportunity = Opportunity(
                kind: OpportunityKind.feature,
                week: w.week,
                partnerArtistId: rival.artistId,
                feeCents: 1000000);
            s.answerOpportunity(OpportunityChoice.accept);
            s.advanceWeeks(3, stop: SkipStop.never);
          }
        }));
    await c.exec(Cmd.closeCareer());
    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    await tab(tester, 'Releases');
    final collabs = _ci('Collabs');
    await tester.scrollUntilVisible(collabs, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    await shot(tester, '19_collabs');
  });
  testWidgets('screenshots: plaques and the chart history', skip: !enabled,
      (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2019,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 232,
        ),
        PortSink(port.sendPort))));
    port.close();
    // Two albums with singles, a year and a half on (docs K231, K232).
    await tester.runAsync(() => c.run((s) {
          final p = s.world.player!;
          p.moneyCents = 1 << 40;
          for (final name in ['Gold Rush', 'Afterglow']) {
            final songs = <int>[];
            for (var i = 0; i < 10; i++) {
              p.creativeEnergy = 100;
              songs.add(s
                  .writeSong(
                      budget: BudgetTier.high, title: '$name ${i + 1}')
                  .id);
            }
            s.releaseSingle(songs.first);
            s.advanceWeeks(3, stop: SkipStop.never);
            s.releaseAlbum(name, songs);
            s.advanceWeeks(4, stop: SkipStop.never);
            s.releaseSingle(songs[1]);
            s.advanceWeeks(35, stop: SkipStop.never);
          }
        }));
    await c.exec(Cmd.closeCareer());
    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    await tab(tester, 'Career');
    await careerPage(tester, 'Track record');
    final plaques = _ci('My plaques');
    await tester.scrollUntilVisible(plaques, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(plaques);
    await tester.pumpAndSettle();
    await shot(tester, '20a_plaques');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await shot(tester, '20b_plaques_list');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(_ci('Chart history'));
    await tester.pumpAndSettle();
    await shot(tester, '20c_chart_history_songs');
    await tester.tap(_ci('Albums'));
    await tester.pumpAndSettle();
    await shot(tester, '20d_chart_history_albums');
    await tester.tap(_ci('Gold Rush').first);
    await tester.pumpAndSettle();
    await shot(tester, '20e_album_hits');
  });
  testWidgets('screenshots: posts with pictures', skip: !enabled,
      (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2019,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 211,
        ),
        PortSink(port.sendPort))));
    port.close();
    // A teaser, a single and the album after it (docs K211).
    await c.run((s) {
      final p = s.world.player!;
      p.moneyCents = 1 << 40;
      final songs = <int>[];
      for (var i = 0; i < 10; i++) {
        p.creativeEnergy = 100;
        songs.add(s.writeSong(budget: BudgetTier.high, title: 'Track ${i + 1}').id);
      }
      s.releaseSingle(songs.first);
      s.advanceWeeks(4, stop: SkipStop.never);
      s.post(PostKind.teaser);
      s.releaseAlbum('Gold Rush', songs);
      s.advanceWeeks(2, stop: SkipStop.never);
    });
    await c.exec(Cmd.closeCareer());
    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    final feed = _ci('Open the feed');
    await tester.scrollUntilVisible(feed, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(feed);
    await tester.pumpAndSettle();
    await shot(tester, '04h_feed_pictures');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await shot(tester, '04i_feed_pictures_more');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await shot(tester, '04j_feed_pictures_more');
  });
  testWidgets('screenshots: the rival editor', skip: !enabled,
      (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2019,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 213,
        ),
        PortSink(port.sendPort))));
    port.close();
    await c.exec(Cmd.closeCareer());
    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    await tab(tester, 'Career');
    await careerPage(tester, 'Me');
    final open = _ci('Open the rival editor');
    await tester.scrollUntilVisible(open, 300,
        scrollable: find.byType(Scrollable).first);
    // The daily bonus note covers the bottom of the page for a while.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    await shot(tester, '15zg_rival_editor');
    await tester.tap(find
        .descendant(
            of: find.byType(RivalEditorScreen),
            matching: find.byIcon(Icons.edit_outlined))
        .first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Velvet Comet');
    await tester.pumpAndSettle();
    await shot(tester, '15zh_rival_edit');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await shot(tester, '15zi_rival_renamed');
  });
  testWidgets('screenshots: tour history', skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2018,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 208,
        ),
        PortSink(port.sendPort))));
    port.close();
    // Two tours played (docs K208).
    await c.run((s) {
      for (final legs in const [
        [
          TourLeg(TourMarket.usa, TourKind.arena, 12),
          TourLeg(TourMarket.ukIreland, TourKind.arena, 4),
        ],
        [
          TourLeg(TourMarket.usa, TourKind.stadium, 20),
          TourLeg(TourMarket.europe, TourKind.stadium, 10),
          TourLeg(TourMarket.latinAmerica, TourKind.stadium, 6),
        ],
      ]) {
        s.startTour(TourRequest(legs: legs));
        while (s.world.player!.tour != null) {
          s.advanceWeek();
        }
        s.advanceWeeks(8, stop: SkipStop.never);
      }
    });
    await c.exec(Cmd.closeCareer());
    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    await tab(tester, 'Career');
    await careerPage(tester, 'Stage');
    final history = _ci('Tour history');
    await tester.scrollUntilVisible(history, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(history);
    await tester.pumpAndSettle();
    await shot(tester, '15zc_tour_history');
    await tester.tap(find.textContaining('All-time').first);
    await tester.pumpAndSettle();
    await shot(tester, '15zd_tour_history_detail');
  });
  testWidgets('screenshots: a discography', skip: !enabled, (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);

    // A star with five albums over four years (docs K86).
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Nova Reyes',
          genre: 0,
          startYear: 2014,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 86,
        ),
        PortSink(port.sendPort))));
    port.close();
    await c.run(_fiveAlbums());
    await c.run((s) {
      // A playlist of the week's hits and two of her own (docs K159).
      // Her own label with two newcomers (docs K169).
      s.foundImprint('Reyes Records');
      for (final c in s.imprintCandidates.take(2)) {
        s.signToImprint(c.artistId);
      }
      s.createPlaylist('Sunday Drive');
      final picks = s.playlistCandidates;
      for (final x in picks.where((x) => !x.isPlayer).take(12)) {
        s.addToPlaylist(x.songId);
      }
      for (final x in picks.where((x) => x.isPlayer).take(2)) {
        s.addToPlaylist(x.songId);
      }
      s.advanceWeeks(8, stop: SkipStop.never);
    });
    // Two brand deals running, one task done (docs K102).
    await c.run((s) {
      final w = s.world, p = w.player!;
      Brands.sign(w, p, 3, 1800000000);
      Brands.sign(w, p, 7, 900000000);
      s.doDealTask(1, 0);
    });
    await c.exec(Cmd.closeCareer());

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Nova Reyes'));
    await tester.pumpAndSettle();
    final deals = find.byIcon(Icons.handshake_outlined);
    await tester.scrollUntilVisible(deals, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(deals), alignment: 0.1);
    await tester.pumpAndSettle();
    await shot(tester, '04h_brand_deals');
    // The year on the streaming app (docs K123).
    await tester.scrollUntilVisible(_ci('Streamify'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Streamify'));
    await tester.pumpAndSettle();
    await shot(tester, '09e_wrapped_banner');
    await tester.tap(find.textContaining('Wrapped is here'));
    await tester.pumpAndSettle();
    await shot(tester, '09f_wrapped');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
    await shot(tester, '09g_wrapped_more');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // The editors' playlists (docs K125).
    final editorial = _ci('Editorial playlists');
    await tester.scrollUntilVisible(editorial, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(editorial), alignment: 0.2);
    await tester.pumpAndSettle();
    await shot(tester, '09h_editorial');
    await tester.tap(find.text('Hot Right Now').first);
    await tester.pumpAndSettle();
    await shot(tester, '09i_editorial_playlist');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // The Billions Club at the end of the row (docs K132).
    await tester.scrollUntilVisible(find.byType(BillionsCover), 400,
        scrollable: find
            .byWidgetPredicate((w) =>
                w is Scrollable && w.axisDirection == AxisDirection.right)
            .last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BillionsCover));
    await tester.pumpAndSettle();
    await shot(tester, '09j_billions_club');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    // The player's own playlist (docs K159).
    await tester.tap(_ci('Sunday Drive').last);
    await tester.pumpAndSettle();
    await shot(tester, '09m_own_playlist');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // The player's own page: listeners over time, top cities (docs K130).
    await tester.tap(find.text('Nova Reyes').first);
    await tester.pumpAndSettle();
    final cities = _ci('Top cities');
    await tester.scrollUntilVisible(cities, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(cities), alignment: 0.4);
    await tester.pumpAndSettle();
    await shot(tester, '10c_my_audience');
    // The editors' This Is list (docs K189).
    final featuring = _ci('Featuring');
    await tester.scrollUntilVisible(featuring, -300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ThisIsCover));
    await tester.pumpAndSettle();
    await shot(tester, '10d_this_is');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    // The year-end charts (docs K110).
    await tab(tester, 'Charts');
    await tester.scrollUntilVisible(_ci('Year-end'), 200,
        scrollable: find
            .byWidgetPredicate((w) =>
                w is Scrollable && w.axisDirection == AxisDirection.right)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Year-end'));
    await shot(tester, '08d_year_end');
    // The year's best sellers, the player's own (F74).
    await tester.tap(_ci('US Albums').last);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Only mine'));
    await shot(tester, '08h_year_end_mine');
    // The songs of the summer (docs K137).
    await tester.tap(_ci('Only mine'));
    await tester.pumpAndSettle();
    final summer = _ci('Songs of the Summer');
    await tester.scrollUntilVisible(summer, 200,
        scrollable: find
            .byWidgetPredicate((w) =>
                w is Scrollable && w.axisDirection == AxisDirection.right)
            .at(1));
    await tester.pumpAndSettle();
    await tester.tap(summer);
    await shot(tester, '08j_songs_of_summer');
    // All-time records (docs K111).
    await tester.tap(_ci('Records'));
    await shot(tester, '08e_records');
    // Best sellers: all time and each year's best (docs K141).
    await tester.tap(_ci('Best sellers'));
    await tester.pumpAndSettle();
    await shot(tester, '08k_best_sellers');
    await tester.tap(_ci("Each year's best"));
    await tester.pumpAndSettle();
    await shot(tester, '08l_year_winners');
    await tester.tap(_ci('Records'));
    await tester.pumpAndSettle();
    // The week's top artists (docs K113).
    await tester.scrollUntilVisible(_ci('Artists'), -200,
        scrollable: find
            .byWidgetPredicate((w) =>
                w is Scrollable && w.axisDirection == AxisDirection.right)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Artists'));
    await shot(tester, '08f_top_artists');
    await tab(tester, 'Career');
    // Record money by source (docs K145).
    await careerPage(tester, 'Business');
    final income = _ci('Record money by source');
    await tester.scrollUntilVisible(income, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(income), alignment: 0.1);
    await tester.pumpAndSettle();
    await shot(tester, '15r_income');
    await careerPage(tester, 'Track record');
    final disco = _ci('Discography & sales chart');
    await tester.scrollUntilVisible(disco, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(disco), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(disco);
    await shot(tester, '15k_sales_chart');
    await card(tester, '15k_share_albums');
    await tester.tap(find.text('Singles').first);
    await tester.pumpAndSettle();
    await card(tester, '15k_share_singles');
    await tester.tap(find.text('Albums').first);
    await tester.pumpAndSettle();
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

    // Honours beyond the awards (docs K116).
    await tester.pageBack();
    await tester.pumpAndSettle();
    final honours = _ci('Honours');
    await tester.scrollUntilVisible(honours, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(honours), alignment: 0.2);
    await tester.pumpAndSettle();
    await shot(tester, '15q_honours');

    // A record deal: three shapes with their terms (docs K107).
    await careerPage(tester, 'Business');
    final labels = _ci('See labels');
    await tester.scrollUntilVisible(labels, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(labels), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(labels);
    await tester.pumpAndSettle();
    final sign = _ci('Sign').first;
    await tester.scrollUntilVisible(sign, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(sign), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(sign);
    await shot(tester, '15p_record_deal');
    // Her label (docs K169).
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    final label = _ci('Reyes Records');
    await tester.scrollUntilVisible(label, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(label), alignment: 0.05);
    await tester.pumpAndSettle();
    await shot(tester, '15u_own_label');
  });
  testWidgets('screenshots: a greatest hits album', skip: !enabled,
      (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);

    // Five albums in the CD era, then the best-of (docs K161).
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Dana Vale',
          genre: 0,
          startYear: 2001,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 161,
        ),
        PortSink(port.sendPort))));
    port.close();
    await c.run(_fiveAlbums());
    await c.run((s) {
      s.advanceWeeks(60, stop: SkipStop.never);
      s.world.player!
        ..creativeEnergy = 100
        ..moneyCents = 1 << 40;
      final fresh = s.writeSong(budget: BudgetTier.high, title: 'Home Again');
      final hits = [for (final h in s.compilationCandidates.take(14)) h.songId];
      final gh = s.releaseGreatestHits('Greatest Hits', hits, [fresh.id]);
      s.advanceWeeks(6, stop: SkipStop.never);
      // On sale this week (docs K163).
      s.cutAlbumPrice(gh.id, PriceCut.deep);
    });
    await c.exec(Cmd.closeCareer());

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Dana Vale'));
    await tester.pumpAndSettle();
    await tab(tester, 'Releases');
    final gh = _ci('Greatest Hits').first;
    await tester.scrollUntilVisible(gh, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(gh);
    await tester.pumpAndSettle();
    await shot(tester, '14k_greatest_hits');
    final hitsOn = _ci('The hits on it');
    await tester.scrollUntilVisible(hitsOn, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(hitsOn), alignment: 0.1);
    await tester.pumpAndSettle();
    await shot(tester, '14l_greatest_hits_tracks');
    final cut = _ci('Price cut on Fruit Tunes');
    await tester.scrollUntilVisible(cut, -300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(cut), alignment: 0.2);
    await tester.pumpAndSettle();
    await shot(tester, '14n_price_cut');
  });

  testWidgets('screenshots: a K-pop music show', skip: !enabled,
      (tester) async {
    await tester.runAsync(loadFonts);
    phoneView(tester);
    final app = TestApp.create(premium: true);
    addTearDown(app.dispose);

    // A K-pop group with two singles out (docs K114).
    final c = app.controller;
    final port = ReceivePort();
    await tester.runAsync(() => c.exec(Cmd.start(
        CareerSetup(
          name: 'Starlight',
          genre: MusicShow.genre,
          kind: ArtistKind.vocalGroup,
          members: const ['Yuna', 'Mira', 'Jin', 'Sora'],
          startYear: 2019,
          tier: StartTier.superstar,
          money: StartMoney.millionaire,
          premium: true,
          seed: 114,
        ),
        PortSink(port.sendPort))));
    port.close();
    await c.run((s) {
      for (final t in ['Moonrise', 'Paper Hearts']) {
        s.world.player!
          ..creativeEnergy = 100
          ..moneyCents = 1 << 40;
        final id = s.writeSong(budget: BudgetTier.high, title: t).id;
        s.releaseSingle(id);
        s.advanceWeeks(3, stop: SkipStop.never);
      }
      // Yuna's solo single and a verse on a star's song (docs K158).
      final p = s.world.player!..creativeEnergy = 100;
      final solo = s.writeSong(budget: BudgetTier.high, title: 'Blue Hour').id;
      s.releaseMemberSolo(0, solo);
      final star = s.world.artists.firstWhere(
          (a) => a.tier == ArtistTier.a && !a.isRetired && a.managedBy < 0);
      Credits.guestOn(s.world, star, p, producerSkill: 85);
      // The fan club (docs K164).
      s.openFanClub(ClubPrice.mid);
      s.advanceWeeks(4, stop: SkipStop.never);
    });
    await c.exec(Cmd.closeCareer());

    await tester.pumpWidget(RepaintBoundary(key: key, child: app.widget));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Starlight'));
    await tester.pumpAndSettle();
    await tab(tester, 'Charts');
    await tester.scrollUntilVisible(_ci('Music Peak'), 200,
        scrollable: find
            .byWidgetPredicate((w) =>
                w is Scrollable && w.axisDirection == AxisDirection.right)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Music Peak'));
    await shot(tester, '08g_music_show');
    await tab(tester, 'Career');
    await careerPage(tester, 'Group');
    final members = _ci("Members' solo records");
    await tester.scrollUntilVisible(members, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(members), alignment: 0.05);
    await tester.pumpAndSettle();
    await shot(tester, '15s_member_solos');
    // Songs built around one member (docs K193).
    final star = _ci('One star');
    await tester.scrollUntilVisible(star, -300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(star), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(star);
    await tester.pumpAndSettle();
    await shot(tester, '15x_line_split');
    await careerPage(tester, 'Business');
    final club = _ci('Fan club');
    await tester.scrollUntilVisible(club, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(club), alignment: 0.05);
    await tester.pumpAndSettle();
    await shot(tester, '15t_fan_club');
    // Mira leaves the group and the career goes on as her (docs K191).
    await careerPage(tester, 'Group');
    final leave = _ci('Leave the group, go solo');
    await tester.scrollUntilVisible(leave.at(1), 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(leave.at(1)), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(leave.at(1));
    await tester.pumpAndSettle();
    await shot(tester, '15u_go_solo');
    await tester.tap(_ci('Go solo'));
    await tester.pumpAndSettle();
    expect(find.text('You are Mira now, on your own.'), findsOneWidget);
    final former = _ci('Your former group');
    await tester.scrollUntilVisible(former, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(former), alignment: 0.2);
    await tester.pumpAndSettle();
    await shot(tester, '15v_former_group');
    expect(find.text('Starlight'), findsWidgets);
    await tab(tester, 'Home');
    await shot(tester, '15w_solo_home');
    // Years later, the reunion (docs K194).
    await c.run((s) => s.world.playerSinceWeek -= Reunions.gapWeeks + 5 * 52);
    final careerState =
        Scope.read<CareerState>(tester.element(find.text('Next week')));
    await careerState.refresh();
    await tester.pumpAndSettle();
    await tab(tester, 'Career');
    await careerPage(tester, 'Group');
    final reunite = _ci('Get back together');
    await tester.scrollUntilVisible(reunite, 300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(reunite), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(reunite);
    await tester.pumpAndSettle();
    await shot(tester, '15y_reunion');
    await tester.tap(_ci('Reunite'));
    await tester.pumpAndSettle();
    expect(find.text('Starlight is back together!'), findsOneWidget);
    final on = find.textContaining('Reunion on');
    await tester.scrollUntilVisible(on, -300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(on), alignment: 0.3);
    await tester.pumpAndSettle();
    await shot(tester, '15z_reunion_on');
    // The reunion tour (docs K196).
    await tester.tap(_ci('Reunion tour'));
    await tester.pumpAndSettle();
    await shot(tester, '15za_reunion_tour');
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
