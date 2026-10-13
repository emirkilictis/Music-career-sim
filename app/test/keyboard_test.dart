import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_career_sim/app.dart';

void main() {
  Widget form(TextEditingController c, FocusNode f) => MaterialApp(
        builder: (context, child) => DismissKeyboard(child: child!),
        home: Scaffold(
          body: ListView(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                  controller: c,
                  focusNode: f,
                  decoration: const InputDecoration(
                      labelText: 'Title', border: OutlineInputBorder())),
            ),
            for (var i = 0; i < 30; i++)
              CheckboxListTile(
                  value: false, onChanged: (_) {}, title: Text('Song $i')),
          ]),
        ),
      );

  testWidgets('tapping elsewhere or scrolling puts the keyboard away',
      (tester) async {
    final c = TextEditingController();
    final f = FocusNode();
    await tester.pumpWidget(form(c, f));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(f.hasFocus, isTrue);
    // A tap on the field itself keeps it.
    await tester
        .tapAt(tester.getTopLeft(find.byType(TextField)) + const Offset(6, 6));
    await tester.pump();
    expect(f.hasFocus, isTrue);
    // Picking a song puts the keyboard away.
    await tester.tap(find.text('Song 1'));
    await tester.pump();
    expect(f.hasFocus, isFalse);
    // So does scrolling the page.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(f.hasFocus, isTrue);
    await tester.drag(find.text('Song 3'), const Offset(0, -200));
    await tester.pump();
    expect(f.hasFocus, isFalse);
  });
}
