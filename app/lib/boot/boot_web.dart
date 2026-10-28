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
    const careers = '/careers';
    final controller = LocalGameController.on(SaveSlots.on(fs, careers));
    final settings = await AppSettings.load(_LocalStorage('mcs.settings'));
    return (controller, settings, WebImageStore(fs, careers) as ImageStore);
  } finally {
    // The page's own loading logo makes way for the app.
    web.document.getElementById('loading')?.remove();
  }
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
