import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../ui/palette.dart';

/// Lets the player choose the square of a photo that becomes a cover or an
/// artist photo (docs K221): drag and pinch, then use it. Returns the
/// square as a PNG, or null if they cancelled.
Future<Uint8List?> cropToSquare(BuildContext context, Uint8List bytes) =>
    cropTo(context, bytes);

/// [cropToSquare] for any shape: [aspect] is width over height (16 / 9 for
/// a video thumbnail; docs K246).
Future<Uint8List?> cropTo(BuildContext context, Uint8List bytes,
        {double aspect = 1}) =>
    Navigator.of(context).push<Uint8List>(MaterialPageRoute(
        fullscreenDialog: true, builder: (_) => _CropScreen(bytes, aspect)));

/// Width and height from a PNG's or a JPEG's header without decoding it
/// (null: another format, or a damaged file).
(int, int)? imageSize(Uint8List b) {
  if (b.length > 24 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E) {
    final v = ByteData.sublistView(b);
    return (v.getUint32(16), v.getUint32(20));
  }
  if (b.length > 4 && b[0] == 0xFF && b[1] == 0xD8) {
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) return null;
      final marker = b[i + 1];
      final len = (b[i + 2] << 8) | b[i + 3];
      // Start of frame (baseline, progressive…), not DHT/JPG/DAC.
      if (marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC) {
        return ((b[i + 7] << 8) | b[i + 8], (b[i + 5] << 8) | b[i + 6]);
      }
      i += 2 + len;
    }
  }
  return null;
}

class _CropScreen extends StatefulWidget {
  const _CropScreen(this.bytes, this.aspect);
  final Uint8List bytes;
  final double aspect;

  @override
  State<_CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<_CropScreen> {
  final _view = TransformationController();
  ui.Image? _image;
  double _side = 0;
  double _fit = 1;
  bool _placed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ui.instantiateImageCodec(widget.bytes).then((c) => c.getNextFrame()).then(
        (f) {
      if (mounted) setState(() => _image = f.image);
    }, onError: (_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _view.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _use() async {
    final img = _image;
    if (img == null || _busy) return;
    setState(() => _busy = true);
    // The square on screen, back in the photo's pixels.
    final inverse = Matrix4.inverted(_view.value);
    final a = MatrixUtils.transformPoint(inverse, Offset.zero) / _fit;
    final b = MatrixUtils.transformPoint(
            inverse, Offset(_side, _side / widget.aspect)) /
        _fit;
    final bounds =
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final src = Rect.fromPoints(a, b).intersect(bounds);
    final cap = widget.aspect == 1 ? 1024 : 1280;
    final out = math.min(cap, src.width.round()).clamp(1, cap);
    final outH = math.max(1, (out / widget.aspect).round());
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImageRect(
        img,
        src,
        Rect.fromLTWH(0, 0, out.toDouble(), outH.toDouble()),
        Paint()..filterQuality = FilterQuality.high);
    final square = await rec.endRecording().toImage(out, outH);
    final png = await square.toByteData(format: ui.ImageByteFormat.png);
    square.dispose();
    if (mounted) Navigator.pop(context, png?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final img = _image;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.cropTitle),
        actions: [
          TextButton(
              onPressed: img == null || _busy ? null : _use,
              child: Text(l.cropUse)),
        ],
      ),
      body: img == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              final aspect = widget.aspect;
              _side = math.min(box.maxWidth - 32,
                  (box.maxHeight - 112) * aspect);
              final frameH = _side / aspect;
              // The photo covers the frame at first, centred.
              _fit = math.max(_side / img.width, frameH / img.height);
              final w = img.width * _fit, h = img.height * _fit;
              if (!_placed) {
                _view.value = Matrix4.translationValues(
                    -(w - _side) / 2, -(h - frameH) / 2, 0);
                _placed = true;
              }
              return Column(children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.text, width: 2)),
                    child: SizedBox(
                      width: _side,
                      height: _side / aspect,
                      child: ClipRect(
                        child: InteractiveViewer(
                          transformationController: _view,
                          constrained: false,
                          minScale: 1,
                          maxScale: 6,
                          child: SizedBox(
                              width: w,
                              height: h,
                              child: RawImage(image: img, fit: BoxFit.fill)),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.cropHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              ]);
            }),
    );
  }
}
