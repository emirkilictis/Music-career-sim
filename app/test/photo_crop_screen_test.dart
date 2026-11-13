import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_career_sim/l10n/gen/app_localizations.dart';
import 'package:music_career_sim/widgets/photo_crop.dart';

/// A wide photo: red on the left half, blue on the right.
Future<Uint8List> _wide() async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, 200, 100),
      Paint()..color = const Color(0xFFFF0000));
  c.drawRect(const Rect.fromLTWH(200, 0, 200, 100),
      Paint()..color = const Color(0xFF0000FF));
  final img = await rec.endRecording().toImage(400, 100);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

Future<(int, int, ByteData)> _decode(Uint8List bytes) async {
  final f = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
  final data = await f.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return (f.image.width, f.image.height, data!);
}

(int, int, int) _pixel((int, int, ByteData) img, int x, int y) {
  final (w, _, d) = img;
  final i = (y * w + x) * 4;
  return (d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2));
}

void main() {
  // docs K301: the whole photo can be fitted, not only its middle square.
  Future<(int, int, ByteData)> Function(String) setUp(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return (String button) async {
      final bytes = (await tester.runAsync(_wide))!;
      Uint8List? out;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => out = await cropToSquare(context, bytes),
            child: const Text('pick'),
          ),
        ),
      ));
      await tester.tap(find.text('pick'));
      for (var i = 0; i < 40 && find.text(button).evaluate().isEmpty; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      // The zoom slider follows the shortcut.
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value,
          button == 'Fit the whole photo' ? slider.min : greaterThan(slider.min));
      await tester.tap(find.text('Use'));
      for (var i = 0; i < 20 && out == null; i++) {
        await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      return (await tester.runAsync(() => _decode(out!)))!;
    };
  }

  testWidgets('a wide photo fits whole in the square', (tester) async {
    final crop = setUp(tester);
    // The whole photo: both halves across the square, the rest filled.
    final whole = await crop('Fit the whole photo');
    expect(whole.$1, whole.$2);
    final mid = whole.$2 ~/ 2;
    final left = _pixel(whole, whole.$1 ~/ 8, mid);
    final right = _pixel(whole, whole.$1 * 7 ~/ 8, mid);
    expect(left.$1, greaterThan(200)); // red
    expect(right.$3, greaterThan(200)); // blue
    // Above the photo: filled, not transparent black only.
    final top = _pixel(whole, whole.$1 ~/ 8, 2);
    expect(top.$1 + top.$2 + top.$3, greaterThan(0));
  });

  testWidgets('or fills it from the middle', (tester) async {
    final crop = setUp(tester);
    // Filling the frame: the middle of the photo, red meeting blue.
    final fill = await crop('Fill the frame');
    expect(fill.$1, fill.$2);
    final l = _pixel(fill, fill.$1 ~/ 8, fill.$2 ~/ 2);
    final r = _pixel(fill, fill.$1 * 7 ~/ 8, fill.$2 ~/ 2);
    expect(l.$1, greaterThan(200));
    expect(r.$3, greaterThan(200));
    expect(_pixel(fill, fill.$1 ~/ 8, 2).$1, greaterThan(200));
  });
}
