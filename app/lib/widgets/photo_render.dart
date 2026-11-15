/// Draws the chosen part of a photo into a new image (docs K301, K302):
/// with Flutter's own canvas on phones and desktops, with the browser's
/// on the web.
library;

export 'photo_render_io.dart'
    if (dart.library.js_interop) 'photo_render_web.dart';
