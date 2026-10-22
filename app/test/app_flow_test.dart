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
    expect(_ci('No careers yet'), findsOneWidget);

    await tester.tap(_ci('New career'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Luna Vale');
    await tester.tap(_ci('Start career'));
    await tester.pumpAndSettle();

    // In the game: name in the header, a full first week ahead.
    expect(_ci('Luna Vale'), findsWidgets);
    expect(_ci('January 2024, week 1'), findsOneWidget);
    expect(_ci('Play a week to see what happens.'), findsOneWidget);

    await tester.tap(_ci('Studio'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    expect(_ci('Song recorded'), findsOneWidget);
    await tester.tap(_ci('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_ci('Vault (1)'));
    expect(_ci('Vault (1)'), findsOneWidget);

    await tester.tap(_ci('Next week'));
    await tester.pumpAndSettle();
    expect(_ci('January 2024, week 2'), findsOneWidget);

    await tester.tap(_ci('Releases'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Release a single'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    // When: this week (the default).
    expect(_ci('When should it come out?'), findsOneWidget);
    await tester.tap(_ci('Continue'));
    await tester.pumpAndSettle();
    expect(_ci('Promotion campaign'), findsOneWidget);
    await tester.tap(_ci('No promotion'));
    await tester.pumpAndSettle();
    // Then the radio push, paid apart (K84).
    expect(_ci('Radio push'), findsWidgets);
    await tester.tap(_ci('No radio push'));
    await tester.pumpAndSettle();
    // Then pitch and autoplay, in the streaming era (K101).
    if (_ci('Streaming tools').evaluate().isNotEmpty) {
      await tester.tap(_ci('Continue').last);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('is out!'), findsOneWidget);

    await tester.tap(_ci('Charts'));
    await tester.pumpAndSettle();
    expect(_ci('US TOP 100 SONGS'), findsOneWidget);
    expect(_ci('LW'), findsOneWidget);

    // A rival's song from the chart: its stats and week-by-week run, then
    // the artist's Streamify page.
    await tester.tap(find.byType(CoverArt).at(1));
    await tester.pumpAndSettle();
    // The row opens its week first (K89); then the page.
    expect(_ci('Streams'), findsWidgets);
    await tester.tap(_ci('Song page'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_ci('Week by week on the charts'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(_ci('Week by week on the charts'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Artist page'), -300,
        scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(
        tester.element(find.textContaining('Artist page')),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Artist page'));
    await tester.pumpAndSettle();
    expect(find.textContaining('monthly listeners'), findsOneWidget);
    expect(_ci('Popular'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(_ci('Career'));
    await tester.pumpAndSettle();
    // The career's totals are under its track record.
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Track record'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_ci('By region'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(_ci('By region'), findsOneWidget);

    // Platforms live on Home, not in the tab bar.
    await tester.tap(_ci('Home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_ci('Streamify'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Streamify'));
    await tester.pumpAndSettle();
    expect(_ci('Your artist profile'), findsOneWidget);
    await tester.tap(_ci('Top 50 – Global'));
    await tester.pumpAndSettle();
    expect(find.textContaining('50 songs'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Skip menu: four weeks without stopping, then the summary page (K203).
    await tester.tap(_ci('Skip'));
    await tester.pumpAndSettle();
    expect(_ci('26 weeks'), findsOneWidget);
    await tester.tap(_ci('4 weeks'));
    await tester.pumpAndSettle();
    expect(_ci('4 weeks played'), findsOneWidget);
    await tester.scrollUntilVisible(_ci('Back to the game'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(_ci('Back to the game'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Back to the game'));
    await tester.pumpAndSettle();

    // A skill point every week, spent on the Career tab.
    await tester.tap(_ci('Career'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Me'), -300,
        scrollable: find.byType(Scrollable).first);
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Me'))
        .onSelected!(true);
    await tester.pumpAndSettle();
    final left = RegExp(r'^(\d+) skill points to spend$');
    await tester.scrollUntilVisible(find.textContaining(left), -300,
        scrollable: find.byType(Scrollable).first);
    int points() => int.parse(left
        .firstMatch((tester.widget<Text>(find.textContaining(left))).data!)!
        .group(1)!);
    final before = points();
    expect(before, greaterThanOrEqualTo(2));
    // Centred: at the very top the floating money bar covers it.
    await Scrollable.ensureVisible(
        tester.element(find.byTooltip('Raise Vocals')),
        alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Raise Vocals'));
    await tester.pumpAndSettle();
    expect(points(), before - 1);
    // All the rest at once, lowest skill first (F34).
    await tester.ensureVisible(_ci('Spread all'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Spread all'));
    await tester.pumpAndSettle();
    expect(find.textContaining(left), findsNothing);
  });

  testWidgets('free players see Premium starts locked', (tester) async {
    phoneView(tester);
    final app = TestApp.create();
    addTearDown(app.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(_ci('New career'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_ci('Superstar'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Superstar'));
    await tester.pump();
    expect(_ci('This start needs Premium.'), findsOneWidget);
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
    await tester.tap(_ci('New career'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Luna Vale');
    await tester.tap(_ci('Start career'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Studio'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);

    // Releasing a single: the campaign sheet offers a cover first.
    await tester.tap(_ci('Releases'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Release a single'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Continue'));
    await tester.pumpAndSettle();
    expect(_ci('Generated cover'), findsOneWidget);
    app.picker.next = photo;
    await tester.tap(_ci('Add cover'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Choose from photos'));
    await tester.pumpAndSettle();
    expect(_ci('Your own image'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    await tester.tap(_ci('No promotion'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('No radio push'));
    await tester.pumpAndSettle();
    // Then pitch and autoplay, in the streaming era (K101).
    if (_ci('Streaming tools').evaluate().isNotEmpty) {
      await tester.tap(_ci('Continue').last);
      await tester.pumpAndSettle();
    }
    // The single's tile in Releases shows the uploaded cover.
    expect(find.byType(Image), findsWidgets);

    // Artist photo: general one from the Career tab.
    await tester.tap(_ci('Career'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_ci('Uses your profile photo'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(_ci('Uses your profile photo'), findsOneWidget);
    app.picker.next = photo;
    await tester.ensureVisible(_ci('Profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Profile photo'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Choose from photos'));
    await tester.pumpAndSettle();
    expect(_ci('Uses your profile photo'), findsOneWidget);
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
    await tester.tap(_ci('New career'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Luna Vale');
    await tester.tap(_ci('Start career'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Studio'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Write & record'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('OK'));
    await tester.pumpAndSettle();

    await tester.tap(_ci('Releases'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Release a single'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'In 4 weeks'));
    await tester.pumpAndSettle();
    expect(_ci('Out: January 2024, week 5'), findsOneWidget);
    await tester.tap(_ci('2 weeks before'));
    await tester.pumpAndSettle();
    expect(_ci('Announcement: January 2024, week 3'), findsOneWidget);
    // Longer than the wait: not possible.
    expect(
        tester
            .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, '6 weeks before'))
            .onSelected,
        isNull);
    await tester.ensureVisible(_ci('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('No promotion'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('No radio push'));
    await tester.pumpAndSettle();
    // Then pitch and autoplay, in the streaming era (K101).
    if (_ci('Streaming tools').evaluate().isNotEmpty) {
      await tester.tap(_ci('Continue').last);
      await tester.pumpAndSettle();
    }
    expect(
        find.textContaining('is set for January 2024, week 5'), findsOneWidget);
    expect(_ci('Coming up'), findsOneWidget);
    final tile = find.textContaining('Announcement: January 2024, week 3');
    expect(tile, findsOneWidget);

    // Move it two weeks later, keeping the announcement plan.
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(_ci('Change date'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'In 6 weeks'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_ci('Save'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Announcement: January 2024, week 5'),
        findsOneWidget);
    expect(find.textContaining('Out: February 2024, week 2'), findsOneWidget);
  });

  testWidgets('an EP kept in the vault, released later (F31)', (tester) async {
    phoneView(tester);
    final app = TestApp.create();
    addTearDown(app.dispose);
    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(_ci('New career'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Luna Vale');
    await tester.tap(_ci('Start career'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Studio'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.textContaining('Write & record'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Write & record'));
      await tester.pumpAndSettle();
      await tester.tap(_ci('OK'));
      await tester.pumpAndSettle();
    }

    await tester.tap(_ci('Releases'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('New album / EP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Someday');
    await tester.tap(_ci('EP'));
    await tester.pumpAndSettle();
    for (final box in find.byType(CheckboxListTile).evaluate().toList()) {
      await tester.tap(find.byWidget(box.widget));
      await tester.pumpAndSettle();
    }
    await tester.tap(_ci('Keep in vault'));
    await tester.pumpAndSettle();
    expect(find.textContaining('is waiting in your vault'), findsOneWidget);
    expect(_ci('Drafts in your vault'), findsOneWidget);
    expect(_ci('Coming up'), findsNothing);

    // Weeks later it comes out.
    await tester.tap(_ci('Next week'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Someday'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('Release now'));
    await tester.pumpAndSettle();
    await tester.tap(_ci('No promotion'));
    await tester.pumpAndSettle();
    expect(_ci('“Someday” is out!'), findsOneWidget);
    expect(_ci('Drafts in your vault'), findsNothing);
  });
}

/// A text in any letter case (labels are set in capitals in the default
/// style, docs K88).
Finder _ci(String text) => find.byWidgetPredicate((w) =>
    w is Text && w.data != null && w.data!.toLowerCase() == text.toLowerCase());
