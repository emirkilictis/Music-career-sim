import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:web/web.dart' as web;

/// Room for [n] bytes in a browser array: copies to and from the browser
/// (storage, files, compression) are then single native copies (docs K218).
Uint8List newBytes(int n) => JSUint8Array.withLength(n).toDart;

/// gzip by the browser's own CompressionStream.
Future<Uint8List> gzipBytes(Uint8List data) =>
    _pipe(data, web.CompressionStream('gzip') as _Pair);

Future<Uint8List> gunzipBytes(Uint8List data) =>
    _pipe(data, web.DecompressionStream('gzip') as _Pair);

extension type _Pair._(JSObject _) implements JSObject {
  external web.ReadableStream get readable;
  external web.WritableStream get writable;
}

Future<Uint8List> _pipe(Uint8List data, _Pair through) async {
  final blob = web.Blob(<JSAny>[data.toJS].toJS);
  final out = blob.stream().pipeThrough(web.ReadableWritablePair(
      readable: through.readable, writable: through.writable));
  final buffer = await web.Response(out).arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

/// Hands a file to the player: a download (Safari asks where to keep it).
Future<void> saveFileAs(Uint8List bytes, String name, {Rect? origin}) async {
  final blob = web.Blob(<JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/octet-stream'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(a);
  a.click();
  a.remove();
  // Long enough for the download to start.
  Future<void>.delayed(const Duration(minutes: 1), () {
    web.URL.revokeObjectURL(url);
  });
}
