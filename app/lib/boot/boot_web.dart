import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:game/game.dart';
import 'package:persistence/web.dart';
import 'package:web/web.dart' as web;

import '../core/game_controller.dart';
import '../core/images.dart';
import '../core/images_web.dart';
import '../core/settings.dart';

/// The app in a browser (docs K218): SQLite as WebAssembly on IndexedDB,
/// the game on the UI's thread (no isolates there), the settings in local
/// storage.
Future<(GameController, AppSettings, ImageStore)> boot() async {
  try {
    final fs = await WebSaveFs.open(wasm: Uri.base.resolve('sqlite3.wasm'));
    _fs = fs;
    const careers = '/careers';
    final controller = LocalGameController.on(SaveSlots.on(fs, careers));
    final settings = await AppSettings.load(_LocalStorage('mcs.settings'));
    return (controller, settings, WebImageStore(fs, careers) as ImageStore);
  } finally {
    // The page's own loading logo makes way for the app.
    web.document.getElementById('loading')?.remove();
  }
}

WebSaveFs? _fs;

/// The release this page runs (the commit, set by the web build; docs
/// K242). Empty in a local build: no update checks.
const _build = String.fromEnvironment('BUILD_ID');

/// A newer release is on the site: the page should reload.
final updateReady = ValueNotifier<bool>(false);

/// Looks for a newer release now, every 10 minutes and whenever the page
/// comes back into view (a Home Screen app stays open for days).
void watchForUpdates() {
  if (_build.isEmpty) return;
  Future<void> check() async {
    if (updateReady.value) return;
    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final r = await web.window
          .fetch('build.txt?t=$t'.toJS, web.RequestInit(cache: 'no-store'))
          .toDart;
      if (!r.ok) return;
      final id = (await r.text().toDart).toDart.trim();
      if (id.isNotEmpty && id != _build) updateReady.value = true;
    } catch (_) {}
  }

  check();
  Timer.periodic(const Duration(minutes: 10), (_) => check());
  web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) {
        if (web.document.visibilityState == 'visible') check();
      }).toJS);
}

/// Stores the saves, then reloads into the new release.
Future<void> applyUpdate() async {
  try {
    await _fs?.flush().timeout(const Duration(seconds: 3));
  } catch (_) {}
  web.window.location.reload();
}

class _LocalStorage implements SettingsStore {
  _LocalStorage(this.key);
  final String key;

  @override
  String? read() => web.window.localStorage.getItem(key);

  @override
  void write(String text) => web.window.localStorage.setItem(key, text);
}

/// Opened inside an app (X, Instagram, TikTok…) rather than the browser:
/// their browsers may wipe a site's storage when closed (docs K218).
bool inAppBrowser() {
  final ua = web.window.navigator.userAgent;
  const apps = [
    'Twitter',
    'Instagram',
    'FBAN',
    'FBAV',
    'TikTok',
    'musical_ly',
    'Snapchat',
    'Line/',
    'Discord',
    'GSA/'
  ];
  return apps.any(ua.contains);
}

const _tipSeen = 'mcs.homeScreenTipSeen';

/// On an iPhone or iPad browser, not yet as a Home Screen app: Safari may
/// clear a site's storage after 7 days without a visit, the Home Screen
/// app keeps it (docs K219). Shown until dismissed.
bool homeScreenTipDue() {
  final nav = web.window.navigator;
  final ua = nav.userAgent;
  final apple = ua.contains('iPhone') ||
      ua.contains('iPad') ||
      (ua.contains('Macintosh') && nav.maxTouchPoints > 1);
  if (!apple || inAppBrowser()) return false;
  if (web.window.matchMedia('(display-mode: standalone)').matches) {
    return false;
  }
  try {
    return web.window.localStorage.getItem(_tipSeen) == null;
  } catch (_) {
    return false;
  }
}

void dismissHomeScreenTip() {
  try {
    web.window.localStorage.setItem(_tipSeen, '1');
  } catch (_) {}
}
