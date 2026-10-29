import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';

import '../core/game_controller.dart';
import '../core/images.dart';
import '../core/settings.dart';

/// The app on a phone or a computer: files in the app's folder, the game
/// in its own isolate.
Future<(GameController, AppSettings, ImageStore)> boot() async {
  final docs = await getApplicationSupportDirectory();
  final settings = await AppSettings.load(
      FileSettingsStore(File('${docs.path}/settings.json')));
  final careers = '${docs.path}/careers';
  final controller = await IsolateGameController.spawn(careers);
  return (controller, settings, ImageStore(careers));
}

/// Only a browser has apps' own browsers (docs K218).
bool inAppBrowser() => false;

/// The Home Screen tip is for iPhone browsers (docs K219).
bool homeScreenTipDue() => false;
void dismissHomeScreenTip() {}

/// Apps update through the store; the web page checks itself (docs K242).
final updateReady = ValueNotifier<bool>(false);
void watchForUpdates() {}
Future<void> applyUpdate() async {}
