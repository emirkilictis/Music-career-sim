import 'dart:io';

import 'package:flutter/material.dart';

/// A player's image: a file on the device, or on the web a data or blob
/// URL (docs K218).
Widget storedImage(String ref,
    {BoxFit? fit,
    double? width,
    double? height,
    int? cacheWidth,
    bool gaplessPlayback = false,
    ImageErrorWidgetBuilder? errorBuilder}) {
  final url = ref.startsWith('data:') ||
      ref.startsWith('blob:') ||
      ref.startsWith('http');
  return url
      ? Image.network(ref,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          gaplessPlayback: gaplessPlayback,
          errorBuilder: errorBuilder)
      : Image.file(File(ref),
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          gaplessPlayback: gaplessPlayback,
          errorBuilder: errorBuilder);
}
