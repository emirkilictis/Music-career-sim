import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/game_controller.dart';
import 'core/images.dart';
import 'core/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationSupportDirectory();
  final settings = await AppSettings.load(File('${docs.path}/settings.json'));
  final careers = '${docs.path}/careers';
  final controller = await IsolateGameController.spawn(careers);
  runApp(MusicCareerApp(
      controller: controller, settings: settings, images: ImageStore(careers)));
}
