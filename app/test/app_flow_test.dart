import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_career_sim/widgets/art.dart';

import 'support.dart';

/// Plays the main loop through the UI: create a career, write a song,
/// play a week, release a single, look at charts and career.
void main() {
  testWidgets('new career → write → next week → release → charts',
      (tester) async {
    phoneView(tester);
    final app = TestApp.create();
    addTearDown(app.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    expect(find.text('No careers yet'), findsOneWidget);

    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Luna Vale');
    await tester.tap(find.text('Start career'));
    await tester.pumpAndSettle();

    // In the game: name in the header, a full first week ahead.
    expect(find.text('Luna Vale'), findsWidgets);
    expect(find.text('January 2024, week 1'), findsOneWidget);
    expect(find.text('Play a week to see what happens.'), findsOneWidget);

    await tester.tap(find.text('Studio'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    expect(find.text('Song recorded'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Vault (1)'));
    expect(find.text('Vault (1)'), findsOneWidget);

    await tester.tap(find.text('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('January 2024, week 2'), findsOneWidget);

    await tester.tap(find.text('Releases'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release a single'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    // When: this week (the default).
    expect(find.text('When should it come out?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Promotion campaign'), findsOneWidget);
    await tester.tap(find.text('No promotion'));
    await tester.pumpAndSettle();
    expect(find.textContaining('is out!'), findsOneWidget);

    await tester.tap(find.text('Charts'));
    await tester.pumpAndSettle();
    expect(find.text('US TOP 100 SONGS'), findsOneWidget);
    expect(find.text('LW'), findsOneWidget);

    // A rival's song from the chart: its stats and week-by-week run, then
    // the artist's Streamify page.
    await tester.tap(find.byType(CoverArt).at(1));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Week by week on the charts'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Week by week on the charts'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Artist page'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('Artist page'));
    await tester.pumpAndSettle();
    expect(find.textContaining('monthly listeners'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Career'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('By region'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('By region'), findsOneWidget);

    // Platforms live on Home, not in the tab bar.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Streamify'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Streamify'));
    await tester.pumpAndSettle();
    expect(find.text('Your artist profile'), findsOneWidget);
    await tester.tap(find.text('Top 50 – Global'));
    await tester.pumpAndSettle();
    expect(find.textContaining('50 songs'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Skip menu: four weeks, then a summary.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Until something happens'), findsOneWidget);
    await tester.tap(find.text('4 weeks'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^(4 weeks played|Stopped after)')),
        findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // A skill point every week, spent on the Career tab.
    await tester.tap(find.text('Career'));
    await tester.pumpAndSettle();
    final left = RegExp(r'^(\d+) skill points to spend$');
    await tester.scrollUntilVisible(find.textContaining(left), -300,
        scrollable: find.byType(Scrollable).first);
    int points() => int.parse(left
        .firstMatch((tester.widget<Text>(find.textContaining(left))).data!)!
        .group(1)!);
    final before = points();
    expect(before, greaterThanOrEqualTo(2));
    await tester.ensureVisible(find.byTooltip('Raise Vocals'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Raise Vocals'));
    await tester.pumpAndSettle();
    expect(points(), before - 1);
  });

  testWidgets('free players see Premium starts locked', (tester) async {
    phoneView(tester);
    final app = TestApp.create();
    addTearDown(app.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Superstar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Superstar'));
    await tester.pump();
    expect(find.text('This start needs Premium.'), findsOneWidget);
  });

  testWidgets('own covers and artist photos replace the generated art',
      (tester) async {
    phoneView(tester);
    final app = TestApp.create();
    addTearDown(app.dispose);
    final photo = await tester.runAsync(() => makeTestImage(
        '${app.dir.path}/photo.png',
        const Color(0xFFFF5C9D),
        const Color(0xFF3B5BDB)));
    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Luna Vale');
    await tester.tap(find.text('Start career'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Studio'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);

    // Releasing a single: the campaign sheet offers a cover first.
    await tester.tap(find.text('Releases'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release a single'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Generated cover'), findsOneWidget);
    app.picker.next = photo;
    await tester.tap(find.text('Add cover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from photos'));
    await tester.pumpAndSettle();
    expect(find.text('Your own image'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    await tester.tap(find.text('No promotion'));
    await tester.pumpAndSettle();
    // The single's tile in Releases shows the uploaded cover.
    expect(find.byType(Image), findsWidgets);

    // Artist photo: general one from the Career tab.
    await tester.tap(find.text('Career'));
    await tester.pumpAndSettle();
    expect(find.text('Uses your profile photo'), findsOneWidget);
    app.picker.next = photo;
    await tester.ensureVisible(find.text('Profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from photos'));
    await tester.pumpAndSettle();
    expect(find.text('Uses your profile photo'), findsOneWidget);
    // One cover and one artist photo, stored with the career.
    expect(
        Directory('${app.dir.path}/careers')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.contains('/images/'))
            .length,
        2);
  });

  testWidgets('a single set for later, announced two weeks before',
      (tester) async {
    phoneView(tester);
    final app = TestApp.create();
    addTearDown(app.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New career'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Luna Vale');
    await tester.tap(find.text('Start career'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Studio'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Releases'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release a single'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('In 4 weeks'));
    await tester.pumpAndSettle();
    expect(find.text('Out: January 2024, week 5'), findsOneWidget);
    await tester.tap(find.text('2 weeks before'));
    await tester.pumpAndSettle();
    expect(find.text('Announcement: January 2024, week 3'), findsOneWidget);
    // Longer than the wait: not possible.
    expect(
        tester
            .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, '6 weeks before'))
            .onSelected,
        isNull);
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No promotion'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('is set for January 2024, week 5'), findsOneWidget);
    expect(find.text('Coming up'), findsOneWidget);
    final tile = find.textContaining('Announcement: January 2024, week 3');
    expect(tile, findsOneWidget);

    // Move it two weeks later, keeping the announcement plan.
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In 6 weeks'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Announcement: January 2024, week 5'),
        findsOneWidget);
    expect(find.textContaining('Out: February 2024, week 2'), findsOneWidget);
  });
}
