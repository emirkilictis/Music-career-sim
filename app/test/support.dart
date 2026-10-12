import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_career_sim/app.dart';
import 'package:music_career_sim/core/game_controller.dart';
import 'package:music_career_sim/core/images.dart';
import 'package:music_career_sim/core/settings.dart';

/// Real fonts so screenshots are readable (tests use a box font otherwise).
Future<void> loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
      '/bin/cache/artifacts/material_fonts';
  Future<ByteData> f(String name) async => ByteData.view(
      Uint8List.fromList(File('$dir/$name').readAsBytesSync()).buffer);
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Light', 'Black']) {
    roboto.addFont(f('Roboto-$w.ttf'));
  }
  await roboto.load();
  ByteData asset(String name) => ByteData.view(
      Uint8List.fromList(File('assets/fonts/$name').readAsBytesSync()).buffer);
  final figtree = FontLoader('Figtree');
  for (final w in [
    '400Regular',
    '500Medium',
    '600SemiBold',
    '700Bold',
    '800ExtraBold',
    '900Black'
  ]) {
    figtree.addFont(Future.value(asset('Figtree_$w.ttf')));
  }
  await figtree.load();
  final barlow = FontLoader('BarlowCondensed');
  for (final w in ['600SemiBold', '700Bold', '800ExtraBold']) {
    barlow.addFont(Future.value(asset('BarlowCondensed_$w.ttf')));
  }
  await barlow.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(f('MaterialIcons-Regular.otf'));
  await icons.load();
}

/// Phone-sized test window (iPhone 16 Pro: 393×852 points).
void phoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Stands in for the phone's photo picker: returns [next] (or cancels).
class FakePickSource implements ImagePickSource {
  String? next;
  @override
  Future<String?> pick() async => next;
}

/// Writes a simple two-color PNG (a stand-in photo). Call inside
/// `tester.runAsync`.
Future<String> makeTestImage(String path, Color a, Color b) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  const s = 256.0;
  canvas.drawRect(
      const Rect.fromLTWH(0, 0, s, s),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(s, s), [a, b]));
  canvas.drawCircle(const Offset(s * 0.62, s * 0.4), s * 0.22,
      Paint()..color = const Color(0xCCFFFFFF));
  final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
  return path;
}

class TestApp {
  TestApp._(this.dir, this.controller, this.settings, this.images, this.picker);
  final Directory dir;
  final LocalGameController controller;
  final AppSettings settings;
  final ImageStore images;
  final FakePickSource picker;

  static TestApp create({bool premium = false}) {
    final dir = Directory.systemTemp.createTempSync('mcs_app_');
    final settings = AppSettings(null)..premium = premium;
    final picker = FakePickSource();
    return TestApp._(dir, LocalGameController('${dir.path}/careers'), settings,
        ImageStore('${dir.path}/careers', source: picker), picker);
  }

  Widget get widget => MusicCareerApp(
      controller: controller, settings: settings, images: images);

  Future<void> dispose() async {
    await controller.dispose();
    dir.deleteSync(recursive: true);
  }
}
