import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The part [frame] (in the photo's pixels; it may reach past the photo)
/// of [image] as a [width] × [height] PNG. Where the photo does not reach,
/// the photo itself fills in, blurred and spread over the frame.
Future<Uint8List?> renderPhoto(Uint8List bytes, ui.Image image, Rect frame,
    int width, int height) async {
  final bounds =
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  final src = frame.intersect(bounds);
  final k = width / frame.width;
  final whole = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  if (src.width < frame.width - 0.5 || src.height < frame.height - 0.5) {
    canvas.saveLayer(whole,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40));
    final cover = math.max(width / image.width, height / image.height);
    final cw = image.width * cover, ch = image.height * cover;
    canvas.drawImageRect(
        image,
        bounds,
        Rect.fromLTWH((width - cw) / 2, (height - ch) / 2, cw, ch),
        Paint()..filterQuality = FilterQuality.low);
    canvas.restore();
    canvas.drawRect(whole, Paint()..color = const Color(0x33000000));
  }
  if (!src.isEmpty) {
    canvas.drawImageRect(
        image,
        src,
        Rect.fromLTWH((src.left - frame.left) * k, (src.top - frame.top) * k,
            src.width * k, src.height * k),
        Paint()..filterQuality = FilterQuality.high);
  }
  final shot = await rec.endRecording().toImage(width, height);
  final png = await shot.toByteData(format: ui.ImageByteFormat.png);
  shot.dispose();
  return png?.buffer.asUint8List();
}
