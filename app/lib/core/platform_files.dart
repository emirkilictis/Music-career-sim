/// Byte files on each platform (docs K219): compressing a backup and
/// handing it to the player.
library;

export 'platform_files_io.dart'
    if (dart.library.js_interop) 'platform_files_web.dart';
