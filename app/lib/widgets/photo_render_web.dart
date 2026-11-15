import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

import 'photo_render_io.dart' as flutter;

/// [flutter.renderPhoto] with the browser's canvas, as a JPEG (docs K302):
/// in the WebAssembly build Flutter's PNG of a drawn image came out the
/// size of the screen with the photo in a corner, so covers and photos
/// were cut on computers and tablets. Falls back to Flutter's canvas if
/// the browser's fails.
Future<Uint8List?> renderPhoto(Uint8List bytes, ui.Image image, Rect frame,
    int width, int height) async {
  try {
    return await _browser(bytes, image, frame, width, height);
  } catch (_) {
    return flutter.renderPhoto(bytes, image, frame, width, height);
  }
}

Future<Uint8List> _browser(Uint8List bytes, ui.Image image, Rect frame,
    int width, int height) async {
  final url = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS));
  try {
    final img = web.HTMLImageElement()..src = url;
    await img.decode().toDart;
    final nw = img.naturalWidth.toDouble(), nh = img.naturalHeight.toDouble();
    if (nw <= 0 || nh <= 0) throw StateError('empty image');
    // The frame was chosen on Flutter's copy of the photo; the browser's
    // is the same picture, its size can differ (a turned phone photo).
    final sx = nw / image.width, sy = nh / image.height;
    final f = Rect.fromLTRB(frame.left * sx, frame.top * sy,
        frame.right * sx, frame.bottom * sy);
    final bounds = Rect.fromLTWH(0, 0, nw, nh);
    final src = f.intersect(bounds);
    final k = width / f.width;
    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final ctx = canvas.context2D
      ..imageSmoothingEnabled = true
      ..imageSmoothingQuality = 'high';
    ctx.fillStyle = '#000'.toJS;
    ctx.fillRect(0, 0, width, height);
    if (src.width < f.width - 0.5 || src.height < f.height - 0.5) {
      // The edges the photo does not reach: the photo drawn tiny and
      // spread over the frame, which blurs it in every browser.
      final cover = math.max(width / nw, height / nh);
      final tiny = web.HTMLCanvasElement()
        ..width = 24
        ..height = math.max(1, (24 * height / width).round());
      final t = tiny.context2D..imageSmoothingEnabled = true;
      final tk = tiny.width / width;
      t.drawImage(img, (width - nw * cover) / 2 * tk,
          (height - nh * cover) / 2 * tk, nw * cover * tk, nh * cover * tk);
      ctx.drawImage(tiny, 0, 0, width, height);
      ctx.fillStyle = 'rgba(0,0,0,0.2)'.toJS;
      ctx.fillRect(0, 0, width, height);
    }
    if (!src.isEmpty) {
      ctx.drawImage(
          img,
          src.left,
          src.top,
          src.width,
          src.height,
          (src.left - f.left) * k,
          (src.top - f.top) * k,
          src.width * k,
          src.height * k);
    }
    final done = Completer<web.Blob?>();
    canvas.toBlob(
        ((web.Blob? b) => done.complete(b)).toJS, 'image/jpeg', 0.9.toJS);
    final blob = await done.future;
    if (blob == null) throw StateError('no image');
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
