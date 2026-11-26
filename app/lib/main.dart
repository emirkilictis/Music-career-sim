import 'package:flutter/material.dart';

import 'app.dart';
import 'boot/boot.dart';
import 'boot/start_failed.dart';
import 'core/error_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // What breaks is kept for a bug report (docs K307, K308).
  ErrorLog.install();
  try {
    final (controller, settings, images) = await boot();
    runApp(MusicCareerApp(
        controller: controller, settings: settings, images: images));
    watchForUpdates();
  } catch (e) {
    runApp(StartFailedApp(error: '$e'));
  }
}
