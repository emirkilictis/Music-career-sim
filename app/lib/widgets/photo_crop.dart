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
  double _frameH = 0;

  /// The photo's size on screen at scale 1: covering the frame.
  double _fit = 1;

  /// The scale at which the whole photo fits in the frame (docs K301).
  double _whole = 1;
  bool _placed = false;
  bool _busy = false;

  static const _maxScale = 6.0;

  @override
  void initState() {
    super.initState();
    ui.instantiateImageCodec(widget.bytes).then((c) => c.getNextFrame()).then(
        (f) {
      if (mounted) setState(() => _image = f.image);
    }, onError: (_) {
      if (mounted) Navigator.pop(context);
    });
    _view.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _view.removeListener(_changed);
    _view.dispose();
    _image?.dispose();
    super.dispose();
  }

  double get _scale => _view.value.getMaxScaleOnAxis();

  /// Zooms to [scale] about the frame's middle, or with [centre] puts the
  /// photo's middle there.
  void _zoom(double scale, {bool centre = false}) {
    final img = _image;
    if (img == null) return;
    final s = scale.clamp(_whole, _maxScale).toDouble();
    final mid = Offset(_side / 2, _frameH / 2);
    final at = centre
        ? Offset(img.width * _fit / 2, img.height * _fit / 2)
        : MatrixUtils.transformPoint(Matrix4.inverted(_view.value), mid);
    _view.value = Matrix4.identity()
      ..translateByDouble(mid.dx - at.dx * s, mid.dy - at.dy * s, 0, 1)
      ..scaleByDouble(s, s, s, 1);
  }

  Future<void> _use() async {
    final img = _image;
    if (img == null || _busy) return;
    setState(() => _busy = true);
    // The frame on screen, back in the photo's pixels (it may reach past
    // the photo when zoomed out: that part is filled, docs K301).
    final inverse = Matrix4.inverted(_view.value);
    final a = MatrixUtils.transformPoint(inverse, Offset.zero) / _fit;
    final b =
        MatrixUtils.transformPoint(inverse, Offset(_side, _frameH)) / _fit;
    final frame = Rect.fromPoints(a, b);
    final bounds =
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final src = frame.intersect(bounds);
    final cap = widget.aspect == 1 ? 1024 : 1280;
    final out = math.min(cap, math.max(frame.width, 1).round()).clamp(1, cap);
    final outH = math.max(1, (out / widget.aspect).round());
    final k = out / frame.width;
    final whole = Rect.fromLTWH(0, 0, out.toDouble(), outH.toDouble());
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    if (src.width < frame.width - 0.5 || src.height < frame.height - 0.5) {
      // The edges the photo does not reach: the photo itself, blurred and
      // spread over the frame, as phones show it.
      canvas.saveLayer(whole,
          Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40));
      final cover = math.max(out / img.width, outH / img.height);
      final cw = img.width * cover, ch = img.height * cover;
      canvas.drawImageRect(
          img,
          bounds,
          Rect.fromLTWH((out - cw) / 2, (outH - ch) / 2, cw, ch),
          Paint()..filterQuality = FilterQuality.low);
      canvas.restore();
      canvas.drawRect(whole, Paint()..color = const Color(0x33000000));
    }
    if (!src.isEmpty) {
      canvas.drawImageRect(
          img,
          src,
          Rect.fromLTWH((src.left - frame.left) * k, (src.top - frame.top) * k,
              src.width * k, src.height * k),
          Paint()..filterQuality = FilterQuality.high);
    }
    final shot = await rec.endRecording().toImage(out, outH);
    final png = await shot.toByteData(format: ui.ImageByteFormat.png);
    shot.dispose();
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
              _side = math.min(
                  box.maxWidth - 32, (box.maxHeight - 220) * aspect);
              _frameH = _side / aspect;
              // At scale 1 the photo covers the frame; zoomed out to
              // [_whole] all of it shows (docs K301).
              _fit = math.max(_side / img.width, _frameH / img.height);
              _whole =
                  math.min(_side / img.width, _frameH / img.height) / _fit;
              final w = img.width * _fit, h = img.height * _fit;
              if (!_placed) {
                // Placed during the build: no rebuild for it.
                _view.removeListener(_changed);
                _view.value = Matrix4.translationValues(
                    -(w - _side) / 2, -(h - _frameH) / 2, 0);
                _view.addListener(_changed);
                _placed = true;
              }
              final scale = _scale.clamp(_whole, _maxScale).toDouble();
              return ListView(children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.text, width: 2)),
                    child: SizedBox(
                      width: _side,
                      height: _frameH,
                      child: ClipRect(
                        child: ColoredBox(
                          color: Colors.black,
                          child: InteractiveViewer(
                            transformationController: _view,
                            constrained: false,
                            minScale: _whole,
                            maxScale: _maxScale,
                            boundaryMargin:
                                const EdgeInsets.all(double.infinity),
                            child: SizedBox(
                                width: w,
                                height: h,
                                child: RawImage(image: img, fit: BoxFit.fill)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Zoom without pinching: a slider and two shortcuts (docs
                // K301; pinching zoomed the page on the web).
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(children: [
                    const Icon(Icons.zoom_out_rounded),
                    Expanded(
                      child: Slider(
                        value: scale,
                        min: _whole,
                        max: _maxScale,
                        onChanged: (v) => _zoom(v),
                      ),
                    ),
                    const Icon(Icons.zoom_in_rounded),
                  ]),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _zoom(_whole, centre: true),
                      icon: const Icon(Icons.fit_screen_rounded),
                      label: Text(l.cropWhole),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _zoom(1, centre: true),
                      icon: const Icon(Icons.crop_square_rounded),
                      label: Text(l.cropFill),
                    ),
                  ],
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
