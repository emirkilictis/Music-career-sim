import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/game.dart';
import 'package:music_career_sim/l10n/gen/app_localizations.dart';
import 'package:music_career_sim/screens/song_detail_screen.dart';

/// docs K312: a song the recurrent rule took off the chart says so.
void main() {
  testWidgets('a recurrent drop-off is explained on the song page',
      (tester) async {
    GameTime.baseYear = GameTime.defaultBaseYear;
    final week = GameTime.firstWeekOf(2030);
    ChartRecord record(int weeksOn, int lastPos) => ChartRecord(
        Charts.usSongs,
        ChartStats()
          ..peak = 3
          ..debutPos = 10
          ..weeksOn = weeksOn
          ..lastPos = lastPos);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(children: [
          ChartRecords(records: [record(30, 0)], week: week),
          ChartRecords(records: [record(30, 12)], week: week),
          ChartRecords(records: [record(8, 0)], week: week),
        ]),
      ),
    ));
    // Off after 30 weeks: the 26-week, #25 step (2025's rule).
    expect(find.textContaining('after 26 weeks, a song below #25'),
        findsOneWidget);
  });
}
