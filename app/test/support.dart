import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_career_sim/app.dart';
import 'package:music_career_sim/core/game_controller.dart';
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

class TestApp {
  TestApp._(this.dir, this.controller, this.settings);
  final Directory dir;
  final LocalGameController controller;
  final AppSettings settings;

  static TestApp create({bool premium = false}) {
    final dir = Directory.systemTemp.createTempSync('mcs_app_');
    final settings = AppSettings(null)..premium = premium;
    return TestApp._(dir, LocalGameController('${dir.path}/careers'), settings);
  }

  Widget get widget =>
      MusicCareerApp(controller: controller, settings: settings);

  Future<void> dispose() async {
    await controller.dispose();
    dir.deleteSync(recursive: true);
  }
}
