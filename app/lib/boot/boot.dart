/// How the app starts on each platform (docs K218): the device's files and
/// a game isolate, or the browser's storage on the UI's thread.
library;

export 'boot_io.dart' if (dart.library.js_interop) 'boot_web.dart';
