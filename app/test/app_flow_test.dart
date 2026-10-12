import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(find.text('Luna Vale'), findsOneWidget);
    expect(find.text('Week 1, 2024'), findsOneWidget);
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
    expect(find.text('Week 2, 2024'), findsOneWidget);

    await tester.tap(find.text('Releases'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release a single'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    expect(find.text('Promotion campaign'), findsOneWidget);
    await tester.tap(find.text('No promotion'));
    await tester.pumpAndSettle();
    expect(find.textContaining('is out!'), findsOneWidget);

    await tester.tap(find.text('Charts'));
    await tester.pumpAndSettle();
    expect(find.text('US Top 100 Songs'), findsOneWidget);

    await tester.tap(find.text('Career'));
    await tester.pumpAndSettle();
    expect(find.text('By region'), findsOneWidget);
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
}
