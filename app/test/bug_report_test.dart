import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_career_sim/core/backup.dart';
import 'package:music_career_sim/core/error_log.dart';
import 'package:music_career_sim/widgets/bug_report.dart';

void main() {
  // docs K307: a bug report is a backup with the player's words.
  test('a bug report keeps the save and the words', () async {
    final db = Uint8List.fromList(List.generate(5000, (i) => i % 251));
    ErrorLog.entries.clear();
    ErrorLog.add(StateError('boom'), StackTrace.current);
    final text = reportText(
        said: 'The album page went gray', artist: 'Nova', week: 2300,
        locale: 'tr-TR');
    expect(text, contains('The album page went gray'));
    expect(text, contains('Artist: Nova'));
    expect(text, contains('Bad state: boom'));
    final file = await CareerBackup(db, const {}, report: text).encode();
    final back = await CareerBackup.decode(file);
    expect(back.database, db);
    expect(back.report, text);
    // A plain backup has none.
    final plain =
        await CareerBackup.decode(await CareerBackup(db, const {}).encode());
    expect(plain.report, isNull);
  });

  test('the error log keeps the last ten', () {
    ErrorLog.entries.clear();
    for (var i = 0; i < 15; i++) {
      ErrorLog.add('error $i', null);
    }
    expect(ErrorLog.entries, hasLength(ErrorLog.size));
    expect(ErrorLog.entries.last, contains('error 14'));
    expect(ErrorLog.entries.first, contains('error 5'));
  });

  // docs K308: a part that fails to draw shows a panel, not a gray box,
  // wherever it was: in a list row with no height limit too.
  testWidgets('the error panel draws in any space and offers a report',
      (tester) async {
    var reported = 0;
    ErrorLog.reporter = (_) => reported++;
    addTearDown(() => ErrorLog.reporter = null);
    final details = FlutterErrorDetails(exception: StateError('broken'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          ErrorPanel(details: details),
          SizedBox(height: 120, child: ErrorPanel(details: details)),
          Row(children: [Expanded(child: ErrorPanel(details: details))]),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Something went wrong here.'), findsNWidgets(3));
    await tester.tap(find.text('Report a bug').first);
    expect(reported, 1);
  });
}
