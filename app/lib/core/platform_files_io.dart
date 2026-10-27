import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

/// Room for [n] bytes.
Uint8List newBytes(int n) => Uint8List(n);

/// gzip, away from the UI thread.
Future<Uint8List> gzipBytes(Uint8List data) =>
    Isolate.run(() => Uint8List.fromList(gzip.encode(data)));

Future<Uint8List> gunzipBytes(Uint8List data) =>
    Isolate.run(() => Uint8List.fromList(gzip.decode(data)));

/// Hands a file to the player: the share sheet (Save to Files, AirDrop…).
Future<void> saveFileAs(Uint8List bytes, String name, {Rect? origin}) =>
    SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(bytes, mimeType: 'application/octet-stream', name: name)
      ],
      sharePositionOrigin: origin,
    ));
