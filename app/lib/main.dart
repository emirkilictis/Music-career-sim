import 'package:flutter/material.dart';

import 'app.dart';
import 'boot/boot.dart';
import 'boot/start_failed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final (controller, settings, images) = await boot();
    runApp(MusicCareerApp(
        controller: controller, settings: settings, images: images));
  } catch (e) {
    runApp(StartFailedApp(error: '$e'));
  }
}
